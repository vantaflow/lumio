import 'package:lumio_core/lumio_core.dart';
import 'package:lumio_core/testing.dart';
import 'package:test/test.dart';

AddonManifest _addon(
  FakeAddonServer s,
  String prefix, {
  List<String>? idPrefixes,
  bool meta = true,
}) => AddonManifest(
  id: prefix.substring(1),
  version: '1.0.0',
  name: prefix,
  types: const ['movie', 'series'],
  resources: [AddonResource(meta ? 'meta' : 'stream')],
  catalogs: const [],
  idPrefixes: idPrefixes,
  transportUrl: s.baseUrl.replace(path: '$prefix/manifest.json'),
);

const _movie = MetaPreview(
  id: 'tt1',
  type: 'movie',
  name: 'Aperçu',
  sourceAddonId: 'cat',
  releaseInfo: '2020',
);

MetaService _service({Duration budget = const Duration(seconds: 8)}) =>
    MetaService(
      AddonClient(
        IoHttpFetcher(),
        allowPrivate: true,
        retryDelay: Duration.zero,
      ),
      budget: budget,
    );

void main() {
  late FakeAddonServer server;
  setUp(() async => server = await FakeAddonServer.start());
  tearDown(() => server.close());

  test('fusion : la description vient du second addon', () async {
    server.route(
      '/a/meta/movie/tt1.json',
      FakeResponse.json({
        'meta': {
          'id': 'tt1',
          'name': 'A',
          'genres': ['Drame'],
        },
      }),
    );
    server.route(
      '/b/meta/movie/tt1.json',
      FakeResponse.json({
        'meta': {
          'id': 'tt1',
          'name': 'B',
          'description': 'Synopsis B',
          'background': 'https://x.test/bg.jpg',
        },
      }),
    );
    final m = await _service().load([
      _addon(server, '/a'),
      _addon(server, '/b'),
    ], _movie);
    expect(m.name, 'A');
    expect(m.description, 'Synopsis B');
    expect(m.genres, ['Drame']);
    expect(m.background, Uri.parse('https://x.test/bg.jpg'));
    expect(m.releaseInfo, '2020');
  });

  test('aucun addon meta : fiche construite depuis le preview', () async {
    final m = await _service().load([
      _addon(server, '/a', meta: false),
    ], _movie);
    expect(m.name, 'Aperçu');
    expect(m.id, 'tt1');
    expect(m.releaseInfo, '2020');
    expect(m.description, isNull);
    expect(m.videos, isEmpty);
  });

  test('un addon en erreur ou en 404 est ignoré', () async {
    server.route('/a/meta/movie/tt1.json', FakeResponse.json({}, status: 500));
    server.route(
      '/c/meta/movie/tt1.json',
      FakeResponse.json({
        'meta': {'id': 'tt1', 'description': 'ok'},
      }),
    );
    final m = await _service().load([
      _addon(server, '/a'),
      _addon(server, '/b'),
      _addon(server, '/c'),
    ], _movie);
    expect(m.description, 'ok');
  });

  test('idPrefixes incompatible : addon non interrogé', () async {
    server.route(
      '/a/meta/movie/tt1.json',
      FakeResponse.json({
        'meta': {'id': 'tt1', 'description': 'non'},
      }),
    );
    final m = await _service().load([
      _addon(server, '/a', idPrefixes: ['kitsu:']),
    ], _movie);
    expect(m.description, isNull);
  });

  test(
    'addon lent : budget global respecté, réponses rapides gardées',
    () async {
      server.route(
        '/slow/meta/movie/tt1.json',
        FakeResponse.json({
          'meta': {'id': 'tt1', 'description': 'lent'},
        }, delay: const Duration(seconds: 3)),
      );
      server.route(
        '/fast/meta/movie/tt1.json',
        FakeResponse.json({
          'meta': {'id': 'tt1', 'name': 'Rapide'},
        }),
      );
      final sw = Stopwatch()..start();
      final m = await _service(
        budget: const Duration(milliseconds: 500),
      ).load([_addon(server, '/slow'), _addon(server, '/fast')], _movie);
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
      expect(m.name, 'Rapide');
      expect(m.description, isNull);
    },
  );

  test('série : tri saison, épisode, date ; saison 0 en dernier', () async {
    server.route(
      '/a/meta/series/tt9.json',
      FakeResponse.json({
        'meta': {
          'id': 'tt9',
          'name': 'Série',
          'videos': [
            {'id': 'tt9:0:1', 'season': 0, 'episode': 1, 'title': 'Spécial'},
            {'id': 'tt9:2:1', 'season': 2, 'episode': 1},
            {'id': 'tt9:1:2', 'season': 1, 'episode': 2, 'title': 'Deux'},
            {'id': 'tt9:1:1', 'season': 1, 'episode': 1, 'title': 'Un'},
            {
              'id': 'tt9:1:x',
              'season': 1,
              'released': '2020-05-01T00:00:00.000Z',
            },
            {'id': 'tt9:1:y', 'season': 1, 'released': 'pas une date'},
            {'season': 1, 'episode': 9},
          ],
        },
      }),
    );
    const p = MetaPreview(
      id: 'tt9',
      type: 'series',
      name: 'S',
      sourceAddonId: 'cat',
    );
    final m = await _service().load([_addon(server, '/a')], p);
    expect(m.videos.map((v) => v.id), [
      'tt9:1:1',
      'tt9:1:2',
      'tt9:1:x',
      'tt9:1:y',
      'tt9:2:1',
      'tt9:0:1',
    ]);
    expect(m.videos[2].released, DateTime.utc(2020, 5, 1));
    expect(m.videos[3].released, isNull);
    expect(m.videos[4].title, 'Épisode 1');
  });

  test('videos : premier addon non vide gagne', () async {
    server.route(
      '/a/meta/series/tt9.json',
      FakeResponse.json({
        'meta': {'id': 'tt9', 'videos': []},
      }),
    );
    server.route(
      '/b/meta/series/tt9.json',
      FakeResponse.json({
        'meta': {
          'id': 'tt9',
          'videos': [
            {'id': 'tt9:1:1', 'season': 1, 'episode': 1},
          ],
        },
      }),
    );
    const p = MetaPreview(
      id: 'tt9',
      type: 'series',
      name: 'S',
      sourceAddonId: 'cat',
    );
    final m = await _service().load([
      _addon(server, '/a'),
      _addon(server, '/b'),
    ], p);
    expect(m.videos.single.id, 'tt9:1:1');
  });
}
