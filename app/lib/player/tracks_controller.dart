import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lumio/player/subtitle_style.dart';
import 'package:lumio_core/lumio_core.dart';
import 'package:media_kit/media_kit.dart';

/// Une piste proposée au choix (audio ou sous-titre interne).
class TrackOption {
  const TrackOption({required this.id, required this.label, this.lang});
  final String id;
  final String label;
  final String? lang;
}

/// Petite façade sur le moteur de lecture, remplaçable par un faux en test.
abstract class TracksBackend {
  List<TrackOption> get audioTracks;
  List<TrackOption> get subtitleTracks;
  String? get selectedAudioId;

  /// `null` = sous-titres désactivés.
  String? get selectedSubtitleId;

  /// Émet à chaque changement de pistes disponibles ou sélectionnées.
  Stream<void> get changes;

  Future<void> selectAudio(String id);

  /// [id] `null` désactive les sous-titres.
  Future<void> selectSubtitle(String? id);

  /// Charge un fichier de sous-titres local comme piste externe et le choisit.
  Future<void> loadExternalSubtitle(String path, {String? title, String? lang});

  Future<void> setSubtitleDelay(int ms);
  Future<void> applySubtitleStyle(SubtitleStyle style);
}

/// Implémentation media_kit / libmpv.
class MediaKitTracksBackend implements TracksBackend {
  MediaKitTracksBackend(this._player);
  final Player _player;

  static String _name(String id, String? title, String? lang, int i) {
    final parts = [
      if (title != null && title.isNotEmpty) title,
      if (lang != null && lang.isNotEmpty) lang,
    ];
    return parts.isEmpty ? 'Piste ${i + 1}' : parts.join(' · ');
  }

  bool _real(String id) => id != 'auto' && id != 'no';

  @override
  List<TrackOption> get audioTracks {
    final out = <TrackOption>[];
    for (final t in _player.state.tracks.audio.where((t) => _real(t.id))) {
      out.add(
        TrackOption(
          id: t.id,
          label: _name(t.id, t.title, t.language, out.length),
          lang: t.language,
        ),
      );
    }
    return out;
  }

  @override
  List<TrackOption> get subtitleTracks {
    final out = <TrackOption>[];
    for (final t in _player.state.tracks.subtitle.where((t) => _real(t.id))) {
      out.add(
        TrackOption(
          id: t.id,
          label: _name(t.id, t.title, t.language, out.length),
          lang: t.language,
        ),
      );
    }
    return out;
  }

  @override
  String? get selectedAudioId {
    final id = _player.state.track.audio.id;
    return _real(id) ? id : null;
  }

  @override
  String? get selectedSubtitleId {
    final id = _player.state.track.subtitle.id;
    return _real(id) ? id : null;
  }

  @override
  Stream<void> get changes => Stream.multi((c) {
    final subs = [
      _player.stream.tracks.listen((_) => c.add(null)),
      _player.stream.track.listen((_) => c.add(null)),
    ];
    c.onCancel = () {
      for (final s in subs) {
        s.cancel();
      }
    };
  });

  @override
  Future<void> selectAudio(String id) => _player.setAudioTrack(
    _player.state.tracks.audio.firstWhere((t) => t.id == id),
  );

  @override
  Future<void> selectSubtitle(String? id) => _player.setSubtitleTrack(
    id == null
        ? SubtitleTrack.no()
        : _player.state.tracks.subtitle.firstWhere((t) => t.id == id),
  );

  @override
  Future<void> loadExternalSubtitle(
    String path, {
    String? title,
    String? lang,
  }) => _player.setSubtitleTrack(
    SubtitleTrack.uri(Uri.file(path).toString(), title: title, language: lang),
  );

  Future<void> _prop(String name, String value) async {
    final p = _player.platform;
    if (p is NativePlayer) await p.setProperty(name, value);
  }

  @override
  Future<void> setSubtitleDelay(int ms) =>
      _prop('sub-delay', (ms / 1000).toStringAsFixed(3));

  @override
  Future<void> applySubtitleStyle(SubtitleStyle style) async {
    for (final e in style.mpvProperties.entries) {
      await _prop(e.key, e.value);
    }
  }
}

const subtitleDelayStepMs = 100;
const subtitleDelayMaxMs = 10000;
const subtitleMaxBytes = 2 * 1024 * 1024;

/// Logique du panneau : sélection, décalage, style, sous-titres d'addons,
/// mémorisation par titre (série).
class TracksController extends ChangeNotifier {
  TracksController({
    required this.backend,
    required this.store,
    required this.profileId,
    required this.metaId,
    this.addonSubtitles = const [],
    this.download,
    this.writeTemp,
    SubtitleStyle style = const SubtitleStyle(),
    this.onStyleChanged,
  }) : _style = style {
    _settings = store.forTitle(profileId, metaId);
    _delay = _settings.subtitleDelayMs;
    _sub = backend.changes.listen((_) {
      _applyPreferences();
      notifyListeners();
    });
  }

  final TracksBackend backend;
  final TitleSettingsStore store;
  final String profileId;
  final String metaId;
  final List<SubtitleItem> addonSubtitles;

  /// Télécharge un sous-titre (chemin gardé, 2 Mo max) ; lève en cas d'échec.
  final Future<List<int>> Function(Uri url)? download;

  /// Écrit le texte décodé dans un fichier temporaire et renvoie son chemin.
  final Future<String> Function(String name, String content)? writeTemp;
  final void Function(SubtitleStyle)? onStyleChanged;

  late TitleSettings _settings;
  late int _delay;
  SubtitleStyle _style;
  StreamSubscription<void>? _sub;
  bool _appliedAudio = false;
  bool _appliedSubs = false;
  String? _addonSelectedId;
  final _errors = StreamController<String>.broadcast();

  /// Messages d'erreur français à afficher (SnackBar).
  Stream<String> get errors => _errors.stream;

  int get delayMs => _delay;
  SubtitleStyle get style => _style;
  String? get addonSelectedId => _addonSelectedId;
  TitleSettings get settings => _settings;

  /// Applique les réglages mémorisés (délai, style) au moteur.
  Future<void> init() async {
    await backend.setSubtitleDelay(_delay);
    await backend.applySubtitleStyle(_style);
    _applyPreferences();
  }

  void _applyPreferences() {
    final a = _settings.audioLang;
    if (!_appliedAudio && a != null && backend.audioTracks.isNotEmpty) {
      _appliedAudio = true;
      for (final t in backend.audioTracks) {
        if (_sameLang(t.lang, a)) {
          unawaited(backend.selectAudio(t.id));
          break;
        }
      }
    }
    final s = _settings.subtitleLang;
    if (!_appliedSubs && s != null && backend.subtitleTracks.isNotEmpty) {
      _appliedSubs = true;
      if (s == 'off') {
        unawaited(backend.selectSubtitle(null));
      } else {
        for (final t in backend.subtitleTracks) {
          if (_sameLang(t.lang, s)) {
            unawaited(backend.selectSubtitle(t.id));
            break;
          }
        }
      }
    }
  }

  static bool _sameLang(String? a, String b) =>
      a != null && a.toLowerCase().startsWith(b.toLowerCase());

  void _save(TitleSettings s) {
    _settings = s;
    store.save(profileId, metaId, s);
  }

  Future<void> selectAudio(TrackOption t) async {
    _appliedAudio = true;
    await backend.selectAudio(t.id);
    if (t.lang != null) _save(_settings.copyWith(audioLang: t.lang));
    notifyListeners();
  }

  Future<void> selectSubtitle(TrackOption? t) async {
    _appliedSubs = true;
    _addonSelectedId = null;
    await backend.selectSubtitle(t?.id);
    _save(_settings.copyWith(subtitleLang: t == null ? 'off' : t.lang));
    notifyListeners();
  }

  Future<void> selectAddonSubtitle(SubtitleItem item) async {
    final dl = download;
    final tmp = writeTemp;
    if (dl == null || tmp == null) {
      _errors.add('Sous-titre illisible');
      return;
    }
    try {
      final bytes = await dl(item.url);
      final text = decodeSubtitleBytes(bytes);
      final path = await tmp('addon-${item.id.hashCode.abs()}.srt', text);
      await backend.loadExternalSubtitle(path, title: item.lang);
      _appliedSubs = true;
      _addonSelectedId = item.id;
      _save(_settings.copyWith(subtitleLang: item.lang));
      notifyListeners();
    } on Object {
      _errors.add('Sous-titre illisible');
    }
  }

  Future<void> changeDelay(int deltaMs) async {
    final v = (_delay + deltaMs).clamp(-subtitleDelayMaxMs, subtitleDelayMaxMs);
    if (v == _delay) return;
    _delay = v;
    await backend.setSubtitleDelay(v);
    _save(_settings.copyWith(subtitleDelayMs: v));
    notifyListeners();
  }

  Future<void> setSize(SubtitleSize s) => _setStyle(_style.copyWith(size: s));

  Future<void> toggleBackground() =>
      _setStyle(_style.copyWith(opaqueBackground: !_style.opaqueBackground));

  Future<void> _setStyle(SubtitleStyle s) async {
    _style = s;
    await backend.applySubtitleStyle(s);
    onStyleChanged?.call(s);
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _errors.close();
    super.dispose();
  }
}
