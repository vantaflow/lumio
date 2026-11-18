import 'package:lumio_core/lumio_core.dart';
import 'package:lumio_core/testing.dart';
import 'package:test/test.dart';

AddonManifest _addon(FakeAddonServer s, String prefix, {bool stream = true}) =>
    AddonManifest(
      id: prefix.substring(1),
      version: '1.0.0',
      name: prefix,
      types: const ['movie'],
      resources: [AddonResource(stream ? 'stream' : 'meta')],
      catalogs: const [],
      transportUrl: s.baseUrl.replace(path: '$prefix/manifest.json'),
    );

void main() {
  late FakeAddonServer server;
  setUp(() async => server = await FakeAddonServer.start());
  tearDown(() => server.close());

  StreamService service() => StreamService(
    AddonClient(IoHttpFetcher(), allowPrivate: true, retryDelay: Duration.zero),
  );

  test(
    'un groupe par addon, erreur isolée, addon sans stream ignoré',
    () async {
      server.route(
        '/ok/stream/movie/tt1.json',
        FakeResponse.json({
          'streams': [
            {
              'title': 'Sintel 1080p\n👤 10 💾 1.4 GB',
              'url': 'https://cdn.example.org/s.mkv',
            },
            {'externalUrl': 'https://x.example.org'},
          ],
        }),
      );
      server.route(
        '/bad/stream/movie/tt1.json',
        FakeResponse.json({}, status: 500),
      );
      server.route(
        '/empty/stream/movie/tt1.json',
        FakeResponse.json({'streams': []}),
      );
      final groups = await service()
          .load(
            [
              _addon(server, '/ok'),
              _addon(server, '/bad'),
              _addon(server, '/empty'),
              _addon(server, '/meta', stream: false),
            ],
            'movie',
            'tt1',
          )
          .toList();
      expect(groups, hasLength(3));
      final by = {for (final g in groups) g.addonId: g};
      expect(by['ok']!.items, hasLength(1));
      expect(by['ok']!.items.single.sizeBytes, 1503238553);
      expect(by['bad']!.error, isNotNull);
      expect(by['empty']!.items, isEmpty);
      expect(by['empty']!.error, isNull);
    },
  );

  test('addon lent : le rapide arrive en premier', () async {
    server.route(
      '/slow/stream/movie/tt1.json',
      FakeResponse.json({
        'streams': [
          {'url': 'https://a.example.org/1'},
        ],
      }, delay: const Duration(milliseconds: 300)),
    );
    server.route(
      '/fast/stream/movie/tt1.json',
      FakeResponse.json({
        'streams': [
          {'url': 'https://a.example.org/2'},
        ],
      }),
    );
    final groups = await service()
        .load(
          [_addon(server, '/slow'), _addon(server, '/fast')],
          'movie',
          'tt1',
        )
        .toList();
    expect(groups.map((g) => g.addonId), ['fast', 'slow']);
  });

  test('aucun addon compatible : flux vide', () async {
    expect(await service().load([], 'movie', 'tt1').toList(), isEmpty);
  });

  test('404 : groupe vide sans erreur', () async {
    final groups = await service()
        .load([_addon(server, '/none')], 'movie', 'tt1')
        .toList();
    expect(groups.single.items, isEmpty);
    expect(groups.single.error, isNull);
  });
}
