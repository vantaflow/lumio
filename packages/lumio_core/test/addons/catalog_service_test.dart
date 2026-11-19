import 'dart:convert';
import 'dart:io';

import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

String fx(String name) =>
    File('test/fixtures/addon_catalog/$name').readAsStringSync();

/// Faux fetcher : route → réponse ou erreur ; enregistre les requêtes.
class FakeSite implements HttpFetcher {
  final Map<String, Object> routes = {};
  final List<Uri> requests = [];
  final List<Map<String, String>> headersSeen = [];
  final List<int> bytesSeen = [];
  bool offline = false;

  @override
  Future<FetchResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) async {
    guard?.call(url);
    requests.add(url);
    headersSeen.add(headers);
    bytesSeen.add(maxBytes);
    if (offline) throw const SocketException('hors ligne');
    final r = routes[url.path] ?? routes[url.toString()];
    if (r == null) return const FetchResponse(status: 404, body: []);
    if (r is FetchResponse) return r;
    return FetchResponse(status: 200, body: utf8.encode(r as String));
  }
}

void main() {
  group('collection officielle', officialTests);
  late FakeSite site;
  late MemoryCatalogCacheStore store;
  late DateTime now;
  late AddonCatalogService service;
  const q = CatalogQuery(categories: ['subtitles']);

  AddonCatalogService build() => AddonCatalogService(
    AddonCatalogSource(site, limiter: RateLimiter(minInterval: Duration.zero)),
    store,
    now: () => now,
  );

  setUp(() {
    site = FakeSite();
    store = MemoryCatalogCacheStore();
    now = DateTime.utc(2026, 11, 19, 12);
    site.routes['/addons'] = fx('list_subtitles.html');
    site.routes['/addons/torrentio'] = fx('fiche_torrentio.html');
    site.routes['/addonscollection.json'] = fx('addonscollection.json');
    service = build();
  });

  group('source', () {
    test(
      'requête : paramètres, User-Agent générique, aucune donnée perso',
      () async {
        await service.list(
          const CatalogQuery(
            categories: ['movies', 'tv shows'],
            sort: CatalogSort.newest,
            page: 3,
          ),
        );
        final u = site.requests.single;
        expect(u.host, 'stremio-addons.net');
        expect(u.queryParametersAll['categories'], ['movies', 'tv shows']);
        expect(u.queryParameters['sort'], 'new');
        expect(u.queryParameters['page'], '3');
        expect(site.headersSeen.single['user-agent'], 'Lumio');
        expect(site.headersSeen.single.keys, isNot(contains('cookie')));
      },
    );

    test('adultes : aucun paramètre de filtre 18+', () async {
      await service.list(q);
      expect(site.requests.single.toString(), isNot(contains('nsfw')));
    });

    test('garde réseau : hôte privé refusé avant toute requête', () async {
      final src = AddonCatalogSource(
        site,
        site: Uri.parse('http://192.168.1.5'),
        limiter: RateLimiter(minInterval: Duration.zero),
      );
      await expectLater(src.list(q), throwsA(isA<UnsafeUrlException>()));
      expect(site.requests, isEmpty);
    });

    test('pages de liste plafonnées à 512 Kio, fiches à 2 Mio', () async {
      await service.list(q);
      await service.detail('torrentio');
      expect(site.bytesSeen, [512 * 1024, 2 * 1024 * 1024]);
    });

    test('page pathologique sans </a> : rendue en moins de 2 s', () async {
      final body = StringBuffer('<p>14000<!-- --> results</p>');
      for (var i = 0; i < 14000; i++) {
        body.write('<a href="/addons/s$i"><h3>N</h3>');
      }
      site.routes['/addons'] = body.toString();
      final sw = Stopwatch()..start();
      final r = await build().list(q);
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
      expect(r.value.entries, isNotEmpty);
    });

    test('statut 500 : indisponible avec le statut', () async {
      site.routes['/addons'] = const FetchResponse(status: 500, body: []);
      final src = AddonCatalogSource(
        site,
        limiter: RateLimiter(minInterval: Duration.zero),
      );
      await expectLater(
        src.list(q),
        throwsA(
          isA<CatalogUnavailableException>().having((e) => e.status, 's', 500),
        ),
      );
    });
  });

  group('limiteur', () {
    test('2 requêtes par seconde au plus', () async {
      var t = DateTime.utc(2026);
      final slept = <Duration>[];
      final l = RateLimiter(
        now: () => t,
        sleep: (d) async {
          slept.add(d);
          t = t.add(d);
        },
      );
      await l.acquire();
      await l.acquire();
      await l.acquire();
      expect(slept, [
        const Duration(milliseconds: 500),
        const Duration(milliseconds: 500),
      ]);
    });

    test('appels concurrents mis en file', () async {
      var t = DateTime.utc(2026);
      var sleeps = 0;
      final l = RateLimiter(
        now: () => t,
        sleep: (d) async {
          sleeps++;
          t = t.add(d);
        },
      );
      await Future.wait([l.acquire(), l.acquire(), l.acquire()]);
      expect(sleeps, 2);
    });
  });

  group('service', () {
    test('réseau puis cache frais (24 h) sans nouvelle requête', () async {
      final a = await service.list(q);
      expect(a.origin, CatalogOrigin.network);
      now = now.add(const Duration(hours: 23));
      final b = await service.list(q);
      expect(b.origin, CatalogOrigin.cache);
      expect(b.value.entries.length, a.value.entries.length);
      expect(site.requests, hasLength(1));
    });

    test('cache périmé après 24 h : nouvelle requête', () async {
      await service.list(q);
      now = now.add(const Duration(hours: 25));
      final b = await service.list(q);
      expect(b.origin, CatalogOrigin.network);
      expect(site.requests, hasLength(2));
    });

    test('rafraîchissement manuel ignore le cache frais', () async {
      await service.list(q);
      final b = await service.list(q, refresh: true);
      expect(b.origin, CatalogOrigin.network);
      expect(site.requests, hasLength(2));
    });

    test('hors ligne : cache périmé servi, daté', () async {
      final a = await service.list(q);
      now = now.add(const Duration(days: 3));
      site.offline = true;
      final b = await service.list(q);
      expect(b.origin, CatalogOrigin.staleCache);
      expect(b.fetchedAt, a.fetchedAt);
      expect(b.value.entries, isNotEmpty);
    });

    test('hors ligne sans cache : collection officielle (repli)', () async {
      site.routes['/addons'] = const FetchResponse(status: 503, body: []);
      final r = await service.list(const CatalogQuery());
      expect(r.origin, CatalogOrigin.fallback);
      expect(r.value.entries, hasLength(12));
      expect(r.value.hasMore, isFalse);
    });

    test('collection de repli altérée : le service ne plante pas', () async {
      final list = jsonDecode(fx('addonscollection.json')) as List;
      ((list[0] as Map)['manifest'] as Map)['description'] = 42;
      site
        ..offline = false
        ..routes['/addons'] = '<html>Erreur</html>'
        ..routes['/addonscollection.json'] = jsonEncode(list);
      final r = await build().list(q);
      expect(r.origin, CatalogOrigin.fallback);
      expect(r.value.entries, isNotEmpty);
    });

    test('collection de repli : types inattendus ignorés', () async {
      site
        ..routes['/addons'] = '<html>Erreur</html>'
        ..routes['/addonscollection.json'] =
            '[{"manifest":{"name":"A",'
            '"types":{"x":1}},"transportUrl":"https://a.example/m.json"}]';
      final r = await build().list(q);
      expect(r.origin, CatalogOrigin.fallback);
    });

    test('page changée : repli sur la collection, filtrée', () async {
      site.routes['/addons'] = '<p>40<!-- --> results</p><div>autre</div>';
      final r = await service.list(const CatalogQuery(categories: ['anime']));
      expect(r.origin, CatalogOrigin.fallback);
      expect(r.value.entries.map((e) => e.name), ['Anime Kitsu']);
    });

    test(
      'catégorie sans équivalent dans la collection : tout est listé',
      () async {
        site.offline = false;
        site.routes['/addons'] = '<html>cassé</html>';
        final r = await service.list(
          const CatalogQuery(categories: ['torrents']),
        );
        expect(r.origin, CatalogOrigin.fallback);
        expect(r.value.entries, hasLength(12));
      },
    );

    test(
      'page cassée mais cache périmé : le cache prime sur le repli',
      () async {
        await service.list(q);
        now = now.add(const Duration(days: 2));
        site.routes['/addons'] = '<html>cassé</html>';
        final r = await service.list(q);
        expect(r.origin, CatalogOrigin.staleCache);
      },
    );

    test('tout est en échec : erreur typée', () async {
      site.offline = true;
      await expectLater(
        service.list(q),
        throwsA(isA<CatalogUnavailableException>()),
      );
    });

    test('page 2 sans cache ni site : pas de repli, erreur', () async {
      site.offline = true;
      await expectLater(
        service.list(q.withPage(2)),
        throwsA(isA<CatalogUnavailableException>()),
      );
    });

    test('collection mise en cache pour le prochain repli', () async {
      site.routes['/addons'] = const FetchResponse(status: 503, body: []);
      await service.list(const CatalogQuery());
      site.offline = true;
      final r = await service.list(const CatalogQuery());
      expect(r.origin, CatalogOrigin.fallback);
    });

    test('cache corrompu ignoré', () async {
      store.entries[q.key] = CachedCatalogEntry('pas du json', now);
      final r = await service.list(q);
      expect(r.origin, CatalogOrigin.network);
    });

    test('fiche : réseau, cache, hors ligne', () async {
      final a = await service.detail('torrentio');
      expect(a.origin, CatalogOrigin.network);
      expect((await service.detail('torrentio')).origin, CatalogOrigin.cache);
      now = now.add(const Duration(days: 2));
      site.offline = true;
      final c = await service.detail('torrentio');
      expect(c.origin, CatalogOrigin.staleCache);
      expect(c.value.instances, hasLength(2));
      await expectLater(
        service.detail('autre'),
        throwsA(isA<CatalogUnavailableException>()),
      );
    });

    test('fiche cassée sans cache : erreur typée de format', () async {
      site.routes['/addons/torrentio'] = '<html>rien</html>';
      await expectLater(
        service.detail('torrentio'),
        throwsA(isA<CatalogParseException>()),
      );
    });

    test('seules les pages demandées sont téléchargées', () async {
      await service.list(q);
      await service.detail('torrentio');
      expect(site.requests, hasLength(2));
    });
  });

  group('cache fichier', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('lumio-cat'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('aller-retour, clé arbitraire, fichier corrompu = absent', () async {
      final s = FileCatalogCacheStore(dir);
      final at = DateTime.utc(2026, 1, 2);
      await s.write('list|a b,c|popular|1', '{"x":1}', at);
      final e = await s.read('list|a b,c|popular|1');
      expect(e?.data, '{"x":1}');
      expect(e?.at, at);
      expect(await s.read('autre'), isNull);
      for (final f in dir.listSync().whereType<File>()) {
        f.writeAsStringSync('{{{');
      }
      expect(await s.read('list|a b,c|popular|1'), isNull);
    });

    test(
      'dossier inexistant : créé ; écriture impossible : sans erreur',
      () async {
        final s = FileCatalogCacheStore(Directory('${dir.path}/x/y'));
        await s.write('k', 'v', DateTime.utc(2026));
        expect((await s.read('k'))?.data, 'v');
      },
    );
  });
}

void officialTests() {
  late FakeSite site;
  late MemoryCatalogCacheStore store;
  late DateTime now;
  late AddonCatalogService service;

  setUp(() {
    site = FakeSite();
    store = MemoryCatalogCacheStore();
    now = DateTime.utc(2026, 11, 19, 12);
    site.routes['/addonsofficialcollection.json'] = fx(
      'addonsofficialcollection.json',
    );
    service = AddonCatalogService(
      AddonCatalogSource(
        site,
        limiter: RateLimiter(minInterval: Duration.zero),
      ),
      store,
      now: () => now,
    );
  });

  test('officiels : Cinemeta et OpenSubtitles v3, sans Local Files', () async {
    final r = await service.official();
    expect(r.origin, CatalogOrigin.network);
    expect(r.value.entries.map((e) => e.name), [
      'Cinemeta',
      'OpenSubtitles v3',
    ]);
    expect(
      site.requests.single.toString(),
      'https://api.strem.io/addonsofficialcollection.json',
    );
  });

  test('officiels : cache de 24 h puis cache périmé hors ligne', () async {
    await service.official();
    await service.official();
    expect(site.requests, hasLength(1));
    now = now.add(const Duration(hours: 30));
    site.offline = true;
    final r = await service.official();
    expect(r.origin, CatalogOrigin.staleCache);
    expect(r.value.entries, hasLength(2));
  });

  test('officiels : hors ligne sans cache = erreur', () async {
    site.offline = true;
    await expectLater(
      service.official(),
      throwsA(isA<CatalogUnavailableException>()),
    );
  });

  test('fusion : officiels en premier, doublons retirés', () async {
    final off = (await service.official()).value.entries;
    CatalogEntry e(String slug, String name) =>
        CatalogEntry(slug: slug, name: name);
    final merged = AddonCatalogService.mergeOfficial(off, [
      e('cinemeta', 'Cinemeta'),
      e('torrentio', 'Torrentio'),
      e('com.linvo.cinemeta', 'Autre nom'),
    ]);
    expect(merged.map((x) => x.name), [
      'Cinemeta',
      'OpenSubtitles v3',
      'Torrentio',
    ]);
  });
}
