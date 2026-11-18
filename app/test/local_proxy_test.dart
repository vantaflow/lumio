import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/player/local_proxy.dart';
import 'package:lumio_core/testing.dart';

/// Serveur d'essai qui enregistre les en-têtes reçus et gère Range.
class _Origin {
  _Origin._(this.server) {
    server.listen(_handle);
  }
  final HttpServer server;
  final seen = <String, String>{};
  static final data = List<int>.generate(100, (i) => i);

  static Future<_Origin> start() async =>
      _Origin._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  Uri url(String path) =>
      Uri(scheme: 'http', host: '127.0.0.1', port: server.port, path: path);

  void _handle(HttpRequest req) async {
    req.headers.forEach((n, v) => seen[n] = v.join(','));
    final res = req.response;
    switch (req.uri.path) {
      case '/forbidden':
        res.statusCode = 403;
      case '/redirect':
        res.statusCode = 302;
        res.headers.set('location', '/file.bin');
      case '/hls/master.m3u8':
        res.headers.contentType = ContentType(
          'application',
          'vnd.apple.mpegurl',
        );
        res.write('#EXTM3U\n#EXTINF:4,\nseg1.ts\n');
      default:
        final range = req.headers.value('range');
        res.headers.set('accept-ranges', 'bytes');
        if (range != null) {
          final m = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range)!;
          final a = int.parse(m[1]!), b = int.parse(m[2]!);
          res.statusCode = 206;
          res.headers.set('content-range', 'bytes $a-$b/${data.length}');
          res.headers.contentLength = b - a + 1;
          res.add(data.sublist(a, b + 1));
        } else {
          res.headers.contentLength = data.length;
          res.add(data);
        }
    }
    await res.close();
  }

  Future<void> close() => server.close(force: true);
}

Future<({int status, List<int> body, HttpHeaders headers})> _get(
  Uri u, {
  Map<String, String> headers = const {},
}) async {
  final c = HttpClient();
  try {
    final req = await c.getUrl(u);
    headers.forEach(req.headers.set);
    final res = await req.close();
    final body = <int>[];
    await for (final chunk in res) {
      body.addAll(chunk);
    }
    return (status: res.statusCode, body: body, headers: res.headers);
  } finally {
    c.close(force: true);
  }
}

void main() {
  late _Origin origin;
  late LocalProxy proxy;

  setUp(() async {
    origin = await _Origin.start();
    proxy = await LocalProxy.start();
  });
  tearDown(() async {
    await proxy.close();
    await origin.close();
  });

  Uri wrap(String path, {Map<String, String> h = const {}}) =>
      proxy.wrap(origin.url(path), headers: h, allowPrivate: true);

  test('Range bytes=10-19 → 206 et 10 octets', () async {
    final r = await _get(wrap('/file.bin'), headers: {'Range': 'bytes=10-19'});
    expect(r.status, 206);
    expect(r.body, List<int>.generate(10, (i) => i + 10));
    expect(r.headers.value('content-range'), 'bytes 10-19/100');
  });

  test('en-tête imposé transmis au serveur', () async {
    await _get(wrap('/file.bin', h: {'X-Token': 'abc'}));
    expect(origin.seen['x-token'], 'abc');
  });

  test('serveur en 403 → proxy 403', () async {
    final r = await _get(wrap('/forbidden'));
    expect(r.status, 403);
  });

  test('redirection suivie', () async {
    final r = await _get(wrap('/redirect'));
    expect(r.status, 200);
    expect(r.body.length, 100);
  });

  test('playlist HLS réécrite vers le proxy', () async {
    final r = await _get(wrap('/hls/master.m3u8'));
    final text = utf8.decode(r.body);
    expect(r.status, 200);
    expect(text, contains('http://127.0.0.1:${proxy.port}/p/'));
    expect(text, isNot(contains('\nseg1.ts')));
  });

  test('chemin sans secret ou mauvais secret → 404', () async {
    final base = 'http://127.0.0.1:${proxy.port}';
    expect((await _get(Uri.parse('$base/p?u=aaa'))).status, 404);
    expect((await _get(Uri.parse('$base/p/${'0' * 32}?u=aaa'))).status, 404);
    expect((await _get(Uri.parse('$base/'))).status, 404);
  });

  test('cible privée refusée sans allowPrivate', () async {
    final u = proxy.wrap(origin.url('/file.bin'));
    expect((await _get(u)).status, 403);
  });

  test('écoute sur 127.0.0.1 uniquement', () {
    expect(proxy.wrap(Uri.parse('https://h/x')).host, '127.0.0.1');
  });

  test('FakeAddonServer joignable aussi (hôte local autorisé)', () async {
    final fake = await FakeAddonServer.start();
    addTearDown(fake.close);
    fake.route('/a', FakeResponse.json({'ok': true}));
    final r = await _get(
      proxy.wrap(fake.baseUrl.replace(path: '/a'), allowPrivate: true),
    );
    expect(r.status, 200);
  });
}
