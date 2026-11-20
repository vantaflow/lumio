import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lumio/torrent/torrserver_engine.dart';

/// Faux TorrServer MatriX.150 : mêmes routes et mêmes formes de réponse que le
/// vrai (relevées sur la box), sans réseau BitTorrent.
class FakeTorrServer {
  FakeTorrServer({this.user = 'lumio', this.password = 'pw'});

  final String user;
  final String password;
  late final HttpServer _server;
  Map<String, Object?> settings = {
    'CacheSize': 67108864,
    'ReaderReadAHead': 95,
    'PreloadCache': 50,
    'UseDisk': false,
    'DisableUpload': false,
    'SomeOtherKey': 'kept',
  };
  final torrents = <String, Map<String, Object?>>{};
  final requests = <String>[];
  int unauthorized = 0;
  int settingsSets = 0;

  /// Fichiers rendus une fois les métadonnées reçues.
  List<Map<String, Object?>> fileStats = [
    {'id': 1, 'path': 'Film/sous-titres.srt', 'length': 1500},
    {'id': 2, 'path': 'Film/film.mkv', 'length': 900000},
    {'id': 3, 'path': 'Film/bonus.mp4', 'length': 100000},
  ];
  bool metadataReady = true;
  Map<String, Object?> stats = {
    'active_peers': 7,
    'connected_seeders': 4,
    'download_speed': 1500000.4,
    'upload_speed': 0.0,
    'torrent_size': 1001500,
    'preloaded_bytes': 500000,
    'loaded_size': 600000,
  };

  late final int port;

  TorrServerEndpoint get endpoint =>
      TorrServerEndpoint(port: port, user: user, password: password);

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    port = _server.port;
    _server.listen(_handle);
  }

  /// Ferme le serveur (simule aussi la mort du processus).
  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest req) async {
    final path = req.uri.path;
    requests.add('${req.method} $path');
    if (path != '/echo') {
      final expected = 'Basic ${base64.encode(utf8.encode('$user:$password'))}';
      final given = req.uri.userInfo.isNotEmpty
          ? 'Basic ${base64.encode(utf8.encode(req.uri.userInfo))}'
          : req.headers.value(HttpHeaders.authorizationHeader);
      if (given != expected) {
        unauthorized++;
        req.response.statusCode = 401;
        await req.response.close();
        return;
      }
    }
    final body = await utf8.decodeStream(req);
    final json = body.isEmpty ? <String, Object?>{} : jsonDecode(body);
    Object? out;
    switch (path) {
      case '/echo':
        out = 'MatriX.150';
      case '/settings':
        if (json['action'] == 'set') {
          settingsSets++;
          settings = Map<String, Object?>.from(json['sets'] as Map);
        } else {
          out = settings;
        }
      case '/torrents':
        out = _torrents(Map<String, Object?>.from(json as Map));
      case '/stream':
        req.response.statusCode = 206;
        req.response.add(List.filled(16, 1));
        await req.response.close();
        return;
      default:
        req.response.statusCode = 404;
        await req.response.close();
        return;
    }
    req.response.headers.contentType = ContentType.json;
    if (out is String) {
      req.response.write(out);
    } else if (out != null) {
      req.response.write(jsonEncode(out));
    }
    await req.response.close();
  }

  Object? _torrents(Map<String, Object?> j) {
    switch (j['action']) {
      case 'add':
        final m = RegExp(
          r'btih:([0-9a-f]{40})',
        ).firstMatch('${j['link']}')!.group(1)!;
        torrents[m] = {'hash': m};
        return {'hash': m, 'stat': 0, 'stat_string': 'Torrent added'};
      case 'get':
        final h = '${j['hash']}';
        if (!torrents.containsKey(h)) return null;
        return {
          'hash': h,
          'name': 'Film',
          ...stats,
          if (metadataReady) 'file_stats': fileStats,
        };
      case 'list':
        return [
          for (final h in torrents.keys) {'hash': h},
        ];
      case 'rem' || 'drop':
        torrents.remove('${j['hash']}');
    }
    return null;
  }
}

/// Processus factice : « démarre » en pointant sur un [FakeTorrServer].
class FakeTorrServerProcess implements TorrServerProcess {
  FakeTorrServerProcess(this.server);
  FakeTorrServer server;
  int starts = 0;
  int stops = 0;

  @override
  Future<TorrServerEndpoint> start() async {
    starts++;
    return server.endpoint;
  }

  @override
  Future<void> stop() async => stops++;
}
