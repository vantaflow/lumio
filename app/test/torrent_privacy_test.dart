import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/app_settings.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/l10n/app_localizations.dart';
import 'package:lumio/l10n/error_messages.dart';
import 'package:lumio/l10n/app_localizations_fr.dart';
import 'package:lumio/player/player_screen.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/torrent/cache_manager.dart';
import 'package:lumio/torrent/network_watcher.dart';
import 'package:lumio/torrent/torrent_playback.dart';
import 'package:lumio/torrent/torrent_providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

import 'support/fake_network.dart';
import 'support/fake_torrent_engine.dart';
import 'support/recording_player.dart';

const _hash = '0123456789abcdef0123456789abcdef01234567';
const _item = StreamItem(addonId: 'a', title: 'Film', infoHash: _hash);
const _wlan = NetInterface('wlan0');
const _tun = NetInterface('tun0');

/// Réglages en mémoire (la base n'est jamais ouverte).
class _MemStore extends AppSettingsStore {
  _MemStore([Map<String, String>? init])
    : data = init ?? {},
      super(AppDatabase(NativeDatabase.memory()));
  final Map<String, String> data;
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
}

class _Storage implements StorageInfo {
  @override
  Future<int?> freeBytes(String path) async => 50 * 1024 * 1024 * 1024;
}

void main() {
  // Bases en mémoire jamais ouvertes (réglages factices) : pas d'alerte.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('TorrentPrivacy', () {
    test('réglages relus à chaque évaluation', () async {
      final store = _MemStore();
      final probe = FakeNetworkProbe([_wlan]);
      final p = TorrentPrivacy(probe: probe, store: store);
      expect(await p.evaluate(), same(GuardDecision.warnNoVpn));
      store.data[AppSettingsStore.requireVpnKey] = '1';
      expect(await p.evaluate(), isA<GuardStop>());
      probe.up = [_wlan, _tun];
      expect(await p.evaluate(), same(GuardDecision.allow));
      store.data[AppSettingsStore.vpnInterfaceKey] = 'wg0';
      expect(await p.evaluate(), isA<GuardStop>());
    });

    test('interfaces illisibles : stop si exigé, sinon rappel', () async {
      final store = _MemStore();
      final probe = FakeNetworkProbe()..error = const SocketException('x');
      final p = TorrentPrivacy(probe: probe, store: store);
      expect(await p.evaluate(), same(GuardDecision.warnNoVpn));
      store.data[AppSettingsStore.requireVpnKey] = '1';
      expect(await p.evaluate(), isA<GuardStop>());
    });

    test('avertissement IP mémorisé', () async {
      final p = TorrentPrivacy(probe: FakeNetworkProbe(), store: _MemStore());
      expect(await p.ipWarningAccepted(), isFalse);
      await p.acceptIpWarning();
      expect(await p.ipWarningAccepted(), isTrue);
    });
  });

  group('NetworkWatcher', () {
    test('appelle onStop une seule fois quand le VPN tombe', () async {
      final store = _MemStore({AppSettingsStore.requireVpnKey: '1'});
      final probe = FakeNetworkProbe([_wlan, _tun]);
      final stops = <String>[];
      final w = NetworkWatcher(
        privacy: TorrentPrivacy(probe: probe, store: store),
        interval: const Duration(milliseconds: 20),
        onStop: stops.add,
      )..start();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(stops, isEmpty);
      expect(probe.calls, greaterThan(1));
      probe.up = [_wlan];
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(stops, hasLength(1));
      expect(w.running, isFalse);
      w.stop();
    });

    test('erreur de lecture : on réessaie, aucun arrêt', () async {
      final store = _MemStore({AppSettingsStore.requireVpnKey: '1'});
      final probe = FakeNetworkProbe([_tun]);
      final stops = <String>[];
      final w = NetworkWatcher(
        privacy: TorrentPrivacy(probe: probe, store: store),
        interval: const Duration(milliseconds: 20),
        onStop: stops.add,
      )..start();
      // Une erreur de lecture avec VPN exigé vaut « interfaces illisibles ».
      probe.error = const SocketException('x');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(stops, hasLength(1));
      w.stop();
    });

    test('arrêté : plus d\'interrogation', () async {
      final probe = FakeNetworkProbe([_tun]);
      final w = NetworkWatcher(
        privacy: TorrentPrivacy(probe: probe, store: _MemStore()),
        interval: const Duration(milliseconds: 20),
        onStop: (_) {},
      )..start();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      w.stop();
      final n = probe.calls;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(probe.calls, n);
    });
  });

  group('démarrage du moteur', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('lumio_priv'));
    tearDown(() => root.deleteSync(recursive: true));

    ProviderContainer container(
      _MemStore store,
      FakeNetworkProbe probe,
      FakeTorrentEngine engine,
    ) {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          torrentEngineProvider.overrideWithValue(engine),
          torrentSavePathProvider.overrideWithValue(Future.value(root.path)),
          storageInfoProvider.overrideWithValue(_Storage()),
          networkProbeProvider.overrideWithValue(probe),
          torrentPrivacyProvider.overrideWithValue(
            TorrentPrivacy(probe: probe, store: store),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test(
      'VPN exigé et absent : refus avant tout contact avec des pairs',
      () async {
        final engine = FakeTorrentEngine();
        final c = container(
          _MemStore({AppSettingsStore.requireVpnKey: '1'}),
          FakeNetworkProbe([_wlan]),
          engine,
        );
        final playback = c.read(torrentPlaybackFactoryProvider)();
        await expectLater(
          playback.prepare(_item),
          throwsA(isA<VpnRequiredException>()),
        );
        expect(engine.settings, isNull);
        expect(engine.addedMagnets, isEmpty);
        expect(
          l10nForError(AppLocalizationsFr(), const VpnRequiredException()),
          contains('VPN'),
        );
      },
    );

    test('VPN exigé et présent : le torrent démarre', () async {
      final engine = FakeTorrentEngine();
      final c = container(
        _MemStore({AppSettingsStore.requireVpnKey: '1'}),
        FakeNetworkProbe([_wlan, _tun]),
        engine,
      );
      final playback = c.read(torrentPlaybackFactoryProvider)();
      await playback.prepare(_item).timeout(const Duration(seconds: 5));
      expect(engine.addedMagnets, hasLength(1));
      await playback.release();
    });
  });

  group('PlayerScreen torrent : confidentialité', () {
    Future<(RecordingPlayerController, FakeTorrentEngine, _MemStore)>
    pumpPlayer(
      WidgetTester t,
      FakeNetworkProbe probe, {
      Map<String, String>? settings,
    }) async {
      final ctl = RecordingPlayerController();
      final e = FakeTorrentEngine();
      final store = _MemStore(settings);
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            torrentPrivacyProvider.overrideWithValue(
              TorrentPrivacy(probe: probe, store: store),
            ),
            torrentPlaybackFactoryProvider.overrideWithValue(
              () => TorrentPlayback(
                engine: e,
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
              item: _item,
              controller: ctl,
              videoBuilder: (_) => const ColoredBox(color: Colors.black),
              tracksBackend: (_) => NoTracksBackend(),
            ),
          ),
        ),
      );
      await _settle(t);
      return (ctl, e, store);
    }

    testWidgets(
      'première utilisation : avertissement, Annuler = rien ne part',
      (t) async {
        final (ctl, e, store) = await pumpPlayer(t, FakeNetworkProbe([_wlan]));
        expect(find.text('Votre adresse IP sera visible'), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('ipWarning:cancel')));
        await _settle(t);
        expect(e.addedMagnets, isEmpty);
        expect(ctl.opened, isEmpty);
        expect(ctl.failures.single, contains('Torrent non démarré'));
        expect(store.data[AppSettingsStore.ipWarningAcceptedKey], isNull);
        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets('Continuer : mémorisé, rappel sans VPN, lecture lancée', (
      t,
    ) async {
      final (ctl, e, store) = await pumpPlayer(t, FakeNetworkProbe([_wlan]));
      await t.tap(find.byKey(const ValueKey('ipWarning:continue')));
      await _settle(t);
      expect(store.data[AppSettingsStore.ipWarningAcceptedKey], '1');
      expect(ctl.opened, hasLength(1));
      expect(e.addedMagnets, hasLength(1));
      expect(find.textContaining('Aucun VPN détecté'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('déjà accepté : pas de dialogue', (t) async {
      final (ctl, _, _) = await pumpPlayer(
        t,
        FakeNetworkProbe([_wlan, _tun]),
        settings: {AppSettingsStore.ipWarningAcceptedKey: '1'},
      );
      expect(find.text('Votre adresse IP sera visible'), findsNothing);
      expect(ctl.opened, hasLength(1));
      expect(find.textContaining('Aucun VPN détecté'), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('VPN exigé et absent : message, aucun pair contacté', (
      t,
    ) async {
      final (ctl, e, _) = await pumpPlayer(
        t,
        FakeNetworkProbe([_wlan]),
        settings: {
          AppSettingsStore.ipWarningAcceptedKey: '1',
          AppSettingsStore.requireVpnKey: '1',
        },
      );
      expect(e.addedMagnets, isEmpty);
      expect(ctl.opened, isEmpty);
      expect(ctl.failures.single, contains('Un VPN est exigé'));
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('VPN coupé pendant la lecture : torrent arrêté et supprimé', (
      t,
    ) async {
      final probe = FakeNetworkProbe([_wlan, _tun]);
      final (ctl, e, _) = await pumpPlayer(
        t,
        probe,
        settings: {
          AppSettingsStore.ipWarningAcceptedKey: '1',
          AppSettingsStore.requireVpnKey: '1',
        },
      );
      expect(ctl.opened, hasLength(1));
      expect(e.stopped, isEmpty);
      await t.pump(const Duration(seconds: 3));
      expect(ctl.failures, isEmpty);
      probe.up = [_wlan];
      await t.pump(const Duration(seconds: 3));
      await _settle(t);
      expect(e.stopped, ['fake-1']);
      expect(e.stopDeleteData, [true]);
      expect(
        ctl.failures.single,
        'VPN coupé : torrent arrêté pour protéger votre adresse IP.',
      );
      await t.pumpWidget(const SizedBox());
    });
  });
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
}
