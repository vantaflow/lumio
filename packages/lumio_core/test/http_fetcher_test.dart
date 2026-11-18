import 'dart:async';
import 'dart:io';

import 'package:lumio_core/lumio_core.dart';
import 'package:lumio_core/testing.dart';
import 'package:test/test.dart';

void main() {
  _validateTests();
  late FakeAddonServer server;
  late IoHttpFetcher fetcher;

  setUp(() async {
    server = await FakeAddonServer.start();
    fetcher = IoHttpFetcher();
  });
  tearDown(() => server.close());

  test('GET simple : statut, corps et en-têtes', () async {
    server.route('/a', FakeResponse.json({'ok': true}));
    final r = await fetcher.get(server.baseUrl.resolve('/a'));
    expect(r.status, 200);
    expect(String.fromCharCodes(r.body), '{"ok":true}');
    expect(r.headers['content-type'], contains('application/json'));
  });

  test('statut 404 rendu sans exception', () async {
    final r = await fetcher.get(server.baseUrl.resolve('/absent'));
    expect(r.status, 404);
  });

  test('corps trop gros : ResponseTooLargeException', () async {
    server.route('/big', FakeResponse.raw(List.filled(10000, 65)));
    expect(
      fetcher.get(server.baseUrl.resolve('/big'), maxBytes: 1000),
      throwsA(isA<ResponseTooLargeException>()),
    );
  });

  test('délai dépassé : TimeoutException', () async {
    server.route(
      '/slow',
      FakeResponse.json({'a': 1}, delay: const Duration(seconds: 2)),
    );
    expect(
      fetcher.get(
        server.baseUrl.resolve('/slow'),
        timeout: const Duration(milliseconds: 200),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('suit une redirection', () async {
    server.route(
      '/r',
      FakeResponse.raw([], status: 302, headers: {'location': '/dest'}),
    );
    server.route('/dest', FakeResponse.json({'d': 1}));
    final r = await fetcher.get(server.baseUrl.resolve('/r'));
    expect(r.status, 200);
    expect(String.fromCharCodes(r.body), '{"d":1}');
  });

  test('trop de redirections : TooManyRedirectsException', () async {
    server.route(
      '/loop',
      FakeResponse.raw([], status: 302, headers: {'location': '/loop'}),
    );
    expect(
      fetcher.get(server.baseUrl.resolve('/loop')),
      throwsA(isA<TooManyRedirectsException>()),
    );
  });

  test(
    'maxRedirects respecté (1 redirection autorisée, 2 demandées)',
    () async {
      server.route(
        '/r1',
        FakeResponse.raw([], status: 302, headers: {'location': '/r2'}),
      );
      server.route(
        '/r2',
        FakeResponse.raw([], status: 302, headers: {'location': '/ok'}),
      );
      server.route('/ok', FakeResponse.json({}));
      expect(
        IoHttpFetcher(maxRedirects: 1).get(server.baseUrl.resolve('/r1')),
        throwsA(isA<TooManyRedirectsException>()),
      );
      final r = await IoHttpFetcher(
        maxRedirects: 2,
      ).get(server.baseUrl.resolve('/r1'));
      expect(r.status, 200);
    },
  );

  test('Location absent : InvalidRedirectException', () async {
    server.route('/nl', FakeResponse.raw([], status: 302));
    expect(
      fetcher.get(server.baseUrl.resolve('/nl')),
      throwsA(isA<InvalidRedirectException>()),
    );
  });

  test('Location illisible : InvalidRedirectException', () async {
    server.route(
      '/bad',
      FakeResponse.raw([], status: 302, headers: {'location': 'http://[::1'}),
    );
    expect(
      fetcher.get(server.baseUrl.resolve('/bad')),
      throwsA(isA<InvalidRedirectException>()),
    );
  });

  test('Location hors http/https : InsecureRedirectException', () async {
    server.route(
      '/ftp',
      FakeResponse.raw([], status: 302, headers: {'location': 'ftp://x/y'}),
    );
    expect(
      fetcher.get(server.baseUrl.resolve('/ftp')),
      throwsA(isA<InsecureRedirectException>()),
    );
  });

  test('corps de exactement maxBytes : accepté', () async {
    server.route('/exact', FakeResponse.raw(List.filled(1000, 65)));
    final r = await fetcher.get(
      server.baseUrl.resolve('/exact'),
      maxBytes: 1000,
    );
    expect(r.body.length, 1000);
  });

  test('en-têtes sensibles retirés au changement d\'origine', () async {
    final seen = <String, String?>{};
    // FakeAddonServer ne renvoie pas les en-têtes reçus : on les observe via
    // un serveur dédié.
    final a = await _echoServer(seen, 'a');
    final b = await _echoServer(seen, 'b');
    addTearDown(() => a.close(force: true));
    addTearDown(() => b.close(force: true));
    // /r sur a redirige vers b (autre port).
    a.redirectTo = 'http://127.0.0.1:${b.port}/dest';
    final r = await fetcher.get(
      Uri.parse('http://127.0.0.1:${a.port}/r'),
      headers: {'Authorization': 'Bearer x', 'Cookie': 'c=1', 'Accept': '*/*'},
    );
    expect(r.status, 200);
    expect(seen['a:authorization'], 'Bearer x');
    expect(seen['a:cookie'], 'c=1');
    expect(seen['b:authorization'], isNull);
    expect(seen['b:cookie'], isNull);
    expect(seen['b:accept'], '*/*');
  });
}

void _validateTests() {
  group('validateRedirect', () {
    final https = Uri.parse('https://a.example/x/y');
    final http = Uri.parse('http://a.example/x/y');
    test('https vers http : refusé', () {
      expect(
        () => validateRedirect(https, 'http://b.example/'),
        throwsA(isA<InsecureRedirectException>()),
      );
    });
    test('https vers https : accepté', () {
      expect(
        validateRedirect(https, 'https://b.example/z'),
        Uri.parse('https://b.example/z'),
      );
    });
    test('http vers https : accepté', () {
      expect(
        validateRedirect(http, 'https://b.example/z'),
        Uri.parse('https://b.example/z'),
      );
    });
    test('ftp : refusé', () {
      expect(
        () => validateRedirect(http, 'ftp://b.example/'),
        throwsA(isA<InsecureRedirectException>()),
      );
    });
    test('chemin relatif résolu', () {
      expect(validateRedirect(https, '/z'), Uri.parse('https://a.example/z'));
    });
    test('absent, vide ou illisible : InvalidRedirectException', () {
      for (final l in [null, '', 'http://[::1']) {
        expect(
          () => validateRedirect(http, l),
          throwsA(isA<InvalidRedirectException>()),
        );
      }
    });
  });
}

class _Echo {
  _Echo(this._server);
  final HttpServer _server;
  String? redirectTo;
  int get port => _server.port;
  Future<void> close({bool force = false}) => _server.close(force: force);
}

Future<_Echo> _echoServer(Map<String, String?> seen, String tag) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final echo = _Echo(server);
  server.listen((req) async {
    for (final n in ['authorization', 'cookie', 'accept']) {
      seen['$tag:$n'] = req.headers.value(n);
    }
    if (echo.redirectTo != null) {
      req.response
        ..statusCode = 302
        ..headers.set('location', echo.redirectTo!);
    } else {
      req.response.write('ok');
    }
    await req.response.close();
  });
  return echo;
}
