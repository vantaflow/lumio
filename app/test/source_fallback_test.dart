import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/app_settings.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/l10n/app_localizations.dart';
import 'package:lumio/l10n/app_localizations_en.dart';
import 'package:lumio/l10n/app_localizations_fr.dart';
import 'package:lumio/player/player_screen.dart';
import 'package:lumio/player/source_fallback.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/torrent/network_watcher.dart' show TorrentPrivacy;
import 'package:lumio/torrent/torrent_engine.dart' show TorrentStatus;
import 'package:lumio/torrent/torrent_playback.dart';
import 'package:lumio/torrent/torrent_providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

import 'support/fake_network.dart';
import 'support/fake_torrent_engine.dart';
import 'support/recording_player.dart';

StreamItem _d(String t) => StreamItem(
  addonId: 'a',
  title: t,
  url: Uri.parse('https://cdn.example.com/$t.mp4'),
);

const _hash = '0123456789abcdef0123456789abcdef01234567';
const _torrent = StreamItem(addonId: 'a', title: 'T', infoHash: _hash);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('runWithFallback (séquence)', () {
    Future<(StreamItem?, List<String>)> run(
      List<StreamItem> items,
      Map<String, AttemptOutcome> outcomes, {
      int max = 3,
    }) async {
      final tried = <String>[];
      final r = await runWithFallback<StreamItem>(
        items,
        maxAttempts: max,
        attempt: (s, i, last) async {
          tried.add(s.title);
          return outcomes[s.title] ?? AttemptOutcome.played;
        },
      );
      return (r, tried);
    }

    test('1er flux en échec : le 2e est ouvert et rendu', () async {
      final (r, tried) = await run(
        [_d('a'), _d('b'), _d('c')],
        {'a': AttemptOutcome.sourceFailed},
      );
      expect(tried, ['a', 'b']);
      expect(r!.title, 'b');
    });

    test('au plus 3 sources essayées', () async {
      final fails = {
        for (final t in ['a', 'b', 'c', 'd']) t: AttemptOutcome.sourceFailed,
      };
      final (r, tried) = await run([_d('a'), _d('b'), _d('c'), _d('d')], fails);
      expect(tried, ['a', 'b', 'c']);
      expect(r, isNull);
    });

    test('lecture démarrée : on ne bascule plus', () async {
      final (r, tried) = await run([_d('a'), _d('b')], {});
      expect(tried, ['a']);
      expect(r!.title, 'a');
    });

    test('échec non imputable à la source : on s\'arrête', () async {
      final (r, tried) = await run(
        [_d('a'), _d('b')],
        {'a': AttemptOutcome.stopped},
      );
      expect(tried, ['a']);
      expect(r, isNull);
    });

    test('annulation : plus aucune tentative', () async {
      var cancel = false;
      final tried = <String>[];
      final r = await runWithFallback<StreamItem>(
        [_d('a'), _d('b')],
        cancelled: () => cancel,
        attempt: (s, i, last) async {
          tried.add(s.title);
          cancel = true;
          return AttemptOutcome.sourceFailed;
        },
      );
      expect(tried, ['a']);
      expect(r, isNull);
    });

    test('liste vide : rien', () async {
      expect((await run(const [], {})).$1, isNull);
    });
  });

  group('AttemptGate (signaux périmés)', () {
    test('erreur tardive de la tentative 1 pendant la tentative 2', () {
      final g = AttemptGate();
      final a1 = g.begin();
      g.bindEngine(a1);
      expect(g.acceptsEngine, isTrue);
      // La source 1 est abandonnée, la tentative 2 démarre.
      final a2 = g.begin();
      expect(g.acceptsEngine, isFalse); // le moteur parle encore de la 1
      expect(g.accepts(a1), isFalse); // échec ou délai de la 1 : ignoré
      expect(g.accepts(a2), isTrue);
      g.bindEngine(a2);
      expect(g.acceptsEngine, isTrue); // média 2 : ses signaux comptent
    });

    test('ouverture simple : le moteur n\'est écouté qu\'une fois lié', () {
      final g = AttemptGate();
      g.unbindEngine();
      expect(g.acceptsEngine, isFalse);
      g.bindEngine(g.current);
      expect(g.acceptsEngine, isTrue);
    });
  });

  test('message de bascule fr et en', () {
    expect(
      AppLocalizationsFr().playerSourceFallback,
      'Source indisponible, essai de la suivante…',
    );
    expect(AppLocalizationsEn().playerSourceFallback, contains('next'));
  });

  group('PlayerScreen : basculement', () {
    late AppDatabase db;

    Future<RecordingPlayerController> pump(
      WidgetTester t,
      StreamItem item,
      List<StreamItem> fallbacks, {
      FakeTorrentEngine? engine,
      Set<String> failing = const {},
      Map<String, String>? settings,
    }) async {
      final ctl = RecordingPlayerController()..failOpen.addAll(failing);
      db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = AppSettingsStore(db);
      for (final e in (settings ?? const <String, String>{}).entries) {
        await t.runAsync(() => store.write(e.key, e.value));
      }
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            torrentPrivacyProvider.overrideWithValue(
              settings == null
                  ? OpenPrivacy(store)
                  : TorrentPrivacy(
                      probe: FakeNetworkProbe([const NetInterface('wlan0')]),
                      store: store,
                    ),
            ),
            torrentPlaybackFactoryProvider.overrideWithValue(
              () => TorrentPlayback(
                engine: engine ?? FakeTorrentEngine(),
                peerTimeout: const Duration(milliseconds: 60),
                pollInterval: const Duration(milliseconds: 5),
              ),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: const [LumioColors.dark]),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('fr'),
            home: PlayerScreen(
              item: item,
              fallbacks: fallbacks,
              controller: ctl,
              videoBuilder: (_) => const ColoredBox(color: Colors.black),
              tracksBackend: (_) => NoTracksBackend(),
            ),
          ),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 100));
      }
      return ctl;
    }

    testWidgets('échec d\'ouverture du 1er : le 2e est lu, signalé', (t) async {
      final ctl = await pump(t, _d('a'), [_d('b'), _d('c')], failing: {'a'});
      expect([for (final s in ctl.opened) s.title], ['a', 'b']);
      expect(ctl.fallbackRuns.single, ['a', 'b', 'c']);
      expect(find.textContaining('autre source : b'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('sans source de secours : ouverture simple, sans bascule', (
      t,
    ) async {
      final ctl = await pump(t, _d('a'), const [], failing: {'a'});
      expect([for (final s in ctl.opened) s.title], ['a']);
      expect(ctl.fallbackRuns, isEmpty);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('VPN exigé et absent : arrêt net, aucune bascule', (t) async {
      final ctl = await pump(
        t,
        _torrent,
        [_d('b')],
        settings: {
          AppSettingsStore.requireVpnKey: '1',
          AppSettingsStore.ipWarningAcceptedKey: '1',
        },
      );
      expect(ctl.opened, isEmpty);
      expect(ctl.failures.single, contains('VPN'));
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('torrent sans pair : bascule sur le lien direct suivant', (
      t,
    ) async {
      final engine = FakeTorrentEngine(
        statusValue: const TorrentStatus(
          peers: 0,
          seeders: 0,
          downloadRate: 0,
          uploadRate: 0,
          progress: 0,
        ),
      );
      final ctl = await pump(t, _torrent, [_d('b')], engine: engine);
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await t.pump(const Duration(milliseconds: 300));
      expect(ctl.failures.single, contains('source'));
      expect([for (final s in ctl.opened) s.title], ['b']);
      expect(ctl.trusted.single, isFalse); // lien direct par le chemin normal
      await t.pumpWidget(const SizedBox());
    });
  });
}
