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

  test(
    'https : TLS établi sur l adresse vérifiée (certificat contrôlé)',
    () async {
      // Certificat auto-signé de courte durée généré à l'exécution (les
      // plateformes refusent les certificats trop longs).
      final dir = Directory.systemTemp.createTempSync('lumio_tls');
      addTearDown(() => dir.deleteSync(recursive: true));
      final cert = '${dir.path}/cert.pem', key = '${dir.path}/key.pem';
      final gen = await Process.run('openssl', [
        'req',
        '-x509',
        '-newkey',
        'rsa:2048',
        '-nodes',
        '-keyout',
        key,
        '-out',
        cert,
        '-days',
        '30',
        '-subj',
        '/CN=localhost',
        '-addext',
        'subjectAltName=DNS:localhost,IP:127.0.0.1',
        '-addext',
        'extendedKeyUsage=serverAuth',
        '-addext',
        'keyUsage=digitalSignature,keyEncipherment,keyCertSign',
      ]);
      if (gen.exitCode != 0) {
        markTestSkipped('openssl indisponible');
        return;
      }
      final ctx = SecurityContext()
        ..useCertificateChain(cert)
        ..usePrivateKey(key);
      final tls = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        ctx,
      );
      addTearDown(() => tls.close(force: true));
      tls.listen((r) async {
        r.response.write('secure');
        await r.response.close();
      });
      final trust = SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificates(cert);
      final f = IoHttpFetcher(
        connectionFactory: guardedConnectionFactory(
          allowPrivate: true,
          lookup: fakeLookup,
          securityContext: trust,
        ),
      );
      final r = await f.get(Uri.parse('https://localhost:${tls.port}/'));
      expect(String.fromCharCodes(r.body), 'secure');
      // Mauvais nom d'hôte : certificat refusé.
      await expectLater(
        f.get(Uri.parse('https://autre.example:${tls.port}/')),
        throwsA(isA<HandshakeException>()),
      );
    },
  );

  test('repli sur l adresse suivante si la première est injoignable', () async {
    final f = IoHttpFetcher(
      connectionFactory: guardedConnectionFactory(
        allowPrivate: true,
        lookup: (_) async => [
          InternetAddress('::1'),
          InternetAddress.loopbackIPv4,
        ],
      ),
    );
    final r = await f.get(Uri.parse('http://exemple.test:${server.port}/'));
    expect(String.fromCharCodes(r.body), 'ok');
  });
}
