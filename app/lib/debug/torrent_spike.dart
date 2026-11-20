import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lumio/torrent/torrserver_engine.dart';
import 'package:lumio/torrent/torrserver_process.dart';
import 'package:lumio/torrent/torrent_engine.dart';

/// Écran de debug du spike 0.6 (`--dart-define=LUMIO_DEBUG_TORRENT=1`).
/// Mesure au niveau moteur uniquement ; journal `LUMIO_TORRENT {json}`.
const _sintelHash = '08ada5a7a6183aae1e09d831df6748d566095a10';

/// Torrent mesuré et durée de la lecture continue, réglables au build :
/// `--dart-define=LUMIO_TORRENT_HASH=<infohash>` et
/// `--dart-define=LUMIO_TORRENT_SECONDS=300` (test de débit 1080p).
const _hash = String.fromEnvironment(
  'LUMIO_TORRENT_HASH',
  defaultValue: _sintelHash,
);
const _readSeconds = int.fromEnvironment(
  'LUMIO_TORRENT_SECONDS',
  defaultValue: 30,
);
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
    final engine = TorrServerEngine(process: const PlatformTorrServerProcess());
    String? id;
    Timer? ticker;
    StreamSubscription<TorrentStatus>? sub;
    Directory? dir;
    try {
      dir = await Directory.systemTemp.createTemp('lumio_spike');
      await engine.init(TorrentSettings(savePath: dir.path));
      _log({'event': 'init', 'ms': sw.elapsedMilliseconds});
      id = await engine.add(
        '${magnetFromInfoHash(_hash, trackers: _trackers)}&dn=Sintel',
      );
      sw.reset();

      var peersMax = 0;
      var rate = 0;
      var peers = 0;
      var seeders = 0;
      var upRate = 0;
      var progress = 0.0;
      sub = engine.status(id).listen((s) {
        rate = s.downloadRate;
        peers = s.peers;
        seeders = s.seeders;
        upRate = s.uploadRate;
        progress = s.progress;
        if (peers > peersMax) peersMax = peers;
      });
      ticker = Timer.periodic(const Duration(seconds: 10), (_) {
        _log({
          'event': 'tick',
          'ms': sw.elapsedMilliseconds,
          'peers': peers,
          'seeders': seeders,
          'rate': rate,
          'up': upRate,
          'progress': progress,
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
      // Jamais l'URL complète : elle porte le mot de passe du moteur.
      _log({'event': 'stream_url', 'host': url.host, 'path': url.path});
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

      // Lecture continue pendant _readSeconds ; le fichier est relu depuis le
      // début quand il est épuisé (mesure du débit soutenu sur 5 min).
      var total = 0;
      final t2 = sw.elapsedMilliseconds;
      final end = DateTime.now().add(const Duration(seconds: _readSeconds));
      var windowStart = DateTime.now();
      var windowBytes = 0;
      var from = 1048576;
      while (DateTime.now().isBefore(end)) {
        final dl = HttpClient();
        try {
          final req = await dl.getUrl(url);
          req.headers.set('Range', 'bytes=$from-');
          final resp = await req.close().timeout(const Duration(minutes: 2));
          await for (final chunk in resp) {
            total += chunk.length;
            windowBytes += chunk.length;
            final now = DateTime.now();
            if (now.difference(windowStart) >= const Duration(seconds: 10)) {
              _log({
                'event': 'window_10s',
                'bytesPerSec':
                    (windowBytes *
                            1000 /
                            now.difference(windowStart).inMilliseconds)
                        .round(),
                'peers': peers,
                'totalBytes': total,
              });
              windowStart = now;
              windowBytes = 0;
            }
            if (now.isAfter(end)) break;
          }
        } catch (e) {
          _log({'event': 'read_fail', 'error': e.runtimeType.toString()});
          break;
        } finally {
          dl.close(force: true);
        }
        from = 0;
      }
      final secs = (sw.elapsedMilliseconds - t2) / 1000;
      _log({
        'event': 'read_continuous',
        'seconds_target': _readSeconds,
        'bytes': total,
        'seconds': secs,
        'bytesPerSec': secs > 0 ? (total / secs).round() : 0,
        'engineRate': rate,
        'peers': peers,
        'peersMax': peersMax,
      });

      _show('terminé');
    } catch (e, st) {
      _log({'event': 'error', 'error': e.toString(), 'stack': st.toString()});
      _show('erreur : $e');
    } finally {
      ticker?.cancel();
      try {
        await sub?.cancel();
      } catch (e) {
        _log({'event': 'sub_cancel_error', 'error': e.toString()});
      }
      try {
        if (id != null) await engine.stop(id, deleteData: true);
      } catch (e) {
        _log({'event': 'stop_error', 'error': e.toString()});
      }
      try {
        await engine.dispose();
      } catch (e) {
        _log({'event': 'dispose_error', 'error': e.toString()});
      }
      final d = dir;
      final left = d != null && await d.exists()
          ? d.listSync(recursive: true).length
          : 0;
      _log({'event': 'done', 'leftoverEntries': left});
    }
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('Spike torrent\n$_line')));
}
