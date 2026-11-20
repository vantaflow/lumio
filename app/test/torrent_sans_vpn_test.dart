import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/app_settings.dart' hide TorrentSettings;
import 'package:lumio/data/db.dart';
import 'package:lumio/features/settings/settings_providers.dart';
import 'package:lumio/l10n/app_localizations.dart';
import 'package:lumio/player/player_screen.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/torrent/cache_manager.dart';
import 'package:lumio/torrent/torrent_playback.dart';
import 'package:lumio/torrent/torrent_providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

import 'support/fake_torrent_engine.dart';
import 'support/recording_player.dart';

const _hash = '0123456789abcdef0123456789abcdef01234567';
const _item = StreamItem(addonId: 'a', title: 'Film', infoHash: _hash);

/// Anciens réglages VPN encore stockés par les versions précédentes.
const _legacy = {
  'torrent_require_vpn': '1',
  'torrent_vpn_interface': 'wg0',
  'torrent_ip_warning_accepted': '0',
};

/// Réglages en mémoire (la base n'est jamais ouverte).
class _MemStore extends AppSettingsStore {
  _MemStore([Map<String, String>? init])
    : data = {...?init},
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

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('torrent sans VPN', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('lumio_novpn'));
    tearDown(() => root.deleteSync(recursive: true));

    ProviderContainer container(_MemStore store, FakeTorrentEngine engine) {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          appSettingsStoreProvider.overrideWithValue(store),
          torrentEngineProvider.overrideWithValue(engine),
          torrentSavePathProvider.overrideWithValue(Future.value(root.path)),
          storageInfoProvider.overrideWithValue(_Storage()),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('le moteur démarre sans aucune condition réseau', () async {
      final engine = FakeTorrentEngine();
      final c = container(_MemStore(), engine);
      final playback = c.read(torrentPlaybackFactoryProvider)();
      await playback.prepare(_item);
      expect(engine.settings, isNotNull);
      expect(engine.addedMagnets, hasLength(1));
      expect(engine.disposed, isFalse);
      await playback.release();
    });

    test(
      'anciens réglages VPN stockés : ignorés, le torrent démarre',
      () async {
        final engine = FakeTorrentEngine();
        final store = _MemStore(_legacy);
        final c = container(store, engine);
        final playback = c.read(torrentPlaybackFactoryProvider)();
        await playback.prepare(_item);
        expect(engine.addedMagnets, hasLength(1));
        await playback.release();
      },
    );

    test(
      'anciens réglages VPN stockés : lecture des réglages sans erreur',
      () async {
        final store = _MemStore({
          ..._legacy,
          AppSettingsStore.torrentCacheKey: '3',
          AppSettingsStore.uploadKey: '512',
        });
        final c = container(store, FakeTorrentEngine());
        c.listen(torrentSettingsProvider, (_, _) {});
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final s = c.read(torrentSettingsProvider);
        expect(s.cacheGb, 3);
        expect(s.uploadKbps, 512);
      },
    );
  });

  group('PlayerScreen torrent', () {
    Future<(RecordingPlayerController, FakeTorrentEngine)> pumpPlayer(
      WidgetTester t,
      Map<String, String> settings,
    ) async {
      final ctl = RecordingPlayerController();
      final e = FakeTorrentEngine();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            appSettingsStoreProvider.overrideWithValue(_MemStore(settings)),
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
      return (ctl, e);
    }

    for (final (name, settings) in [
      ('premier torrent', <String, String>{}),
      ('anciens réglages VPN stockés', _legacy),
    ]) {
      testWidgets('$name : lecture directe, sans dialogue ni rappel', (
        t,
      ) async {
        final (ctl, e) = await pumpPlayer(t, settings);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        expect(find.textContaining('VPN'), findsNothing);
        expect(find.textContaining('adresse IP'), findsNothing);
        expect(e.addedMagnets, hasLength(1));
        expect(ctl.opened, hasLength(1));
        expect(ctl.failures, isEmpty);
        await t.pumpWidget(const SizedBox());
      });
    }

    testWidgets('Réessayer après échec du moteur : nouvelle préparation', (
      t,
    ) async {
      final ctl = RecordingPlayerController();
      final e = FakeTorrentEngine()
        ..addFailureOnce = const SocketException('moteur désaccordé');
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
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
      expect(ctl.failures, hasLength(1));
      expect(ctl.opened, isEmpty);
      await t.tap(find.text('Réessayer'));
      await _settle(t);
      expect(e.addedMagnets, hasLength(1));
      expect(ctl.opened, hasLength(1));
      await t.pumpWidget(const SizedBox());
    });
  });
}
