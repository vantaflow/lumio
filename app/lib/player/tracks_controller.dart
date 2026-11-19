import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:lumio/l10n/app_localizations.dart';
import 'package:lumio/features/settings/settings_screen.dart'
    show languageChoices;
import 'package:lumio/l10n/app_localizations_fr.dart';
import 'package:lumio/player/playback_report.dart' show isIgnorableEngineError;
import 'package:lumio/player/subtitle_groups.dart';
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

/// Moteur capable de signaler qu'il a refusé un fichier de sous-titres
/// (message d'erreur libmpv sur un fichier externe).
abstract interface class SubtitleErrorSource {
  Stream<String> get subtitleErrors;
}

/// Implémentation media_kit / libmpv.
class MediaKitTracksBackend implements TracksBackend, SubtitleErrorSource {
  MediaKitTracksBackend(this._player, {AppLocalizations? l10n})
    : l10n = l10n ?? AppLocalizationsFr();
  final Player _player;

  /// Textes (pistes sans titre) ; mis à jour par l'écran selon la langue.
  AppLocalizations l10n;

  String _name(String id, String? title, String? lang, int i) {
    final parts = [
      if (title != null && title.isNotEmpty) title,
      if (lang != null && lang.isNotEmpty) lang,
    ];
    return parts.isEmpty ? l10n.trackN(i + 1) : parts.join(' · ');
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
  Stream<String> get subtitleErrors =>
      _player.stream.error.where(isIgnorableEngineError);

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

/// Fetcher des sous-titres : la connexion applique le même [allowPrivate] que
/// la garde de [downloadSubtitle] (un nom public résolvant vers une adresse
/// privée est refusé sauf addon approuvé sur le réseau privé).
HttpFetcher subtitleFetcher({required bool allowPrivate, HostLookup? lookup}) =>
    IoHttpFetcher(
      connectionFactory: guardedConnectionFactory(
        allowPrivate: allowPrivate,
        lookup: lookup,
      ),
    );

/// Télécharge un sous-titre d'addon : garde d'URL (adresse et redirections,
/// réseau privé seulement si l'addon du sous-titre y est autorisé), 2 Mo
/// maximum, statut 200 exigé. Lève dans les autres cas.
Future<List<int>> downloadSubtitle(
  HttpFetcher fetcher,
  Uri url, {
  required bool allowPrivate,
}) async {
  final r = await fetcher.get(
    url,
    maxBytes: subtitleMaxBytes,
    guard: (u) => UrlGuard.check(u, allowPrivate: allowPrivate),
  );
  if (r.status != 200) throw HttpException('statut ${r.status}');
  return r.body;
}

/// Dossier temporaire de session pour les sous-titres d'addons : noms sans
/// collision (SHA-1 de l'URL), supprimé en fin de session.
class SubtitleTempStore {
  SubtitleTempStore(this._base);

  /// Crée le dossier de session sous [_base] à la première écriture.
  final Future<Directory> Function() _base;
  Directory? _dir;

  Future<String> write(Uri url, String content) async {
    final dir = _dir ??= await (await _base()).createTemp('lumio-subs-');
    final name = sha1.convert(utf8.encode(url.toString())).toString();
    final f = File('${dir.path}/$name.srt');
    await f.writeAsString(content);
    return f.path;
  }

  Future<void> dispose() async {
    final d = _dir;
    _dir = null;
    try {
      if (d != null && await d.exists()) await d.delete(recursive: true);
    } on FileSystemException {
      // Dossier déjà parti ou verrouillé : le système purgera le cache.
    }
  }
}

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
    this.tempStore,
    SubtitleStyle style = const SubtitleStyle(),
    this.onStyleChanged,
    AppLocalizations? l10n,
    this.defaultAudioLang,
    this.defaultSubtitleLang,
    this.refusalWindow = const Duration(milliseconds: 1500),
  }) : _style = style,
       l10n = l10n ?? AppLocalizationsFr() {
    _settings = store.forTitle(profileId, metaId);
    _delay = _settings.subtitleDelayMs;
    _sub = backend.changes.listen((_) {
      _applyPreferences();
      _notify();
    });
  }

  final TracksBackend backend;

  /// Textes des messages d'erreur ; mis à jour par l'écran selon la langue.
  AppLocalizations l10n;

  /// Langues par défaut des réglages (code de langue, `off` pour aucun
  /// sous-titre) ; utilisées quand le titre n'a pas de mémorisation.
  final String? defaultAudioLang;
  final String? defaultSubtitleLang;

  /// Délai pendant lequel un refus du moteur annule le choix d'un sous-titre.
  final Duration refusalWindow;
  final TitleSettingsStore store;
  final String profileId;
  final String metaId;
  final List<SubtitleItem> addonSubtitles;

  /// Télécharge un sous-titre (voir [downloadSubtitle] ; la garde dépend de
  /// l'addon du sous-titre) ; lève en cas d'échec.
  final Future<List<int>> Function(SubtitleItem item)? download;

  /// Fichiers temporaires des sous-titres d'addons, supprimés à la fermeture.
  final SubtitleTempStore? tempStore;
  final void Function(SubtitleStyle)? onStyleChanged;

  late TitleSettings _settings;
  late int _delay;
  SubtitleStyle _style;
  StreamSubscription<void>? _sub;
  bool _appliedAudio = false;
  bool _appliedSubs = false;
  bool _disposed = false;
  String? _addonSelectedId;
  final _errors = StreamController<String>.broadcast();

  void _emit(String m) {
    if (!_disposed) _errors.add(m);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Messages d'erreur français à afficher (SnackBar).
  Stream<String> get errors => _errors.stream;

  /// Libellé d'un sous-titre d'addon : langue en clair, addon source et, si
  /// plusieurs sous-titres ont la même langue et la même source, leur rang.
  String addonLabel(SubtitleItem s) {
    String langName(String code) {
      for (final (c, n) in languageChoices(l10n)) {
        if (c == code) return n;
      }
      return languageDisplayName(code, l10n.localeName);
    }

    final name = s.addonName?.trim();
    final source = (name == null || name.isEmpty) ? l10n.addonFallback : name;
    final same = [
      for (final o in addonSubtitles)
        if (o.addonId == s.addonId && o.lang == s.lang) o,
    ];
    final lang = langName(s.lang);
    if (same.length < 2) return l10n.subtitleLabel(lang, source);
    return l10n.subtitleLabelN(lang, source, same.indexOf(s) + 1);
  }

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

  /// Les pistes sont connues dès que le moteur en liste au moins une.
  bool get _tracksKnown =>
      backend.audioTracks.isNotEmpty || backend.subtitleTracks.isNotEmpty;

  void _applyPreferences() {
    if (_disposed) return;
    final a = _settings.audioLang ?? defaultAudioLang;
    final audio = backend.audioTracks;
    if (!_appliedAudio && a != null && audio.isNotEmpty) {
      _appliedAudio = true;
      for (final t in audio) {
        if (_matches(t, audio, a)) {
          unawaited(backend.selectAudio(t.id));
          break;
        }
      }
    }
    final s = _settings.subtitleLang ?? defaultSubtitleLang;
    if (!_appliedSubs && s != null && _tracksKnown) {
      _appliedSubs = true;
      if (s == 'off') {
        unawaited(backend.selectSubtitle(null));
        return;
      }
      final subs = backend.subtitleTracks;
      for (final t in subs) {
        if (_matches(t, subs, s)) {
          unawaited(backend.selectSubtitle(t.id));
          return;
        }
      }
      // Pas de piste interne : repli sur le sous-titre d'addon de même langue.
      for (final item in addonSubtitles) {
        if (_sameLang(item.lang, s)) {
          unawaited(selectAddonSubtitle(item));
          return;
        }
      }
    }
  }

  static bool _sameLang(String? a, String b) =>
      a != null &&
      (a.toLowerCase().startsWith(b.toLowerCase()) ||
          normalizeLang(a) == normalizeLang(b));

  /// Mémorisation d'une piste : sa langue, sinon son rang (`idx:N`).
  static String _keyOf(TrackOption t, List<TrackOption> all) =>
      t.lang ?? 'idx:${all.indexOf(t)}';

  static bool _matches(TrackOption t, List<TrackOption> all, String pref) =>
      pref.startsWith('idx:')
      ? _keyOf(t, all) == pref
      : _sameLang(t.lang, pref);

  void _save(TitleSettings s) {
    _settings = s;
    try {
      store.save(profileId, metaId, s);
    } on Object {
      _emit(l10n.settingsNotSaved);
    }
  }

  Future<void> selectAudio(TrackOption t) async {
    _appliedAudio = true;
    await backend.selectAudio(t.id);
    _save(_settings.copyWith(audioLang: _keyOf(t, backend.audioTracks)));
    _notify();
  }

  Future<void> selectSubtitle(TrackOption? t) async {
    _appliedSubs = true;
    _addonSelectedId = null;
    await backend.selectSubtitle(t?.id);
    _save(
      _settings.copyWith(
        subtitleLang: t == null ? 'off' : _keyOf(t, backend.subtitleTracks),
      ),
    );
    _notify();
  }

  Future<void> selectAddonSubtitle(SubtitleItem item) async {
    final dl = download;
    final tmp = tempStore;
    if (dl == null || tmp == null) {
      _emit(l10n.subtitleUnreadable);
      return;
    }
    try {
      final bytes = await dl(item);
      final text = decodeSubtitleBytes(bytes);
      final path = await tmp.write(item.url, text);
      if (_disposed) return;
      final src = backend is SubtitleErrorSource
          ? (backend as SubtitleErrorSource).subtitleErrors
          : null;
      var refused = false;
      final sub = src?.listen((_) => refused = true);
      try {
        await backend.loadExternalSubtitle(path, title: item.lang);
        _appliedSubs = true;
        _addonSelectedId = item.id;
        _notify();
        // Le moteur signale un fichier refusé après coup : la ligne ne reste
        // pas marquée « choisie ».
        if (src != null) await Future<void>.delayed(refusalWindow);
      } finally {
        await sub?.cancel();
      }
      if (_disposed) return;
      if (refused) {
        if (_addonSelectedId == item.id) _addonSelectedId = null;
        _emit(l10n.subtitleUnreadable);
        _notify();
        return;
      }
      if (_addonSelectedId != item.id) return; // un autre choix a suivi
      _save(_settings.copyWith(subtitleLang: item.lang));
      _notify();
    } on Object {
      _emit(l10n.subtitleUnreadable);
    }
  }

  Future<void> changeDelay(int deltaMs) async {
    final v = (_delay + deltaMs).clamp(-subtitleDelayMaxMs, subtitleDelayMaxMs);
    if (v == _delay) return;
    _delay = v;
    await backend.setSubtitleDelay(v);
    _save(_settings.copyWith(subtitleDelayMs: v));
    _notify();
  }

  Future<void> setSize(SubtitleSize s) => _setStyle(_style.copyWith(size: s));

  Future<void> toggleBackground() =>
      _setStyle(_style.copyWith(opaqueBackground: !_style.opaqueBackground));

  Future<void> _setStyle(SubtitleStyle s) async {
    _style = s;
    await backend.applySubtitleStyle(s);
    onStyleChanged?.call(s);
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _errors.close();
    unawaited(tempStore?.dispose());
    super.dispose();
  }
}
