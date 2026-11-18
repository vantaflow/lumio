import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/app_settings.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/torrent/cache_manager.dart';
import 'package:lumio/torrent/torrent_providers.dart';
import 'package:lumio_core/lumio_core.dart';

import 'support/fake_torrent_engine.dart';

class _Storage implements StorageInfo {
  _Storage(this.free);
  final int free;
  @override
  Future<int?> freeBytes(String path) async => free;
}

const _hash = '0123456789abcdef0123456789abcdef01234567';

void main() {
  late Directory root;
  late AppDatabase db;
  setUp(() {
    root = Directory.systemTemp.createTempSync('lumio_start_test');
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
  });

  ProviderContainer container(int free, FakeTorrentEngine engine) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        torrentEngineProvider.overrideWithValue(engine),
        torrentSavePathProvider.overrideWithValue(Future.value(root.path)),
        storageInfoProvider.overrideWithValue(_Storage(free)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'espace insuffisant : erreur avant tout contact avec des pairs',
    () async {
      final engine = FakeTorrentEngine();
      final c = container(200 * 1024 * 1024, engine);
      final playback = c.read(torrentPlaybackFactoryProvider)();
      await expectLater(
        playback.prepare(
          const StreamItem(addonId: 'a', title: 't', infoHash: _hash),
        ),
        throwsA(isA<InsufficientStorageException>()),
      );
      expect(engine.settings, isNull);
      expect(engine.addedMagnets, isEmpty);
    },
  );

  test('réglages enregistrés : cache borné et ensemencement coupé', () async {
    final engine = FakeTorrentEngine();
    final c = container(10 * 1024 * 1024 * 1024, engine);
    await AppSettingsStore(db).write(AppSettingsStore.torrentCacheKey, '5');
    final playback = c.read(torrentPlaybackFactoryProvider)();
    await playback
        .prepare(const StreamItem(addonId: 'a', title: 't', infoHash: _hash))
        .timeout(const Duration(seconds: 5));
    expect(engine.settings!.maxCacheBytes, 3 * 1024 * 1024 * 1024);
    expect(engine.settings!.seed, isFalse);
    await playback.release();
  });
}
