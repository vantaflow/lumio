import 'dart:async';

import 'package:lumio_core/lumio_core.dart';
import 'package:lumio_core/testing.dart';
import 'package:test/test.dart';

void main() {
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
}
