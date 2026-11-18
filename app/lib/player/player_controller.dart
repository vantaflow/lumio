import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:lumio/l10n/app_localizations.dart';
import 'package:lumio/l10n/app_localizations_fr.dart';
import 'package:lumio/player/local_proxy.dart';
import 'package:lumio/player/play_router.dart';
import 'package:lumio/player/playback_report.dart';
import 'package:lumio/player/source_fallback.dart';
import 'package:lumio_core/lumio_core.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:lumio/player/next_episode_overlay.dart' show parseCreditsStart;

export 'package:lumio/player/playback_report.dart'
    show PlaybackReport, explainFailure;

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
       player = player ?? Player() {
    video = VideoController(this.player);
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
    ]);
  }

  final Player player;
  late final VideoController video;
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
  bool _refused = false;
  bool _viaProxy = false;
  bool _playing = false;
  bool _buffering = false;
  bool _opened = false;
  int? _lastStatus;
  bool _disposed = false;

  // Basculement automatique (voir [playWithFallback]).
  int _runId = 0;
  Completer<bool>? _outcome;
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
  /// composants (torrent), jamais aux données d'un addon. Échec : phase `failed` avec message ([PlayerState.error]).
  Future<void> open(
    StreamItem s, {
    bool allowPrivate = false,
    bool trustedLocal = false,
    Duration start = Duration.zero,
  }) async {
    _item = s;
    _allowPrivate = allowPrivate;
    _trustedLocal = trustedLocal;
    _refused = false;
    _lastStatus = null;
    firstFrameMs = null;
    _opened = false;
    _firstFrame = Completer<int>();
    _sinceOpen = Stopwatch()..start();
    _stall?.cancel();
    _set(
      PlayerState(
        phase: PlayerPhase.opening,
        volume: state.volume,
        notice: _notice,
      ),
    );
    final url = s.url;
    if (url == null || s.isTorrent) {
      _fail(l10n.torrentNotPlayable);
      return;
    }
    try {
      final route = await routePlayback(
        s,
        proxy: _proxy,
        allowPrivate: allowPrivate,
        trustedLocal: trustedLocal,
      );
      _viaProxy = route.kind == PlayRouteKind.proxy;
      if (_viaProxy) {
        _proxySub ??= (await _proxy()).events.listen((e) {
          if (e.status != 0) _lastStatus = e.status;
          if (e.refused) _refused = true;
        });
      }
      final playUrl = route.url;
      await player.open(
        Media(playUrl.toString(), start: start == Duration.zero ? null : start),
      );
      _armStall();
    } catch (e) {
      _fail(
        explainFailure(
          e,
          httpStatus: _lastStatus,
          refused: _refused,
          l10n: l10n,
        ),
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
      start: state.position,
    );
  }

  void _onFirstFrame() {
    final c = _firstFrame;
    if (c == null || c.isCompleted) return;
    firstFrameMs = _sinceOpen?.elapsedMilliseconds;
    c.complete(firstFrameMs);
    _opened = true;
    _stall?.cancel();
    _notice = null;
    _set(state.copyWith(clearNotice: true));
    _settle(true);
  }

  /// Attend la première image (pour la mesure de la sonde de debug).
  Future<int> waitFirstFrame(Duration timeout) =>
      _firstFrame!.future.timeout(timeout);

  void _onEngineError(String message) {
    // Le moteur signale aussi des avertissements bénins après une image.
    if (_opened && message.isEmpty) return;
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

  void _fail(String message, {bool fallbackable = true}) {
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

  void _settle(bool ok) {
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
          final outcome = _outcome = Completer<bool>();
          await open(item);
          final ok = await outcome.future.timeout(
            attemptTimeout,
            onTimeout: () {
              _fail(
                explainFailure(TimeoutException('open'), l10n: l10n),
                fallbackable: true,
              );
              return false;
            },
          );
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

  void _armStall() {
    _stall?.cancel();
    _stall = Timer(stallTimeout, () {
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

  Future<void> setVolume(double v) => player.setVolume(v.clamp(0, 100));

  Future<void> dispose() async {
    _disposed = true;
    _settle(false);
    _stall?.cancel();
    _wake(false);
    await _proxySub?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    await player.dispose();
    _state.dispose();
  }
}
