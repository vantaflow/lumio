import 'dart:convert';
import 'dart:io';

import 'package:lumio_core/lumio_core.dart';
import 'package:lumio_core/testing.dart';
import 'package:test/test.dart';

AddonManifest _addon(
  FakeAddonServer s,
  String prefix,
  String id, {
  List<CatalogDecl>? catalogs,
}) => AddonManifest(
  id: id,
  version: '1.0.0',
  name: id,
  types: const ['movie'],
  resources: const [AddonResource('catalog')],
  catalogs:
      catalogs ?? const [CatalogDecl(type: 'movie', id: 'top', name: 'Top')],
  transportUrl: s.baseUrl.replace(path: '$prefix/manifest.json'),
);

Map<String, Object> _metas(Iterable<String> ids) => {
  'metas': [
    for (final i in ids) {'id': i, 'type': 'movie', 'name': 'Film $i'},
  ],
};

AddonClient _client({Duration timeout = const Duration(seconds: 8)}) =>
    AddonClient(
      IoHttpFetcher(),
      allowPrivate: true,
      timeout: timeout,
      retryDelay: Duration.zero,
    );

void main() {
  late FakeAddonServer server;
  setUp(() async => server = await FakeAddonServer.start());
  tearDown(() => server.close());

  test('un addon en 500 donne une ligne failed sans couper le flux', () async {
    server.route(
      '/ok/catalog/movie/top.json',
      FakeResponse.json(_metas(['a'])),
    );
    server.route(
      '/ko/catalog/movie/top.json',
      FakeResponse.json({}, status: 500),
    );
    final agg = CatalogAggregator(_client(), TtlCache());
    final rows = await agg.rows([
      _addon(server, '/ok', 'ok'),
      _addon(server, '/ko', 'ko'),
    ]).toList();
    expect(rows, hasLength(2));
    final bad = rows.singleWhere((r) => r.failed);
    expect(bad.addonId, 'ko');
    expect(bad.error, isA<AddonException>());
    expect((bad.error as AddonException).message, contains('500'));
    final good = rows.singleWhere((r) => !r.failed);
    expect(good.items.map((m) => m.id), ['a']);
    expect(good.title, 'Top');
    expect(good.type, 'movie');
    expect(good.catalogId, 'top');
  });

  test('un addon lent ne retarde pas l\'autre', () async {
    server.route(
      '/slow/catalog/movie/top.json',
      FakeResponse.json(_metas(['s']), delay: const Duration(seconds: 2)),
    );
    server.route(
      '/fast/catalog/movie/top.json',
      FakeResponse.json(_metas(['f'])),
    );
    final agg = CatalogAggregator(_client(), TtlCache());
    final sw = Stopwatch()..start();
    final rows = <CatalogRow>[];
    var firstAt = Duration.zero;
    await for (final r in agg.rows([
      _addon(server, '/slow', 'slow'),
      _addon(server, '/fast', 'fast'),
    ])) {
      if (rows.isEmpty) firstAt = sw.elapsed;
      rows.add(r);
    }
    expect(rows.first.addonId, 'fast');
    expect(firstAt, lessThan(const Duration(seconds: 1)));
    expect(rows.last.addonId, 'slow');
  });

  test('un délai dépassé donne une ligne failed', () async {
    server.route(
      '/slow/catalog/movie/top.json',
      FakeResponse.json(_metas(['s']), delay: const Duration(seconds: 2)),
    );
    final agg = CatalogAggregator(
      AddonClient(
        IoHttpFetcher(),
        allowPrivate: true,
        timeout: const Duration(milliseconds: 200),
        retries: 0,
      ),
      TtlCache(),
    );
    final rows = await agg.rows([_addon(server, '/slow', 'slow')]).toList();
    expect(rows.single.failed, isTrue);
    expect(rows.single.error, isA<AddonTimeoutException>());
  });

  test('ignore les catalogues à extra obligatoire (recherche)', () async {
    server.route('/a/catalog/movie/top.json', FakeResponse.json(_metas(['a'])));
    final addon = _addon(
      server,
      '/a',
      'a',
      catalogs: const [
        CatalogDecl(type: 'movie', id: 'top', name: 'Top'),
        CatalogDecl(
          type: 'movie',
          id: 'search',
          name: 'Recherche',
          extra: [ExtraDecl('search', isRequired: true)],
        ),
        CatalogDecl(
          type: 'movie',
          id: 'genre',
          name: 'Genre',
          extra: [ExtraDecl('genre')],
        ),
      ],
    );
    server.route(
      '/a/catalog/movie/genre.json',
      FakeResponse.json(_metas(['g'])),
    );
    final rows = await CatalogAggregator(
      _client(),
      TtlCache(),
    ).rows([addon]).toList();
    expect(rows.map((r) => r.catalogId).toSet(), {'top', 'genre'});
  });

  test('page(skip) ne renvoie aucun doublon de la page 0', () async {
    server.route(
      '/a/catalog/movie/top.json',
      FakeResponse.json(_metas(['a', 'b', 'c'])),
    );
    server.route(
      '/a/catalog/movie/top/skip=100.json',
      FakeResponse.json(_metas(['c', 'd', 'e', 'e'])),
    );
    final addon = _addon(server, '/a', 'a');
    final agg = CatalogAggregator(_client(), TtlCache());
    final rows = await agg.rows([addon]).toList();
    expect(rows.single.items.map((m) => m.id), ['a', 'b', 'c']);
    final next = await agg.page(addon, addon.catalogs.first, skip: 100);
    expect(next.map((m) => m.id), ['d', 'e']);
    // Redemander la même page (réessai, reconstruction) donne le même résultat.
    final again = await agg.page(addon, addon.catalogs.first, skip: 100);
    expect(again.map((m) => m.id), ['d', 'e']);
  });

  test('page(skip) lève AddonException si l\'addon est en erreur', () async {
    final addon = _addon(server, '/a', 'a');
    final agg = CatalogAggregator(_client(), TtlCache());
    expect(
      agg.page(addon, addon.catalogs.first, skip: 100),
      throwsA(isA<AddonException>()),
    );
  });

  test('le cache évite le réseau dans le TTL puis refait la requête', () async {
    server.route('/a/catalog/movie/top.json', FakeResponse.json(_metas(['a'])));
    var now = DateTime(2026, 1, 1, 12);
    final cache = TtlCache(ttl: const Duration(minutes: 30), now: () => now);
    final agg = CatalogAggregator(_client(), cache);
    final addon = _addon(server, '/a', 'a');

    expect((await agg.rows([addon]).toList()).single.items, hasLength(1));
    // Le serveur ne répond plus : seule la copie en cache peut servir.
    server.route(
      '/a/catalog/movie/top.json',
      FakeResponse.json({}, status: 500),
    );
    final cached = await agg.rows([addon]).toList();
    expect(cached.single.failed, isFalse);
    expect(cached.single.items.map((m) => m.id), ['a']);

    now = now.add(const Duration(minutes: 31));
    final after = await agg.rows([addon]).toList();
    expect(after.single.failed, isTrue);
  });

  test('au plus 4 requêtes simultanées (pic mesuré)', () async {
    final catalogs = [
      for (var i = 0; i < 8; i++)
        CatalogDecl(type: 'movie', id: 'c$i', name: 'C$i'),
    ];
    var current = 0, peak = 0;
    final raw = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => raw.close(force: true));
    raw.listen((req) async {
      peak = ++current > peak ? current : peak;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      current--;
      req.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(_metas([req.uri.pathSegments.last])));
      await req.response.close();
    });
    final addon = AddonManifest(
      id: 'a',
      version: '1.0.0',
      name: 'a',
      types: const ['movie'],
      resources: const [AddonResource('catalog')],
      catalogs: catalogs,
      transportUrl: Uri.parse('http://127.0.0.1:${raw.port}/manifest.json'),
    );
    final rows = await CatalogAggregator(
      _client(),
      TtlCache(),
    ).rows([addon]).toList();
    expect(rows, hasLength(8));
    expect(rows.every((r) => !r.failed), isTrue);
    expect(peak, 4);
  });
}
