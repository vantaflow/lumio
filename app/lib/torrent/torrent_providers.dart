import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/app_settings.dart' as prefs;
import 'package:lumio/features/settings/settings_providers.dart';
import 'package:lumio/torrent/libtorrent_engine.dart';
import 'package:lumio/torrent/torrent_engine.dart';
import 'package:lumio/torrent/torrent_playback.dart';
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

/// Fabrique de lectures de torrent ; le moteur est initialisé au premier
/// torrent seulement, avec les réglages de cache et de débit montant (la
/// politique de cache complète est portée par la tâche 25).
final torrentPlaybackFactoryProvider = Provider<TorrentPlayback Function()>((
  ref,
) {
  Future<void>? init;
  Future<void> start() async {
    final store = ref.read(appSettingsStoreProvider);
    final cacheGb =
        await store.readInt(prefs.AppSettingsStore.torrentCacheKey) ??
        const prefs.TorrentSettings().cacheGb;
    final upKbps =
        await store.readInt(prefs.AppSettingsStore.uploadKey) ??
        const prefs.TorrentSettings().uploadKbps;
    await ref
        .read(torrentEngineProvider)
        .init(
          TorrentSettings(
            savePath: await ref.read(torrentSavePathProvider),
            maxCacheBytes: (cacheGb > 0 ? cacheGb : 2) * 1024 * 1024 * 1024,
            uploadLimit: upKbps > 0 ? upKbps * 1024 : 0,
          ),
        );
  }

  Future<void> ready() => init ??= start().catchError((Object e) {
    init = null; // nouvelle tentative au prochain torrent
    throw e;
  });
  return () =>
      TorrentPlayback(engine: ref.read(torrentEngineProvider), ready: ready);
});
