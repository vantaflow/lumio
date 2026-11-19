// Rendu PNG des écrans TV à 1920x1080 pour comparer aux maquettes. Inactif
// sauf avec LUMIO_RENDER_DIR=<dossier> (sinon ignoré).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/progress_repository.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio/features/home/continue_playback.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/features/home/home_screen.dart';
import 'package:lumio/features/search/search_providers.dart';
import 'package:lumio/features/search/search_screen.dart';
import 'package:lumio/features/update/update_banner.dart';
import 'package:lumio_core/lumio_core.dart';
import 'package:lumio/features/jellyfin/jellyfin_screen.dart';
import 'package:lumio/features/local/local_screen.dart';
import 'package:lumio/features/settings/settings_screen.dart' show AboutScreen;
import 'package:lumio/features/onboarding/onboarding_flow.dart';
import 'package:lumio/features/settings/stremio_import_screen.dart';
import 'package:lumio/features/tracking/tracking_providers.dart';
import 'package:lumio/features/tracking/tracking_screen.dart';
import 'package:lumio/providers.dart';

import 'support/app_harness.dart';

final _dir = Platform.environment['LUMIO_RENDER_DIR'];

Future<void> _fonts() async {
  for (final (family, file) in const [
    ('Bricolage Grotesque', 'BricolageGrotesque-Variable.ttf'),
    ('Manrope', 'Manrope-Variable.ttf'),
  ]) {
    final loader = FontLoader(family)
      ..addFont(
        Future.value(
          ByteData.sublistView(File('assets/fonts/$file').readAsBytesSync()),
        ),
      );
    await loader.load();
  }
}

Future<void> _save(WidgetTester t, GlobalKey key, String name) async {
  await t.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  final skip = _dir == null ? 'LUMIO_RENDER_DIR non défini' : null;

  testWidgets('onboarding TV', skip: skip != null, (t) async {
    await t.runAsync(_fonts);
    final h = AppHarness(t);
    final key = GlobalKey();
    await h.pump(RepaintBoundary(key: key, child: const OnboardingFlow()));
    await _save(t, key, 'render-onboarding-1');
    await t.tap(find.byKey(const ValueKey('onboarding-next')));
    await h.settle();
    await _save(t, key, 'render-onboarding-2');
    await t.tap(find.byKey(const ValueKey('onboarding-next')));
    await h.settle();
    await _save(t, key, 'render-onboarding-3');
    await h.close();
  });

  testWidgets('lot 4 : import, dossiers, suivi', skip: skip != null, (t) async {
    await t.runAsync(_fonts);
    final h = AppHarness(t);
    final key = GlobalKey();
    await h.pump(RepaintBoundary(key: key, child: const StremioImportScreen()));
    await _save(t, key, 'r-TV32');
    await h.close();

    final h2 = AppHarness(t);
    final k2 = GlobalKey();
    await h2.pump(RepaintBoundary(key: k2, child: const LocalFoldersScreen()));
    await _save(t, k2, 'r-TV49');
    await h2.close();

    final h3 = AppHarness(t);
    final k3 = GlobalKey();
    await h3.pump(
      RepaintBoundary(key: k3, child: const TrackingScreen()),
      extra: [
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        traktCredentialsProvider.overrideWithValue((id: 'c', secret: 's')),
        trackingStatusProvider.overrideWith(
          (ref, key) async => const TrackingStatus(
            configured: true,
            connected: true,
            reauthRequired: false,
            pending: 1,
            kidAllowed: false,
          ),
        ),
      ],
    );
    await _save(t, k3, 'r-TV25');
    await h3.close();

    final h4 = AppHarness(t);
    final k4 = GlobalKey();
    await h4.pump(
      RepaintBoundary(key: k4, child: const TrackingScreen()),
      extra: [
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        traktCredentialsProvider.overrideWithValue((id: '', secret: '')),
      ],
    );
    await _save(t, k4, 'r-TV48');
    await h4.close();
    final h5 = AppHarness(t);
    final k5 = GlobalKey();
    await h5.pump(RepaintBoundary(key: k5, child: const AboutScreen()));
    await _save(t, k5, 'r-TV34');
    await h5.close();

    final h6 = AppHarness(t);
    final k6 = GlobalKey();
    await h6.pump(
      RepaintBoundary(key: k6, child: const JellyfinServersScreen()),
    );
    await _save(t, k6, 'r-TV50');
    await h6.close();
  });

  testWidgets('lot 5 : accueil', skip: skip != null, (t) async {
    await t.runAsync(_fonts);

    Future<void> shot(
      String name, {
      List<Override> extra = const [],
      Profile? profile,
      Widget Function(Widget home)? wrap,
      double extraHeight = 0,
    }) async {
      final h = AppHarness(t, size: Size(1920, 1080 + extraHeight));
      final key = GlobalKey();
      Widget home = const HomeScreen();
      if (wrap != null) home = wrap(home);
      await h.pump(
        RepaintBoundary(key: key, child: home),
        extra: extra,
      );
      if (profile != null) {
        h.container.read(currentProfileProvider.notifier).select(profile);
        await h.settle();
      }
      await _save(t, key, name);
      await h.close();
    }

    AddonManifest manifest(String id, String name, String cat) => AddonManifest(
      id: id,
      version: '1.0.0',
      name: name,
      types: const ['movie'],
      resources: const [AddonResource('catalog')],
      catalogs: [CatalogDecl(type: 'movie', id: cat, name: cat)],
      transportUrl: Uri.parse('https://$id.example.com/tok/manifest.json'),
    );
    final alpha = manifest('alpha', 'Source Alpha', 'Populaires');
    final plus = manifest('plus', 'Direct Plus', 'Séries du moment');
    List<Override> addons(List<AddonManifest> ms) => [
      addonsProvider.overrideWith(() => _RAddons(ms)),
    ];
    MetaPreview meta(String n, {String? cert = 'G'}) => MetaPreview(
      id: n,
      type: 'movie',
      name: n,
      sourceAddonId: 'alpha',
      certification: cert,
    );
    final cont = [
      for (final (i, id) in const ['tt1', 'tt2', 'tt3', 'tt4'].indexed)
        ProgressEntry(
          profileId: 'default',
          metaId: id,
          videoId: '$id:1:4',
          position: Duration(minutes: [37, 5, 20, 55][i]),
          duration: const Duration(minutes: 60),
          watched: false,
          updatedAt: DateTime.utc(2026, 11, 18, 10 - i),
          certification: 'G',
        ),
    ];
    final names = {
      'tt1': 'Cosmos Laundromat',
      'tt2': 'Sintel',
      'tt3': 'Tears of Steel',
      'tt4': 'Big Buck Bunny',
    };
    final contOverrides = <Override>[
      continueWatchingProvider.overrideWith((ref) => Stream.value(cont)),
      continuePlaybackProvider.overrideWithValue(_RPlayback(names)),
    ];
    final myList = [
      for (final n in ['Spring', 'Agent 327', 'Caminandes', 'Charge', 'Hero'])
        meta(n),
    ];

    await shot(
      'r-TV05',
      extra: [
        ...addons([alpha]),
        ...contOverrides,
        libraryProvider.overrideWith((ref) => Stream.value(myList)),
        aggregatorFactoryProvider.overrideWithValue(
          ({required bool allowPrivate}) => _RAgg({
            'alpha': [
              CatalogRow(
                addonId: 'alpha',
                catalogId: 'Populaires',
                type: 'movie',
                title: 'Populaires',
                items: [for (final n in names.values) meta(n)],
              ),
            ],
          }),
        ),
      ],
    );
    await shot(
      'r-TV44',
      extraHeight: 450,
      extra: [
        ...addons([alpha, plus]),
        ...contOverrides,
        aggregatorFactoryProvider.overrideWithValue(
          ({required bool allowPrivate}) => _RAgg(
            {
              'alpha': const [],
              'plus': [
                const CatalogRow(
                  addonId: 'plus',
                  catalogId: 'Séries du moment',
                  type: 'movie',
                  title: 'Séries du moment',
                  items: [],
                  error: 'x',
                ),
              ],
            },
            hang: {'alpha'},
          ),
        ),
      ],
    );
    await shot(
      'r-TV45',
      profile: const Profile(
        id: 'kid',
        name: 'Emma',
        createdAt: 0,
        ageLimit: 2,
        isKid: true,
        locked: false,
      ),
      extra: [
        ...addons([alpha]),
        continueWatchingProvider.overrideWith((ref) => Stream.value(const [])),
        aggregatorFactoryProvider.overrideWithValue(
          ({required bool allowPrivate}) => _RAgg({
            'alpha': [
              CatalogRow(
                addonId: 'alpha',
                catalogId: 'Populaires',
                type: 'movie',
                title: 'Populaires',
                items: [meta('Film adulte', cert: 'R')],
              ),
            ],
          }),
        ),
      ],
    );
    await shot(
      'r-TV52',
      extraHeight: 450,
      extra: [
        ...addons([alpha]),
        ...contOverrides,
        aggregatorFactoryProvider.overrideWithValue(
          ({required bool allowPrivate}) => _RAgg({'alpha': const []}),
        ),
      ],
      wrap: (home) => Column(
        children: [
          UpdateBanner(
            manifestUrl: 'https://example.org/update.json',
            fetcher: _UpdateFetcher(),
            currentVersion: () async => '1.0.0',
          ),
          Expanded(child: home),
        ],
      ),
    );
    await shot('r-TV13', extra: addons(const []));
  });

  testWidgets('lot 5 : recherche', skip: skip != null, (t) async {
    await t.runAsync(_fonts);

    Future<void> shot(String name, String query, List<MetaPreview> hits) async {
      final h = AppHarness(t);
      final key = GlobalKey();
      await h.pump(
        RepaintBoundary(key: key, child: const SearchScreen()),
        extra: [
          addonsProvider.overrideWith(
            () => _RAddons([
              AddonManifest(
                id: 'alpha',
                version: '1.0.0',
                name: 'Source Alpha',
                types: const ['movie'],
                resources: const [AddonResource('catalog')],
                catalogs: [
                  CatalogDecl(
                    type: 'movie',
                    id: 'top',
                    name: 'Top',
                    extra: const [ExtraDecl('search')],
                  ),
                ],
                transportUrl: Uri.parse('https://alpha.example.com/m.json'),
              ),
            ]),
          ),
          searchServiceProvider.overrideWithValue(_RSearch(hits)),
          voiceInputProvider.overrideWithValue(_RVoice()),
        ],
      );
      for (final ch in query.split('')) {
        await t.tap(find.byKey(ValueKey('key-$ch')));
        await t.pump();
      }
      await t.pump(searchDebounce);
      await h.settle();
      await _save(t, key, name);
      await h.close();
    }

    MetaPreview m(String n, String kind) => MetaPreview(
      id: n,
      type: 'movie',
      name: n,
      sourceAddonId: 'org.fake',
      sourceKind: kind,
    );
    await shot('r-TV12', 'sint', [
      m('Sintel', 'addon'),
      m('Sintel Lite', 'addon'),
      m('Sintel (2010)', 'jellyfin'),
    ]);
    await shot('r-TV46', 'zzzz', const []);
    await shot('r-TV46b', '', const []);
  });
}

class _RAddons extends AddonsController {
  _RAddons(this.manifests);
  final List<AddonManifest> manifests;

  @override
  Future<List<InstalledAddon>> build() async => [
    for (final (i, m) in manifests.indexed)
      InstalledAddon(id: m.id, manifest: m, position: i, enabled: true),
  ];
}

/// Agrégateur de rendu : une réponse par addon ; `hang` ne répond jamais.
class _RAgg implements CatalogAggregator {
  _RAgg(this.byAddon, {this.hang = const {}});
  final Map<String, List<CatalogRow>> byAddon;
  final Set<String> hang;

  @override
  Stream<CatalogRow> rows(List<AddonManifest> addons) async* {
    for (final a in addons) {
      if (hang.contains(a.id)) await Completer<void>().future;
      for (final r in byAddon[a.id] ?? const <CatalogRow>[]) {
        yield r;
      }
    }
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _RPlayback implements ContinuePlayback {
  _RPlayback(this.names);
  final Map<String, String> names;

  @override
  Future<ContinueInfo> describe(ProgressEntry e) async =>
      ContinueInfo(title: names[e.metaId] ?? e.metaId, subtitle: 'S1E4');

  @override
  Future<void> play(BuildContext context, ProgressEntry e) async {}
}

class _UpdateFetcher implements HttpFetcher {
  @override
  Future<FetchResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) async => FetchResponse(
    status: 200,
    body: utf8.encode(
      jsonEncode({
        'version': '1.1.0',
        'apk': 'https://example.org/lumio.apk',
        'sha256': 'a' * 64,
      }),
    ),
  );
}

class _RSearch implements SearchService {
  _RSearch(this.hits);
  final List<MetaPreview> hits;

  @override
  Stream<List<MetaPreview>> search(List<AddonManifest> addons, String query) =>
      Stream.value(hits);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _RVoice implements VoiceInput {
  @override
  bool get maySupport => true;

  @override
  Future<bool> init() async => true;

  @override
  Future<void> listen(void Function(String text, bool done) onText) async {}

  @override
  Future<void> stop() async {}
}
