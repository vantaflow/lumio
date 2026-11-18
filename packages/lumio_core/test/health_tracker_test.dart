import 'dart:async';

import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

const _ms = Duration(milliseconds: 1);

AddonManifest _manifest(String id) => AddonManifest(
  id: id,
  version: '1.0.0',
  name: id,
  types: const ['movie'],
  resources: const [AddonResource('stream')],
  catalogs: const [],
  transportUrl: Uri.parse('https://$id.example.com/manifest.json'),
);

/// Client factice : chaque méthode exécute [behavior].
class _Inner extends AddonClient {
  _Inner(this.behavior, this.clock, {this.takes = Duration.zero})
    : super(_NoFetcher());

  final Future<void> Function() behavior;
  final _Clock clock;
  final Duration takes;

  Future<T> _run<T>(T value) async {
    clock.advance(takes);
    await behavior();
    return value;
  }

  @override
  Future<List<Map<String, dynamic>>> rawStreams(
    AddonManifest a,
    String type,
    String id,
  ) => _run(const <Map<String, dynamic>>[]);

  @override
  Future<Map<String, dynamic>?> rawMeta(
    AddonManifest a,
    String type,
    String id,
  ) => _run<Map<String, dynamic>?>(null);

  @override
  Future<List<MetaPreview>> catalog(
    AddonManifest a,
    String type,
    String id, {
    Map<String, String> extra = const {},
  }) => _run(const <MetaPreview>[]);
}

class _NoFetcher implements HttpFetcher {
  @override
  Future<FetchResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) => throw StateError('unused');
}

class _Clock {
  DateTime now = DateTime.utc(2026, 11, 18);
  void advance(Duration d) => now = now.add(d);
}

void main() {
  group('HealthTracker', () {
    test('médiane de [100, 200, 900] ms = 200 ms', () {
      final t = HealthTracker();
      for (final ms in [900, 100, 200]) {
        t.record('a', _ms * ms, true);
      }
      final h = t.stats('a');
      expect(h.median, _ms * 200);
      expect(h.samples, 3);
      expect(h.successRate, 1.0);
      expect(h.failing, isFalse);
    });

    test('médiane paire = moyenne des deux valeurs centrales', () {
      final t = HealthTracker();
      for (final ms in [100, 200, 300, 500]) {
        t.record('a', _ms * ms, true);
      }
      expect(t.stats('a').median, _ms * 250);
    });

    test('la médiane ignore les échecs (délais d\'attente)', () {
      final t = HealthTracker();
      t.record('a', _ms * 100, true);
      t.record('a', _ms * 8000, false);
      t.record('a', _ms * 300, true);
      expect(t.stats('a').median, _ms * 200);
    });

    test('6 échecs sur 10 : défaillant', () {
      final t = HealthTracker();
      for (var i = 0; i < 10; i++) {
        t.record('a', _ms * 100, i >= 6);
      }
      final h = t.stats('a');
      expect(h.successRate, closeTo(0.4, 1e-9));
      expect(h.failing, isTrue);
      expect(h.level, HealthLevel.failing);
    });

    test('5 succès sur 10 : pas défaillant (seuil strict)', () {
      final t = HealthTracker();
      for (var i = 0; i < 10; i++) {
        t.record('a', _ms * 100, i.isEven);
      }
      expect(t.stats('a').failing, isFalse);
    });

    test('moins de 10 mesures : jamais défaillant', () {
      final t = HealthTracker();
      for (var i = 0; i < 9; i++) {
        t.record('a', _ms * 100, false);
      }
      expect(t.stats('a').failing, isFalse);
      expect(t.stats('a').level, HealthLevel.reliable);
    });

    test('fenêtre limitée à 50 appels', () {
      final t = HealthTracker();
      for (var i = 0; i < 50; i++) {
        t.record('a', _ms * 100, false);
      }
      for (var i = 0; i < 50; i++) {
        t.record('a', _ms * 100, true);
      }
      final h = t.stats('a');
      expect(h.samples, 50);
      expect(h.successRate, 1.0);
    });

    test('inconnu : aucune mesure', () {
      final h = HealthTracker().stats('nope');
      expect(h.samples, 0);
      expect(h.level, HealthLevel.unknown);
      expect(h.failing, isFalse);
    });

    test('lent au-delà de 3 s de médiane', () {
      final t = HealthTracker();
      for (final ms in [3500, 4000, 3200]) {
        t.record('a', _ms * ms, true);
      }
      expect(t.stats('a').level, HealthLevel.slow);
      final u = HealthTracker();
      u.record('a', const Duration(seconds: 3), true);
      expect(u.stats('a').level, HealthLevel.reliable);
    });

    test('défaillant l\'emporte sur lent', () {
      final t = HealthTracker();
      for (var i = 0; i < 10; i++) {
        t.record('a', const Duration(seconds: 5), i < 2);
      }
      expect(t.stats('a').level, HealthLevel.failing);
    });

    test('toJson / fromJson : aller-retour', () {
      final clock = _Clock();
      final t = HealthTracker(clock: () => clock.now);
      t.record('a', _ms * 100, true);
      t.record('a', _ms * 400, false);
      t.record('b', _ms * 50, true);
      final copy = HealthTracker.fromJson(t.toJson());
      expect(copy.stats('a').samples, 2);
      expect(copy.stats('a').successRate, 0.5);
      expect(copy.stats('b').median, _ms * 50);
      expect(copy.toJson(), t.toJson());
    });

    test('fromJson tolère des données malformées', () {
      final t = HealthTracker.fromJson({
        'a': 'oops',
        'b': {'s': 'x'},
        'c': {
          's': [
            [100, 1],
            'bad',
            [null, 1],
            [200],
            [300, 0],
          ],
        },
      });
      expect(t.stats('c').samples, 2);
      expect(t.stats('a').samples, 0);
      expect(HealthTracker.fromJson('nope').stats('x').samples, 0);
    });

    test('fromJson borne la fenêtre à 50', () {
      final t = HealthTracker.fromJson({
        'a': {
          's': [
            for (var i = 0; i < 80; i++) [100, 1],
          ],
        },
      });
      expect(t.stats('a').samples, 50);
    });

    test('reset et remove', () {
      final t = HealthTracker();
      t.record('a', _ms * 100, true);
      t.record('b', _ms * 100, true);
      t.reset('a');
      expect(t.stats('a').samples, 0);
      expect(t.stats('b').samples, 1);
      t.remove('b');
      expect(t.ids, isEmpty);
    });

    test('notifie les changements', () async {
      final t = HealthTracker();
      final seen = <String>[];
      final sub = t.changes.listen(seen.add);
      t.record('a', _ms * 100, true);
      t.reset('a');
      await Future<void>.delayed(Duration.zero);
      expect(seen, ['a', 'a']);
      await sub.cancel();
    });

    test('toJsonFor / loadAddon : une seule entrée', () {
      final t = HealthTracker();
      t.record('a', _ms * 100, true);
      t.record('b', _ms * 100, true);
      final j = t.toJsonFor('a');
      final u = HealthTracker()..loadAddon('a', j);
      expect(u.ids, ['a']);
      expect(u.stats('a').samples, 1);
    });

    test('loadAddon place les anciennes mesures avant les récentes', () {
      final t = HealthTracker();
      t.record('a', _ms * 100, false);
      final old = HealthTracker();
      old.record('a', _ms * 900, true);
      t.loadAddon('a', old.toJsonFor('a'));
      final s = t.toJsonFor('a')!['s'] as List;
      expect(s.first, [900, 1]);
      expect(s.last, [100, 0]);
    });
  });

  group('HealthRecordingAddonClient', () {
    late _Clock clock;
    late HealthTracker tracker;

    setUp(() {
      clock = _Clock();
      tracker = HealthTracker(clock: () => clock.now);
    });

    HealthRecordingAddonClient wrap(
      Future<void> Function() behavior, {
      String? Function(AddonManifest)? key,
    }) => HealthRecordingAddonClient(
      _Inner(behavior, clock, takes: _ms * 120),
      tracker,
      key ?? (m) => 'storage-${m.id}',
    );

    test(
      'succès : durée et réussite enregistrées par identifiant de stockage',
      () async {
        final c = wrap(() async {});
        await c.rawStreams(_manifest('org.x'), 'movie', 'tt1');
        final h = tracker.stats('storage-org.x');
        expect(h.samples, 1);
        expect(h.median, _ms * 120);
        expect(tracker.stats('org.x').samples, 0);
      },
    );

    for (final code in [
      AddonErrorCode.timeout,
      AddonErrorCode.unreachable,
      AddonErrorCode.tlsFailed,
      AddonErrorCode.serverError,
      AddonErrorCode.invalidJson,
      AddonErrorCode.tooLarge,
      AddonErrorCode.refused,
      AddonErrorCode.redirect,
    ]) {
      test('$code est un échec, relancé tel quel', () async {
        final c = wrap(() async => throw AddonException('x', code: code));
        await expectLater(
          c.rawStreams(_manifest('a'), 'movie', 'tt1'),
          throwsA(isA<AddonException>().having((e) => e.code, 'code', code)),
        );
        final h = tracker.stats('storage-a');
        expect(h.samples, 1);
        expect(h.successRate, 0);
      });
    }

    test('404 (aucun contenu) n\'est pas un échec', () async {
      final c = wrap(
        () async =>
            throw const AddonException('404', code: AddonErrorCode.notFound),
      );
      await expectLater(
        c.catalog(_manifest('a'), 'movie', 'top'),
        throwsA(isA<AddonException>()),
      );
      final h = tracker.stats('storage-a');
      expect(h.samples, 1);
      expect(h.successRate, 1);
    });

    test('adresse refusée localement : rien enregistré', () async {
      final c = wrap(
        () async => throw const AddonException(
          'x',
          code: AddonErrorCode.addressRefused,
        ),
      );
      await expectLater(
        c.rawMeta(_manifest('a'), 'movie', 'tt1'),
        throwsA(isA<AddonException>()),
      );
      expect(tracker.stats('storage-a').samples, 0);
    });

    test('erreur inattendue : rien enregistré', () async {
      final c = wrap(() async => throw StateError('bug'));
      await expectLater(
        c.rawMeta(_manifest('a'), 'movie', 'tt1'),
        throwsStateError,
      );
      expect(tracker.stats('storage-a').samples, 0);
    });

    test('addon sans identifiant de stockage : rien enregistré', () async {
      final c = wrap(() async {}, key: (_) => null);
      await c.rawStreams(_manifest('a'), 'movie', 'tt1');
      expect(tracker.ids, isEmpty);
    });

    test('deux addons de même id de manifeste restent séparés', () async {
      final c = wrap(
        () async {},
        key: (m) => m.transportUrl.host.contains('one') ? 's1' : 's2',
      );
      final one = AddonManifest(
        id: 'same',
        version: '1',
        name: 'one',
        types: const [],
        resources: const [],
        catalogs: const [],
        transportUrl: Uri.parse('https://one.example.com/manifest.json'),
      );
      final two = AddonManifest(
        id: 'same',
        version: '1',
        name: 'two',
        types: const [],
        resources: const [],
        catalogs: const [],
        transportUrl: Uri.parse('https://two.example.com/manifest.json'),
      );
      await c.rawStreams(one, 'movie', 'tt1');
      await c.rawStreams(one, 'movie', 'tt1');
      await c.rawStreams(two, 'movie', 'tt1');
      expect(tracker.stats('s1').samples, 2);
      expect(tracker.stats('s2').samples, 1);
      expect(tracker.stats('same').samples, 0);
    });

    test('timeout réel du client : échec enregistré', () async {
      final c = HealthRecordingAddonClient(
        AddonClient(
          _TimeoutFetcher(),
          retries: 0,
          retryDelay: Duration.zero,
          allowPrivate: true,
        ),
        tracker,
        (_) => 's',
      );
      await expectLater(
        c.rawStreams(_manifest('a'), 'movie', 'tt1'),
        throwsA(isA<AddonTimeoutException>()),
      );
      expect(tracker.stats('s').successRate, 0);
    });
  });
}

class _TimeoutFetcher implements HttpFetcher {
  @override
  Future<FetchResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) => throw TimeoutException('slow');
}
