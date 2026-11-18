import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/player/tracks_controller.dart';
import 'package:lumio_core/lumio_core.dart';

// Fichier à part : aucun test de widget ici, donc HttpClient réel.
void main() {
  late HttpServer srv;
  setUp(() async {
    srv = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    srv.listen((r) async {
      r.response.write('sub');
      await r.response.close();
    });
  });
  tearDown(() => srv.close(force: true));

  Future<List<InternetAddress>> toLoopback(String _) async => [
    InternetAddress.loopbackIPv4,
  ];
  Uri url() => Uri.parse('http://subs.example:${srv.port}/a.srt');

  test('addon approuvé sur le réseau privé : téléchargé', () async {
    final f = subtitleFetcher(allowPrivate: true, lookup: toLoopback);
    expect(
      await downloadSubtitle(f, url(), allowPrivate: true),
      'sub'.codeUnits,
    );
  });

  test('addon public vers une IP privée : refusé', () async {
    final f = subtitleFetcher(allowPrivate: false, lookup: toLoopback);
    await expectLater(
      downloadSubtitle(f, url(), allowPrivate: false),
      throwsA(isA<UnsafeUrlException>()),
    );
  });
}
