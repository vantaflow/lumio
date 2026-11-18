import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/app_settings.dart' as prefs;
import 'package:lumio/features/settings/settings_providers.dart';
import 'package:lumio/torrent/cache_manager.dart';
import 'package:lumio/torrent/libtorrent_engine.dart';
import 'package:lumio/torrent/torrent_engine.dart';
import 'package:lumio/torrent/torrent_playback.dart';
import 'package:lumio/ui/focus/tv_detection.dart';
import 'package:path_provider/path_provider.dart';

/// Moteur de torrents unique pour toute l'application ; remplacé en test.
final torrentEngineProvider = Provider<TorrentEngine>((ref) {
  final engine = LibtorrentEngine();
  ref.onDispose(() => engine.dispose());
  return engine;
});

/// Dossier de travail des torrents (vidé à chaque lecture par `release`).
final torrentSavePathProvider = Provider<Future<String>>((ref) async {
  final base = await getTemporaryDirectory();
  final dir = await Directory(
    '${base.path}/lumio_torrents',
  ).create(recursive: true);
  return dir.path;
});

/// Espace libre du volume (Android : StatFs) ; remplacé en test.
final storageInfoProvider = Provider<StorageInfo>(
  (ref) => const PlatformStorageInfo(),
);

/// Politique de cache : taille selon l'espace libre, nettoyage au démarrage
/// et à la fermeture.
final cacheManagerProvider = Provider<CacheManager>((ref) {
  return CacheManager(
    storage: ref.watch(storageInfoProvider),
    savePath: () => ref.read(torrentSavePathProvider),
    isTv: ref.watch(androidTvProvider),
    clearOnExit: () async {
      final stored = await ref
          .read(appSettingsStoreProvider)
          .read(prefs.AppSettingsStore.clearCacheOnExitKey);
      // Sans réglage enregistré : activé sur TV seulement.
      return stored == null ? ref.read(androidTvProvider) : stored == '1';
    },
  );
});

/// Fabrique de lectures de torrent ; le moteur est initialisé au premier
/// torrent seulement, avec la taille de cache bornée par l'espace libre et
/// le débit montant (0 = ensemencement désactivé). Un espace insuffisant
/// lève `InsufficientStorageException` avant tout contact avec des pairs.
final torrentPlaybackFactoryProvider = Provider<TorrentPlayback Function()>((
  ref,
) {
  Future<void>? init;
  Future<void> start() async {
    final store = ref.read(appSettingsStoreProvider);
    final cache = ref.read(cacheManagerProvider);
    await cache.cleanOnStart();
    const defaults = prefs.TorrentSettings();
    final cacheGb = await store.readInt(prefs.AppSettingsStore.torrentCacheKey);
    final upKbps =
        await store.readInt(prefs.AppSettingsStore.uploadKey) ??
        defaults.uploadKbps;
    final settings = await cache.resolve(
      requestedCacheBytes: cacheGb != null && cacheGb > 0
          ? cacheGb * 1024 * 1024 * 1024
          : null,
      uploadKbps: upKbps,
    );
    await ref.read(torrentEngineProvider).init(settings);
  }

  Future<void> ready() => init ??= start().catchError((Object e) {
    init = null; // nouvelle tentative au prochain torrent
    throw e;
  });
  return () => TorrentPlayback(
    engine: ref.read(torrentEngineProvider),
    ready: ready,
    enforceCache: (playing) =>
        ref.read(cacheManagerProvider).enforce(playingId: playing),
  );
});
