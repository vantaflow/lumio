import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

const _desc = '''<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <device>
    <friendlyName>Salon TV</friendlyName>
    <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType>
        <controlURL>/rc</controlURL>
      </service>
      <service>
        <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
        <controlURL>/upnp/control/avt</controlURL>
      </service>
    </serviceList>
  </device>
</root>''';

String _response(String location, {String st = ssdpRendererTarget}) =>
    'HTTP/1.1 200 OK\r\nCACHE-CONTROL: max-age=1800\r\n'
    'LOCATION: $location\r\nST: $st\r\n'
    'USN: uuid:abc::$st\r\n\r\n';

void main() {
  group('parseSsdpResponse', () {
    test('lit LOCATION, ST et USN sans tenir compte de la casse', () {
      final r = parseSsdpResponse(
        _response(
          'http://192.168.1.20:8080/d.xml',
        ).replaceAll('LOCATION', 'location'),
      );
      expect(r, isNotNull);
      expect(r!.location, Uri.parse('http://192.168.1.20:8080/d.xml'));
      expect(r.st, ssdpRendererTarget);
      expect(r.usn, 'uuid:abc::$ssdpRendererTarget');
    });

    test('refuse une réponse sans LOCATION, mal formée ou sans statut 200', () {
      expect(parseSsdpResponse('HTTP/1.1 200 OK\r\nST: x\r\n\r\n'), isNull);
      expect(parseSsdpResponse('n importe quoi'), isNull);
      expect(
        parseSsdpResponse(
          'HTTP/1.1 500 Err\r\nLOCATION: http://1.2.3.4/\r\n\r\n',
        ),
        isNull,
      );
      expect(parseSsdpResponse(_response('ftp://192.168.1.2/d.xml')), isNull);
      expect(
        parseSsdpResponse('HTTP/1.1 200 OK\r\nLOCATION: ::bad::\r\n\r\n'),
        isNull,
      );
    });

    test('M-SEARCH vise MediaRenderer:1', () {
      final m = buildMSearch();
      expect(m, startsWith('M-SEARCH * HTTP/1.1\r\n'));
      expect(m, contains('MAN: "ssdp:discover"'));
      expect(m, contains('ST: urn:schemas-upnp-org:device:MediaRenderer:1'));
      expect(m, endsWith('\r\n\r\n'));
    });
  });

  group('parseDeviceDescription', () {
    final loc = Uri.parse('http://192.168.1.20:8080/d.xml');

    test('trouve le nom et le controlURL AVTransport (résolu)', () {
      final d = parseDeviceDescription(utf8.encode(_desc), loc);
      expect(d.friendlyName, 'Salon TV');
      expect(
        d.controlUrl,
        Uri.parse('http://192.168.1.20:8080/upnp/control/avt'),
      );
      expect(d.serviceType, 'urn:schemas-upnp-org:service:AVTransport:1');
    });

    test('XXE : DOCTYPE et entités rejetés', () {
      const evil =
          '<?xml version="1.0"?><!DOCTYPE r [<!ENTITY x SYSTEM "file:///etc/passwd">]>'
          '<root><device><friendlyName>&x;</friendlyName></device></root>';
      expect(
        () => parseDeviceDescription(utf8.encode(evil), loc),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseDeviceDescription(
          utf8.encode(_desc.replaceFirst('<root', '<!doctype root><root')),
          loc,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('un controlURL vers un autre hôte est refusé', () {
      final other = _desc.replaceFirst(
        '/upnp/control/avt',
        'http://203.0.113.9/steal',
      );
      expect(
        () => parseDeviceDescription(utf8.encode(other), loc),
        throwsA(isA<FormatException>()),
      );
    });

    test('sans service AVTransport : erreur', () {
      expect(
        () => parseDeviceDescription(
          utf8.encode(_desc.replaceAll('AVTransport', 'Other')),
          loc,
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('discover', () {
    late RawDatagramSocket renderer;
    late HttpServer http;
    late List<String> hits;

    setUp(() async {
      hits = [];
      http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      http.listen((req) async {
        hits.add(req.uri.path);
        if (req.uri.path == '/big.xml') {
          req.response.write('<a>${'x' * (300 * 1024)}</a>');
        } else if (req.uri.path == '/redir.xml') {
          req.response.statusCode = 302;
          req.response.headers.set('location', 'http://203.0.113.9/x.xml');
        } else {
          req.response.write(_desc);
        }
        await req.response.close();
      });
      renderer = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    });

    tearDown(() async {
      renderer.close();
      await http.close(force: true);
    });

    void answerWith(List<String> locations) {
      renderer.listen((e) {
        if (e != RawSocketEvent.read) return;
        final d = renderer.receive();
        if (d == null) return;
        expect(utf8.decode(d.data), contains('M-SEARCH'));
        for (final l in locations) {
          renderer.send(utf8.encode(_response(l)), d.address, d.port);
        }
      });
    }

    Stream<CastDevice> run() => discover(
      timeout: const Duration(milliseconds: 600),
      target: InternetAddress.loopbackIPv4,
      targetPort: renderer.port,
      allowLoopback: true,
    );

    test(
      'trouve un appareil, recoupe le LOCATION avec l\'expéditeur',
      () async {
        answerWith(['http://127.0.0.1:${http.port}/d.xml']);
        final found = await run().toList();
        expect(found, hasLength(1));
        expect(found.single.friendlyName, 'Salon TV');
        expect(found.single.address, InternetAddress.loopbackIPv4);
      },
    );

    test(
      'ignore un LOCATION dont l\'hôte n\'est pas l\'expéditeur (SSRF)',
      () async {
        answerWith(['http://203.0.113.9:80/d.xml', 'http://10.0.0.5/d.xml']);
        expect(await run().toList(), isEmpty);
        expect(hits, isEmpty);
      },
    );

    test(
      'description trop grosse (> 256 Ko) ou redirigée ailleurs : ignorée',
      () async {
        answerWith([
          'http://127.0.0.1:${http.port}/big.xml',
          'http://127.0.0.1:${http.port}/redir.xml',
        ]);
        expect(await run().toList(), isEmpty);
      },
    );

    test('même appareil répondu deux fois : un seul résultat', () async {
      final l = 'http://127.0.0.1:${http.port}/d.xml';
      answerWith([l, l]);
      expect(await run().toList(), hasLength(1));
    });

    test('refuse une expéditeur de boucle locale hors tests', () async {
      answerWith(['http://127.0.0.1:${http.port}/d.xml']);
      final found = await discover(
        timeout: const Duration(milliseconds: 400),
        target: InternetAddress.loopbackIPv4,
        targetPort: renderer.port,
      ).toList();
      expect(found, isEmpty);
    });

    test('aucune réponse : flux vide', () async {
      expect(await run().toList(), isEmpty);
    }, timeout: const Timeout(Duration(seconds: 5)));
  });
}
