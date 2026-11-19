import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio/features/addons/add_addon_screen.dart';
import 'package:lumio/providers.dart';
import 'package:lumio_core/lumio_core.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'support/app_harness.dart';
import 'support/fake_addon_fetcher.dart';
import 'support/fake_catalog.dart';

const _alpha = 'https://alpha.example.com/manifest.json';
const _beta1 = 'https://beta-one.example.org/manifest.json';
const _beta2 = 'https://beta-two.example.net/manifest.json';
const _cfg = 'https://cfg.example.com/manifest.json';

const _cards = [
  ('alpha', 'Alpha Addon', 'Catalogue alpha', 120, '1.0.0'),
  ('beta', 'Beta Addon', 'Plusieurs instances', 90, '2.0.0'),
  ('cfg', 'Cfg Addon', 'Demande une configuration', 70, '3.0.0'),
];

Map<String, List<(String, bool, bool)>> _details() => {
  'alpha': [(_alpha, false, false)],
  'beta': [(_beta1, false, false), (_beta2, true, true)],
  'cfg': [(_cfg, true, true)],
};

Override _repo(Map<String, Map<String, Object?>> manifests) =>
    addonRepositoryProvider.overrideWith(
      (ref) => AddonRepository(
        ref.watch(appDatabaseProvider),
        MemorySecretStore(),
        clientFactory: ({required allowPrivate}) => AddonClient(
          FakeAddonFetcher(manifests),
          allowPrivate: allowPrivate,
          retries: 0,
        ),
      ),
    );

/// Écran ouvert depuis une page d'accueil factice ; `result` reçoit le retour.
class _Launcher extends StatelessWidget {
  const _Launcher(this.result, {this.initialUrl});
  final ValueNotifier<bool?> result;
  final String? initialUrl;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () async => result.value = await showAddAddonScreen(
          context,
          initialUrl: initialUrl,
        ),
        child: const Text('OUVRIR'),
      ),
    ),
  );
}

Future<void> _open(AppHarness h, WidgetTester t) async {
  await t.tap(find.text('OUVRIR'));
  await h.settle();
}

void main() {
  testWidgets('catalogue : cartes, badge Installé, onglets', (t) async {
    final site = FakeCatalogSite(cards: _cards, details: _details());
    final h = AppHarness(t, size: const Size(1920, 1080));
    final result = ValueNotifier<bool?>(null);
    await h.pump(
      _Launcher(result),
      extra: [
        catalogOverride(site),
        addonsProvider.overrideWith(() => FakeAddonsController()),
      ],
    );
    await _open(h, t);

    expect(find.text('Ajouter un addon'), findsOneWidget);
    for (final n in ['Catalogue', 'Par lien', 'Depuis le téléphone']) {
      expect(find.text(n), findsOneWidget);
    }
    for (final n in [
      'Populaires',
      'Films et séries',
      'Torrents',
      'Débrideurs',
    ]) {
      expect(find.text(n), findsOneWidget);
    }
    expect(find.text('Alpha Addon'), findsOneWidget);
    expect(find.text('Catalogue alpha'), findsOneWidget);
    expect(find.text('★ 120 · v1.0.0'), findsOneWidget);
    expect(find.text('Installé'), findsNothing);
    // Une seule requête de liste, sans filtre de catégorie, User-Agent propre.
    expect(site.requests, hasLength(1));
    expect(
      site.requests.single.queryParametersAll.containsKey('categories'),
      isFalse,
    );
    await h.close();
  });

  testWidgets('puce de catégorie : nouvelle requête filtrée', (t) async {
    final site = FakeCatalogSite(cards: _cards, details: _details());
    final h = AppHarness(t, size: const Size(1920, 1080));
    await h.pump(
      _Launcher(ValueNotifier(null)),
      extra: [catalogOverride(site)],
    );
    await _open(h, t);
    await t.tap(find.byKey(const ValueKey('chip:movies')));
    await h.settle();
    expect(site.requests.last.queryParametersAll['categories'], [
      'movies',
      'tv shows',
    ]);
    await t.tap(find.byKey(const ValueKey('chip:torrents')));
    await h.settle();
    expect(site.requests.last.queryParametersAll['categories'], ['torrents']);
    await h.close();
  });

  testWidgets('« Plus… » : catégories supplémentaires', (t) async {
    final site = FakeCatalogSite(cards: _cards, details: _details());
    final h = AppHarness(t, size: const Size(1920, 1080));
    await h.pump(
      _Launcher(ValueNotifier(null)),
      extra: [catalogOverride(site)],
    );
    await _open(h, t);
    await t.ensureVisible(find.byKey(const ValueKey('chip:more')));
    await t.tap(find.byKey(const ValueKey('chip:more')));
    await h.settle();
    await t.tap(find.text('Usenet'));
    await h.settle();
    expect(site.requests.last.queryParametersAll['categories'], ['usenet']);
    await h.close();
  });

  testWidgets('voir plus : page suivante ajoutée sans doublon', (t) async {
    final many = [
      for (var i = 0; i < 12; i++) ('a$i', 'Addon $i', 'd$i', 100 - i, '1.0'),
    ];
    final site = FakeCatalogSite(cards: many);
    final h = AppHarness(t, size: const Size(1920, 1080));
    await h.pump(
      _Launcher(ValueNotifier(null)),
      extra: [catalogOverride(site)],
    );
    await _open(h, t);
    expect(find.text('Addon 0'), findsOneWidget);
    expect(find.text('Addon 11'), findsNothing);
    await t.ensureVisible(find.byKey(const ValueKey('catalog-more')));
    await t.tap(find.byKey(const ValueKey('catalog-more')));
    await h.settle();
    expect(site.requests.last.queryParameters['page'], '2');
    expect(find.byKey(const ValueKey('card:a11')), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-more')), findsNothing);
    await h.close();
  });

  testWidgets('badge Installé : addon installé de même nom', (t) async {
    final site = FakeCatalogSite(cards: _cards, details: _details());
    final h = AppHarness(t, size: const Size(1920, 1080));
    await h.pump(
      _Launcher(ValueNotifier(null)),
      extra: [
        catalogOverride(site),
        addonsProvider.overrideWith(() => _Installed('alpha addon')),
      ],
    );
    await _open(h, t);
    expect(find.byKey(const ValueKey('installed:alpha')), findsOneWidget);
    expect(find.byKey(const ValueKey('installed:beta')), findsNothing);
    await h.close();
  });

  testWidgets('installer depuis le catalogue : aperçu puis Installer', (
    t,
  ) async {
    final site = FakeCatalogSite(cards: _cards, details: _details());
    final h = AppHarness(t, size: const Size(1920, 1080));
    final result = ValueNotifier<bool?>(null);
    await h.pump(
      _Launcher(result),
      extra: [
        catalogOverride(site),
        _repo({_alpha: sampleManifest(id: 'alpha', name: 'Alpha Addon')}),
      ],
    );
    await _open(h, t);
    await t.tap(find.byKey(const ValueKey('card:alpha')));
    await h.settle();
    // La fiche n'est téléchargée qu'à la sélection de la carte.
    expect(site.requests.map((u) => u.path), contains('/addons/alpha'));
    // Flux « Par lien » : aperçu du manifest, rien d'installé tant qu'on
    // n'a pas validé.
    expect(find.text('APERÇU · v1.0.0'), findsOneWidget);
    expect(
      await t.runAsync(() => h.container.read(addonRepositoryProvider).list()),
      isEmpty,
    );
    await t.tap(find.byKey(const ValueKey('link-install')));
    await h.settle();
    expect(result.value, isTrue);
    final list = await t.runAsync(
      () => h.container.read(addonRepositoryProvider).list(),
    );
    expect(list, hasLength(1));
    await h.close();
  });

  testWidgets('plusieurs instances : choix du domaine', (t) async {
    final site = FakeCatalogSite(cards: _cards, details: _details());
    final h = AppHarness(t, size: const Size(1920, 1080));
    await h.pump(
      _Launcher(ValueNotifier(null)),
      extra: [
        catalogOverride(site),
        _repo({_beta1: sampleManifest(id: 'beta', name: 'Beta Addon')}),
      ],
    );
    await _open(h, t);
    await t.tap(find.byKey(const ValueKey('card:beta')));
    await h.settle();
    expect(find.text('Choisir une instance'), findsOneWidget);
    expect(find.text('beta-one.example.org'), findsOneWidget);
    expect(find.text('beta-two.example.net · à configurer'), findsOneWidget);
    await t.tap(find.text('beta-one.example.org'));
    await h.settle();
    expect(find.text('APERÇU · v1.0.0'), findsOneWidget);
    await h.close();
  });

  testWidgets(
    'configuration requise : QR vers /configure, pas d\'installation',
    (t) async {
      final site = FakeCatalogSite(cards: _cards, details: _details());
      final h = AppHarness(t, size: const Size(1920, 1080));
      await h.pump(
        _Launcher(ValueNotifier(null)),
        extra: [catalogOverride(site), _repo({})],
      );
      await _open(h, t);
      await t.tap(find.byKey(const ValueKey('card:cfg')));
      await h.settle();
      expect(find.text('À configurer sur le téléphone'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('configure-host'))).data,
        'cfg.example.com/configure',
      );
      expect(find.byKey(const ValueKey('link-install')), findsNothing);
      expect(
        await t.runAsync(
          () => h.container.read(addonRepositoryProvider).list(),
        ),
        isEmpty,
      );
      await h.close();
    },
  );

  testWidgets(
    'instance configurable mais pas obligatoire : installation directe',
    (t) async {
      final site = FakeCatalogSite(
        cards: [_cards.first],
        details: {
          'alpha': [(_alpha, true, false)],
        },
      );
      final h = AppHarness(t, size: const Size(1920, 1080));
      await h.pump(
        _Launcher(ValueNotifier(null)),
        extra: [
          catalogOverride(site),
          _repo({_alpha: sampleManifest(id: 'alpha', name: 'Alpha Addon')}),
        ],
      );
      await _open(h, t);
      await t.tap(find.byKey(const ValueKey('card:alpha')));
      await h.settle();
      expect(find.byKey(const ValueKey('link-install')), findsOneWidget);
      await h.close();
    },
  );

  testWidgets('fiche illisible : message, pas de crash', (t) async {
    final site = FakeCatalogSite(cards: _cards, details: {});
    final h = AppHarness(t, size: const Size(1920, 1080));
    await h.pump(
      _Launcher(ValueNotifier(null)),
      extra: [catalogOverride(site)],
    );
    await _open(h, t);
    await t.tap(find.byKey(const ValueKey('card:alpha')));
    await h.settle();
    expect(
      find.text('Impossible de lire la fiche de cet addon.'),
      findsOneWidget,
    );
    expect(find.text('Alpha Addon'), findsOneWidget);
    await h.close();
  });

  testWidgets('site en panne : collection officielle et bandeau', (t) async {
    final site = FakeCatalogSite(
      siteDown: true,
      collectionJson:
          '[{"transportUrl":"https://c.example.com/manifest.json","manifest":{"id":"c","version":"1","name":"Collection Addon","resources":["subtitles"],"types":["movie"]}}]',
    );
    final h = AppHarness(t, size: const Size(1920, 1080));
    await h.pump(
      _Launcher(ValueNotifier(null)),
      extra: [catalogOverride(site)],
    );
    await _open(h, t);
    expect(find.text('Collection Addon'), findsOneWidget);
    // Libellé = ressources réelles : un addon de sous-titres n'est pas
    // « Films · Séries ».
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('card:c')),
        matching: find.text('Sous-titres'),
      ),
      findsOneWidget,
    );
    expect(find.text('Films · Séries'), findsNothing);
    expect(find.byKey(const ValueKey('catalog-note')), findsOneWidget);
    await h.close();
  });

  testWidgets('tout est injoignable : erreur et Réessayer', (t) async {
    final site = FakeCatalogSite(offline: true);
    final h = AppHarness(t, size: const Size(1920, 1080));
    await h.pump(
      _Launcher(ValueNotifier(null)),
      extra: [catalogOverride(site)],
    );
    await _open(h, t);
    expect(find.byKey(const ValueKey('catalog-error')), findsOneWidget);
    site
      ..offline = false
      ..cards = _cards;
    await t.tap(find.byKey(const ValueKey('catalog-retry')));
    await h.settle();
    expect(find.text('Alpha Addon'), findsOneWidget);
    await h.close();
  });

  testWidgets('actualiser : ignore le cache frais', (t) async {
    final site = FakeCatalogSite(cards: _cards);
    final h = AppHarness(t, size: const Size(1920, 1080));
    await h.pump(
      _Launcher(ValueNotifier(null)),
      extra: [catalogOverride(site)],
    );
    await _open(h, t);
    expect(site.requests, hasLength(1));
    await t.ensureVisible(find.byKey(const ValueKey('catalog-refresh')));
    await t.tap(find.byKey(const ValueKey('catalog-refresh')));
    await h.settle();
    expect(site.requests, hasLength(2));
    await h.close();
  });

  testWidgets('lien préchargé : ouvre « Par lien » ; téléphone : emplacement', (
    t,
  ) async {
    final site = FakeCatalogSite(cards: _cards);
    final h = AppHarness(t, size: const Size(1920, 1080));
    await h.pump(
      _Launcher(ValueNotifier(null), initialUrl: _alpha),
      extra: [
        catalogOverride(site),
        _repo({_alpha: sampleManifest(id: 'alpha', name: 'Alpha Addon')}),
      ],
    );
    await _open(h, t);
    expect(find.text('APERÇU · v1.0.0'), findsOneWidget);
    // Le catalogue n'est pas chargé tant qu'on ne l'ouvre pas.
    expect(site.requests, isEmpty);
    await t.tap(find.byKey(const ValueKey('addtab:phone')));
    await h.settle();
    expect(find.byKey(const ValueKey('addtab:phone-body')), findsOneWidget);
    expect(find.text('Bientôt disponible'), findsOneWidget);
    await h.close();
  });
}

class _Installed extends AddonsController {
  _Installed(this.name);
  final String name;

  @override
  Future<List<InstalledAddon>> build() async => [
    InstalledAddon(
      id: 'i1',
      manifest: AddonManifest(
        id: 'i1',
        version: '1',
        name: name,
        types: const ['movie'],
        resources: const [AddonResource('catalog')],
        catalogs: const [],
        transportUrl: Uri.parse('https://i1.example.com/manifest.json'),
      ),
      position: 0,
      enabled: true,
    ),
  ];
}
