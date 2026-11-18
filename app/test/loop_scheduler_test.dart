import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/debug/loop_scheduler.dart';

class _Fixture {
  final events = <String>[];
  final logs = <(String, Map<String, Object?>)>[];
  int waits = 0;
  late final LoopScheduler sched;

  LoopPhase phase(
    String name,
    String tag, {
    Object? failStart,
    Object? failStop,
  }) => LoopPhase(
    name: name,
    logTag: tag,
    start: () async {
      events.add('start:$name');
      if (failStart != null) throw failStart;
    },
    stop: () async {
      events.add('stop:$name');
      if (failStop != null) throw failStop;
    },
    status: () => {'pos': 1},
  );

  /// Horloge factice : rend la main aussitôt, arrête après [maxWaits] attentes.
  void build(List<LoopPhase> phases, {required int maxWaits}) {
    sched = LoopScheduler(
      phases: phases,
      log: (t, j) => logs.add((t, j)),
      phaseDuration: const Duration(minutes: 1),
      heartbeat: const Duration(seconds: 30),
      errorPause: const Duration(seconds: 5),
      wait: (_) async {
        waits++;
        if (waits >= maxWaits) sched.stop();
      },
    );
  }

  List<String> events_(String name) => logs
      .where((l) => l.$2['event'] == name)
      .map((l) => '${l.$1}:${l.$2['phase'] ?? l.$2['n']}')
      .toList();
}

void main() {
  test('alterne direct puis torrent, battements, tour compté', () async {
    final f = _Fixture();
    f.build([
      f.phase('direct', 'LUMIO_PLAYER'),
      f.phase('torrent', 'LUMIO_TORRENT'),
    ], maxWaits: 5);
    await f.sched.run();

    // 1 min / 30 s = 2 battements par phase ; arrêt au 5e wait (phase 3).
    expect(f.events.take(4), [
      'start:direct',
      'stop:direct',
      'start:torrent',
      'stop:torrent',
    ]);
    expect(f.events_('phase_start').take(3), [
      'LUMIO_PLAYER:direct',
      'LUMIO_TORRENT:torrent',
      'LUMIO_PLAYER:direct',
    ]);
    expect(f.sched.cycles, 1);
    final tick = f.logs.firstWhere((l) => l.$2['event'] == 'tick');
    expect(tick.$1, 'LUMIO_PLAYER');
    expect(tick.$2['elapsed_s'], 30);
    expect(tick.$2['pos'], 1);
    expect(f.sched.running, isFalse);
  });

  test('stop() interrompt la phase en cours et l\'arrête proprement', () async {
    final f = _Fixture();
    f.build([f.phase('direct', 'LUMIO_PLAYER')], maxWaits: 1);
    await f.sched.run();
    expect(f.events, ['start:direct', 'stop:direct']);
    expect(f.sched.cycles, 0);
    expect(f.sched.isStopped, isTrue);
  });

  test('une phase en erreur est journalisée et la boucle continue', () async {
    final f = _Fixture();
    f.build([
      f.phase('direct', 'LUMIO_PLAYER', failStart: StateError('x')),
      f.phase('torrent', 'LUMIO_TORRENT'),
    ], maxWaits: 4);
    await f.sched.run();
    expect(f.events_('error').first, 'LUMIO_PLAYER:direct');
    expect(f.events, contains('start:torrent'));
    expect(f.events, contains('stop:direct'));
  });

  test('une erreur à l\'arrêt est journalisée sans casser la boucle', () async {
    final f = _Fixture();
    f.build([
      f.phase('direct', 'LUMIO_PLAYER', failStop: StateError('y')),
    ], maxWaits: 3);
    await f.sched.run();
    expect(f.events_('stop_error'), isNotEmpty);
    expect(f.sched.running, isFalse);
  });

  test('le journal ne contient jamais le texte de l\'erreur (URL)', () async {
    final f = _Fixture();
    f.build([
      f.phase(
        'direct',
        'LUMIO_PLAYER',
        failStart: StateError('https://secret.example/token=abc'),
      ),
    ], maxWaits: 2);
    await f.sched.run();
    expect(f.logs.toString(), isNot(contains('secret')));
  });
}
