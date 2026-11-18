import 'dart:convert';
import 'dart:io';

import 'package:lumio_core/testing.dart';
import 'package:test/test.dart';

Future<HttpClientResponse> _get(Uri uri) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(uri);
    return await req.close();
  } finally {
    client.close();
  }
}

void main() {
  late FakeAddonServer server;
  setUp(() async => server = await FakeAddonServer.start());
  tearDown(() async => server.close());

  test('répond 200 après le délai configuré', () async {
    server.route(
      '/manifest.json',
      FakeResponse.json({'id': 'x'}, delay: const Duration(milliseconds: 300)),
    );
    final sw = Stopwatch()..start();
    final res = await _get(server.baseUrl.resolve('/manifest.json'));
    final body = await res.transform(utf8.decoder).join();
    sw.stop();
    expect(res.statusCode, 200);
    expect(res.headers.contentType?.mimeType, 'application/json');
    expect(jsonDecode(body), {'id': 'x'});
    expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(290));
  });

  test('route inconnue : 404', () async {
    final res = await _get(server.baseUrl.resolve('/nope'));
    await res.drain<void>();
    expect(res.statusCode, 404);
  });

  test('statut d\'erreur personnalisé', () async {
    server.route('/boom', FakeResponse.json({'e': 1}, status: 500));
    final res = await _get(server.baseUrl.resolve('/boom'));
    await res.drain<void>();
    expect(res.statusCode, 500);
  });

  test('réponse brute : octets, type de contenu et statut', () async {
    server.route(
      '/raw',
      FakeResponse.raw(
        utf8.encode('<html>oops'),
        contentType: 'text/html',
        status: 200,
      ),
    );
    final res = await _get(server.baseUrl.resolve('/raw'));
    final body = await res.transform(utf8.decoder).join();
    expect(res.headers.contentType?.mimeType, 'text/html');
    expect(body, '<html>oops');
  });

  test('JSON non ASCII (arabe) transmis en UTF-8', () async {
    server.route('/ar', FakeResponse.json({'name': 'مرحبا'}));
    final res = await _get(server.baseUrl.resolve('/ar'));
    final body = await res.transform(utf8.decoder).join();
    expect(jsonDecode(body)['name'], 'مرحبا');
  });

  test('route remplacée par un second appel à route()', () async {
    server.route('/a', FakeResponse.json({'v': 1}));
    server.route('/a', FakeResponse.json({'v': 2}));
    final res = await _get(server.baseUrl.resolve('/a'));
    expect(jsonDecode(await res.transform(utf8.decoder).join()), {'v': 2});
  });

  test('baseUrl en boucle locale avec port éphémère', () {
    expect(server.baseUrl.host, '127.0.0.1');
    expect(server.baseUrl.port, greaterThan(0));
  });
}
