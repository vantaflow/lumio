import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumio/l10n/app_localizations.dart';
import 'package:lumio/l10n/app_localizations_fr.dart';
import 'package:lumio/player/local_proxy.dart';
import 'package:lumio/player/mpv_overrides.dart';
import 'package:lumio/player/play_router.dart';
import 'package:lumio/player/playback_report.dart';
import 'package:lumio/player/source_fallback.dart';
import 'package:lumio_core/lumio_core.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:lumio/player/next_episode_overlay.dart' show parseCreditsStart;

export 'package:lumio/player/playback_report.dart'
    show
        PlaybackReport,
        explainFailure,
        isIgnorableEngineError,
        redactEngineMessage;

/// État de lecture exposé à l'écran.
enum PlayerPhase { idle, opening, playing, paused, buffering, failed, ended }

class PlayerState {
  const PlayerState({
    this.phase = PlayerPhase.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.volume = 100,
    this.error,
    this.notice,
  });

  final PlayerPhase phase;
  final Duration position;
  final Duration duration;
  final Duration buffered;

  /// 0 à 100.
  final double volume;

  /// Message français, sans URL (voir [explainFailure]).
  final String? error;

  /// Information passagère affichée pendant l'ouverture (ex. basculement
  /// vers la source suivante).
  final String? notice;

  bool get isPlaying => phase == PlayerPhase.playing;

  PlayerState copyWith({
    PlayerPhase? phase,
    Duration? position,
    Duration? duration,
    Duration? buffered,
    double? volume,
    String? error,
    bool clearError = false,
    bool clearNotice = false,
  }) => PlayerState(
    phase: phase ?? this.phase,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    buffered: buffered ?? this.buffered,
    volume: volume ?? this.volume,
    error: clearError ? null : (error ?? this.error),
    notice: clearNotice ? null : notice,
  );
}

/// Pilote media_kit (libmpv) : passe par le proxy local pour le HLS et les
/// flux à en-têtes imposés, lit directement sinon.
class PlayerController {
  PlayerController({
    required Future<LocalProxy> Function() proxy,
    Player? player,
    this.stallTimeout = const Duration(seconds: 25),
    AppLocalizations? l10n,
  }) : l10n = l10n ?? AppLocalizationsFr(),
       _proxy = proxy,
       player =
           player ??
           Player(
             configuration: PlayerConfiguration(
               logLevel: mpvLogLevelFor(cachedMpvOverrides),
             ),
           ) {
    final cfg = videoConfigFor(
      android: Platform.isAndroid,
      overrides: cachedMpvOverrides,
    );
    video = VideoController(
      this.player,
      configuration: VideoControllerConfiguration(vo: cfg.vo, hwdec: cfg.hwdec),
    );
    _subs.addAll([
      this.player.stream.playing.listen((p) {
        _playing = p;
        _wake(p);
        _recompute();
      }),
      this.player.stream.buffering.listen((b) {
        _buffering = b;
        _recompute();
      }),
      this.player.stream.position.listen(
        (p) => _set(state.copyWith(position: p)),
      ),
      this.player.stream.duration.listen(
        (d) => _set(state.copyWith(duration: d)),
      ),
      this.player.stream.buffer.listen(
        (b) => _set(state.copyWith(buffered: b)),
      ),
      this.player.stream.volume.listen((v) => _set(state.copyWith(volume: v))),
      this.player.stream.completed.listen((c) {
        if (c) _set(state.copyWith(phase: PlayerPhase.ended));
      }),
      this.player.stream.width.listen((w) {
        if (w != null && w > 0) _onFirstFrame();
      }),
      this.player.stream.error.listen(_onEngineError),
      // Avertissements du moteur (jamais d'adresse) : cause des échecs HLS.
      this.player.stream.log.listen((l) {
        // ignore: avoid_print
        print(
          'LUMIO_PLAYER ${jsonEncode({'event': 'mpv_log', 'p': l.prefix, 'm': redactEngineMessage(l.text.trim())})}',
        );
      }),
    ]);
  }

  final Player player;
  late final VideoController video;
  bool _overridesApplied = false;

  Future<void> _setLavfFormat(String format) async {
    final p = player.platform;
    if (p is! NativePlayer) return;
    try {
      await p.setProperty('demuxer-lavf-format', format);
      // Sans `demuxer=lavf`, mpv essaie d'abord son lecteur de listes de
      // fichiers (« Reading plaintext playlist ») sur toute playlist .m3u8.
      await p.setProperty('demuxer', format.isEmpty ? '' : 'lavf');
      // ignore: avoid_print
      print('LUMIO_PLAYER {"event":"lavf_format","v":"$format"}');
    } on Object {
      // Option inconnue : la détection automatique reste en place.
    }
  }

  /// Applique une fois `mpv.conf` (réglages avancés, voir [loadMpvOverrides]).
  Future<void> _applyOverrides() async {
    if (_overridesApplied) return;
    _overridesApplied = true;
    final p = player.platform;
    if (p is! NativePlayer) return;
    final o = cachedMpvOverrides;
    for (final e in o.entries) {
      if (mpvControllerKeys.contains(e.key)) continue;
      try {
        await p.setProperty(e.key, e.value);
      } on Object {
        // Option inconnue de ce moteur : ignorée.
      }
    }
    if (o.isNotEmpty) {
      // ignore: avoid_print
      print(
        'LUMIO_PLAYER {"event":"mpv_overrides","keys":${jsonEncode(o.keys.toList())}}',
      );
    }
  }

  final Future<LocalProxy> Function() _proxy;

  /// Textes des messages d'erreur ; mis à jour par l'écran selon la langue.
  AppLocalizations l10n;

  /// Durée de mise en mémoire tampon continue avant de proposer une erreur.
  final Duration stallTimeout;

  final _subs = <StreamSubscription<Object?>>[];
  final _state = ValueNotifier<PlayerState>(const PlayerState());
  ValueListenable<PlayerState> get stateListenable => _state;
  PlayerState get state => _state.value;

  StreamSubscription<ProxyEvent>? _proxySub;
  Timer? _stall;
  Stopwatch? _sinceOpen;
  Completer<int>? _firstFrame;
  StreamItem? _item;
  bool _allowPrivate = false;
  bool _trustedLocal = false;
  LocalFileSource? _local;
  bool _refused = false;
  bool _viaProxy = false;
  bool _playing = false;
  bool _buffering = false;
  bool _opened = false;
  int? _lastStatus;
  bool _disposed = false;
  CastSource? _castSource;

  /// Source de la lecture en cours telle que le serveur de cast peut la
  /// relayer (fichier local, ou URL de nos composants sur la boucle locale :
  /// proxy ou moteur de torrents). `null` : rien d'ouvert ou flux non
  /// diffusable (playlist HLS). Ne sort jamais de l'appareil : seul le serveur
  /// de cast la lit.
  CastSource? get castSource => _castSource;

  // Basculement automatique (voir [playWithFallback]).
  int _runId = 0;
  Completer<bool>? _outcome;
  final _gate = AttemptGate();
  bool _failFallbackable = false;
  bool _holdFailure = false;
  String? _notice;

  /// Durée jusqu'à la première image (ms) ; `null` tant qu'elle n'est pas là.
  int? firstFrameMs;

  void _set(PlayerState s) {
    if (!_disposed) _state.value = s;
  }

  /// Ouvre [s] ; [allowPrivate] seulement pour un addon autorisé sur le réseau
  /// privé. [trustedLocal] : lecture directe réservée aux URL de nos propres
  /// composants (torrent), jamais aux données d'un addon. [local] : fichier
  /// d'un dossier local accordé (lecture `file://`). Échec : phase `failed` avec message ([PlayerState.error]).
  Future<void> open(
    StreamItem s, {
    bool allowPrivate = false,
    bool trustedLocal = false,
    LocalFileSource? local,
    Duration start = Duration.zero,
  }) async {
    final attempt = _gate.current;
    _gate.unbindEngine(); // rien du moteur avant l'ouverture de CE média
    _item = s;
    _allowPrivate = allowPrivate;
    _trustedLocal = trustedLocal;
    _local = local;
    _refused = false;
    _lastStatus = null;
    _castSource = null;
    firstFrameMs = null;
    _opened = false;
    _firstFrame = Completer<int>();
    _sinceOpen = Stopwatch()..start();
    _stall?.cancel();
    _statsTimer?.cancel();
    _set(
      PlayerState(
        phase: PlayerPhase.opening,
        volume: state.volume,
        notice: _notice,
      ),
    );
    final url = s.url;
    if (url == null || s.isTorrent) {
      _fail(l10n.torrentNotPlayable, attempt: attempt);
      return;
    }
    try {
      final route = await routePlayback(
        s,
        proxy: _proxy,
        allowPrivate: allowPrivate,
        trustedLocal: trustedLocal,
        local: local,
      );
      _viaProxy = route.kind == PlayRouteKind.proxy;
      _castSource = local != null
          ? CastFileSource(File(local.path))
          : (url.path.toLowerCase().endsWith('.m3u8')
                ? null
                : CastHttpSource(route.url, mimeType: mimeForPath(url.path)));
      if (_viaProxy) {
        _proxySub ??= (await _proxy()).events.listen((e) {
          if (e.status >= 400) _lastStatus = e.status;
          if (e.refused) _refused = true;
        });
      }
      final playUrl = route.url;
      await _applyOverrides();
      await _setLavfFormat(lavfFormatFor(url));
      if (!_gate.accepts(attempt)) return; // série abandonnée entre-temps
      _gate.bindEngine(attempt);
      await player.open(
        Media(playUrl.toString(), start: start == Duration.zero ? null : start),
      );
      _armStall(attempt);
    } catch (e) {
      _fail(
        explainFailure(
          e,
          httpStatus: _lastStatus,
          refused: _refused,
          l10n: l10n,
        ),
        attempt: attempt,
      );
    }
  }

  /// Relance la lecture depuis la dernière position connue.
  Future<void> retry() async {
    final s = _item;
    if (s == null) return;
    await open(
      s,
      allowPrivate: _allowPrivate,
      trustedLocal: _trustedLocal,
      local: _local,
      start: state.position,
    );
  }

  void _onFirstFrame() {
    if (!_gate.acceptsEngine) return; // image d'une source abandonnée
    final c = _firstFrame;
    if (c == null || c.isCompleted) return;
    firstFrameMs = _sinceOpen?.elapsedMilliseconds;
    // Journal de diagnostic (jamais d'adresse) : délai et chemin de la lecture.
    // ignore: avoid_print
    print(
      'LUMIO_PLAYER {"event":"first_frame","ms":$firstFrameMs,'
      '"via_proxy":$_viaProxy}',
    );
    _startStats();
    c.complete(firstFrameMs);
    _opened = true;
    _stall?.cancel();
    _notice = null;
    _set(state.copyWith(clearNotice: true));
    _settle(true);
  }

  Timer? _statsTimer;

  /// Image par image : toutes les 10 s, codec, décodeur matériel et images
  /// perdues (propriétés libmpv) dans le journal `LUMIO_PLAYER`.
  void _startStats() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      final p = player.platform;
      if (_disposed || p is! NativePlayer) return;
      try {
        final m = <String, String>{};
        for (final k in const [
          'video-format',
          'hwdec-current',
          'frame-drop-count',
          'decoder-frame-drop-count',
          'estimated-vf-fps',
          'container-fps',
        ]) {
          m[k] = await p.getProperty(k);
        }
        // ignore: avoid_print
        print('LUMIO_PLAYER ${jsonEncode({'event': 'stats', ...m})}');
      } on Object {
        // Propriété indisponible : sans importance.
      }
    });
  }

  /// Attend la première image (pour la mesure de la sonde de debug).
  Future<int> waitFirstFrame(Duration timeout) =>
      _firstFrame!.future.timeout(timeout);

  void _onEngineError(String message) {
    // Le moteur signale aussi des avertissements bénins après une image.
    if (_opened && message.isEmpty) return;
    if (!_gate.acceptsEngine) return; // erreur d'une source abandonnée
    // Journal de diagnostic (jamais d'adresse).
    // ignore: avoid_print
    print(
      'LUMIO_PLAYER {"event":"engine_error","opened":$_opened,"msg":'
      '${jsonEncode(redactEngineMessage(message))}}',
    );
    // Un sous-titre refusé n'est pas un échec de lecture.
    if (isIgnorableEngineError(message)) return;
    _fail(
      explainFailure(
        message,
        httpStatus: _lastStatus,
        refused: _refused,
        l10n: l10n,
      ),
    );
  }

  /// Affiche une erreur sans ouvrir de média (échec avant l'ouverture, par
  /// exemple la préparation d'un torrent). [fallbackable] : la source est en
  /// cause (le basculement peut essayer la suivante) ; sinon (VPN exigé,
  /// avertissement refusé, stockage) la suivante échouerait de même.
  void fail(String message, {bool fallbackable = false}) =>
      _fail(message, fallbackable: fallbackable);

  /// Repasse en phase d'ouverture (préparation d'un torrent en cours).
  void showOpening() {
    _stall?.cancel();
    _set(
      PlayerState(
        phase: PlayerPhase.opening,
        volume: state.volume,
        notice: _notice,
      ),
    );
  }

  void _fail(String message, {bool fallbackable = true, int? attempt}) {
    if (attempt != null && !_gate.accepts(attempt)) return; // signal périmé
    _stall?.cancel();
    _failFallbackable = fallbackable;
    if (_holdFailure && fallbackable) {
      // Une autre source va être essayée : pas d'écran d'erreur entre-temps.
      _set(
        PlayerState(
          phase: PlayerPhase.opening,
          volume: state.volume,
          notice: _notice,
        ),
      );
    } else {
      _notice = null;
      _set(
        state.copyWith(
          phase: PlayerPhase.failed,
          error: message,
          clearNotice: true,
        ),
      );
    }
    _settle(false);
  }

  /// Termine la tentative en cours. [id] : numéro de la tentative qui signale
  /// (un signal d'une tentative abandonnée est ignoré).
  void _settle(bool ok, {int? id}) {
    if (id != null && !_gate.accepts(id)) return;
    final c = _outcome;
    if (c != null && !c.isCompleted) c.complete(ok);
  }

  /// Ouvre la première source de [ranked] et, si elle échoue AVANT la
  /// première image (ouverture, refus du proxy, torrent sans source ou trop
  /// lent), essaie la suivante, [maxAttempts] sources au plus, avec la
  /// notice « Source indisponible… ». Jamais de bascule une fois la lecture
  /// commencée. [opener] ouvre une source en respectant toutes les gardes
  /// (adresse privée, VPN, avertissement IP) ; par défaut [open].
  /// Un échec qui n'est pas imputable à la source (VPN exigé…) arrête la
  /// série. Retourne la source qui a démarré, `null` si aucune.
  Future<StreamItem?> playWithFallback(
    List<StreamItem> ranked, {
    Future<void> Function(StreamItem item)? opener,
    int maxAttempts = 3,
    Duration attemptTimeout = const Duration(minutes: 3),
    Future<void> Function(StreamItem item)? onAbandon,
  }) async {
    final run = ++_runId;
    _settle(false); // libère une série précédente
    final open = opener ?? (StreamItem s) => this.open(s);
    try {
      return await runWithFallback<StreamItem>(
        ranked,
        maxAttempts: maxAttempts,
        cancelled: () => _disposed || run != _runId,
        attempt: (item, i, last) async {
          _notice = i == 0 ? null : l10n.playerSourceFallback;
          _holdFailure = !last;
          _failFallbackable = false;
          final id = _gate.begin();
          final outcome = _outcome = Completer<bool>();
          // Le délai court dès l'ouverture : une préparation bloquée est
          // bornée elle aussi.
          final ok =
              await (() async {
                await open(item);
                return outcome.future;
              })().timeout(
                attemptTimeout,
                onTimeout: () async {
                  // Trop long : cette source est abandonnée (lecteur arrêté,
                  // torrent libéré) avant de passer à la suivante.
                  await _abandon(item, onAbandon);
                  _fail(
                    explainFailure(TimeoutException('open'), l10n: l10n),
                    fallbackable: true,
                    attempt: id,
                  );
                  return false;
                },
              );
          if (!_gate.accepts(id)) return AttemptOutcome.stopped;
          if (ok) return AttemptOutcome.played;
          _stall?.cancel();
          return _failFallbackable
              ? AttemptOutcome.sourceFailed
              : AttemptOutcome.stopped;
        },
      );
    } finally {
      if (run == _runId) {
        _holdFailure = false;
        _notice = null;
        _outcome = null;
      }
    }
  }

  Future<void> _abandon(
    StreamItem item,
    Future<void> Function(StreamItem item)? onAbandon,
  ) async {
    try {
      await onAbandon?.call(item);
    } on Object {
      // Libération best effort.
    }
    try {
      await player.stop();
    } on Object {
      // Lecteur indisponible : rien à arrêter.
    }
  }

  void _recompute() {
    if (state.phase == PlayerPhase.failed) return;
    if (state.phase == PlayerPhase.opening && !_playing && !_buffering) return;
    if (state.phase == PlayerPhase.ended && !_playing && !_buffering) return;
    final phase = _buffering
        ? PlayerPhase.buffering
        : (_playing ? PlayerPhase.playing : PlayerPhase.paused);
    _set(state.copyWith(phase: phase, clearError: true));
    if (_buffering) {
      _armStall();
    } else {
      _stall?.cancel();
    }
  }

  void _armStall([int? attempt]) {
    final id = attempt ?? _gate.current;
    _stall?.cancel();
    _stall = Timer(stallTimeout, () {
      if (!_gate.accepts(id)) return;
      if (_buffering || !_opened) {
        _fail(
          explainFailure(
            TimeoutException('stall'),
            httpStatus: _lastStatus,
            l10n: l10n,
          ),
        );
      }
    });
  }

  void _wake(bool on) {
    unawaited(
      (on ? WakelockPlus.enable() : WakelockPlus.disable()).catchError((_) {}),
    );
  }

  Future<void> playPause() => player.playOrPause();

  Future<void> seekBy(Duration delta) {
    final max = state.duration;
    var t = state.position + delta;
    if (t < Duration.zero) t = Duration.zero;
    if (max > Duration.zero && t > max) t = max;
    return player.seek(t);
  }

  Future<void> seekTo(Duration t) => player.seek(t);

  /// Début du chapitre « Credits » / « Générique » s'il existe ; `null` sinon
  /// (ou si le moteur ne sait pas lister les chapitres).
  Future<Duration?> creditsStart() async {
    final p = player.platform;
    if (p is! NativePlayer) return null;
    try {
      return parseCreditsStart(
        await p.getProperty('chapter-list'),
        duration: state.duration,
      );
    } on Object {
      return null;
    }
  }

  /// Vitesse de lecture (1 = normale).
  Future<void> setRate(double r) => player.setRate(r);

  Future<void> setVolume(double v) => player.setVolume(v.clamp(0, 100));

  Future<void> dispose() async {
    _disposed = true;
    _settle(false);
    _stall?.cancel();
    _statsTimer?.cancel();
    _wake(false);
    await _proxySub?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    await player.dispose();
    _state.dispose();
  }
}
