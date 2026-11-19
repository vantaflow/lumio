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
import 'package:lumio/features/addons/health_providers.dart';
import 'package:lumio/features/detail/detail_screen.dart';
import 'package:lumio/features/detail/playback_service.dart'
    show PlaybackLauncher, addonClientProvider, playbackLauncherProvider;
import 'package:lumio/features/home/continue_playback.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/features/home/home_screen.dart';
import 'package:lumio/features/search/search_providers.dart';
import 'package:lumio/features/search/search_screen.dart';
import 'package:lumio/features/update/update_banner.dart';
import 'package:lumio_core/lumio_core.dart';
import 'package:lumio/features/jellyfin/jellyfin_screen.dart';
import 'package:lumio/features/local/local_screen.dart';
import 'package:lumio/data/db.dart' show LocalFolder;
import 'package:lumio/data/jellyfin_repository.dart' show JellyfinServer;
import 'package:lumio/features/addons/addons_screen.dart';
import 'package:lumio/features/jellyfin/jellyfin_providers.dart';
import 'package:lumio/features/local/local_providers.dart';
import 'package:lumio/features/settings/settings_screen.dart'
    show AboutScreen, SettingsScreen;
import 'package:lumio/features/onboarding/onboarding_flow.dart';
import 'package:lumio/features/settings/stremio_import_screen.dart';
import 'package:lumio/features/tracking/tracking_providers.dart';
import 'package:lumio/features/library/library_screen.dart';
import 'package:lumio/features/settings/backup_section.dart'
    show ImportPassphraseDialog;
import 'package:lumio/ui/common/tv_dialogs.dart' show showTvPanel;
import 'package:lumio/features/calendar/calendar_providers.dart';
import 'package:lumio/features/calendar/calendar_screen.dart';
import 'package:lumio/features/home/row_editor_screen.dart';
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

  testWidgets('lot 5 : fiches', skip: skip != null, (t) async {
    await t.runAsync(_fonts);

    AddonManifest manifest(String id, String name) => AddonManifest(
      id: id,
      version: '1.0.0',
      name: name,
      types: const ['movie', 'series'],
      resources: const [AddonResource('meta'), AddonResource('stream')],
      catalogs: const [],
      transportUrl: Uri.parse('https://$id.example.com/tok/manifest.json'),
    );
    Map<String, dynamic> torrent(String q, String lang, String size, int s) => {
      'name': q,
      'title': 'Cosmos Laundromat $q $lang 👤 $s 💾 $size',
      'infoHash': 'a' * 39 + '${q.length}${lang.length}$s'.substring(0, 1),
    };
    Map<String, dynamic> direct(String q, String lang, String size, String n) =>
        {
          'name': q,
          'title': 'Cosmos Laundromat $q $lang 💾 $size',
          'url': 'https://cdn.example.com/$n.mp4',
        };

    Future<void> shot(
      String name, {
      required Map<String, Map<String, dynamic>?> metas,
      required Map<String, List<Map<String, dynamic>>> streams,
      Set<String> failing = const {},
      Map<String, AddonHealth> health = const {},
      String type = 'movie',
      String id = 'tt1',
      bool onlyOneAddon = false,
      bool metaError = false,
    }) async {
      final h = AppHarness(t);
      final key = GlobalKey();
      final ms = [
        manifest('a1', 'Source Alpha'),
        if (!onlyOneAddon) manifest('a2', 'Direct Plus'),
      ];
      await h.pump(
        RepaintBoundary(
          key: key,
          child: DetailScreen(
            preview: MetaPreview(
              id: id,
              type: type,
              name: 'Cosmos Laundromat',
              sourceAddonId: 'a1',
              certification: 'G',
            ),
          ),
        ),
        extra: [
          addonsProvider.overrideWith(() => _RAddons(ms)),
          addonClientProvider.overrideWithValue(
            _RClient(metas, streams, failing, metaError: metaError),
          ),
          healthSnapshotProvider.overrideWith((ref) => Stream.value(health)),
          if (metaError)
            playbackLauncherProvider.overrideWith(
              (ref) => _BrokenLauncher(ref),
            ),
        ],
      );
      await h.settle(14);
      await _save(t, key, name);
      await h.close();
    }

    const reliable = AddonHealth(
      median: Duration(milliseconds: 300),
      successRate: 1,
      samples: 20,
    );
    const slow = AddonHealth(
      median: Duration(seconds: 4),
      successRate: 0.9,
      samples: 20,
    );
    const failing = AddonHealth(
      median: Duration(milliseconds: 4200),
      successRate: 0.38,
      samples: 20,
    );
    final movie = {
      'name': 'Cosmos Laundromat',
      'description':
          'Un mouton suicidaire rencontre un vendeur excentrique qui lui offre une infinité de vies.',
      'releaseInfo': '2015',
      'genres': ['Animation', 'Fantastique'],
    };
    await shot(
      'r-TV06',
      metas: {'a1': movie, 'a2': movie},
      streams: {
        'a1': [
          torrent('1080p', 'FR EN', '2.1 GB', 128),
          torrent('720p', 'FR', '980 MB', 9),
        ],
        'a2': [
          direct('4K', 'EN', '6.4 GB', 'a'),
          direct('1080p', 'FR', '1.4 GB', 'b'),
        ],
      },
      health: {'a1': reliable, 'a2': slow},
    );
    await shot(
      'r-P11',
      metas: {'a1': movie},
      streams: const {},
      onlyOneAddon: true,
    );
    await shot(
      'r-P12',
      metas: {'a1': movie, 'a2': movie},
      streams: {
        'a2': [
          direct('1080p', 'FR', '1.4 GB', 'a'),
          direct('720p', 'FR', '640 MB', 'b'),
        ],
      },
      failing: {'a1'},
      health: {'a1': failing, 'a2': reliable},
    );
    final series = {
      'name': 'Les Voisins du Phare',
      'description':
          "Une famille s'installe dans un phare désaffecté et découvre ses voisins.",
      'releaseInfo': '2014',
      'genres': ['Comédie', 'Drame'],
      'videos': [
        for (var s = 1; s <= 6; s++)
          for (var e = 1; e <= 4; e++)
            {
              'id': 'tt9:$s:$e',
              'season': s,
              'episode': e,
              'title': 'Épisode $e',
            },
      ],
    };
    await shot(
      'r-TV40',
      type: 'series',
      id: 'tt9',
      metas: {'a1': series, 'a2': series},
      streams: {
        'a1': [torrent('1080p', 'FR EN', '2.1 GB', 128)],
        'a2': [direct('720p', 'FR', '980 MB', 'c')],
      },
      health: {'a1': reliable, 'a2': reliable},
    );
    await shot(
      'r-P24',
      metas: const {},
      streams: const {},
      onlyOneAddon: true,
      metaError: true,
    );
  });

  testWidgets('lot 5 : sources', skip: skip != null, (t) async {
    await t.runAsync(_fonts);

    AddonManifest manifest(String id, String name, {bool catalog = true}) =>
        AddonManifest(
          id: id,
          version: '1.0.0',
          name: name,
          types: const ['movie'],
          resources: [
            if (catalog) const AddonResource('catalog'),
            const AddonResource('stream'),
          ],
          catalogs: [
            if (catalog) CatalogDecl(type: 'movie', id: 'top', name: 'Top'),
          ],
          transportUrl: Uri.parse('https://$id.example.com/tok/manifest.json'),
        );
    final now = DateTime.now().millisecondsSinceEpoch;

    final h = AppHarness(t);
    final key = GlobalKey();
    await h.pump(
      RepaintBoundary(key: key, child: const SettingsScreen()),
      extra: [
        addonsProvider.overrideWith(
          () => _RAddons(
            [
              manifest('a1', 'Source Alpha'),
              manifest('a2', 'Direct Plus', catalog: false),
              manifest('a3', 'Catalogue Libre'),
            ],
            disabled: {'a3'},
          ),
        ),
        healthSnapshotProvider.overrideWith(
          (ref) => Stream.value({
            'a1': const AddonHealth(
              median: Duration(milliseconds: 62),
              successRate: 1,
              samples: 20,
            ),
            'a2': const AddonHealth(
              median: Duration(milliseconds: 1840),
              successRate: 0.95,
              samples: 20,
            ),
            'a3': const AddonHealth(
              median: Duration(seconds: 5),
              successRate: 0.2,
              samples: 20,
            ),
          }),
        ),
        localFoldersProvider.overrideWith(
          (ref) => Stream.value([
            LocalFolder(
              path: '/Films',
              addedAt: now,
              lastScanAt: now - const Duration(hours: 2).inMilliseconds,
            ),
            LocalFolder(path: '/Séries', addedAt: now, lastScanAt: now),
          ]),
        ),
        jellyfinServersProvider.overrideWith(_RJellyfin.new),
      ],
    );
    await t.tap(find.byKey(const ValueKey('rail:sources')));
    await h.settle();
    await _save(t, key, 'r-TV10');
    await h.close();

    final h2 = AppHarness(t);
    final k2 = GlobalKey();
    await h2.pump(
      RepaintBoundary(key: k2, child: const AddonsScreen()),
      extra: [addonsProvider.overrideWith(() => _RAddons(const []))],
    );
    await _save(t, k2, 'r-TV51');
    await h2.close();
  });

  testWidgets('lot 6 : listes', skip: skip != null, (t) async {
    await t.runAsync(_fonts);
    MetaPreview m(String n, {String type = 'movie'}) => MetaPreview(
      id: n,
      type: type,
      name: n,
      sourceAddonId: 'alpha',
      certification: 'G',
    );
    final names = [
      'Sintel',
      'Big Buck Bunny',
      'Tears of Steel',
      'Cosmos Laundromat',
      'Spring',
      'Elephants Dream',
      'Agent 327',
      'Coffee Run',
      'Hero',
      'Glass Half',
      'Caminandes 3',
      'Charge',
      'Sprite Fright',
      'Wing It!',
    ];
    Future<void> shot(
      String name,
      Widget screen,
      List<Override> extra, {
      Future<void> Function(AppHarness h)? after,
    }) async {
      final h = AppHarness(t);
      final key = GlobalKey();
      await h.pump(
        RepaintBoundary(key: key, child: screen),
        extra: extra,
      );
      if (after != null) await after(h);
      await _save(t, key, name);
      await h.close();
    }

    Future<void> right(AppHarness h, int n) async {
      for (var i = 0; i < n; i++) {
        await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await t.pump(const Duration(milliseconds: 300));
      }
    }

    await shot('r-TV20', const LibraryScreen(), [
      libraryProvider.overrideWith(
        (ref) => Stream.value([for (final n in names) m(n)]),
      ),
    ], after: (h) => right(h, 2));
    await shot('r-TV41', const LibraryScreen(), [
      libraryProvider.overrideWith((ref) => Stream.value(const [])),
    ]);
    final now = DateTime.now();
    CalendarEntry entry(String n, DateTime? d, int? s, int? e) => CalendarEntry(
      series: Meta(id: n, type: 'series', name: n),
      video: d == null && s == null
          ? null
          : Video(
              id: '$n:$s:$e',
              title: s == null ? 'Épisode 12' : 'Épisode $e',
              season: s,
              episode: e,
              released: d,
            ),
      date: d,
    );
    final today = DateTime(now.year, now.month, now.day, 20);
    final calOverrides = <Override>[
      calendarClockProvider.overrideWithValue(() => now),
      calendarProvider.overrideWith(
        (ref) async => CalendarData(
          entries: [
            entry('Cosmos Laundromat', today, 2, 4),
            entry('Spring', today.add(const Duration(days: 1)), 1, 7),
            entry(
              'Sintel',
              today.add(const Duration(days: 1, hours: 1)),
              null,
              12,
            ),
            entry('Tears of Steel', today.add(const Duration(days: 2)), 3, 1),
            entry('Big Buck Bunny', null, null, null),
          ],
          previews: {
            for (final n in [
              'Cosmos Laundromat',
              'Spring',
              'Sintel',
              'Tears of Steel',
              'Big Buck Bunny',
            ])
              n: m(n, type: 'series'),
          },
        ),
      ),
      notifyReleasesProvider.overrideWith(() => _RNotify(true)),
    ];
    await shot('r-TV21', const CalendarScreen(), calOverrides);
    await shot('r-TV42', const CalendarScreen(), [
      calendarClockProvider.overrideWithValue(() => now),
      calendarProvider.overrideWith(
        (ref) async => const CalendarData(entries: [], previews: {}),
      ),
      notifyReleasesProvider.overrideWith(() => _RNotify(false)),
    ]);
    await shot('r-TV42b', const CalendarScreen(), [
      calendarClockProvider.overrideWithValue(() => now),
      calendarProvider.overrideWith(
        (ref) async => CalendarData(
          entries: const [],
          previews: {'a': m('a', type: 'series')},
        ),
      ),
      notifyReleasesProvider.overrideWith(() => _RNotify(false)),
    ]);
    await shot('r-TV22', const RowEditorScreen(), [
      addonsProvider.overrideWith(
        () => _RAddons([
          AddonManifest(
            id: 'alpha',
            version: '1.0.0',
            name: 'Cinemeta',
            types: const ['movie', 'series'],
            resources: const [AddonResource('catalog')],
            catalogs: [
              CatalogDecl(type: 'movie', id: 'top', name: 'Populaires'),
              CatalogDecl(type: 'series', id: 'top', name: 'Populaires'),
            ],
            transportUrl: Uri.parse('https://alpha.example.com/m.json'),
          ),
        ]),
      ),
    ]);
  });

  testWidgets('lot 6 : suivi et sauvegarde', skip: skip != null, (t) async {
    await t.runAsync(_fonts);

    Future<void> shot(
      String name,
      Widget screen,
      List<Override> extra, {
      Future<void> Function(AppHarness h)? after,
    }) async {
      final h = AppHarness(t);
      final key = GlobalKey();
      await h.pump(screen, extra: extra, boundary: key);
      if (after != null) await after(h);
      await _save(t, key, name);
      await h.close();
    }

    final noTrakt = <Override>[
      secretStoreProvider.overrideWithValue(MemorySecretStore()),
      traktCredentialsProvider.overrideWithValue((id: '', secret: '')),
    ];
    await shot(
      'r-TV48',
      const SettingsScreen(),
      noTrakt,
      after: (h) async {
        await t.tap(find.byKey(const ValueKey('rail:tracking')));
        await h.settle();
      },
    );
    await shot(
      'r-TV26',
      const TraktDeviceAuthScreen(profileId: 'default'),
      [
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        traktCredentialsProvider.overrideWithValue((id: 'c', secret: 's')),
        trackingFetcherProvider.overrideWithValue(_RTrakt()),
        trackingSleepProvider.overrideWithValue(
          (_) => Completer<void>().future,
        ),
      ],
      after: (h) => h.settle(3),
    );
    await shot(
      'r-P07',
      const JellyfinServersScreen(),
      [jellyfinServersProvider.overrideWith(_RJellyfinFail.new)],
      after: (h) async {
        await t.tap(find.byKey(const ValueKey('jellyfin-add')));
        await h.settle();
        _fill(
          t,
          find.byKey(const ValueKey('jellyfin-url')),
          'https://jellyfin.exemple.fr',
        );
        _fill(t, find.byKey(const ValueKey('jellyfin-user')), 'lilou');
        _fill(t, find.byKey(const ValueKey('jellyfin-pass')), 'motdepasse');
        await t.tap(find.byKey(const ValueKey('jellyfin-connect')));
        await h.settle();
      },
    );
    await shot(
      'r-TV33',
      const SettingsScreen(),
      const [],
      after: (h) async {
        await t.tap(find.byKey(const ValueKey('rail:backup')));
        await h.settle();
      },
    );
    await shot(
      'r-TV33b',
      const SettingsScreen(),
      const [],
      after: (h) async {
        await t.tap(find.byKey(const ValueKey('rail:backup')));
        await h.settle();
        await t.tap(find.byKey(const ValueKey('setting:backupExport')));
        await h.settle();
      },
    );
    await shot(
      'r-P14',
      const SettingsScreen(),
      const [],
      after: (h) async {
        await t.tap(find.byKey(const ValueKey('rail:playback')));
        await h.settle();
        final ctx = t.element(find.byType(Scaffold).first);
        unawaited(
          showTvPanel<String>(
            ctx,
            builder: (_) => const ImportPassphraseDialog(wrong: true),
          ),
        );
        await h.settle();
        _fill(t, find.byType(TextField).last, 'motdepasse12');
        await h.settle(2);
      },
    );
  });
}

/// Remplit un champ (en mode TV les champs sont en lecture seule : on écrit
/// dans leur contrôleur).
void _fill(WidgetTester t, Finder f, String text) {
  final field = f.evaluate().first.widget is TextField
      ? f.evaluate().first.widget as TextField
      : t.widget<TextField>(
          find.descendant(of: f, matching: find.byType(TextField)).first,
        );
  field.controller!.text = text;
}

class _RNotify extends NotifyReleasesController {
  _RNotify(this.v);
  final bool v;
  @override
  Future<bool> build() async => v;
}

class _RAddons extends AddonsController {
  _RAddons(this.manifests, {this.disabled = const {}});
  final List<AddonManifest> manifests;
  final Set<String> disabled;

  @override
  Future<List<InstalledAddon>> build() async => [
    for (final (i, m) in manifests.indexed)
      InstalledAddon(
        id: m.id,
        manifest: m,
        position: i,
        enabled: !disabled.contains(m.id),
      ),
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

class _RClient extends AddonClient {
  _RClient(this.metas, this.streams, this.failing, {this.metaError = false})
    : super(_UpdateFetcher());
  final bool metaError;
  final Map<String, Map<String, dynamic>?> metas;
  final Map<String, List<Map<String, dynamic>>> streams;
  final Set<String> failing;

  @override
  Future<Map<String, dynamic>?> rawMeta(
    AddonManifest a,
    String type,
    String id,
  ) async {
    if (metaError) throw StateError('hors ligne');
    return metas[a.id];
  }

  @override
  Future<List<Map<String, dynamic>>> rawStreams(
    AddonManifest a,
    String type,
    String id,
  ) async {
    if (failing.contains(a.id)) throw StateError('hors ligne');
    return streams[a.id] ?? const [];
  }

  @override
  Future<List<Map<String, dynamic>>> rawSubtitles(
    AddonManifest a,
    String type,
    String id,
  ) async => const [];
}

/// Lanceur dont le chargement de la fiche échoue (pop-up P24).
class _BrokenLauncher extends PlaybackLauncher {
  _BrokenLauncher(super.ref);

  @override
  Future<Meta> loadMeta(MetaPreview p) =>
      Future.error(StateError('hors ligne'));
}

class _RJellyfin extends JellyfinServersController {
  @override
  Future<List<JellyfinServer>> build() async => [
    JellyfinServer(
      id: 's1',
      name: 'Salon',
      url: Uri.parse('https://salon.example.com'),
      allowPrivate: false,
      userId: 'u',
      userName: 'lilou',
    ),
  ];
}

class _RTrakt implements HttpPostFetcher {
  @override
  Future<FetchResponse> post(
    Uri url, {
    required List<int> body,
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) async => FetchResponse(
    status: 200,
    body: utf8.encode(
      jsonEncode({
        'device_code': 'dev-1',
        'user_code': '5B7C9D2E',
        'verification_url': 'https://trakt.tv/activate',
        'expires_in': 600,
        'interval': 5,
      }),
    ),
  );

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _RJellyfinFail extends _RJellyfin {
  @override
  Future<JellyfinServer> add(
    Uri url,
    String user,
    String password, {
    bool confirmedInsecure = false,
  }) => Future.error(const JellyfinAuthException());
}
