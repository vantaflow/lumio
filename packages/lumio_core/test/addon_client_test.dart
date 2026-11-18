import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lumio_core/lumio_core.dart';
import 'package:lumio_core/testing.dart';
import 'package:test/test.dart';

AddonManifest _manifest(Uri base) => AddonManifest(
  id: 'dev.test',
  version: '1.0.0',
  name: 'Test',
  types: const ['movie'],
  resources: const [AddonResource('catalog')],
  catalogs: const [],
  transportUrl: base.replace(path: '/manifest.json'),
);

class _Scripted implements HttpFetcher {
  _Scripted(this.script);
  final List<Object> script; // FetchResponse ou Exception
  final urls = <Uri>[];

  @override
  Future<FetchResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) async {
    urls.add(url);
    final next = script.removeAt(0);
    if (next is FetchResponse) return next;
    throw next;
  }
}

FetchResponse _ok(Object body, [int status = 200]) =>
    FetchResponse(status: status, body: utf8.encode(jsonEncode(body)));

void main() {
  late FakeAddonServer server;
  late AddonManifest manifest;

  setUp(() async {
    server = await FakeAddonServer.start();
    manifest = _manifest(server.baseUrl);
  });
  tearDown(() => server.close());

  AddonClient client({int retries = 0, Duration? timeout}) => AddonClient(
    IoHttpFetcher(),
    allowPrivate: true,
    retries: retries,
    timeout: timeout ?? const Duration(seconds: 8),
  );

  test('catalog : chemin sans extra et lecture des metas', () async {
    server.route(
      '/catalog/movie/top.json',
      FakeResponse.json({
        'metas': [
          {
            'id': 'tt1',
            'type': 'movie',
            'name': 'Film',
            'poster': 'https://e.com/p.jpg',
            'releaseInfo': '2020',
          },
          {'name': 'sans id'},
          'bizarre',
        ],
      }),
    );
    final r = await client().catalog(manifest, 'movie', 'top');
    expect(r, hasLength(1));
    expect(r.single.name, 'Film');
    expect(r.single.sourceAddonId, 'dev.test');
    expect(r.single.sourceKind, 'addon');
    expect(r.single.poster, Uri.parse('https://e.com/p.jpg'));
  });

  test('catalog avec extra : /catalog/movie/top/skip=100.json', () async {
    server.route(
      '/catalog/movie/top/skip=100.json',
      FakeResponse.json({'metas': []}),
    );
    expect(
      await client().catalog(manifest, 'movie', 'top', extra: {'skip': '100'}),
      isEmpty,
    );
  });

  test('extras : clés et valeurs encodées, jointes par &', () {
    final u = AddonClient.resourceUrl(
      manifest,
      'catalog',
      'movie',
      'top',
      extra: {'search': 'a b&c', 'skip': '1'},
    );
    expect(u.path, '/catalog/movie/top/search=a%20b%26c&skip=1.json');
  });

  test('ids avec « : » conservés', () {
    final u = AddonClient.resourceUrl(manifest, 'stream', 'series', 'tt1:1:2');
    expect(u.path, '/stream/series/tt1:1:2.json');
  });

  test('rawMeta, rawStreams, rawSubtitles', () async {
    server
      ..route(
        '/meta/movie/tt1.json',
        FakeResponse.json({
          'meta': {'id': 'tt1', 'name': 'F'},
        }),
      )
      ..route(
        '/stream/movie/tt1.json',
        FakeResponse.json({
          'streams': [
            {'url': 'https://e.com/v'},
            3,
          ],
        }),
      )
      ..route(
        '/subtitles/movie/tt1.json',
        FakeResponse.json({
          'subtitles': [
            {'id': 's', 'lang': 'fra'},
          ],
        }),
      );
    final c = client();
    expect((await c.rawMeta(manifest, 'movie', 'tt1'))!['name'], 'F');
    expect(await c.rawStreams(manifest, 'movie', 'tt1'), hasLength(1));
    expect(
      (await c.rawSubtitles(manifest, 'movie', 'tt1')).single['lang'],
      'fra',
    );
  });

  test('404 : meta null, flux vides, catalogue en erreur', () async {
    final c = client();
    expect(await c.rawMeta(manifest, 'movie', 'x'), isNull);
    expect(await c.rawStreams(manifest, 'movie', 'x'), isEmpty);
    expect(await c.rawSubtitles(manifest, 'movie', 'x'), isEmpty);
    await expectLater(
      c.catalog(manifest, 'movie', 'x'),
      throwsA(isA<AddonException>()),
    );
  });

  test('délai serveur 10 s : TimeoutException après ≈ 8 s', () async {
    server.route(
      '/catalog/movie/top.json',
      FakeResponse.json({'metas': []}, delay: const Duration(seconds: 10)),
    );
    final sw = Stopwatch()..start();
    await expectLater(
      client().catalog(manifest, 'movie', 'top'),
      throwsA(
        isA<TimeoutException>().having(
          (e) => (e as AddonException).message,
          'message',
          contains('Délai dépassé'),
        ),
      ),
    );
    sw.stop();
    expect(sw.elapsed, greaterThan(const Duration(milliseconds: 7500)));
    expect(sw.elapsed, lessThan(const Duration(seconds: 9)));
  });

  test('timeout : nouvelle tentative puis échec (2 appels)', () async {
    final f = _Scripted([TimeoutException('a'), TimeoutException('b')]);
    final c = AddonClient(f, allowPrivate: true, retryDelay: Duration.zero);
    await expectLater(
      c.catalog(manifest, 'movie', 'top'),
      throwsA(isA<TimeoutException>()),
    );
    expect(f.urls, hasLength(2));
  });

  test('500 puis 200 : succès grâce à la nouvelle tentative', () async {
    final f = _Scripted([
      _ok({}, 500),
      _ok({
        'metas': [
          {'id': 'tt1', 'name': 'F'},
        ],
      }),
    ]);
    final c = AddonClient(f, allowPrivate: true, retryDelay: Duration.zero);
    expect(await c.catalog(manifest, 'movie', 'top'), hasLength(1));
    expect(f.urls, hasLength(2));
  });

  test('500 puis 500 : erreur après une seule nouvelle tentative', () async {
    final f = _Scripted([_ok({}, 500), _ok({}, 503)]);
    final c = AddonClient(f, allowPrivate: true, retryDelay: Duration.zero);
    await expectLater(
      c.catalog(manifest, 'movie', 'top'),
      throwsA(
        isA<AddonException>().having(
          (e) => e.message,
          'message',
          contains('HTTP 503'),
        ),
      ),
    );
    expect(f.urls, hasLength(2));
  });

  test('4xx : jamais de nouvelle tentative', () async {
    final f = _Scripted([
      _ok({}, 403),
      _ok({'metas': []}),
    ]);
    final c = AddonClient(f, allowPrivate: true, retryDelay: Duration.zero);
    await expectLater(
      c.catalog(manifest, 'movie', 'top'),
      throwsA(isA<AddonException>()),
    );
    expect(f.urls, hasLength(1));
  });

  test(
    'socket : « Addon injoignable » ; jamais d\'URL dans le message',
    () async {
      final f = _Scripted([const SocketException('boom')]);
      final c = AddonClient(f, allowPrivate: true);
      await expectLater(
        c.fetchManifest(Uri.parse('https://addon.example/TOKEN/manifest.json')),
        throwsA(
          isA<ManifestException>().having(
            (e) => e.message,
            'message',
            allOf('Addon injoignable', isNot(contains('TOKEN'))),
          ),
        ),
      );
    },
  );

  test('JSON de plus de 256 Ko décodé (isolate)', () async {
    final big = {
      'metas': [
        for (var i = 0; i < 6000; i++)
          {'id': 'tt$i', 'name': 'Titre numéro $i ' * 3},
      ],
    };
    final body = utf8.encode(jsonEncode(big));
    expect(body.length, greaterThan(AddonClient.isolateThreshold));
    final f = _Scripted([FetchResponse(status: 200, body: body)]);
    final r = await AddonClient(
      f,
      allowPrivate: true,
    ).catalog(manifest, 'movie', 'top');
    expect(r, hasLength(6000));
  });

  test('JSON invalide : message clair', () async {
    server.route(
      '/catalog/movie/top.json',
      FakeResponse.raw(utf8.encode('<html>'), contentType: 'text/html'),
    );
    await expectLater(
      client().catalog(manifest, 'movie', 'top'),
      throwsA(isA<AddonException>()),
    );
  });

  group('garde d\'URL', () {
    test('URL initiale privée refusée sans allowPrivate', () async {
      final f = _Scripted([]);
      final c = AddonClient(f);
      await expectLater(
        c.fetchManifest(Uri.parse('http://192.168.1.2/manifest.json')),
        throwsA(isA<ManifestException>()),
      );
      expect(f.urls, isEmpty);
    });

    test('chaque saut de redirection est contrôlé', () async {
      server.route(
        '/manifest.json',
        FakeResponse.raw(
          const [],
          status: 302,
          headers: {'location': 'http://10.0.0.5/manifest.json'},
        ),
      );
      final fetcher = IoHttpFetcher(redirectGuard: (u) => UrlGuard.check(u));
      // Direct : le garde lève sur la cible de redirection.
      await expectLater(
        fetcher.get(server.baseUrl.replace(path: '/manifest.json')),
        throwsA(isA<UnsafeUrlException>()),
      );
      // Via le client : message lisible.
      await expectLater(
        AddonClient(
          fetcher,
          allowPrivate: true,
        ).fetchManifest(server.baseUrl.replace(path: '/manifest.json')),
        throwsA(
          isA<ManifestException>().having(
            (e) => e.message,
            'message',
            startsWith('Adresse refusée'),
          ),
        ),
      );
    });
  });

  group('garde par construction', () {
    test(
      'AddonClient(IoHttpFetcher()) refuse une redirection vers le privé',
      () async {
        server.route(
          '/manifest.json',
          FakeResponse.raw(
            const [],
            status: 302,
            headers: {'location': 'http://10.0.0.5/manifest.json'},
          ),
        );
        await expectLater(
          AddonClient(
            IoHttpFetcher(),
            allowPrivate: false,
          ).fetchManifest(server.baseUrl.replace(path: '/manifest.json')),
          throwsA(isA<ManifestException>()),
        );
        // Avec allowPrivate, la première URL (127.0.0.1) passe, la cible 10.x
        // aussi ; le garde par défaut est donc bien celui d'allowPrivate.
        final res = AddonClient(IoHttpFetcher(), allowPrivate: false);
        await expectLater(
          res.catalog(manifest, 'movie', 'top'),
          throwsA(isA<AddonException>()),
        );
      },
    );

    test(
      'redirection multi-sauts : le dernier saut privé est refusé',
      () async {
        server
          ..route(
            '/a',
            FakeResponse.raw(
              const [],
              status: 302,
              headers: {'location': '/b'},
            ),
          )
          ..route(
            '/b',
            FakeResponse.raw(
              const [],
              status: 302,
              headers: {'location': 'http://169.254.169.254/'},
            ),
          );
        await expectLater(
          IoHttpFetcher().get(
            server.baseUrl.replace(path: '/a'),
            guard: (u) =>
                UrlGuard.check(u, allowPrivate: u.host == '127.0.0.1'),
          ),
          throwsA(isA<UnsafeUrlException>()),
        );
      },
    );

    test(
      '5xx puis erreur socket : « Addon injoignable », pas de 3e appel',
      () async {
        final f = _Scripted([_ok({}, 502), const SocketException('x')]);
        final c = AddonClient(f, allowPrivate: true, retryDelay: Duration.zero);
        await expectLater(
          c.catalog(manifest, 'movie', 'top'),
          throwsA(
            isA<AddonException>().having(
              (e) => e.message,
              'message',
              'Addon injoignable',
            ),
          ),
        );
        expect(f.urls, hasLength(2));
      },
    );

    test('JSON invalide de plus de 256 Ko : erreur lisible', () async {
      final f = _Scripted([
        FetchResponse(
          status: 200,
          body: utf8.encode('{"metas": [${'1,' * 200000}'),
        ),
      ]);
      await expectLater(
        AddonClient(f, allowPrivate: true).catalog(manifest, 'movie', 'top'),
        throwsA(isA<AddonException>()),
      );
    });
  });
}
