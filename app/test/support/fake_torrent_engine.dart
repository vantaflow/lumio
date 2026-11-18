import 'dart:async';

import 'package:lumio/torrent/torrent_engine.dart';

/// Moteur factice déterministe, réutilisé par les tests des écrans torrent.
/// Mêmes erreurs que l'adaptateur sur identifiant inconnu ; l'état est piloté
/// par [emitStatus].
class FakeTorrentEngine implements TorrentEngine {
  FakeTorrentEngine({
    this.fileList = const [
      TorrentFile(index: 0, name: 'video.mkv', size: 1000000, streamable: true),
    ],
    this.statusValue = const TorrentStatus(
      peers: 3,
      seeders: 2,
      downloadRate: 500000,
      uploadRate: 0,
      progress: 0.1,
    ),
  });

  final List<TorrentFile> fileList;
  TorrentStatus statusValue;
  final addedMagnets = <String>[];
  final stopped = <String>[];
  final stopDeleteData = <bool>[];
  final streamedIndexes = <int?>[];
  TorrentSettings? settings;

  /// Remplace l'URL rendue par `stream` (test d'URL non locale).
  Uri? streamUrlOverride;

  /// Si renseigné, `init` échoue avec cette erreur.
  Object? initError;
  bool disposed = false;
  final _live = <String>{};
  final _controllers = <String, StreamController<TorrentStatus>>{};

  @override
  Future<void> init(TorrentSettings s) async {
    if (initError != null) throw initError!;
    settings = s;
  }

  @override
  Future<String> add(String magnetOrInfoHash) async {
    final m = isInfoHash(magnetOrInfoHash)
        ? magnetFromInfoHash(magnetOrInfoHash)
        : magnetOrInfoHash;
    addedMagnets.add(m);
    final id = 'fake-${addedMagnets.length}';
    _live.add(id);
    return id;
  }

  void _check(String id) {
    if (!_live.contains(id)) throw StateError('torrent inconnu : $id');
  }

  StreamController<TorrentStatus> _ctrl(String id) => _controllers.putIfAbsent(
    id,
    () => StreamController<TorrentStatus>.broadcast(),
  );

  /// Pousse une mise à jour de statut vers les abonnés de [status].
  void emitStatus(String id, TorrentStatus s) {
    _check(id);
    statusValue = s;
    _ctrl(id).add(s);
  }

  @override
  Future<List<TorrentFile>> files(String id) async {
    _check(id);
    return fileList;
  }

  @override
  Future<Uri> stream(String id, {int? fileIndex}) async {
    _check(id);
    streamedIndexes.add(fileIndex);
    if (streamUrlOverride != null) return streamUrlOverride!;
    return Uri.parse('http://127.0.0.1:8080/stream/$id/${fileIndex ?? 0}');
  }

  /// Émet d'abord le statut courant, puis les [emitStatus] suivants.
  @override
  Stream<TorrentStatus> status(String id) {
    _check(id);
    final c = _ctrl(id);
    return Stream<TorrentStatus>.multi((m) {
      m.add(statusValue);
      final sub = c.stream.listen(m.add, onDone: m.close);
      m.onCancel = sub.cancel;
    });
  }

  @override
  Future<void> stop(String id, {bool deleteData = true}) async {
    _check(id);
    _live.remove(id);
    stopped.add(id);
    stopDeleteData.add(deleteData);
    await _controllers.remove(id)?.close();
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    for (final c in _controllers.values) {
      await c.close();
    }
    _controllers.clear();
  }
}
