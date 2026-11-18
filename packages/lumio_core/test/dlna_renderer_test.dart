import 'dart:convert';
import 'dart:io';

import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

class _Post {
  _Post(this.url, this.body, this.headers);
  final Uri url;
  final String body;
  final Map<String, String> headers;
}

class _FakeFetcher implements HttpPostFetcher {
  final posts = <_Post>[];
  FetchResponse Function(_Post) reply = (_) => FetchResponse(
    status: 200,
    body: utf8.encode('<s:Envelope xmlns:s="x"><s:Body/></s:Envelope>'),
  );
  Object? throwError;
  void Function(Uri)? lastGuard;

  @override
  Future<FetchResponse> post(
    Uri url, {
    required List<int> body,
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) async {
    lastGuard = guard;
    guard?.call(url);
    if (throwError != null) throw throwError!;
    final p = _Post(url, utf8.decode(body), headers);
    posts.add(p);
    return reply(p);
  }

  @override
  Future<FetchResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) => throw UnimplementedError();
}

final _device = CastDevice(
  usn: 'uuid:1',
  friendlyName: 'TV',
  location: Uri.parse('http://192.168.1.20:8080/d.xml'),
  address: InternetAddress('192.168.1.20'),
  controlUrl: Uri.parse('http://192.168.1.20:8080/avt'),
  serviceType: 'urn:schemas-upnp-org:service:AVTransport:1',
);

String _fault(int code) =>
    '<?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">'
    '<s:Body><s:Fault><faultcode>s:Client</faultcode><faultstring>UPnPError</faultstring>'
    '<detail><UPnPError xmlns="urn:schemas-upnp-org:control-1-0"><errorCode>$code</errorCode>'
    '<errorDescription>Transition not available</errorDescription></UPnPError></detail>'
    '</s:Fault></s:Body></s:Envelope>';

void main() {
  late _FakeFetcher f;
  late DlnaRenderer r;
  setUp(() {
    f = _FakeFetcher();
    r = DlnaRenderer(_device, fetcher: f);
  });

  test('SetAVTransportURI : enveloppe, action et métadonnées échappées', () async {
    await r.setUri(
      Uri.parse('http://192.168.1.10:5000/abc?x=1&y=2'),
      'Tom & <Jerry> "1"',
    );
    final p = f.posts.single;
    expect(p.url, _device.controlUrl);
    expect(
      p.headers['SOAPACTION'],
      '"urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI"',
    );
    expect(p.headers['Content-Type'], contains('text/xml'));
    // L'enveloppe est du XML bien formé et les métadonnées DIDL y sont du texte.
    expect(
      p.body,
      contains(
        '<u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">',
      ),
    );
    expect(p.body, contains('<InstanceID>0</InstanceID>'));
    expect(
      p.body,
      contains(
        '<CurrentURI>http://192.168.1.10:5000/abc?x=1&amp;y=2</CurrentURI>',
      ),
    );
    expect(p.body, contains('&lt;DIDL-Lite'));
    expect(
      p.body,
      contains('Tom &amp;amp; &amp;lt;Jerry&amp;gt; &amp;quot;1&amp;quot;'),
    );
    expect(p.body, isNot(contains('<Jerry>')));
    expect(p.body, isNot(contains('<DIDL-Lite')));
    expect(p.body, contains('object.item.videoItem'));
  });

  test('protocolInfo suit le type MIME donné', () async {
    await r.setUri(Uri.parse('http://192.168.1.10/a'), 'T', mime: 'video/webm');
    expect(f.posts.single.body, contains('http-get:*:video/webm:*'));
  });

  test('Play, Pause, Stop, Seek : bonnes actions et paramètres', () async {
    await r.play();
    await r.pause();
    await r.stop();
    await r.seek(const Duration(hours: 1, minutes: 2, seconds: 3));
    final actions = f.posts.map((p) => p.headers['SOAPACTION']).toList();
    expect(actions, [
      '"urn:schemas-upnp-org:service:AVTransport:1#Play"',
      '"urn:schemas-upnp-org:service:AVTransport:1#Pause"',
      '"urn:schemas-upnp-org:service:AVTransport:1#Stop"',
      '"urn:schemas-upnp-org:service:AVTransport:1#Seek"',
    ]);
    expect(f.posts[0].body, contains('<Speed>1</Speed>'));
    expect(f.posts[3].body, contains('<Unit>REL_TIME</Unit>'));
    expect(f.posts[3].body, contains('<Target>01:02:03</Target>'));
  });

  test('GetPositionInfo : RelTime lu', () async {
    f.reply = (_) => FetchResponse(
      status: 200,
      body: utf8.encode(
        '<s:Envelope xmlns:s="x"><s:Body><u:GetPositionInfoResponse xmlns:u="y">'
        '<Track>1</Track><RelTime>0:01:30.500</RelTime></u:GetPositionInfoResponse>'
        '</s:Body></s:Envelope>',
      ),
    );
    expect(
      await r.position(),
      const Duration(minutes: 1, seconds: 30, milliseconds: 500),
    );
  });

  test('GetPositionInfo : NOT_IMPLEMENTED vaut zéro', () async {
    f.reply = (_) => FetchResponse(
      status: 200,
      body: utf8.encode('<e><RelTime>NOT_IMPLEMENTED</RelTime></e>'),
    );
    expect(await r.position(), Duration.zero);
  });

  test(
    'défaut SOAP 701 (HTTP 500) : SoapFaultException avec le code',
    () async {
      f.reply = (_) =>
          FetchResponse(status: 500, body: utf8.encode(_fault(701)));
      await expectLater(
        r.play(),
        throwsA(
          isA<SoapFaultException>()
              .having((e) => e.code, 'code', 701)
              .having(
                (e) => e.description,
                'description',
                contains('Transition'),
              ),
        ),
      );
    },
  );

  test('HTTP 500 sans défaut lisible : DlnaException', () async {
    f.reply = (_) => FetchResponse(status: 500, body: utf8.encode('oops'));
    await expectLater(r.pause(), throwsA(isA<DlnaException>()));
  });

  test('réponse avec DOCTYPE : rejetée (XXE)', () async {
    f.reply = (_) => FetchResponse(
      status: 200,
      body: utf8.encode(
        '<!DOCTYPE x [<!ENTITY e SYSTEM "file:///etc/passwd">]><a>&e;</a>',
      ),
    );
    await expectLater(r.position(), throwsA(isA<DlnaException>()));
  });

  test('la garde de requête n\'autorise que l\'hôte de l\'appareil', () async {
    await r.play();
    expect(
      () => f.lastGuard!(Uri.parse('http://203.0.113.9/x')),
      throwsA(anything),
    );
    f.lastGuard!(_device.controlUrl);
  });

  test('controlUrl d\'un autre hôte : refusé à la construction', () {
    final bad = CastDevice(
      usn: 'u',
      friendlyName: 'x',
      location: _device.location,
      address: _device.address,
      controlUrl: Uri.parse('http://203.0.113.9/avt'),
      serviceType: _device.serviceType,
    );
    expect(() => DlnaRenderer(bad, fetcher: f), throwsArgumentError);
  });

  test('erreur réseau : propagée (appareil injoignable)', () async {
    f.throwError = const SocketException('down');
    await expectLater(r.position(), throwsA(isA<SocketException>()));
  });
}
