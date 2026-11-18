import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:lumio/torrent/torrent_engine.dart';
import 'package:lumio_core/lumio_core.dart';

/// Espace libre du volume qui porte un dossier (octets), `null` si inconnu.
abstract class StorageInfo {
  Future<int?> freeBytes(String path);
}

/// Android : `StatFs` via un petit canal (voir `MainActivity`). Autres
/// plateformes : `df -k` (macOS, Linux) ; `null` ailleurs (Windows).
class PlatformStorageInfo implements StorageInfo {
  const PlatformStorageInfo();

  static const channel = MethodChannel('dev.lumio.app/storage');

  @override
  Future<int?> freeBytes(String path) async {
    try {
      if (Platform.isAndroid) {
        return await channel.invokeMethod<int>('freeBytes', {'path': path});
      }
      if (Platform.isMacOS || Platform.isLinux) {
        final r = await Process.run('df', ['-k', path]);
        return r.exitCode == 0 ? parseDfAvailableBytes('${r.stdout}') : null;
      }
    } on Object catch (e) {
      debugPrint('PlatformStorageInfo : lecture impossible (${e.runtimeType})');
    }
    return null;
  }
}

/// Colonne « Available » (en Ko) de la 2e ligne de `df -k`, en octets.
int? parseDfAvailableBytes(String out) {
  final lines = out.trim().split('\n');
  if (lines.length < 2) return null;
  // Le nom du volume peut contenir des espaces : on cherche le premier
  // triplet numérique consécutif (total, utilisé, disponible).
  final cols = lines[1].trim().split(RegExp(r'\s+'));
  for (var i = 1; i + 2 < cols.length; i++) {
    final total = int.tryParse(cols[i]);
    final used = int.tryParse(cols[i + 1]);
    final avail = int.tryParse(cols[i + 2]);
    if (total != null && used != null && avail != null) return avail * 1024;
  }
  return null;
}

/// Politique de cache côté application : taille effective selon l'espace
/// libre, éviction des plus anciens, nettoyage au démarrage et à la fermeture.
/// Le dossier [savePath] ne contient que des données de torrents.
class CacheManager {
  CacheManager({
    required this.storage,
    required this.savePath,
    required this.isTv,
    required this.clearOnExit,
    this.fallbackFreeBytes = 10 * 1024 * 1024 * 1024,
  });

  final StorageInfo storage;
  final Future<String> Function() savePath;
  final bool isTv;

  /// Réglage « Vider le cache à la fermeture ».
  final Future<bool> Function() clearOnExit;

  /// Espace supposé libre quand il est inconnu (prudent, sans bloquer).
  final int fallbackFreeBytes;

  Future<void>? _startClean;

  /// Réglages du moteur : taille du cache bornée par l'espace libre, débit
  /// montant (0 = ensemencement désactivé). Lève
  /// [InsufficientStorageException] avant tout contact avec des pairs.
  Future<TorrentSettings> resolve({
    int? requestedCacheBytes,
    int uploadKbps = 0,
    String? playingId,
  }) async {
    final dir = await savePath();
    final free = await storage.freeBytes(dir) ?? fallbackFreeBytes;
    final cache = effectiveCacheBytes(
      requestedBytes: requestedCacheBytes,
      freeBytes: free,
      isTv: isTv,
    );
    await enforceLimit(cache, playingId: playingId);
    return TorrentSettings(
      savePath: dir,
      maxCacheBytes: cache,
      seed: uploadKbps > 0,
      uploadLimit: uploadKbps > 0 ? uploadKbps * 1024 : 0,
    );
  }

  /// Supprime les plus anciens dossiers de torrents jusqu'à passer sous
  /// [limit], sauf [playingId].
  Future<void> enforceLimit(int limit, {String? playingId}) async {
    final dir = Directory(await savePath());
    if (!dir.existsSync()) return;
    final all = <CachedTorrent>[];
    for (final e in dir.listSync(followLinks: false)) {
      final id = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
      all.add(CachedTorrent(id: id, bytes: _sizeOf(e), lastUsed: _lastUsed(e)));
    }
    for (final victim in evictionPlan(all, limit, playingId)) {
      _deletePath('${dir.path}/${victim.id}');
    }
  }

  /// Supprime les données orphelines (aucun torrent n'est actif au démarrage).
  /// Une seule exécution, partagée entre le démarrage de l'application et le
  /// premier torrent.
  Future<void> cleanOnStart() => _startClean ??= _wipe();

  /// Vide le cache à la fermeture si le réglage est activé.
  Future<void> cleanOnExit() async {
    if (await clearOnExit()) await _wipe();
  }

  Future<void> _wipe() async {
    try {
      final dir = Directory(await savePath());
      if (!dir.existsSync()) return;
      for (final e in dir.listSync(followLinks: false)) {
        try {
          e.deleteSync(recursive: true);
        } on FileSystemException catch (err) {
          debugPrint('CacheManager : suppression impossible (${err.message})');
        }
      }
    } on Object catch (e) {
      debugPrint('CacheManager : nettoyage échoué (${e.runtimeType})');
    }
  }

  void _deletePath(String path) {
    try {
      if (FileSystemEntity.isDirectorySync(path)) {
        Directory(path).deleteSync(recursive: true);
      } else {
        File(path).deleteSync();
      }
    } on FileSystemException catch (err) {
      debugPrint('CacheManager : suppression impossible (${err.message})');
    }
  }

  static int _sizeOf(FileSystemEntity e) {
    if (e is File) return e.lengthSync();
    if (e is Directory) {
      var total = 0;
      for (final f in e.listSync(recursive: true, followLinks: false)) {
        if (f is File) total += f.lengthSync();
      }
      return total;
    }
    return 0;
  }

  static DateTime _lastUsed(FileSystemEntity e) {
    var latest = e.statSync().modified;
    if (e is Directory) {
      for (final f in e.listSync(recursive: true, followLinks: false)) {
        final m = f.statSync().modified;
        if (m.isAfter(latest)) latest = m;
      }
    }
    return latest;
  }
}
