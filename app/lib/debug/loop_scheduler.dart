import 'dart:async';

/// Une phase de la boucle d'endurance (lecture directe ou torrent).
class LoopPhase {
  const LoopPhase({
    required this.name,
    required this.logTag,
    required this.start,
    required this.stop,
    this.status,
  });

  /// Nom court journalisé (`direct`, `torrent`).
  final String name;

  /// Préfixe de journal lu par `scripts/endurance.sh` : `LUMIO_PLAYER` ou
  /// `LUMIO_TORRENT`.
  final String logTag;

  final Future<void> Function() start;
  final Future<void> Function() stop;

  /// Champs ajoutés à chaque battement (position, pairs…).
  final Map<String, Object?> Function()? status;
}

/// Enchaîne les [phases] indéfiniment : démarre, laisse tourner
/// [phaseDuration] avec un battement tous les [heartbeat], arrête, passe à la
/// suivante. Une erreur est journalisée puis la boucle continue après
/// [errorPause]. Sans dépendance Flutter : horloge et journal injectés.
class LoopScheduler {
  LoopScheduler({
    required this.phases,
    required this.log,
    this.phaseDuration = const Duration(minutes: 10),
    this.heartbeat = const Duration(seconds: 30),
    this.errorPause = const Duration(seconds: 30),
    Future<void> Function(Duration)? wait,
  }) : assert(phases.isNotEmpty),
       _wait = wait ?? ((d) => Future<void>.delayed(d));

  final List<LoopPhase> phases;
  final void Function(String tag, Map<String, Object?> json) log;
  final Duration phaseDuration;
  final Duration heartbeat;
  final Duration errorPause;
  final Future<void> Function(Duration) _wait;

  final _stopped = Completer<void>();
  int _cycles = 0;
  bool _running = false;

  /// Nombre de tours complets terminés.
  int get cycles => _cycles;
  bool get running => _running;
  bool get isStopped => _stopped.isCompleted;

  /// Demande l'arrêt ; [run] rend la main après l'arrêt de la phase courante.
  void stop() {
    if (!_stopped.isCompleted) _stopped.complete();
  }

  Future<void> _sleep(Duration d) =>
      Future.any<void>([_wait(d), _stopped.future]);

  /// Tourne jusqu'à [stop].
  Future<void> run() async {
    _running = true;
    try {
      while (!isStopped) {
        for (final p in phases) {
          if (isStopped) break;
          await _runPhase(p);
        }
        if (!isStopped) {
          _cycles++;
          log('LUMIO_PLAYER', {'event': 'cycle', 'n': _cycles});
        }
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _runPhase(LoopPhase p) async {
    var started = false;
    try {
      log(p.logTag, {'event': 'phase_start', 'phase': p.name});
      await p.start();
      started = true;
      var elapsed = Duration.zero;
      while (!isStopped && elapsed < phaseDuration) {
        final slice = phaseDuration - elapsed < heartbeat
            ? phaseDuration - elapsed
            : heartbeat;
        await _sleep(slice);
        if (isStopped) break;
        elapsed += slice;
        log(p.logTag, {
          'event': 'tick',
          'phase': p.name,
          'elapsed_s': elapsed.inSeconds,
          ...?p.status?.call(),
        });
      }
    } on Object catch (e) {
      log(p.logTag, {
        'event': 'error',
        'phase': p.name,
        'error': e.runtimeType.toString(),
      });
      await _sleep(errorPause);
    } finally {
      try {
        if (started || !isStopped) await p.stop();
      } on Object catch (e) {
        log(p.logTag, {
          'event': 'stop_error',
          'phase': p.name,
          'error': e.runtimeType.toString(),
        });
      }
      log(p.logTag, {'event': 'phase_end', 'phase': p.name});
    }
  }
}
