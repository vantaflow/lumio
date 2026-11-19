import 'dart:io';

import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

String fx(String name) =>
    File('test/fixtures/addon_catalog/$name').readAsStringSync();

void main() {
  group('liste', () {
    test('films et séries : 10 cartes, total et pages', () {
      final p = AddonCatalogParser.parseList(fx('list_movies_tv.html'));
      expect(p.entries, hasLength(10));
      expect(p.total, 472);
      expect(p.totalPages, greaterThan(40));
      final e = p.entries.first;
      expect(e.slug, 'comet');
      expect(e.name, isNotEmpty);
      expect(e.description, isNotNull);
      expect(e.stars, greaterThan(0));
      expect(e.version, isNotNull);
      expect(e.logo?.scheme, anyOf('http', 'https'));
    });

    test('sous-titres : slugs attendus, entités décodées', () {
      final p = AddonCatalogParser.parseList(fx('list_subtitles.html'));
      expect(p.entries.map((e) => e.slug), contains('opensubtitles-pro'));
      expect(p.total, 158);
      for (final e in p.entries) {
        expect(e.name, isNot(contains('&amp;')));
        expect(e.name, isNot(contains('<')));
        expect(e.slug, isNot(contains('/')));
      }
    });

    test('page 2 : autres fiches, pas de doublon', () {
      final a = AddonCatalogParser.parseList(fx('list_subtitles.html'));
      final b = AddonCatalogParser.parseList(fx('list_page2.html'));
      expect(b.entries, hasLength(10));
      final slugs = {...a.entries.map((e) => e.slug)};
      expect(b.entries.where((e) => slugs.contains(e.slug)), isEmpty);
    });

    test('0 résultat légitime : liste vide sans erreur', () {
      final p = AddonCatalogParser.parseList(
        '<p class="x">0<!-- --> results</p><div></div>',
      );
      expect(p.entries, isEmpty);
      expect(p.total, 0);
    });

    test(
      'page changée (cartes absentes mais résultats annoncés) : erreur typée',
      () {
        expect(
          () => AddonCatalogParser.parseList(
            '<p class="x">12<!-- --> results</p><div>nouvelle mise en page</div>',
          ),
          throwsA(isA<CatalogParseException>()),
        );
      },
    );

    test('page sans aucun marqueur connu : erreur typée', () {
      expect(
        () => AddonCatalogParser.parseList('<html>Erreur 502</html>'),
        throwsA(isA<CatalogParseException>()),
      );
      expect(
        () => AddonCatalogParser.parseList(''),
        throwsA(isA<CatalogParseException>()),
      );
    });

    test('carte tronquée : ignorée, les autres restent', () {
      final p = AddonCatalogParser.parseList(
        '<p>2<!-- --> results</p>'
        '<a class="block" href="/addons/ok"><h3 class="a">Ok</h3><p class="b">d</p></a>'
        '<a class="block" href="/addons/"><h3>Vide</h3></a>',
      );
      expect(p.entries.map((e) => e.slug), ['ok']);
    });

    test(
      'contenu diffusé après coup (template/hidden) : nom et description',
      () {
        final p = AddonCatalogParser.parseList(fx('list_page2.html'));
        final c = p.entries.firstWhere((e) => e.slug == 'cncverse-bridge');
        expect(c.name, 'CNCVerse Bridge');
        expect(c.description, contains('Cloudstream'));
      },
    );

    test('logo non http(s) écarté', () {
      final p = AddonCatalogParser.parseList(
        '<p>1<!-- --> results</p><a class="block" href="/addons/x">'
        '<img src="javascript:alert(1)"/><h3>X</h3></a>',
      );
      expect(p.entries.single.logo, isNull);
    });
  });

  group('fiche', () {
    test('torrentio : deux instances, configurable, lien configure', () {
      final d = AddonCatalogParser.parseDetail(
        fx('fiche_torrentio.html'),
        'torrentio',
      );
      expect(d.name, 'Torrentio');
      expect(d.description, contains('torrent'));
      expect(d.instances, hasLength(2));
      final i = d.instances.first;
      expect(
        i.manifestUrl.toString(),
        'https://torrentio.strem.fun/manifest.json',
      );
      expect(i.configurable, isTrue);
      expect(i.configurationRequired, isFalse);
      expect(
        i.configureUrl.toString(),
        'https://torrentio.strem.fun/configure',
      );
      expect(i.domain, 'torrentio.strem.fun');
      expect(d.installable, isTrue);
    });

    test('opensubtitles pro : configuration requise', () {
      final d = AddonCatalogParser.parseDetail(
        fx('fiche_opensubtitles.html'),
        'opensubtitles-pro',
      );
      expect(d.instances, hasLength(1));
      expect(d.instances.single.configurationRequired, isTrue);
      expect(d.installable, isFalse);
      expect(d.instances.single.configureUrl, isNotNull);
    });

    test('aiostreams : 9 instances distinctes', () {
      final d = AddonCatalogParser.parseDetail(
        fx('fiche_aiostreams.html'),
        'aiostreams',
      );
      expect(d.instances.length, greaterThanOrEqualTo(8));
      expect(
        d.instances.map((i) => i.manifestUrl.toString()).toSet().length,
        d.instances.length,
      );
    });

    test('fiche sans URL de manifest : erreur typée', () {
      expect(
        () => AddonCatalogParser.parseDetail('<html><h1>x</h1></html>', 'x'),
        throwsA(isA<CatalogParseException>()),
      );
    });

    test('URL non http(s) ou hôte vide ignorées', () {
      expect(
        () => AddonCatalogParser.parseDetail(
          r'{\"manifestUrl\":\"javascript:alert(1)\"}',
          'x',
        ),
        throwsA(isA<CatalogParseException>()),
      );
    });

    test('sans tableau d\'instances : repli sur les manifestUrl de la page', () {
      final d = AddonCatalogParser.parseDetail(
        r'<meta property="og:title" content="Z"/>{\"manifestUrl\":\"https://z.example/manifest.json\"}',
        'z',
      );
      expect(d.instances.single.configurable, isFalse);
      expect(d.name, 'Z');
    });
  });

  group('collection officielle', () {
    test('entrées avec une instance et capacités', () {
      final p = AddonCatalogParser.parseCollection(fx('addonscollection.json'));
      expect(p.entries, hasLength(12));
      final e = p.entries.firstWhere((e) => e.name == 'Anime Kitsu');
      expect(e.instances.single.manifestUrl.host, 'anime-kitsu.strem.fun');
      expect(e.instances.single.configurable, isFalse);
      final cfg = p.entries.firstWhere((e) => e.name == 'Cast Search');
      expect(cfg.instances.single.configurable, isTrue);
      expect(cfg.types, isNotEmpty);
    });

    test('JSON invalide : erreur typée', () {
      expect(
        () => AddonCatalogParser.parseCollection('<html>'),
        throwsA(isA<CatalogParseException>()),
      );
      expect(
        () => AddonCatalogParser.parseCollection('{"a":1}'),
        throwsA(isA<CatalogParseException>()),
      );
    });
  });

  test('sérialisation aller-retour', () {
    final p = AddonCatalogParser.parseList(fx('list_subtitles.html'));
    final back = CatalogPage.fromJson(p.toJson());
    expect(back.entries.length, p.entries.length);
    expect(back.entries.first.slug, p.entries.first.slug);
    expect(back.total, p.total);
    final d = AddonCatalogParser.parseDetail(fx('fiche_torrentio.html'), 't');
    final bd = CatalogDetail.fromJson(d.toJson());
    expect(bd.instances.length, 2);
    expect(bd.instances.first.configurable, isTrue);
  });
}
