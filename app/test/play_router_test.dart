import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:lumio/player/local_proxy.dart';
import 'package:lumio/player/play_router.dart';
import 'package:lumio_core/lumio_core.dart';

void main() {
  late LocalProxy proxy;
  setUp(() async => proxy = await LocalProxy.start());
  tearDown(() => proxy.close());

  StreamItem item(String url, {Map<String, String> h = const {}}) => StreamItem(
    addonId: 'a',
    title: 't',
    url: Uri.parse(url),
    requestHeaders: h,
  );

  Future<PlayRoute> route(
    StreamItem s, {
    bool allowPrivate = false,
    bool trustedLocal = false,
  }) => routePlayback(
    s,
    proxy: () async => proxy,
    allowPrivate: allowPrivate,
    trustedLocal: trustedLocal,
  );

  test('fichier public → via le proxy (redirections gardées)', () async {
    final r = await route(item('https://cdn.example/v.mp4'));
    expect(r.kind, PlayRouteKind.proxy);
    expect(r.url.host, '127.0.0.1');
    expect(r.url.port, proxy.port);
  });

  test('HLS et en-têtes imposés → via le proxy', () async {
    expect((await route(item('https://h/a.m3u8'))).kind, PlayRouteKind.proxy);
    final r = await route(item('https://h/v.mp4', h: {'Referer': 'x'}));
    expect(r.kind, PlayRouteKind.proxy);
    expect(r.url.queryParameters.containsKey('h'), isTrue);
  });

  test('hôte local ou privé d\'un addon → refusé', () async {
    for (final u in [
      'http://127.0.0.1:8080/x',
      'http://192.168.1.5/x.mp4',
      'http://localhost/x',
    ]) {
      await expectLater(route(item(u)), throwsA(isA<UnsafeUrlException>()));
    }
  });

  test('allowPrivate : autorisé, via le proxy avec a=1', () async {
    final r = await route(item('http://192.168.1.5/x.mp4'), allowPrivate: true);
    expect(r.kind, PlayRouteKind.proxy);
    expect(r.url.queryParameters['a'], '1');
  });

  test('trustedLocal (torrent) : lecture directe', () async {
    final r = await route(
      item('http://127.0.0.1:9999/stream/abc'),
      trustedLocal: true,
    );
    expect(r.kind, PlayRouteKind.direct);
    expect(r.url.port, 9999);
  });

  test('trustedLocal ne laisse pas passer file:', () async {
    await expectLater(
      route(item('file:///etc/passwd'), trustedLocal: true),
      throwsA(isA<UnsafeUrlException>()),
    );
  });

  test('schéma non http(s) refusé', () async {
    await expectLater(
      route(item('rtmp://h/x')),
      throwsA(isA<UnsafeUrlException>()),
    );
  });

  group('LocalFileSource', () {
    const root = '/storage/emulated/0/Movies';
    Future<PlayRoute> local(String path, {List<String> roots = const [root]}) =>
        routePlayback(
          item('https://x/ignored'),
          proxy: () async => proxy,
          local: LocalFileSource(
            path: path,
            grantedFolders: roots,
            checkReal: false,
          ),
        );

    test('fichier dans un dossier accordé : file:// direct', () async {
      final r = await local('$root/Sous/Film (2019).mkv');
      expect(r.kind, PlayRouteKind.direct);
      expect(r.url.scheme, 'file');
      expect(r.url.toFilePath(), '$root/Sous/Film (2019).mkv');
    });

    test('hors des dossiers accordés, traversée, relatif : refusé', () async {
      for (final path in [
        '/etc/passwd',
        '/storage/emulated/0/Other/a.mkv',
        '$root/../Other/a.mkv',
        '${root}2/a.mkv', // préfixe voisin, pas un sous-dossier
        'Movies/a.mkv',
        '$root/a\u0000.mkv',
        '',
      ]) {
        await expectLater(
          local(path),
          throwsA(isA<UnsafeUrlException>()),
          reason: path,
        );
      }
      await expectLater(
        local('$root/a.mkv', roots: const []),
        throwsA(isA<UnsafeUrlException>()),
      );
    });

    test('extension non vidéo refusée', () async {
      await expectLater(
        local('$root/notes.txt'),
        throwsA(isA<UnsafeUrlException>()),
      );
    });

    test(
      'un flux d\'addon en file: reste refusé sans LocalFileSource',
      () async {
        await expectLater(
          route(item('file://$root/a.mkv')),
          throwsA(isA<UnsafeUrlException>()),
        );
        await expectLater(
          route(item('file://$root/a.mkv'), trustedLocal: true),
          throwsA(isA<UnsafeUrlException>()),
        );
      },
    );
  });

  group('LocalFileSource : chemins réels et style Windows', () {
    test('lien déplacé après l\'analyse : refusé', () {
      final root = Directory.systemTemp.createTempSync('lumio_rt_');
      final outside = Directory.systemTemp.createTempSync('lumio_out_');
      addTearDown(() {
        root.deleteSync(recursive: true);
        outside.deleteSync(recursive: true);
      });
      File('${outside.path}/secret.mkv').writeAsStringSync('x');
      File('${root.path}/a.mkv').writeAsStringSync('x');
      final link = '${root.path}/l.mkv';
      Link(link).createSync('${root.path}/a.mkv');
      LocalFileSource src() =>
          LocalFileSource(path: link, grantedFolders: [root.path]);
      expect(src().validate().scheme, 'file'); // cible dans le dossier
      Link(link)
        ..deleteSync()
        ..createSync('${outside.path}/secret.mkv'); // lien rediriger
      expect(src().validate, throwsA(isA<UnsafeUrlException>()));
    });

    test('fichier absent : refusé', () {
      final root = Directory.systemTemp.createTempSync('lumio_rt_');
      addTearDown(() => root.deleteSync(recursive: true));
      expect(
        LocalFileSource(
          path: '${root.path}/nope.mkv',
          grantedFolders: [root.path],
        ).validate,
        throwsA(isA<UnsafeUrlException>()),
      );
    });

    final win = p.Context(style: p.Style.windows);
    LocalFileSource w(String path, [String root = r'C:\Videos']) =>
        LocalFileSource(
          path: path,
          grantedFolders: [root],
          checkReal: false,
          context: win,
        );

    test('Windows : lettre de lecteur, casse mixte, sous-dossier', () {
      expect(w(r'C:\Videos\Sub\Film.MKV').validate().scheme, 'file');
      expect(w(r'C:\Videos\a.mp4', r'c:\videos').validate().scheme, 'file');
    });

    test('Windows : slashs, traversée, autre lecteur, relatif : refusés', () {
      for (final path in [
        'C:/Videos/a.mkv',
        r'C:\Videos\..\Other\a.mkv',
        r'D:\Videos\a.mkv',
        r'C:\Videos2\a.mkv',
        r'Videos\a.mkv',
        r'\\srv\share\a.mkv',
      ]) {
        expect(
          w(path).validate,
          throwsA(isA<UnsafeUrlException>()),
          reason: path,
        );
      }
    });
  });
}
