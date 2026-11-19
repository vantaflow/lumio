import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/features/calendar/calendar_providers.dart';
import 'package:lumio/ui/common/tv_screen.dart';
import 'package:lumio/features/calendar/calendar_screen.dart';
import 'package:lumio/features/calendar/release_notifier.dart';
import 'package:lumio/features/calendar/release_sync.dart';
import 'package:lumio/features/detail/playback_service.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

MetaPreview _p(String id, {String type = 'series', String cert = 'G'}) =>
    MetaPreview(
      id: id,
      type: type,
      name: 'Série $id',
      sourceAddonId: 'a',
      certification: cert,
    );

Video _ep(String id, int s, int e, DateTime? at) => Video(
  id: id,
  title: 'Épisode $e',
  season: s,
  episode: e,
  released: at?.toUtc(),
);

class _FakeLauncher extends PlaybackLauncher {
  _FakeLauncher(super.ref, this.fn);
  final Future<Meta> Function(MetaPreview p) fn;

  @override
  Future<Meta> loadMeta(MetaPreview p) => fn(p);
}

class _FakeNotifier implements ReleaseNotifier {
  _FakeNotifier({this.grant = true});
  final bool grant;
  int permissionCalls = 0;
  int cancelCalls = 0;
  final scheduled = <List<ScheduledRelease>>[];

  @override
  Future<bool> requestPermission() async {
    permissionCalls++;
    return grant;
  }

  bool replaceOk = true;

  @override
  Future<bool> replaceAll(
    List<ScheduledRelease> items,
    String c, {
    bool Function()? isCurrent,
  }) async {
    scheduled.add(items);
    return replaceOk;
  }

  @override
  Future<void> cancelAll() async => cancelCalls++;
}

const _kid = Profile(
  id: 'kid',
  name: 'Léa',
  createdAt: 0,
  ageLimit: 1,
  isKid: true,
  locked: false,
);

/// Heure fixée du calendrier (voir `main`).
final _fixedNow = DateTime(2030, 6, 15, 14);

class _H {
  _H(this.tester);
  final WidgetTester tester;
  late AppDatabase db;
  late ProviderContainer container;
  final opened = <String>[];

  Future<void> start({
    List<MetaPreview> library = const [],
    Stream<List<MetaPreview>>? libraryStream,
    required Future<Meta> Function(MetaPreview p) meta,
    _FakeNotifier? notifier,
    Profile? profile,
    Locale locale = const Locale('fr'),
  }) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        libraryProvider.overrideWith(
          (ref) => libraryStream ?? Stream.value(library),
        ),
        playbackLauncherProvider.overrideWith(
          (ref) => _FakeLauncher(ref, meta),
        ),
        releaseNotifierProvider.overrideWithValue(notifier ?? _FakeNotifier()),
        calendarClockProvider.overrideWithValue(() => _fixedNow),
      ],
    );
    addTearDown(container.dispose);
    container.listen(releaseSyncProvider, (_, _) {}); // comme la racine
    if (profile != null) {
      container.read(currentProfileProvider.notifier).select(profile);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LumioTheme.dark(),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: CalendarScreen(onOpenItem: (i) => opened.add(i.id)),
        ),
      ),
    );
    await settle();
  }

  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> close() async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  // Horloge fixe : le test ne dépend plus de l'heure courante.
  final now = DateTime(2030, 6, 15, 14);
  DateTime inDays(int d, [int hour = 20]) =>
      DateTime(now.year, now.month, now.day + d, hour);

  group('regroupement', () {
    test('par jour local, « date inconnue » en dernier', () {
      final a = Meta(id: 'a', type: 'series', name: 'A');
      final entries = [
        CalendarEntry(
          series: a,
          video: _ep('a:1:1', 1, 1, inDays(1, 10)),
          date: inDays(1, 10).toUtc(),
        ),
        CalendarEntry(
          series: a,
          video: _ep('a:1:2', 1, 2, inDays(1, 22)),
          date: inDays(1, 22).toUtc(),
        ),
        CalendarEntry(
          series: a,
          video: _ep('a:1:3', 1, 3, inDays(3)),
          date: inDays(3).toUtc(),
        ),
        CalendarEntry(
          series: Meta(id: 'b', type: 'series', name: 'B'),
        ),
      ];
      final g = groupByDay(entries);
      expect(g.length, 3);
      expect(g[0].entries.length, 2);
      expect(g[1].entries.length, 1);
      expect(g[2].day, isNull);
    });

    testWidgets('libellés Aujourd\'hui / Demain / date', (tester) async {
      late AppLocalizations l;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (c) {
              l = c.l10n;
              return const SizedBox();
            },
          ),
        ),
      );
      final today = DateTime(now.year, now.month, now.day);
      const fr = Locale('fr');
      expect(dayLabel(l, fr, today, now), 'Aujourd\'hui');
      expect(dayLabel(l, fr, inDays(1), now), 'Demain');
      final far = DateTime(2026, 12, 25);
      final label = dayLabel(l, fr, far, DateTime(2026, 11, 18));
      // Maquette TV21 : jour de la semaine abrégé (« ven. 25 décembre »).
      expect(label.toLowerCase(), contains('ven.'));
      expect(label.toLowerCase(), contains('décembre'));
    });
  });

  group('notifications : plan', () {
    CalendarEntry entry(int i, DateTime at) => CalendarEntry(
      series: Meta(id: 's$i', type: 'series', name: 'S$i'),
      video: _ep('s$i:1:1', 1, 1, at),
      date: at.toUtc(),
    );

    test('au plus 20, entrées datées futures seulement', () {
      final entries = [
        for (var i = 0; i < 30; i++) entry(i, inDays(1 + i % 5)),
        CalendarEntry(
          series: Meta(id: 'u', type: 'series', name: 'U'),
        ),
      ];
      final plan = planReleases(entries, now, body: (_) => 'x');
      expect(plan.length, maxScheduledReleases);
      expect(plan.map((r) => r.id).toSet().length, 20);
      for (var i = 1; i < plan.length; i++) {
        expect(plan[i].when.isBefore(plan[i - 1].when), isFalse);
      }
    });

    test('passé ignoré ; sortie de nuit ramenée à 9 h locales', () {
      final past = entry(1, now.subtract(const Duration(hours: 1)));
      final night = entry(2, inDays(2, 1));
      final plan = planReleases([past, night], now, body: (_) => 'x');
      expect(plan.length, 1);
      final local = plan.single.when.toLocal();
      expect(local.hour, 9);
      expect(local.day, inDays(2).day);
    });
  });

  group('écran', () {
    testWidgets('vide : aucune série dans « Ma liste »', (tester) async {
      final h = _H(tester);
      await h.start(
        library: [_p('m', type: 'movie')],
        meta: (p) async => Meta(id: p.id, type: p.type, name: p.name),
      );
      expect(
        find.textContaining('Aucune série dans votre liste'),
        findsOneWidget,
      );
      await h.close();
    });

    testWidgets('sorties datées groupées par jour, date inconnue, ouverture', (
      tester,
    ) async {
      final h = _H(tester);
      await h.start(
        library: [_p('a'), _p('b'), _p('c')],
        meta: (p) async => Meta(
          id: p.id,
          type: p.type,
          name: p.name,
          videos: switch (p.id) {
            'a' => [_ep('a:1:2', 1, 2, inDays(1, 12))],
            'b' => [_ep('b:2:5', 2, 5, inDays(0, 23))],
            _ => [_ep('c:1:1', 1, 1, null)],
          },
        ),
      );
      expect(find.text('Demain'), findsOneWidget);
      expect(find.text('Date inconnue'), findsNWidgets(2)); // en-tête + ligne
      expect(find.text('S1 · É2'), findsOneWidget);
      expect(find.text('S2 · É5'), findsOneWidget);
      // Ordre : b (aujourd'hui 23 h) avant a (demain), c à la fin.
      final y = [
        for (final n in ['Série b', 'Série a', 'Série c'])
          tester.getTopLeft(find.text(n)).dy,
      ];
      expect(y[0] < y[1] && y[1] < y[2], isTrue);

      await tester.tap(find.text('Série a'));
      await h.settle();
      expect(h.opened, ['a']);
      await h.close();
    });

    testWidgets('anglais : « Today » / « Date unknown »', (tester) async {
      final h = _H(tester);
      await h.start(
        locale: const Locale('en'),
        library: [_p('a'), _p('c')],
        meta: (p) async => Meta(
          id: p.id,
          type: p.type,
          name: p.name,
          videos: p.id == 'a' ? [_ep('a:1:1', 1, 1, inDays(0, 23))] : const [],
        ),
      );
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Date unknown'), findsNWidgets(2));
      await h.close();
    });

    testWidgets('une série en échec n\'empêche pas les autres', (tester) async {
      final h = _H(tester);
      await h.start(
        library: [_p('a'), _p('bad')],
        meta: (p) async {
          if (p.id == 'bad') throw StateError('addon en panne');
          return Meta(
            id: p.id,
            type: p.type,
            name: p.name,
            videos: [_ep('a:1:1', 1, 1, inDays(2))],
          );
        },
      );
      expect(find.text('Série a'), findsOneWidget);
      expect(find.text('Série bad'), findsOneWidget); // date inconnue
      expect(find.text('Date inconnue'), findsNWidgets(2));
      await h.close();
    });

    testWidgets('au plus 4 chargements simultanés', (tester) async {
      final h = _H(tester);
      var running = 0;
      var peak = 0;
      await h.start(
        library: [for (var i = 0; i < 10; i++) _p('s$i')],
        meta: (p) async {
          running++;
          if (running > peak) peak = running;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          running--;
          return Meta(id: p.id, type: p.type, name: p.name);
        },
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await h.settle();
      expect(peak, lessThanOrEqualTo(calendarConcurrency));
      expect(peak, greaterThan(1));
      expect(find.text('Série s9'), findsOneWidget);
      await h.close();
    });

    testWidgets('profil enfant : séries non autorisées masquées', (
      tester,
    ) async {
      final h = _H(tester);
      await h.start(
        profile: _kid,
        library: [
          _p('ok'),
          _p('adult', cert: 'R'),
        ],
        meta: (p) async => Meta(
          id: p.id,
          type: p.type,
          name: p.name,
          certification: p.certification,
          videos: [_ep('${p.id}:1:1', 1, 1, inDays(1))],
        ),
      );
      expect(find.text('Série ok'), findsOneWidget);
      expect(find.text('Série adult'), findsNothing);
      await h.close();
    });

    testWidgets('notifications : désactivées par défaut, aucune permission', (
      tester,
    ) async {
      final h = _H(tester);
      final n = _FakeNotifier();
      await h.start(
        notifier: n,
        library: [_p('a')],
        meta: (p) async => Meta(
          id: p.id,
          type: p.type,
          name: p.name,
          videos: [_ep('a:1:1', 1, 1, inDays(2))],
        ),
      );
      expect(
        tester.widget<TvSwitchTile>(find.byType(TvSwitchTile)).value,
        isFalse,
      );
      expect(n.permissionCalls, 0);
      expect(n.scheduled, isEmpty);
      await h.close();
    });

    testWidgets(
      'activer : permission demandée puis notifications programmées',
      (tester) async {
        final h = _H(tester);
        final n = _FakeNotifier();
        await h.start(
          notifier: n,
          library: [_p('a')],
          meta: (p) async => Meta(
            id: p.id,
            type: p.type,
            name: p.name,
            videos: [_ep('a:1:1', 1, 1, inDays(2))],
          ),
        );
        await tester.tap(find.byType(TvSwitchTile));
        await h.settle();
        expect(n.permissionCalls, 1);
        expect(n.scheduled, isNotEmpty);
        expect(n.scheduled.last.single.title, 'Série a');
        expect(
          tester.widget<TvSwitchTile>(find.byType(TvSwitchTile)).value,
          isTrue,
        );
        // Désactiver : annulation.
        final before = n.cancelCalls;
        await tester.tap(find.byType(TvSwitchTile));
        await h.settle();
        expect(n.cancelCalls, greaterThan(before));
        await h.close();
      },
    );

    testWidgets('permission refusée : le réglage reste désactivé', (
      tester,
    ) async {
      final h = _H(tester);
      final n = _FakeNotifier(grant: false);
      await h.start(
        notifier: n,
        library: [_p('a')],
        meta: (p) async => Meta(
          id: p.id,
          type: p.type,
          name: p.name,
          videos: [_ep('a:1:1', 1, 1, inDays(2))],
        ),
      );
      await tester.tap(find.byType(TvSwitchTile));
      await h.settle();
      expect(n.permissionCalls, 1);
      expect(n.scheduled, isEmpty);
      expect(
        tester.widget<TvSwitchTile>(find.byType(TvSwitchTile)).value,
        isFalse,
      );
      expect(find.textContaining('Notifications refusées'), findsOneWidget);
      await h.close();
    });
  });

  group('synchronisation des notifications', () {
    Future<Meta> meta(MetaPreview p) async => Meta(
      id: p.id,
      type: p.type,
      name: p.name,
      certification: p.certification,
      videos: [_ep('${p.id}:1:1', 1, 1, inDays(2))],
    );

    testWidgets('série retirée de « Ma liste » : notification retirée', (
      tester,
    ) async {
      final h = _H(tester);
      final n = _FakeNotifier();
      final lib = StreamController<List<MetaPreview>>();
      addTearDown(lib.close);
      lib.add([_p('a'), _p('b')]);
      await h.start(notifier: n, libraryStream: lib.stream, meta: meta);
      await tester.tap(find.byType(TvSwitchTile));
      await h.settle();
      expect(n.scheduled.last.map((r) => r.title), ['Série a', 'Série b']);
      lib.add([_p('b')]); // retirée ailleurs (écran fermé ou autre écran)
      await h.settle();
      expect(n.scheduled.last.map((r) => r.title), ['Série b']);
      lib.add(const []);
      await h.settle();
      expect(n.scheduled.last, isEmpty);
      await h.close();
    });

    testWidgets(
      'changement de profil : annulation, filtre enfant, réglage propre',
      (tester) async {
        final h = _H(tester);
        final n = _FakeNotifier();
        await h.start(
          notifier: n,
          library: [
            _p('ok'),
            _p('adult', cert: 'R'),
          ],
          meta: meta,
        );
        await tester.tap(find.byType(TvSwitchTile));
        await h.settle();
        expect(n.scheduled.last.length, 2);
        final before = n.cancelCalls;
        h.container.read(currentProfileProvider.notifier).select(_kid);
        await h.settle();
        expect(n.cancelCalls, greaterThan(before));
        // Réglage du profil enfant : désactivé par défaut.
        expect(
          tester.widget<TvSwitchTile>(find.byType(TvSwitchTile)).value,
          isFalse,
        );
        // Activé pour l'enfant : seule la série autorisée est programmée.
        await tester.tap(find.byType(TvSwitchTile));
        await h.settle();
        expect(n.scheduled.last.map((r) => r.title), ['Série ok']);
        await h.close();
      },
    );

    testWidgets('échec de programmation : l\'interrupteur affiche l\'erreur', (
      tester,
    ) async {
      final h = _H(tester);
      final n = _FakeNotifier()..replaceOk = false;
      await h.start(notifier: n, library: [_p('a')], meta: meta);
      await tester.tap(find.byType(TvSwitchTile));
      await h.settle();
      expect(
        find.byKey(const ValueKey('calendar-notify-error')),
        findsOneWidget,
      );
      await h.close();
    });

    test(
      'désactivation pendant replaceAll : plus rien de programmé après',
      () async {
        final inner = _SlowNotifier();
        final q = QueuedReleaseNotifier(inner);
        final items = [
          for (var i = 1; i <= 5; i++)
            ScheduledRelease(
              id: i,
              when: DateTime.utc(2030),
              title: 'T$i',
              body: 'b',
            ),
        ];
        final replacing = q.replaceAll(items, 'c');
        await Future<void>.delayed(const Duration(milliseconds: 25));
        final cancelling = q.cancelAll();
        await Future.wait([replacing, cancelling]);
        // Annulation exécutée après la fin du remplacement, qui s'est arrêté.
        expect(inner.log.last, 'cancel');
        expect(
          inner.log.where((e) => e.startsWith('sched')).length,
          lessThan(5),
        );
        expect(inner.maxConcurrent, 1);
      },
    );
  });

  test('jour affiché : minuit UTC garde la date (pas de veille)', () {
    final m = Meta(id: 'a', type: 'series', name: 'A');
    final e = CalendarEntry(
      series: m,
      video: _ep('a:1:1', 1, 1, null),
      date: DateTime.utc(2030, 5, 10),
    );
    expect(groupByDay([e]).single.day, DateTime(2030, 5, 10));
    final p = notifyInstant(DateTime.utc(2030, 5, 10)).toLocal();
    expect([p.year, p.month, p.day, p.hour], [2030, 5, 10, 9]);
  });
}

class _SlowNotifier implements ReleaseNotifier {
  final log = <String>[];
  int running = 0;
  int maxConcurrent = 0;

  Future<void> _op(String name, Future<void> Function() f) async {
    running++;
    if (running > maxConcurrent) maxConcurrent = running;
    await f();
    running--;
  }

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> replaceAll(
    List<ScheduledRelease> items,
    String c, {
    bool Function()? isCurrent,
  }) async {
    await _op('replace', () async {
      for (final r in items) {
        if (isCurrent != null && !isCurrent()) return;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        log.add('sched${r.id}');
      }
    });
    return true;
  }

  @override
  Future<void> cancelAll() => _op('cancel', () async => log.add('cancel'));
}
