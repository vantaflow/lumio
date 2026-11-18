import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/pairing_client.dart';

/// Serveur factice local : reproduit le contrat du Worker.
class _FakeServer {
  late HttpServer server;
  final polls = <String>[];
  int pending = 0; // nombre de 204 avant 200
  int finalStatus = 200;
  String payload = 'https://x.example/manifest.json';
  int created = 0;

  Future<void> start() async {
    server = await HttpServer.bind('127.0.0.1', 0);
    server.listen((req) async {
      final res = req.response;
      if (req.method == 'POST' && req.uri.path == '/base/pair') {
        created++;
        res.statusCode = 201;
        res.write(
          jsonEncode({'code': 'KR74PQ', 'pollToken': 'tok', 'expiresIn': 300}),
        );
      } else if (req.method == 'GET' && req.uri.path == '/base/pair/KR74PQ') {
        polls.add(req.headers.value('authorization') ?? '');
        if (pending > 0) {
          pending--;
          res.statusCode = 204;
        } else {
          res.statusCode = finalStatus;
          if (finalStatus == 200) res.write(jsonEncode({'payload': payload}));
        }
      } else {
        res.statusCode = 404;
      }
      await res.close();
    });
  }

  String get url => 'http://127.0.0.1:${server.port}/base/';
}

class _DownHttp implements PairHttp {
  @override
  Future<PairHttpResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
  }) async => throw const SocketException('down');
}

PairingClient _client(_FakeServer s, {DateTime Function()? now}) =>
    PairingClient(
      s.url,
      pollInterval: const Duration(milliseconds: 5),
      now: now,
    );

void main() {
  late _FakeServer srv;
  setUp(() async {
    srv = _FakeServer();
    await srv.start();
  });
  tearDown(() => srv.server.close(force: true));

  test('create renvoie le code, le jeton et l\'expiration', () async {
    final s = await _client(srv).create();
    expect(s.code, 'KR74PQ');
    expect(s.pollToken, 'tok');
    expect(
      s.expiresAt.difference(DateTime.now()).inSeconds,
      inInclusiveRange(295, 300),
    );
  });

  test(
    'waitPayload émet la valeur quand le serveur passe de 204 à 200',
    () async {
      srv.pending = 3;
      final c = _client(srv);
      final s = await c.create();
      final values = await c.waitPayload(s).toList();
      expect(values, ['https://x.example/manifest.json']);
      expect(srv.polls.length, 4);
      expect(srv.polls.toSet(), {'Bearer tok'});
    },
  );

  test('410 -> PairingException(expired)', () async {
    srv.finalStatus = 410;
    final c = _client(srv);
    final s = await c.create();
    expect(
      c.waitPayload(s).toList(),
      throwsA(
        isA<PairingException>().having(
          (e) => e.code,
          'code',
          PairingErrorCode.expired,
        ),
      ),
    );
  });

  test('expiration locale sans interroger davantage', () async {
    srv.pending = 1000;
    var t = DateTime.now();
    final c = _client(srv, now: () => t);
    final s = await c.create();
    t = t.add(const Duration(seconds: 301));
    await expectLater(
      c.waitPayload(s).toList(),
      throwsA(isA<PairingException>()),
    );
    expect(srv.polls, isEmpty);
  });

  test('annuler l\'abonnement arrête l\'interrogation', () async {
    srv.pending = 1000;
    final c = _client(srv);
    final s = await c.create();
    final sub = c.waitPayload(s).listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await sub.cancel();
    final n = srv.polls.length;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(srv.polls.length, lessThanOrEqualTo(n + 1));
  });

  test('serveur injoignable -> unavailable', () async {
    final c = PairingClient('https://api.example', http: _DownHttp());
    await expectLater(
      c.create(),
      throwsA(
        isA<PairingException>().having(
          (e) => e.code,
          'code',
          PairingErrorCode.unavailable,
        ),
      ),
    );
  });

  test('refuse http hors localhost, accepte https', () {
    expect(
      () => PairingClient('http://evil.example'),
      throwsA(isA<PairingException>()),
    );
    expect(
      () => PairingClient('ftp://x.example'),
      throwsA(isA<PairingException>()),
    );
    expect(
      PairingClient('https://api.lumio.example/').baseUrl.host,
      'api.lumio.example',
    );
    expect(PairingClient('http://localhost:8787').baseUrl.port, 8787);
  });

  test('companionUrl encode /p/<code>', () {
    expect(
      PairingClient(
        'https://api.lumio.example/v1/',
      ).companionUrl('KR74PQ').toString(),
      'https://api.lumio.example/v1/p/KR74PQ',
    );
  });
}
