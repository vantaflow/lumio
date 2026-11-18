import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart' as lt;
import 'package:lumio/torrent/torrent_engine.dart';

/// Limite montante envoyée à libtorrent (octets/s). libtorrent_flutter 1.7.5
/// n'expose aucun interrupteur d'ensemencement et traite 0 comme « illimité » :
/// quand l'ensemencement est désactivé (`seed` faux) on applique donc le
/// minimum, 1 octet/s, ce qui coupe l'envoi en pratique.
int engineUploadLimit(TorrentSettings s) =>
    !s.seed ? 1 : (s.uploadLimit < 0 ? 0 : s.uploadLimit);

/// Adaptateur de `libtorrent_flutter` (libtorrent 2.x via FFI).
/// Aucun type libtorrent ne sort de cette classe.
class LibtorrentEngine implements TorrentEngine {
  LibtorrentEngine();

  late TorrentSettings _settings;
  final _streamIds = <int, int>{}; // torrentId -> streamId
  bool _ready = false;

  lt.LibtorrentFlutter get _e => lt.LibtorrentFlutter.instance;

  void _requireReady() {
    if (!_ready) throw StateError('moteur non initialisé');
  }

  @override
  Future<void> init(TorrentSettings s) async {
    if (_ready) throw StateError('moteur déjà initialisé');
    _settings = s;
    await lt.LibtorrentFlutter.init(
      downloadLimit: s.downloadLimit,
      uploadLimit: engineUploadLimit(s),
      defaultSavePath: s.savePath,
    );
    _ready = true;
  }

  int _id(String id) =>
      int.tryParse(id) ?? (throw StateError('torrent inconnu : $id'));

  void _stopStream(int sid) {
    try {
      _e.stopStream(sid);
    } catch (e) {
      debugPrint('LibtorrentEngine : stopStream($sid) a échoué : $e');
    }
  }

  @override
  Future<String> add(String magnetOrInfoHash) async {
    _requireReady();
    final magnet = isInfoHash(magnetOrInfoHash)
        ? magnetFromInfoHash(magnetOrInfoHash)
        : magnetOrInfoHash;
    return _e.addMagnet(magnet, _settings.savePath).toString();
  }

  @override
  Future<List<TorrentFile>> files(String id) async {
    _requireReady();
    return _e
        .getFiles(_id(id))
        .map(
          (f) => TorrentFile(
            index: f.index,
            name: f.name,
            path: f.path,
            size: f.size,
            streamable: f.isStreamable,
          ),
        )
        .toList();
  }

  @override
  Future<Uri> stream(String id, {int? fileIndex}) async {
    _requireReady();
    final tid = _id(id);
    final previous = _streamIds.remove(tid);
    if (previous != null) _stopStream(previous);
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
    _requireReady();
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
    return Stream<TorrentStatus>.multi((c) {
      final initial = map(_e.torrents[tid]);
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
    _requireReady();
    final tid = _id(id);
    final sid = _streamIds.remove(tid);
    if (sid != null) _stopStream(sid);
    _e.removeTorrent(tid, deleteFiles: deleteData);
  }

  @override
  Future<void> dispose() async {
    if (!_ready) return;
    _ready = false;
    for (final sid in _streamIds.values) {
      _stopStream(sid);
    }
    _streamIds.clear();
    // dispose() natif appelle disposeAll() : arrête les flux et supprime les
    // torrents restants (données comprises).
    await _e.dispose();
  }
}
