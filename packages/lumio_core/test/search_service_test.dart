import 'package:lumio_core/lumio_core.dart';
import 'package:lumio_core/testing.dart';
import 'package:test/test.dart';

AddonManifest _addon(
  FakeAddonServer s,
  String prefix, {
  bool search = true,
  List<CatalogDecl>? catalogs,
}) => AddonManifest(
  id: prefix,
  version: '1.0.0',
  name: prefix,
  types: const ['movie'],
  resources: const [AddonResource('catalog')],
  catalogs:
      catalogs ??
      [
        CatalogDecl(
          type: 'movie',
          id: 'top',
          name: 'Top',
          extra: [if (search) const ExtraDecl('search')],
        ),
      ],
  transportUrl: s.baseUrl.replace(path: '$prefix/manifest.json'),
);

FakeResponse _metas(
  List<(String, String)> items, {
  Duration delay = Duration.zero,
}) => FakeResponse.json({
  'metas': [
    for (final i in items) {'id': i.$1, 'type': 'movie', 'name': i.$2},
  ],
}, delay: delay);

String _path(String prefix, String q) =>
    '$prefix/catalog/movie/top/search=${Uri.encodeComponent(q)}.json';

void main() {
  late FakeAddonServer server;
  setUp(() async => server = await FakeAddonServer.start());
  tearDown(() => server.close());

  final used = <String>[];
  setUp(used.clear);

  SearchService svc({Duration? timeout}) => SearchService((a) {
    used.add(a.id);
    return AddonClient(
      IoHttpFetcher(),
      allowPrivate: true,
      retryDelay: Duration.zero,
      retries: 0,
    );
  }, timeout: timeout ?? const Duration(seconds: 8));

  test('deux addons, même id : un seul résultat (le premier addon)', () async {
    server.route(_path('/a', 'matrix'), _metas([('tt1', 'Matrix A')]));
    server.route(
      _path('/b', 'matrix'),
      _metas([('tt1', 'Matrix B'), ('tt2', 'Matrix Reloaded')]),
    );
    final out = await svc().search([
      _addon(server, '/a'),
      _addon(server, '/b'),
    ], 'matrix').toList();
    final last = out.last;
    expect(last.map((m) => m.id), ['tt1', 'tt2']);
    expect(last.first.name, 'Matrix A');
  });

  test('requête vide ou blanche : aucun appel, liste vide', () async {
    final a = _addon(server, '/a');
    for (final q in ['', '   ']) {
      final out = await svc().search([a], q).toList();
      expect(out, [isEmpty]);
    }
    expect(used, isEmpty);
  });

  test('seuls les catalogues déclarant search sont interrogés', () async {
    server.route(_path('/a', 'x'), _metas([('1', 'X')]));
    final out = await svc().search([
      _addon(server, '/a'),
      _addon(server, '/n', search: false),
    ], 'x').toList();
    expect(out.last, hasLength(1));
    expect(used, ['/a']);
  });

  test('un addon en échec est ignoré', () async {
    server.route(
      '/ko/catalog/movie/top/search=x.json',
      FakeResponse.json({}, status: 500),
    );
    server.route(_path('/ok', 'x'), _metas([('1', 'X')]));
    final out = await svc().search([
      _addon(server, '/ko'),
      _addon(server, '/ok'),
    ], 'x').toList();
    expect(out.last.map((m) => m.id), ['1']);
  });

  test('addon lent : délai par addon, les autres arrivent', () async {
    server.route(
      _path('/slow', 'x'),
      _metas([('s', 'X lent')], delay: const Duration(seconds: 2)),
    );
    server.route(_path('/fast', 'x'), _metas([('f', 'X')]));
    final sw = Stopwatch()..start();
    final out = await svc(
      timeout: const Duration(milliseconds: 300),
    ).search([_addon(server, '/slow'), _addon(server, '/fast')], 'x').toList();
    expect(sw.elapsed, lessThan(const Duration(seconds: 1)));
    expect(out.last.map((m) => m.id), ['f']);
  });

  test('pertinence : exact > préfixe > contient, accents ignorés', () async {
    server.route(
      _path('/a', 'élève'),
      _metas([('1', 'Le grand eleve'), ('2', 'Élève libre'), ('3', 'ELEVE')]),
    );
    final out = await svc().search([_addon(server, '/a')], 'élève').toList();
    expect(out.last.map((m) => m.id), ['3', '2', '1']);
  });

  test(
    'émission progressive : chaque émission est la fusion courante',
    () async {
      server.route(_path('/a', 'x'), _metas([('1', 'X')]));
      server.route(
        _path('/b', 'x'),
        _metas([('2', 'X2')], delay: const Duration(milliseconds: 200)),
      );
      final out = await svc().search([
        _addon(server, '/a'),
        _addon(server, '/b'),
      ], 'x').toList();
      expect(out, hasLength(2));
      expect(out.first.map((m) => m.id), ['1']);
      expect(out.last.map((m) => m.id), ['1', '2']);
    },
  );

  test('clientFor qui lève : addon ignoré, le flux se ferme', () async {
    server.route(_path('/ok', 'x'), _metas([('1', 'X')]));
    final bad = SearchService(
      (a) => a.id == '/ko'
          ? throw StateError('boom')
          : AddonClient(IoHttpFetcher(), allowPrivate: true),
    );
    final out = await bad.search([
      _addon(server, '/ko'),
      _addon(server, '/ok'),
    ], 'x').toList();
    expect(out.last.map((m) => m.id), ['1']);
  });
}
