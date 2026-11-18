import 'dart:async';

import 'package:libtorrent_flutter/libtorrent_flutter.dart' as lt;
import 'package:lumio/torrent/torrent_engine.dart';

/// Adaptateur de `libtorrent_flutter` (libtorrent 2.x via FFI).
/// Aucun type libtorrent ne sort de cette classe.
class LibtorrentEngine implements TorrentEngine {
  LibtorrentEngine();

  late TorrentSettings _settings;
  final _streamIds = <int, int>{}; // torrentId -> streamId
  bool _ready = false;

  lt.LibtorrentFlutter get _e => lt.LibtorrentFlutter.instance;

  @override
  Future<void> init(TorrentSettings s) async {
    _settings = s;
    await lt.LibtorrentFlutter.init(
      downloadLimit: s.downloadLimit,
      uploadLimit: s.uploadLimit,
      defaultSavePath: s.savePath,
    );
    _ready = true;
  }

  int _id(String id) =>
      int.tryParse(id) ?? (throw StateError('torrent inconnu : $id'));

  @override
  Future<String> add(String magnetOrInfoHash) async {
    if (!_ready) throw StateError('moteur non initialisé');
    final isHash = RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(magnetOrInfoHash);
    final magnet = isHash
        ? magnetFromInfoHash(magnetOrInfoHash)
        : magnetOrInfoHash;
    return _e.addMagnet(magnet, _settings.savePath).toString();
  }

  @override
  Future<List<TorrentFile>> files(String id) async => _e
      .getFiles(_id(id))
      .map(
        (f) => TorrentFile(
          index: f.index,
          name: f.name,
          size: f.size,
          streamable: f.isStreamable,
        ),
      )
      .toList();

  @override
  Future<Uri> stream(String id, {int? fileIndex}) async {
    final tid = _id(id);
    final info = _e.startStream(
      tid,
      fileIndex: fileIndex ?? -1,
      maxCacheBytes: _settings.maxCacheBytes,
    );
    _streamIds[tid] = info.id;
    return Uri.parse(info.url);
  }

  @override
  Stream<TorrentStatus> status(String id) {
    final tid = _id(id);
    TorrentStatus? map(lt.TorrentInfo? t) => t == null
        ? null
        : TorrentStatus(
            peers: t.numPeers,
            seeders: t.numSeeds,
            downloadRate: t.downloadRate,
            uploadRate: t.uploadRate,
            progress: t.progress,
            error: t.errorMsg.isEmpty ? null : t.errorMsg,
          );
    final initial = map(_e.torrents[tid]);
    return Stream<TorrentStatus>.multi((c) {
      if (initial != null) c.add(initial);
      final sub = _e.torrentUpdates.listen((all) {
        final s = map(all[tid]);
        if (s != null) c.add(s);
      });
      c.onCancel = sub.cancel;
    });
  }

  @override
  Future<void> stop(String id, {bool deleteData = true}) async {
    final tid = _id(id);
    final sid = _streamIds.remove(tid);
    if (sid != null) {
      try {
        _e.stopStream(sid);
      } catch (_) {}
    }
    _e.removeTorrent(tid, deleteFiles: deleteData);
  }

  @override
  Future<void> dispose() async {
    if (!_ready) return;
    _ready = false;
    await _e.dispose();
  }
}
