import 'package:lumio_core/lumio_core.dart';
import 'package:lumio_core/testing.dart';
import 'package:test/test.dart';

AddonManifest _addon(FakeAddonServer s, String prefix, {bool subs = true}) =>
    AddonManifest(
      id: prefix.substring(1),
      version: '1.0.0',
      name: prefix,
      types: const ['movie'],
      resources: [AddonResource(subs ? 'subtitles' : 'meta')],
      catalogs: const [],
      transportUrl: s.baseUrl.replace(path: '$prefix/manifest.json'),
    );

SubtitleItem _s(String lang, String n) => SubtitleItem(
  id: n,
  url: Uri.parse('https://x.example.org/$n.srt'),
  lang: lang,
  addonId: 'a',
);

void main() {
  late FakeAddonServer server;
  setUp(() async => server = await FakeAddonServer.start());
  tearDown(() => server.close());

  SubtitleService service() => SubtitleService(
    AddonClient(IoHttpFetcher(), allowPrivate: true, retryDelay: Duration.zero),
  );

  test('agrège, normalise, dédoublonne, ignore les addons en échec', () async {
    server.route(
      '/a/subtitles/movie/tt1.json',
      FakeResponse.json({
        'subtitles': [
          {'id': '1', 'url': 'https://s.example.org/1.srt', 'lang': 'fre'},
          {'id': '2', 'url': 'ftp://s.example.org/2.srt', 'lang': 'eng'},
          {'id': '3', 'url': 'https://s.example.org/3.srt', 'lang': 'zzz'},
        ],
      }),
    );
    server.route(
      '/b/subtitles/movie/tt1.json',
      FakeResponse.json({
        'subtitles': [
          {'id': '9', 'url': 'https://s.example.org/1.srt', 'lang': 'fr'},
          {'id': '4', 'url': 'https://s.example.org/4.srt', 'lang': 'ara'},
        ],
      }),
    );
    server.route(
      '/bad/subtitles/movie/tt1.json',
      FakeResponse.json({}, status: 500),
    );
    final r = await service().load(
      [
        _addon(server, '/a'),
        _addon(server, '/b'),
        _addon(server, '/bad'),
        _addon(server, '/meta', subs: false),
      ],
      'movie',
      'tt1',
    );
    expect(r.map((e) => e.url.path), ['/1.srt', '/3.srt', '/4.srt']);
    expect(r.map((e) => e.lang), ['fr', 'zzz', 'ar']);
    expect(r.first.addonId, 'a');
  });

  test('tri : fre/fra/fr regroupés en tête pour fr, stable', () {
    final items = [
      _s('en', 'e1'),
      _s('fre', 'f1'),
      _s('ara', 'a1'),
      _s('fra', 'f2'),
      _s('de', 'd1'),
      _s('fr', 'f3'),
    ];
    final sorted = service().sortByPreference(items, ['fr']);
    expect(sorted.map((e) => e.id), ['f1', 'f2', 'f3', 'a1', 'd1', 'e1']);
  });

  test('tri : ordre des préférences respecté', () {
    final sorted = service().sortByPreference(
      [_s('en', 'e'), _s('ar', 'a'), _s('fr', 'f')],
      ['ar', 'en'],
    );
    expect(sorted.map((e) => e.id), ['a', 'e', 'f']);
  });
}
