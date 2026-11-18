import 'dart:io';

import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) async {
      r.response.write('ok');
      await r.response.close();
    });
  });
  tearDown(() => server.close(force: true));

  Future<List<InternetAddress>> fakeLookup(String h) async => [
    InternetAddress.loopbackIPv4,
  ];

  test('un nom public qui résout vers une adresse privée est refusé', () async {
    final f = IoHttpFetcher(
      connectionFactory: guardedConnectionFactory(lookup: fakeLookup),
    );
    await expectLater(
      f.get(Uri.parse('http://192.168.1.1.nip.io:${server.port}/')),
      throwsA(isA<UnsafeUrlException>()),
    );
  });

  test(
    'allowPrivate laisse passer et se connecte à l adresse résolue',
    () async {
      final f = IoHttpFetcher(
        connectionFactory: guardedConnectionFactory(
          allowPrivate: true,
          lookup: fakeLookup,
        ),
      );
      final r = await f.get(Uri.parse('http://exemple.test:${server.port}/'));
      expect(String.fromCharCodes(r.body), 'ok');
    },
  );
}
