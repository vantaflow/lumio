import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/player/local_proxy.dart';
import 'package:lumio_core/lumio_core.dart';
import 'package:lumio_core/testing.dart';

/// Serveur d'essai qui enregistre les en-têtes reçus et gère Range.
class _Origin {
  _Origin._(this.server) {
    server.listen(_handle);
  }
  final HttpServer server;
  final seen = <String, String>{};
  Uri? otherSegment;
  final closedEndless = Completer<void>();
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
      case '/to-localhost':
        res.statusCode = 302;
        res.headers.set('location', 'http://localhost:${server.port}/file.bin');
      case '/big.m3u8':
        res.headers.contentType = ContentType(
          'application',
          'vnd.apple.mpegurl',
        );
        final line = [...List<int>.filled(1024, 0x61), 10];
        for (var i = 0; i < 6 * 1024; i++) {
          res.add(line);
        }
      case '/endless':
        res.headers.contentType = ContentType('video', 'mp4');
        var gone = false;
        res.done.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
          gone = true;
          if (!closedEndless.isCompleted) closedEndless.complete();
        });
        try {
          while (!gone) {
            res.add(List<int>.filled(1024, 1));
            await res.flush();
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        } catch (_) {
          if (!closedEndless.isCompleted) closedEndless.complete();
        }
        return;
      case '/xo.m3u8':
        res.headers.contentType = ContentType(
          'application',
          'vnd.apple.mpegurl',
        );
        res.write('#EXTM3U\n#EXTINF:4,\n$otherSegment\n');
      case '/mp4-playlist':
        res.headers.contentType = ContentType('video', 'mp4');
        if (req.headers.value('range') != null) {
          res.statusCode = 206;
          res.headers.set('content-range', 'bytes 0-29/30');
        }
        res.add([0xEF, 0xBB, 0xBF]);
        res.write('#EXTM3U\n#EXTINF:4,\nseg1.ts\n');
      case '/text-playlist':
        res.headers.contentType = ContentType('text', 'plain');
        res.write('#EXTM3U\n#EXTINF:4,\nseg1.ts\n');
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

  test('l\'adresse d\'écoute est 127.0.0.1', () {
    expect(proxy.address.address, '127.0.0.1');
    expect(proxy.address.isLoopback, isTrue);
  });

  test('allowPrivate propagé aux segments réécrits', () async {
    final on = utf8.decode((await _get(wrap('/hls/master.m3u8'))).body);
    expect(on, contains('a=1'));
    final off = proxy.wrap(origin.url('/hls/master.m3u8'));
    // Sans allowPrivate la cible locale est refusée : on vérifie la
    // réécriture avec un garde permissif.
    final lax = await LocalProxy.start(
      guard: (_, {bool allowPrivate = false}) {},
      enforceResolvedAddresses: false,
    );
    addTearDown(lax.close);
    final body = utf8.decode(
      (await _get(lax.wrap(origin.url('/hls/master.m3u8')))).body,
    );
    expect(body, isNot(contains('a=1')));
    expect(off.queryParameters.containsKey('a'), isFalse);
  });

  test('redirection vers un hôte privé sans allowPrivate → refusée', () async {
    final guarded = await LocalProxy.start(
      guard: (u, {bool allowPrivate = false}) {
        if (u.host == 'localhost' && !allowPrivate) {
          throw const UnsafeUrlException('hôte local');
        }
      },
      enforceResolvedAddresses: false,
    );
    addTearDown(guarded.close);
    final events = <ProxyEvent>[];
    guarded.events.listen(events.add);
    final r = await _get(guarded.wrap(origin.url('/to-localhost')));
    expect(r.status, 403);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(events.any((e) => e.refused), isTrue);
  });

  test('playlist de plus de 5 Mo → 502 et événement', () async {
    final events = <ProxyEvent>[];
    proxy.events.listen(events.add);
    final r = await _get(wrap('/big.m3u8'));
    expect(r.status, 502);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(events.any((e) => e.error is ResponseTooLargeException), isTrue);
  });

  test('HEAD sur .m3u8 : pas de Content-Length amont', () async {
    final c = HttpClient();
    addTearDown(() => c.close(force: true));
    final req = await c.openUrl('HEAD', wrap('/hls/master.m3u8'));
    final res = await req.close();
    await res.drain<void>();
    expect(res.statusCode, 200);
    expect(res.headers.value('content-length'), anyOf(isNull, '0'));
  });

  test('segment d une autre origine : Authorization retiré', () async {
    final other = await _Origin.start();
    addTearDown(other.close);
    origin.otherSegment = other.url('/file.bin');
    final pl = await _get(wrap('/xo.m3u8', h: {'Authorization': 'Bearer s3'}));
    final line = utf8
        .decode(pl.body)
        .split('\n')
        .firstWhere((l) => l.startsWith('http'));
    await _get(Uri.parse(line));
    expect(other.seen.containsKey('authorization'), isFalse);
    // Même origine : l'en-tête est conservé.
    await _get(wrap('/file.bin', h: {'Authorization': 'Bearer s3'}));
    expect(origin.seen['authorization'], 'Bearer s3');
  });

  test('playlist servie en video/mp4 ou text/plain (BOM) réécrite', () async {
    for (final path in ['/mp4-playlist', '/text-playlist']) {
      final body = utf8.decode((await _get(wrap(path))).body);
      expect(body, contains('/p/'), reason: path);
      expect(body, isNot(contains('\nseg1.ts')), reason: path);
    }
  });

  test('206 débutant à 0 : playlist réécrite aussi', () async {
    final r = await _get(wrap('/mp4-playlist'), headers: {'Range': 'bytes=0-'});
    expect(utf8.decode(r.body), contains('/p/'));
  });

  test('nom public résolvant vers une adresse privée refusé', () async {
    final rebinding = await LocalProxy.start(
      lookup: (_) async => [InternetAddress.loopbackIPv4],
      guard: (_, {bool allowPrivate = false}) {},
    );
    addTearDown(rebinding.close);
    final target = Uri(
      scheme: 'http',
      host: 'public.example',
      port: origin.server.port,
      path: '/file.bin',
    );
    expect((await _get(rebinding.wrap(target))).status, 403);
    final lax = await LocalProxy.start(
      lookup: (_) async => [InternetAddress.loopbackIPv4],
      guard: (_, {bool allowPrivate = false}) {},
    );
    addTearDown(lax.close);
    expect((await _get(lax.wrap(target, allowPrivate: true))).status, 200);
  });

  test('en-têtes réservés d addon ignorés (Range du lecteur prime)', () async {
    final r = await _get(
      wrap('/file.bin', h: {'Range': 'bytes=0-0', 'Host': 'evil.test'}),
      headers: {'Range': 'bytes=10-19'},
    );
    expect(r.status, 206);
    expect(r.body.length, 10);
    expect(origin.seen['host'], isNot('evil.test'));
  });

  test('cible au schéma non http → 404', () async {
    final u = proxy.wrap(Uri.parse('file:///etc/passwd'));
    expect((await _get(u)).status, 404);
  });

  test('le client qui part ferme la connexion amont', () async {
    final c = HttpClient();
    final req = await c.getUrl(wrap('/endless'));
    final res = await req.close();
    await res.first;
    c.close(force: true);
    expect(proxy.activeUpstreams, greaterThan(0));
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (proxy.activeUpstreams > 0 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(proxy.activeUpstreams, 0);
  });
}
