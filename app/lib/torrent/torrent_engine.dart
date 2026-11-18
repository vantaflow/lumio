export 'package:lumio_core/lumio_core.dart' show magnetFromInfoHash;

class TorrentSettings {
  const TorrentSettings({
    required this.savePath,
    this.maxCacheBytes = 512 * 1024 * 1024,
    this.downloadLimit = 0,
    this.uploadLimit = 0,
    this.seed = false,
  });
  final int maxCacheBytes;
  final int downloadLimit; // octets/s, 0 = illimité
  final int uploadLimit; // octets/s, 0 = illimité
  final bool seed;
  final String savePath;
}

class TorrentFile {
  const TorrentFile({
    required this.index,
    required this.name,
    required this.size,
    required this.streamable,
  });
  final int index;
  final String name;
  final int size;
  final bool streamable;
}

class TorrentStatus {
  const TorrentStatus({
    required this.peers,
    required this.seeders,
    required this.downloadRate,
    required this.uploadRate,
    required this.progress,
    this.error,
  });
  final int peers;
  final int seeders;
  final int downloadRate;
  final int uploadRate;
  final double progress;
  final String? error;
}

abstract class TorrentEngine {
  Future<void> init(TorrentSettings s);

  /// Accepte un magnet ou un infoHash nu (40 hex, converti en magnet).
  Future<String> add(String magnetOrInfoHash);
  Future<List<TorrentFile>> files(String id);

  /// URL HTTP locale à plages d'octets.
  Future<Uri> stream(String id, {int? fileIndex});
  Stream<TorrentStatus> status(String id);
  Future<void> stop(String id, {bool deleteData = true});
  Future<void> dispose();
}
