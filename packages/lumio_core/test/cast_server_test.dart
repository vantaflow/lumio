import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

Future<(int, String, Map<String, String>)> _get(
  Uri url, {
  String method = 'GET',
  Map<String, String> headers = const {},
}) async {
  final c = HttpClient();
  try {
    final r = await c.openUrl(method, url);
    headers.forEach(r.headers.set);
    final res = await r.close();
    final body = await res.transform(latin1.decoder).join();
    final h = <String, String>{};
    res.headers.forEach((n, v) => h[n] = v.join(','));
    return (res.statusCode, body, h);
  } finally {
    c.close(force: true);
  }
}

void main() {
  late HttpServer upstream;
  late List<String> upstreamRanges;
  late Directory tmp;
  final media = List<int>.generate(1000, (i) => i % 251);

  setUp(() async {
    upstreamRanges = [];
    tmp = await Directory.systemTemp.createTemp('cast_test');
    upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    upstream.listen((req) async {
      upstreamRanges.add(req.headers.value('range') ?? '');
      if (req.uri.path == '/hls') {
        req.response.headers.contentType = ContentType(
          'application',
          'vnd.apple.mpegurl',
        );
        req.response.write('#EXTM3U');
      } else {
        req.response.headers.contentType = ContentType('video', 'mp4');
        final r = req.headers.value('range');
        if (r != null) {
          req.response.statusCode = 206;
          req.response.headers.set('content-range', 'bytes 0-9/1000');
          req.response.add(media.sublist(0, 10));
        } else {
          req.response.add(media);
        }
      }
      await req.response.close();
    });
  });

  tearDown(() async {
    await upstream.close(force: true);
    await tmp.delete(recursive: true);
  });

  Future<CastServer> start({InternetAddress? allowed, CastSource? source}) =>
      CastServer.start(
        bindAddress: InternetAddress.loopbackIPv4,
        allowedClient: allowed ?? InternetAddress.loopbackIPv4,
        source:
            source ??
            CastHttpSource(
              Uri.parse('http://127.0.0.1:${upstream.port}/v.mp4'),
            ),
      );

  test('le jeton est aléatoire (128 bits) et unique par session', () async {
    final a = await start();
    final b = await start();
    addTearDown(a.close);
    addTearDown(b.close);
    expect(RegExp(r'^/[0-9a-f]{32}$').hasMatch(a.url.path), isTrue);
    expect(a.url.path, isNot(b.url.path));
    expect(a.url.host, '127.0.0.1');
  });

  test('sert la ressource au rendu autorisé, avec Range relayé', () async {
    final s = await start();
    addTearDown(s.close);
    final (code, body, h) = await _get(s.url);
    expect(code, 200);
    expect(body.length, greaterThan(500));
    expect(h['content-type'], contains('video/mp4'));
    final (c2, _, h2) = await _get(s.url, headers: {'range': 'bytes=0-9'});
    expect(c2, 206);
    expect(h2['content-range'], 'bytes 0-9/1000');
    expect(upstreamRanges.last, 'bytes=0-9');
  });

  test('un autre chemin que le jeton : 404, rien ne part en amont', () async {
    final s = await start();
    addTearDown(s.close);
    final base = s.url.replace(path: '/');
    for (final p in [
      '/',
      '/p/abc',
      '${s.url.path}x',
      '/${'0' * 32}',
      '${s.url.path}/a',
    ]) {
      final (code, _, _) = await _get(base.replace(path: p));
      expect(code, 404, reason: p);
    }
    expect(upstreamRanges, isEmpty);
  });

  test('un client dont l\'IP n\'est pas celle du rendu : refusé', () async {
    // Le seul client possible ici est 127.0.0.1 : on n'autorise que l'autre.
    final s = await start(allowed: InternetAddress('192.168.1.99'));
    addTearDown(s.close);
    final (code, body, _) = await _get(s.url);
    expect(code, 404);
    expect(body, isEmpty);
    expect(upstreamRanges, isEmpty);
  });

  test('méthodes autres que GET/HEAD : refusées', () async {
    final s = await start();
    addTearDown(s.close);
    final (code, _, _) = await _get(s.url, method: 'POST');
    expect(code, 404);
  });

  test(
    'flux HLS : refusé (415), jamais relayé avec ses segments locaux',
    () async {
      final s = await start(
        source: CastHttpSource(
          Uri.parse('http://127.0.0.1:${upstream.port}/hls'),
        ),
      );
      addTearDown(s.close);
      final (code, body, _) = await _get(s.url);
      expect(code, 415);
      expect(body, isNot(contains('EXTM3U')));
    },
  );

  test('source amont hors boucle locale : ArgumentError', () {
    expect(
      () => CastServer.start(
        bindAddress: InternetAddress.loopbackIPv4,
        allowedClient: InternetAddress.loopbackIPv4,
        source: CastHttpSource(Uri.parse('http://203.0.113.9/v.mp4')),
      ),
      throwsArgumentError,
    );
  });

  test('fichier local : contenu et Range', () async {
    final f = File('${tmp.path}/film.mp4')..writeAsBytesSync(media);
    final s = await start(source: CastFileSource(f));
    addTearDown(s.close);
    final c = HttpClient();
    final r = await c.getUrl(s.url);
    r.headers.set('range', 'bytes=10-19');
    final res = await r.close();
    final bytes = await res.fold<List<int>>([], (a, b) => a..addAll(b));
    c.close(force: true);
    expect(res.statusCode, 206);
    expect(bytes, media.sublist(10, 20));
    expect(res.headers.value('content-range'), 'bytes 10-19/1000');
    final (head, _, hh) = await _get(s.url, method: 'HEAD');
    expect(head, 200);
    expect(hh['content-length'], '1000');
  });

  test('close() : le port est libéré, plus aucune réponse', () async {
    final s = await start();
    final url = s.url;
    await s.close();
    await expectLater(_get(url), throwsA(isA<SocketException>()));
    await s.close(); // idempotent
  });

  group('pickLanAddress', () {
    final tv = InternetAddress('192.168.1.20');
    test('préfère le même /24, sinon le même /16, jamais public ni boucle', () {
      expect(
        pickLanAddress(tv, [
          InternetAddress('10.0.0.4'),
          InternetAddress('192.168.2.5'),
          InternetAddress('192.168.1.7'),
        ]),
        InternetAddress('192.168.1.7'),
      );
      expect(
        pickLanAddress(tv, [InternetAddress('192.168.2.5')]),
        InternetAddress('192.168.2.5'),
      );
      expect(
        pickLanAddress(tv, [
          InternetAddress('10.0.0.4'),
          InternetAddress('127.0.0.1'),
          InternetAddress('203.0.113.9'),
        ]),
        isNull,
      );
    });
  });

  test(
    'erreur amont : pas de Content-Length copié ; HEAD relayé sans corps',
    () async {
      final err = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => err.close(force: true));
      err.listen((req) async {
        if (req.uri.path == '/missing') {
          req.response.statusCode = 404;
          req.response.headers.contentLength = 5000;
          req.response.add(List.filled(5000, 1));
          await req.response.close();
          return;
        }
        req.response.headers.contentLength = 1000;
        req.response.headers.contentType = ContentType('video', 'mp4');
        if (req.method != 'HEAD') req.response.add(media);
        await req.response.close();
      });
      final s404 = await start(
        source: CastHttpSource(
          Uri.parse('http://127.0.0.1:${err.port}/missing'),
        ),
      );
      addTearDown(s404.close);
      final (code, body, h) = await _get(s404.url);
      expect(code, 404);
      expect(body, isEmpty);
      expect(h['content-length'], '0');
      final sh = await start(
        source: CastHttpSource(Uri.parse('http://127.0.0.1:${err.port}/ok')),
      );
      addTearDown(sh.close);
      final (hc, hb, hh) = await _get(sh.url, method: 'HEAD');
      expect(hc, 200);
      expect(hb, isEmpty);
      expect(hh['content-length'], '1000');
    },
  );

  test(
    'le téléviseur coupe en plein flux : la connexion amont est fermée',
    () async {
      final slow = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => slow.close(force: true));
      final closed = Completer<void>();
      slow.listen((req) async {
        req.response.headers.contentType = ContentType('video', 'mp4');
        req.response.headers.chunkedTransferEncoding = false;
        req.response.persistentConnection = false;
        final sock = await req.response.detachSocket(writeHeaders: true);
        unawaited(sock.done.then((_) {}, onError: (Object _) {}));
        sock.listen(
          (_) {},
          onDone: () {
            if (!closed.isCompleted) closed.complete();
          },
          onError: (Object _) {
            if (!closed.isCompleted) closed.complete();
          },
        );
        try {
          for (var i = 0; i < 200; i++) {
            sock.add(List.filled(4096, 1));
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
        } on Object {
          // Écriture refusée : connexion déjà fermée.
        }
      });
      final s = await start(
        source: CastHttpSource(Uri.parse('http://127.0.0.1:${slow.port}/v')),
      );
      addTearDown(s.close);
      final c = HttpClient();
      final res = await (await c.getUrl(s.url)).close();
      await res.first;
      c.close(force: true); // le téléviseur part
      await closed.future.timeout(const Duration(seconds: 5));
    },
  );

  test('client figé : close() détruit la socket et ferme l\'amont', () async {
    final slow = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => slow.close(force: true));
    final upstreamGone = Completer<void>();
    slow.listen((req) async {
      req.response.headers.chunkedTransferEncoding = false;
      req.response.persistentConnection = false;
      final sock = await req.response.detachSocket(writeHeaders: true);
      unawaited(sock.done.then((_) {}, onError: (Object _) {}));
      sock.listen(
        (_) {},
        onDone: () {
          if (!upstreamGone.isCompleted) upstreamGone.complete();
        },
        onError: (Object _) {
          if (!upstreamGone.isCompleted) upstreamGone.complete();
        },
      );
      // Beaucoup de données : le tampon du client figé se remplit.
      try {
        for (var i = 0; i < 4000; i++) {
          sock.add(List.filled(64 * 1024, 1));
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      } on Object {
        // Connexion fermée.
      }
    });
    final s = await start(
      source: CastHttpSource(Uri.parse('http://127.0.0.1:${slow.port}/v')),
    );
    // Client brut qui lit une fois puis se fige (pause sur la socket).
    final raw = await Socket.connect(s.url.host, s.url.port);
    raw.write(
      'GET ${s.url.path} HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n',
    );
    final got = Completer<void>();
    final ended = Completer<void>();
    final sub = raw.listen(
      (_) {
        if (!got.isCompleted) got.complete();
      },
      onDone: () {
        if (!ended.isCompleted) ended.complete();
      },
      onError: (Object _) {
        if (!ended.isCompleted) ended.complete();
      },
    );
    await got.future.timeout(const Duration(seconds: 5));
    unawaited(raw.done.catchError((Object _) {}));
    sub.pause(); // figé, jamais déconnecté
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(s.openSockets, 1); // le flux figé est bien en cours
    await s.close();
    // Immédiatement après close() : la socket détachée est détruite et
    // oubliée, sans attendre l'échec de l'écriture ni la fermeture amont.
    expect(s.openSockets, 0);
    await upstreamGone.future.timeout(const Duration(seconds: 5));
    // La socket du client figé a bien été détruite côté serveur.
    sub.resume();
    await ended.future.timeout(const Duration(seconds: 5));
    raw.destroy();
  });

  test(
    'demi-fermeture du client juste après la requête : flux non coupé',
    () async {
      final s = await start();
      addTearDown(s.close);
      final raw = await Socket.connect(s.url.host, s.url.port);
      raw.write('GET ${s.url.path} HTTP/1.1\r\nHost: x\r\n\r\n');
      await raw.flush();
      await raw.close(); // fin d'écriture seulement
      final bytes = await raw.fold<List<int>>([], (a, b) => a..addAll(b));
      expect(String.fromCharCodes(bytes), startsWith('HTTP/1.1 200'));
      expect(bytes.length, greaterThan(1000));
    },
  );
}
