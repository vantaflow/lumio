import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lumio/torrent/libtorrent_engine.dart';
import 'package:lumio/torrent/torrent_engine.dart';

/// Écran de debug du spike 0.6 (`--dart-define=LUMIO_DEBUG_TORRENT=1`).
/// Mesure au niveau moteur uniquement ; journal `LUMIO_TORRENT {json}`.
const _sintelHash = '08ada5a7a6183aae1e09d831df6748d566095a10';
const _trackers = [
  'wss://tracker.openwebtorrent.com',
  'wss://tracker.btorrent.xyz',
  'wss://tracker.webtorrent.dev',
  'udp://tracker.opentrackr.org:1337/announce',
  'udp://open.tracker.cl:1337/announce',
  'udp://tracker.torrent.eu.org:451/announce',
];

void _log(Map<String, Object?> m) {
  // ignore: avoid_print
  print('LUMIO_TORRENT ${jsonEncode(m)}');
}

class TorrentSpikeScreen extends StatefulWidget {
  const TorrentSpikeScreen({super.key});

  @override
  State<TorrentSpikeScreen> createState() => _TorrentSpikeScreenState();
}

class _TorrentSpikeScreenState extends State<TorrentSpikeScreen> {
  String _line = 'démarrage…';

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  void _show(String s) {
    if (mounted) setState(() => _line = s);
  }

  Future<void> _run() async {
    final sw = Stopwatch()..start();
    final engine = LibtorrentEngine();
    String? id;
    Timer? ticker;
    StreamSubscription<TorrentStatus>? sub;
    Directory? dir;
    try {
      dir = await Directory.systemTemp.createTemp('lumio_spike');
      await engine.init(TorrentSettings(savePath: dir.path));
      _log({'event': 'init', 'ms': sw.elapsedMilliseconds});
      id = await engine.add(
        '${magnetFromInfoHash(_sintelHash, trackers: _trackers)}&dn=Sintel',
      );
      sw.reset();

      var peersMax = 0;
      var rate = 0;
      var peers = 0;
      sub = engine.status(id).listen((s) {
        rate = s.downloadRate;
        peers = s.peers;
        if (peers > peersMax) peersMax = peers;
      });
      ticker = Timer.periodic(const Duration(seconds: 10), (_) {
        _log({
          'event': 'tick',
          'ms': sw.elapsedMilliseconds,
          'peers': peers,
          'rate': rate,
        });
        _show('t=${sw.elapsed.inSeconds}s pairs=$peers débit=$rate');
      });

      List<TorrentFile> files = const [];
      String? firstFilesError;
      while (sw.elapsed < const Duration(minutes: 5)) {
        try {
          files = await engine.files(id);
        } catch (e) {
          if (firstFilesError == null) {
            firstFilesError = e.toString();
            _log({'event': 'files_error', 'error': firstFilesError});
          }
        }
        if (files.isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (files.isEmpty) {
        _log({
          'event': 'fail',
          'reason': 'no_metadata_5min',
          'peers': peersMax,
        });
        _show('ÉCHEC métadonnées');
        return;
      }
      final metaMs = sw.elapsedMilliseconds;
      final streamable = files.where((f) => f.streamable).toList()
        ..sort((a, b) => b.size.compareTo(a.size));
      final target = streamable.isEmpty ? files.first : streamable.first;
      _log({
        'event': 'metadata',
        'ms': metaMs,
        'files': files.length,
        'target': target.name,
        'size': target.size,
        'peers': peers,
      });

      final url = await engine.stream(id, fileIndex: target.index);
      _log({'event': 'stream_url', 'url': url.toString()});
      final t1 = sw.elapsedMilliseconds;
      var got = 0;
      final client = HttpClient();
      try {
        final req = await client.getUrl(url);
        req.headers.set('Range', 'bytes=0-1048575');
        final resp = await req.close().timeout(const Duration(minutes: 4));
        final firstByteMs = sw.elapsedMilliseconds - t1;
        await for (final chunk in resp.timeout(const Duration(minutes: 4))) {
          got += chunk.length;
          if (got >= 1048576) break;
        }
        _log({
          'event': 'first_mib',
          'status': resp.statusCode,
          'bytes': got,
          'firstByteMs': firstByteMs,
          'sinceStreamMs': sw.elapsedMilliseconds - t1,
          'sinceAddMs': sw.elapsedMilliseconds,
        });
      } catch (e) {
        _log({'event': 'first_mib_fail', 'error': e.toString(), 'bytes': got});
      } finally {
        client.close(force: true);
      }

      // Lecture continue jusqu'à 30 s après l'ajout du flux.
      final dl = HttpClient();
      var total = 0;
      final t2 = sw.elapsedMilliseconds;
      try {
        final req = await dl.getUrl(url);
        req.headers.set('Range', 'bytes=1048576-');
        final resp = await req.close().timeout(const Duration(minutes: 2));
        final end = DateTime.now().add(const Duration(seconds: 30));
        await for (final chunk in resp) {
          total += chunk.length;
          if (DateTime.now().isAfter(end)) break;
        }
      } catch (e) {
        _log({'event': 'read30_fail', 'error': e.toString()});
      } finally {
        dl.close(force: true);
      }
      final secs = (sw.elapsedMilliseconds - t2) / 1000;
      _log({
        'event': 'read_30s',
        'bytes': total,
        'seconds': secs,
        'bytesPerSec': secs > 0 ? (total / secs).round() : 0,
        'engineRate': rate,
        'peers': peers,
        'peersMax': peersMax,
      });

      ticker.cancel();
      await sub.cancel();
      await engine.stop(id);
      await engine.dispose();
      final left = await dir.exists()
          ? dir.listSync(recursive: true).length
          : 0;
      _log({'event': 'done', 'leftoverEntries': left});
      _show('terminé');
    } catch (e, st) {
      _log({'event': 'error', 'error': e.toString(), 'stack': st.toString()});
      _show('erreur : $e');
    }
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('Spike torrent\n$_line')));
}
