import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/app_settings.dart' hide TorrentSettings;
import 'package:lumio/data/db.dart';
import 'package:lumio/l10n/app_localizations.dart';
import 'package:lumio/l10n/error_messages.dart';
import 'package:lumio/l10n/app_localizations_fr.dart';
import 'package:lumio/player/player_screen.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/torrent/cache_manager.dart';
import 'package:lumio/torrent/network_watcher.dart';
import 'package:lumio/torrent/torrent_engine.dart' show TorrentSettings;
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

/// Lecture des réglages qui échoue une fois [failing] activé.
class _FailingStore extends _MemStore {
  _FailingStore([super.init]);
  bool failing = false;
  @override
  Future<String?> read(String key) async =>
      failing ? throw StateError('base fermée') : super.read(key);
}

/// Moteur dont l'initialisation coupe le VPN (fenêtre d'init longue).
class _DropVpnOnInit extends FakeTorrentEngine {
  _DropVpnOnInit(this.probe);
  final FakeNetworkProbe probe;
  @override
  Future<void> init(TorrentSettings s) async {
    await super.init(s);
    probe.up = [_wlan];
  }
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
    const tick = Duration(seconds: 3);

    test('appelle onStop une seule fois quand le VPN tombe', () {
      fakeAsync((fa) {
        final store = _MemStore({AppSettingsStore.requireVpnKey: '1'});
        final probe = FakeNetworkProbe([_wlan, _tun]);
        final stops = <String>[];
        final w = NetworkWatcher(
          privacy: TorrentPrivacy(probe: probe, store: store),
          onStop: stops.add,
        )..start();
        fa.elapse(tick * 3);
        expect(stops, isEmpty);
        expect(probe.calls, 3);
        probe.up = [_wlan];
        fa.elapse(tick * 3);
        expect(stops, hasLength(1));
        expect(w.running, isFalse);
      });
    });

    test('interfaces illisibles avec VPN exigé : arrêt', () {
      fakeAsync((fa) {
        final store = _MemStore({AppSettingsStore.requireVpnKey: '1'});
        final probe = FakeNetworkProbe([_tun]);
        final stops = <String>[];
        NetworkWatcher(
          privacy: TorrentPrivacy(probe: probe, store: store),
          onStop: stops.add,
        ).start();
        probe.error = const SocketException('x');
        fa.elapse(tick);
        expect(stops, hasLength(1));
      });
    });

    test('réglages illisibles : échec fermé, torrent arrêté', () {
      fakeAsync((fa) {
        final store = _FailingStore({AppSettingsStore.requireVpnKey: '1'});
        final stops = <String>[];
        NetworkWatcher(
          privacy: TorrentPrivacy(
            probe: FakeNetworkProbe([_tun]),
            store: store,
          ),
          onStop: stops.add,
        ).start();
        fa.elapse(tick);
        expect(stops, isEmpty);
        store.failing = true;
        fa.elapse(tick);
        expect(stops, hasLength(1));
      });
    });

    test('arrêté : plus d\'interrogation', () {
      fakeAsync((fa) {
        final probe = FakeNetworkProbe([_tun]);
        final w = NetworkWatcher(
          privacy: TorrentPrivacy(probe: probe, store: _MemStore()),
          onStop: (_) {},
        )..start();
        fa.elapse(tick * 2);
        w.stop();
        final n = probe.calls;
        fa.elapse(tick * 5);
        expect(probe.calls, n);
      });
    });
  });

  group('filterInterfaces', () {
    final v4 = InternetAddress('10.8.0.2');
    final linkLocal = InternetAddress('169.254.3.4');
    final v6 = InternetAddress('fe80::1');

    test('macOS : utun sans IPv4 routable ne compte pas comme VPN', () {
      final up = filterInterfaces([
        ('en0', [v4]),
        ('utun0', [v6]),
        ('utun1', [linkLocal]),
        ('utun2', [v4]),
      ], macos: true);
      expect([for (final i in up) i.name], ['en0', 'utun2']);
    });

    test('hors macOS : toutes les interfaces gardées', () {
      final up = filterInterfaces([
        ('wlan0', [v4]),
        ('tun0', [v6]),
      ], macos: false);
      expect(up, hasLength(2));
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
        // Le processus du moteur ne doit pas tourner sans le VPN exigé.
        expect(engine.disposed, isTrue);
        expect(
          l10nForError(AppLocalizationsFr(), const VpnRequiredException()),
          contains('VPN'),
        );
      },
    );

    test('VPN coupé pendant l\'initialisation : aucun pair contacté', () async {
      final probe = FakeNetworkProbe([_wlan, _tun]);
      final engine = _DropVpnOnInit(probe);
      final c = container(
        _MemStore({AppSettingsStore.requireVpnKey: '1'}),
        probe,
        engine,
      );
      final playback = c.read(torrentPlaybackFactoryProvider)();
      await expectLater(
        playback.prepare(_item),
        throwsA(isA<VpnRequiredException>()),
      );
      expect(engine.settings, isNotNull);
      expect(engine.addedMagnets, isEmpty);
      expect(engine.disposed, isTrue); // moteur lancé puis arrêté aussitôt
    });

    test(
      'shutdown (VPN tombé) arrête le moteur ; le suivant le relance',
      () async {
        final probe = FakeNetworkProbe([_wlan, _tun]);
        final engine = FakeTorrentEngine();
        final c = container(
          _MemStore({AppSettingsStore.requireVpnKey: '1'}),
          probe,
          engine,
        );
        final playback = c.read(torrentPlaybackFactoryProvider)();
        await playback.prepare(_item).timeout(const Duration(seconds: 5));
        expect(engine.disposed, isFalse);
        await playback.shutdown();
        expect(engine.disposed, isTrue);
        expect(engine.stopped, isNotEmpty); // torrent libéré avant l'arrêt
        engine.disposed = false;
        engine.settings = null;
        await playback.prepare(_item).timeout(const Duration(seconds: 5));
        expect(engine.settings, isNotNull); // réinitialisé
        await playback.release();
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
      FakeTorrentEngine? engine,
    }) async {
      final ctl = RecordingPlayerController();
      final e = engine ?? FakeTorrentEngine();
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
                stopEngine: e.dispose,
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
        expect(ctl.failures, isEmpty); // pas de « La lecture a échoué »
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
      expect(e.disposed, isTrue); // le processus du moteur est arrêté
      expect(
        ctl.failures.single,
        'VPN coupé : torrent arrêté pour protéger votre adresse IP.',
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('fermeture du lecteur : le watcher s\'arrête', (t) async {
      final probe = FakeNetworkProbe([_wlan, _tun]);
      await pumpPlayer(
        t,
        probe,
        settings: {
          AppSettingsStore.ipWarningAcceptedKey: '1',
          AppSettingsStore.requireVpnKey: '1',
        },
      );
      await t.pump(const Duration(seconds: 3));
      final n = probe.calls;
      expect(n, greaterThan(0));
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 12));
      expect(probe.calls, n);
    });

    testWidgets('Réessayer après échec du moteur : nouvelle préparation', (
      t,
    ) async {
      final probe = FakeNetworkProbe([_wlan]);
      final e = FakeTorrentEngine()
        ..addFailureOnce = const SocketException('moteur désaccordé');
      final (ctl, _, _) = await pumpPlayer(
        t,
        probe,
        engine: e,
        settings: {AppSettingsStore.ipWarningAcceptedKey: '1'},
      );
      expect(ctl.failures, hasLength(1));
      expect(ctl.opened, isEmpty);
      await t.tap(find.text('Réessayer'));
      await _settle(t);
      expect(e.addedMagnets, hasLength(1)); // le 1er add a échoué avant
      expect(ctl.opened, hasLength(1));
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('Réessayer après VPN coupé : le watcher repart', (t) async {
      final probe = FakeNetworkProbe([_wlan, _tun]);
      final (ctl, e, _) = await pumpPlayer(
        t,
        probe,
        settings: {
          AppSettingsStore.ipWarningAcceptedKey: '1',
          AppSettingsStore.requireVpnKey: '1',
        },
      );
      probe.up = [_wlan];
      await t.pump(const Duration(seconds: 3));
      await _settle(t);
      expect(ctl.failures, hasLength(1));
      probe.up = [_wlan, _tun];
      await t.tap(find.text('Réessayer'));
      await _settle(t);
      expect(ctl.opened, hasLength(2));
      probe.up = [_wlan];
      await t.pump(const Duration(seconds: 3));
      await _settle(t);
      expect(ctl.failures, hasLength(2));
      expect(e.stopped, ['fake-1', 'fake-2']);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('réglages illisibles : échec fermé, rien ne démarre', (
      t,
    ) async {
      final ctl = RecordingPlayerController();
      final e = FakeTorrentEngine();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            torrentPrivacyProvider.overrideWithValue(
              TorrentPrivacy(
                probe: FakeNetworkProbe([_tun]),
                store: _FailingStore()..failing = true,
              ),
            ),
            torrentPlaybackFactoryProvider.overrideWithValue(
              () => TorrentPlayback(engine: e),
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
      expect(e.addedMagnets, isEmpty);
      expect(ctl.failures.single, contains("n'a pas pu démarrer"));
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('dialogue IP : gauche/droite changent de bouton', (t) async {
      await pumpPlayer(t, FakeNetworkProbe([_wlan]));
      Finder btn(String k) => find.byKey(ValueKey('ipWarning:$k'));
      // La clé est sur le TvButton : le focus est celui de la carte qu'il contient.
      bool focused(String k) => Focus.of(
        t.element(find.descendant(of: btn(k), matching: find.byType(Text))),
      ).hasFocus;
      expect(focused('continue'), isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pump();
      expect(focused('cancel'), isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pump();
      expect(focused('continue'), isTrue);
      await t.tap(btn('cancel'));
      await _settle(t);
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
