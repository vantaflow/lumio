/// Politique du cache disque des torrents (story 1.9) : taille par défaut
/// selon l'espace libre et plan d'éviction. Fonctions pures, sans E/S.
library;

const _mb = 1024 * 1024;
const _gb = 1024 * _mb;

/// Taille minimale utile du cache ; en dessous, la lecture n'est pas tentée.
const minCacheBytes = 300 * _mb;

/// Plafond par défaut sur Android TV (stockage réduit).
const tvCacheCapBytes = 3 * _gb ~/ 2;

/// Plafond par défaut sur les autres appareils.
const defaultCacheCapBytes = 5 * _gb;

/// Part maximale de l'espace libre que le cache peut occuper (30 %).
int _thirtyPercent(int freeBytes) => freeBytes * 3 ~/ 10;

/// L'espace libre est trop faible pour un cache d'au moins [minCacheBytes].
class InsufficientStorageException implements Exception {
  const InsufficientStorageException({
    required this.freeBytes,
    this.neededBytes = minCacheBytes,
  });
  final int freeBytes;
  final int neededBytes;
  @override
  String toString() =>
      'InsufficientStorageException: espace insuffisant ($freeBytes octets libres)';
}

/// Taille par défaut du cache : TV min(1,5 Go, 30 % du libre), autres
/// min(5 Go, 30 % du libre). Lève [InsufficientStorageException] si le
/// résultat est inférieur à 300 Mo.
int defaultCacheBytes({required int freeBytes, required bool isTv}) {
  final cap = isTv ? tvCacheCapBytes : defaultCacheCapBytes;
  final share = _thirtyPercent(freeBytes < 0 ? 0 : freeBytes);
  final v = share < cap ? share : cap;
  if (v < minCacheBytes) {
    throw InsufficientStorageException(freeBytes: freeBytes);
  }
  return v;
}

/// Taille effective : le réglage [requestedBytes] (s'il existe) remplace la
/// valeur par défaut mais reste borné à 30 % de l'espace libre. Même seuil
/// minimal de 300 Mo que [defaultCacheBytes].
int effectiveCacheBytes({
  required int? requestedBytes,
  required int freeBytes,
  required bool isTv,
}) {
  final base = defaultCacheBytes(freeBytes: freeBytes, isTv: isTv);
  if (requestedBytes == null || requestedBytes <= 0) return base;
  final bounded = requestedBytes < _thirtyPercent(freeBytes)
      ? requestedBytes
      : _thirtyPercent(freeBytes);
  return bounded < minCacheBytes ? minCacheBytes : bounded;
}

/// Un torrent présent dans le cache.
class CachedTorrent {
  const CachedTorrent({
    required this.id,
    required this.bytes,
    required this.lastUsed,
  });
  final String id;
  final int bytes;
  final DateTime lastUsed;
}

/// Éléments à supprimer pour ramener le total sous [limit] : les plus anciens
/// d'abord, jamais celui dont l'id est [playingId]. Si le torrent en lecture
/// dépasse seul la limite, il reste et le plan s'arrête aux autres.
List<CachedTorrent> evictionPlan(
  List<CachedTorrent> all,
  int limit,
  String? playingId,
) {
  var total = all.fold<int>(0, (a, e) => a + e.bytes);
  if (total <= limit) return const [];
  final candidates = all.where((e) => e.id != playingId).toList()
    ..sort((a, b) => a.lastUsed.compareTo(b.lastUsed));
  final plan = <CachedTorrent>[];
  for (final e in candidates) {
    if (total <= limit) break;
    plan.add(e);
    total -= e.bytes;
  }
  return plan;
}
