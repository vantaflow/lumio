import 'dart:async';

import 'package:lumio/torrent/torrent_engine.dart';

/// Moteur factice déterministe, réutilisé par les tests des écrans torrent.
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
  TorrentSettings? settings;
  bool disposed = false;

  @override
  Future<void> init(TorrentSettings s) async => settings = s;

  @override
  Future<String> add(String magnetOrInfoHash) async {
    final m = RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(magnetOrInfoHash)
        ? magnetFromInfoHash(magnetOrInfoHash)
        : magnetOrInfoHash;
    addedMagnets.add(m);
    return 'fake-${addedMagnets.length}';
  }

  void _check(String id) {
    if (!id.startsWith('fake-')) throw StateError('torrent inconnu : $id');
  }

  @override
  Future<List<TorrentFile>> files(String id) async {
    _check(id);
    return fileList;
  }

  @override
  Future<Uri> stream(String id, {int? fileIndex}) async {
    _check(id);
    return Uri.parse('http://127.0.0.1:8080/stream/$id/${fileIndex ?? 0}');
  }

  @override
  Stream<TorrentStatus> status(String id) async* {
    _check(id);
    yield statusValue;
  }

  @override
  Future<void> stop(String id, {bool deleteData = true}) async =>
      stopped.add(id);

  @override
  Future<void> dispose() async => disposed = true;
}
