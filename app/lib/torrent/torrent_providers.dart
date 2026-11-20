import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/app_settings.dart' as prefs;
import 'package:lumio/features/settings/settings_providers.dart';
import 'package:lumio/torrent/cache_manager.dart';
import 'package:lumio/torrent/network_watcher.dart';
import 'package:lumio/torrent/torrent_engine.dart';
import 'package:lumio/torrent/torrent_playback.dart';
import 'package:lumio/torrent/torrserver_engine.dart';
import 'package:lumio/torrent/torrserver_process.dart';
import 'package:lumio/ui/focus/tv_detection.dart';
import 'package:lumio_core/lumio_core.dart' show GuardStop;
import 'package:path_provider/path_provider.dart';

/// Moteur de torrents unique pour toute l'application ; remplacé en test.
final torrentEngineProvider = Provider<TorrentEngine>((ref) {
  final engine = TorrServerEngine(process: const PlatformTorrServerProcess());
  ref.onDispose(() => engine.dispose());
  return engine;
});

/// Interfaces réseau actives ; remplacé en test.
final networkProbeProvider = Provider<NetworkProbe>(
  (ref) => const PlatformNetworkProbe(),
);

/// Confidentialité réseau des torrents (coupe-circuit VPN, avertissement IP).
final torrentPrivacyProvider = Provider<TorrentPrivacy>(
  (ref) => TorrentPrivacy(
    probe: ref.watch(networkProbeProvider),
    store: ref.watch(appSettingsStoreProvider),
  ),
);

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

  Future<void> initOnce() => init ??= start().catchError((Object e) {
    init = null; // nouvelle tentative au prochain torrent
    throw e;
  });

  /// Arrête le moteur et son processus ; `ready` le relancera.
  Future<void> stopEngine() async {
    init = null;
    await ref.read(torrentEngineProvider).dispose();
  }

  Future<void> ready() async {
    // Coupe-circuit à chaque démarrage, avant tout contact avec des pairs :
    // sans le VPN exigé, le processus du moteur ne démarre pas (et s'il
    // tournait encore, il est arrêté).
    final d = await ref.read(torrentPrivacyProvider).evaluate();
    if (d is GuardStop) {
      await stopEngine();
      throw const VpnRequiredException();
    }
    await initOnce();
    // L'initialisation peut être longue (premier démarrage) : le VPN a pu
    // tomber entre-temps. Nouvelle évaluation juste avant `engine.add`.
    final again = await ref.read(torrentPrivacyProvider).evaluate();
    if (again is GuardStop) {
      await stopEngine();
      throw const VpnRequiredException();
    }
  }

  return () => TorrentPlayback(
    engine: ref.read(torrentEngineProvider),
    ready: ready,
    stopEngine: stopEngine,
    enforceCache: (playing) =>
        ref.read(cacheManagerProvider).enforce(playingId: playing),
  );
});
