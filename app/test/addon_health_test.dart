import 'dart:convert';

import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/addon_health_service.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/app_settings.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/features/addons/addons_screen.dart';
import 'package:lumio/features/addons/health_providers.dart';
import 'package:lumio/features/detail/streams_list.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

const _ms = Duration(milliseconds: 1);

AddonManifest _manifest(String id, String name) => AddonManifest(
  id: id,
  version: '1.0.0',
  name: name,
  types: const ['movie'],
  resources: const [AddonResource('stream')],
  catalogs: const [],
  transportUrl: Uri.parse('https://$name.example.com/manifest.json'),
);

InstalledAddon _addon(String id, String name, {String? manifestId}) =>
    InstalledAddon(
      id: id,
      manifest: _manifest(manifestId ?? 'org.$name', name),
      position: 0,
      enabled: true,
    );

class _FakeAddons extends AddonsController {
  _FakeAddons(this.list);
  final List<InstalledAddon> list;

  @override
  Future<List<InstalledAddon>> build() async => list;
}

StreamItem _stream(String addon) => StreamItem(
  addonId: addon,
  title: 'Sintel',
  url: Uri.parse('https://cdn.example.org/s.mkv'),
);

class _MemoryStore extends AppSettingsStore {
  _MemoryStore(super.db);
  final rows = <String, String>{};
  int writes = 0;

  @override
  Future<String?> read(String key) async => rows[key];

  @override
  Future<void> write(String key, String value) async {
    writes++;
    rows[key] = value;
  }

  @override
  Future<void> delete(String key) async => rows.remove(key);

  @override
  Future<Map<String, String>> readPrefix(String prefix) async => {
    for (final e in rows.entries)
      if (e.key.startsWith(prefix)) e.key: e.value,
  };
}

void main() {
  group('AddonHealthService (persistance locale)', () {
    late AppDatabase db;
    late AppSettingsStore store;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      store = AppSettingsStore(db);
    });
    tearDown(() => db.close());

    test('flush() écrit aussitôt, sans attendre le minuteur', () async {
      final service = AddonHealthService(HealthTracker(), store);
      await service.ready;
      service.tracker.record('s1', _ms * 100, true);
      expect(await store.read('addon_health:s1'), isNull);
      await service.flush();
      final saved = jsonDecode((await store.read('addon_health:s1'))!) as Map;
      expect((saved['s'] as List).length, 1);
      service.dispose();
    });

    test('écriture différée : une seule fois par période de 30 s', () {
      fakeAsync((fake) {
        final mem = _MemoryStore(db);
        final service = AddonHealthService(HealthTracker(), mem);
        fake.flushMicrotasks();
        for (var i = 0; i < 5; i++) {
          service.tracker.record('s1', _ms * 100, true);
        }
        fake.elapse(const Duration(seconds: 29));
        fake.flushMicrotasks();
        expect(mem.writes, 0);
        fake.elapse(const Duration(seconds: 2));
        fake.flushMicrotasks();
        expect(mem.writes, 1);
        expect(
          ((jsonDecode(mem.rows['addon_health:s1']!) as Map)['s'] as List),
          hasLength(5),
        );
        service.dispose();
      });
    });

    test('recharge les mesures au démarrage', () async {
      final a = AddonHealthService(HealthTracker(), store);
      await a.ready;
      a.tracker.record('s1', _ms * 300, true);
      a.tracker.record('s1', _ms * 500, false);
      await a.flush();
      a.dispose();

      final b = AddonHealthService(HealthTracker(), store);
      await b.ready;
      expect(b.tracker.stats('s1').samples, 2);
      expect(b.tracker.stats('s1').successRate, 0.5);
      // Le rechargement n'est pas une modification : rien à réécrire.
      await b.flush();
      b.dispose();
    });

    test('ligne illisible : ignorée', () async {
      await store.write('addon_health:s1', '{pas du json');
      await store.write('addon_health:s2', '"x"');
      final s = AddonHealthService(HealthTracker(), store);
      await s.ready;
      expect(s.tracker.ids, isEmpty);
      s.dispose();
    });

    test('un addon désinstallé est purgé (mémoire et disque)', () async {
      final s = AddonHealthService(HealthTracker(), store);
      await s.ready;
      s.tracker.record('s1', _ms * 100, true);
      s.tracker.record('s2', _ms * 100, true);
      await s.flush();
      expect(await store.readPrefix('addon_health:'), hasLength(2));

      await s.keepOnly({'s2'});
      expect(s.tracker.ids, ['s2']);
      expect(await store.read('addon_health:s1'), isNull);
      expect(await store.read('addon_health:s2'), isNotNull);

      // Une mesure tardive d'un addon retiré n'est pas réécrite.
      s.tracker.record('s1', _ms * 100, true);
      await s.flush();
      expect(await store.read('addon_health:s1'), isNull);
      s.dispose();
    });

    test('réinitialiser efface mémoire et disque aussitôt', () async {
      final s = AddonHealthService(HealthTracker(), store);
      await s.ready;
      s.tracker.record('s1', _ms * 100, true);
      await s.flush();
      await s.reset('s1');
      expect(s.tracker.stats('s1').samples, 0);
      expect(await store.read('addon_health:s1'), isNull);
      s.dispose();
    });
  });

  group('interface', () {
    late AppDatabase db;
    late HealthTracker tracker;
    late AddonHealthService service;

    /// Arrête le minuteur d'écriture avant la fin du test (sinon Flutter
    /// signale un Timer en attente) puis ferme la base.
    Future<void> done(WidgetTester t) async {
      service.dispose();
      tracker.dispose();
      await t.runAsync(db.close);
    }

    Future<void> pumpAddons(WidgetTester t, List<InstalledAddon> addons) async {
      db = AppDatabase(NativeDatabase.memory());
      tracker = HealthTracker();
      service = AddonHealthService(tracker, AppSettingsStore(db));
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            addonsProvider.overrideWith(() => _FakeAddons(addons)),
            addonHealthServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            theme: LumioTheme.dark(),
            home: const AddonsScreen(),
          ),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
    }

    testWidgets('pastille Fiable avec latence médiane et taux de succès', (
      t,
    ) async {
      await pumpAddons(t, [_addon('s1', 'alpha')]);
      for (final ms in [100, 200, 900]) {
        tracker.record('s1', _ms * ms, true);
      }
      await t.pump();
      expect(find.text('Fiable'), findsOneWidget);
      expect(find.text('Médiane 200 ms · 100 % de réussite'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Santé : Fiable, Médiane 200 ms · 100 % de réussite',
        ),
        findsOneWidget,
      );
      await done(t);
    });

    testWidgets('pas de reconstruction si l\'affichage ne change pas', (
      t,
    ) async {
      await pumpAddons(t, [_addon('s1', 'alpha')]);
      final c = ProviderScope.containerOf(t.element(find.byType(AddonsScreen)));
      var emissions = 0;
      c.listen(healthSnapshotProvider, (_, _) => emissions++);
      for (var i = 0; i < 5; i++) {
        tracker.record('s1', _ms * 100, true);
      }
      await t.pump();
      final first = emissions;
      // Même verdict, même médiane, même taux : rien de nouveau.
      for (var i = 0; i < 5; i++) {
        tracker.record('s1', _ms * 100, true);
      }
      await t.pump();
      expect(emissions, first);
      await done(t);
    });

    testWidgets('lent : médiane au-dessus de 3 s', (t) async {
      await pumpAddons(t, [_addon('s1', 'alpha')]);
      for (final ms in [3500, 4200, 3100]) {
        tracker.record('s1', _ms * ms, true);
      }
      await t.pump();
      expect(find.text('Lent (> 3 s)'), findsOneWidget);
      expect(find.textContaining('3,5 s'), findsOneWidget);
      await done(t);
    });

    testWidgets('défaillant : 6 échecs sur 10', (t) async {
      await pumpAddons(t, [_addon('s1', 'alpha')]);
      for (var i = 0; i < 10; i++) {
        tracker.record('s1', _ms * 100, i >= 6);
      }
      await t.pump();
      expect(find.text('Défaillant'), findsOneWidget);
      expect(find.textContaining('40 % de réussite'), findsOneWidget);
      await done(t);
    });

    testWidgets('sans mesure : « Pas encore de mesure », pas de bouton', (
      t,
    ) async {
      await pumpAddons(t, [_addon('s1', 'alpha')]);
      expect(find.text('Pas encore de mesure'), findsOneWidget);
      expect(
        find.byTooltip('Réinitialiser les mesures de alpha'),
        findsNothing,
      );
      await done(t);
    });

    testWidgets('deux addons de même id de manifeste : mesures séparées', (
      t,
    ) async {
      await pumpAddons(t, [
        _addon('s1', 'alpha', manifestId: 'same'),
        _addon('s2', 'bravo', manifestId: 'same'),
      ]);
      for (var i = 0; i < 10; i++) {
        tracker.record('s1', _ms * 100, false);
        tracker.record('s2', _ms * 100, true);
      }
      await t.pump();
      expect(find.text('Défaillant'), findsOneWidget);
      expect(find.text('Fiable'), findsOneWidget);
      await done(t);
    });

    testWidgets('Réinitialiser les mesures remet l\'addon à zéro', (t) async {
      await pumpAddons(t, [_addon('s1', 'alpha')]);
      tracker.record('s1', _ms * 100, true);
      await t.pump();
      final btn = find.byTooltip('Réinitialiser les mesures de alpha');
      expect(btn, findsOneWidget);
      await t.tap(btn);
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
      expect(find.text('Pas encore de mesure'), findsOneWidget);
      expect(tracker.stats('s1').samples, 0);
      await done(t);
    });

    testWidgets('le bouton de réinitialisation est atteignable au clavier', (
      t,
    ) async {
      await pumpAddons(t, [_addon('s1', 'alpha')]);
      tracker.record('s1', _ms * 100, true);
      await t.pump();
      final iconButton = find.ancestor(
        of: find.byIcon(Icons.restart_alt),
        matching: find.byType(IconButton),
      );
      final node = t.widget<IconButton>(iconButton);
      expect(node.onPressed, isNotNull);
      expect(node.focusNode?.canRequestFocus ?? true, isTrue);
      await done(t);
    });

    testWidgets('liste des flux : pastille de santé par groupe', (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: LumioTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: StreamsList(
                groups: [
                  StreamGroup(addonId: 's1', items: [_stream('s1')]),
                  const StreamGroup(addonId: 's2', error: 'x'),
                ],
                addonNames: const {'s1': 'Alpha', 's2': 'Bravo'},
                health: {
                  's1': const AddonHealth(
                    median: Duration(milliseconds: 420),
                    successRate: 1,
                    samples: 12,
                  ),
                },
                loading: false,
                prefs: const StreamPrefs(),
                preferred: null,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Fiable'), findsOneWidget);
    });
  });
}
