import 'dart:async';
import 'dart:io';

import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

class _FakeRenderer implements CastRenderer {
  final calls = <String>[];
  Uri? uri;
  Duration pos = const Duration(seconds: 5);
  Object? positionError;
  Object? setUriError;
  Object? seekError;
  String? lastMime;
  Completer<void>? gate;

  @override
  Future<void> setUri(
    Uri media,
    String title, {
    String mime = 'video/mp4',
  }) async {
    calls.add('setUri');
    lastMime = mime;
    await gate?.future;
    if (setUriError != null) throw setUriError!;
    uri = media;
  }

  @override
  Future<void> play() async => calls.add('play');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> seek(Duration p) async {
    calls.add('seek:${p.inSeconds}');
    if (seekError != null) throw seekError!;
  }

  @override
  Future<Duration> position() async {
    if (positionError != null) throw positionError!;
    return pos;
  }
}

final _device = CastDevice(
  usn: 'u',
  friendlyName: 'TV',
  location: Uri.parse('http://127.0.0.1:1/d.xml'),
  address: InternetAddress.loopbackIPv4,
  controlUrl: Uri.parse('http://127.0.0.1:1/c'),
  serviceType: 'urn:schemas-upnp-org:service:AVTransport:1',
);

void main() {
  late HttpServer upstream;
  late _FakeRenderer renderer;

  setUp(() async {
    renderer = _FakeRenderer();
    upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    upstream.listen((req) async {
      req.response.add([1, 2, 3]);
      await req.response.close();
    });
  });
  tearDown(() => upstream.close(force: true));

  CastSession make({Duration lost = const Duration(milliseconds: 200)}) =>
      CastSession(
        device: _device,
        renderer: renderer,
        source: CastHttpSource(
          Uri.parse('http://127.0.0.1:${upstream.port}/v.mp4'),
        ),
        title: 'Film',
        localAddresses: () async => [InternetAddress.loopbackIPv4],
        pollInterval: const Duration(milliseconds: 30),
        lostAfter: lost,
      );

  Future<int> fetchCode(Uri u) async {
    final c = HttpClient();
    try {
      return (await (await c.getUrl(u)).close()).statusCode;
    } finally {
      c.close(force: true);
    }
  }

  test(
    'start : serveur ouvert, URL du jeton (pas d\'URL source), play + reprise',
    () async {
      final s = make();
      await s.start(startAt: const Duration(seconds: 42));
      addTearDown(s.stop);
      expect(renderer.calls, containsAllInOrder(['setUri', 'play', 'seek:42']));
      final sent = renderer.uri!;
      expect(sent.host, '127.0.0.1');
      expect(sent.toString(), isNot(contains('v.mp4')));
      expect(sent.toString(), isNot(contains('${upstream.port}')));
      expect(await fetchCode(sent), 200);
    },
  );

  test(
    'stop : renvoie la dernière position, arrête l\'appareil et ferme le serveur',
    () async {
      final s = make();
      await s.start();
      final url = renderer.uri!;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final last = await s.stop();
      expect(last, const Duration(seconds: 5));
      expect(renderer.calls, contains('stop'));
      await expectLater(fetchCode(url), throwsA(isA<SocketException>()));
      expect(await s.stop(), last); // idempotent
    },
  );

  test('échec de setUri : serveur fermé, erreur propagée', () async {
    renderer.setUriError = const SoapFaultException(716, 'x');
    final s = make();
    await expectLater(s.start(), throwsA(isA<SoapFaultException>()));
  });

  test(
    'appareil muet pendant le délai : onLost avec la dernière position, serveur fermé',
    () async {
      final s = make();
      final lost = Completer<Duration>();
      s.onLost = lost.complete;
      await s.start();
      final url = renderer.uri!;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      renderer.pos = const Duration(seconds: 9);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      renderer.positionError = const SocketException('down');
      final p = await lost.future.timeout(const Duration(seconds: 3));
      expect(p, const Duration(seconds: 9));
      await expectLater(fetchCode(url), throwsA(isA<SocketException>()));
      expect(s.isActive, isFalse);
    },
  );

  test(
    'défaut SOAP 701 sur la position : l\'appareil répond, pas perdu',
    () async {
      final s = make(lost: const Duration(milliseconds: 100));
      var lost = false;
      s.onLost = (_) => lost = true;
      await s.start();
      addTearDown(s.stop);
      renderer.positionError = const SoapFaultException(701, 'x');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(lost, isFalse);
      expect(s.isActive, isTrue);
    },
  );

  test(
    'pas d\'adresse locale commune avec l\'appareil : erreur claire',
    () async {
      final s = CastSession(
        device: _device,
        renderer: renderer,
        source: CastHttpSource(
          Uri.parse('http://127.0.0.1:${upstream.port}/a'),
        ),
        title: 't',
        localAddresses: () async => [InternetAddress('203.0.113.9')],
      );
      await expectLater(s.start(), throwsA(isA<CastNetworkException>()));
      expect(renderer.calls, isEmpty);
    },
  );

  test('stop pendant le démarrage : serveur fermé, démarrage annulé', () async {
    renderer.gate = Completer<void>();
    final s = make();
    final started = s.start();
    started.ignore();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final url = renderer.uri;
    expect(url, isNull);
    await s.stop();
    renderer.gate!.complete();
    await expectLater(started, throwsA(anything));
    expect(s.isActive, isFalse);
  });

  test(
    'MIME annoncé : fichier par extension, flux HTTP par mimeType',
    () async {
      final f = File('${Directory.systemTemp.path}/x_cast.mkv');
      final s1 = CastSession(
        device: _device,
        renderer: renderer,
        source: CastFileSource(f),
        title: 't',
        localAddresses: () async => [InternetAddress.loopbackIPv4],
      );
      await s1.start();
      await s1.stop();
      expect(renderer.lastMime, 'video/x-matroska');
      final s2 = CastSession(
        device: _device,
        renderer: renderer,
        source: CastHttpSource(
          Uri.parse('http://127.0.0.1:${upstream.port}/a'),
          mimeType: 'video/webm',
        ),
        title: 't',
        localAddresses: () async => [InternetAddress.loopbackIPv4],
      );
      await s2.start();
      await s2.stop();
      expect(renderer.lastMime, 'video/webm');
    },
  );
}
