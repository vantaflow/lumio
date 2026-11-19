import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/progress_repository.dart';
import 'package:lumio/features/detail/detail_screen.dart';
import 'package:lumio/features/detail/playback_service.dart';
import 'package:lumio/features/home/continue_playback.dart';
import 'package:lumio/features/home/home_layout.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/features/home/home_screen.dart';
import 'package:lumio/features/local/local_providers.dart';
import 'package:lumio/features/local/local_screen.dart' show LocalTitleCard;
import 'package:lumio/providers.dart';
import 'package:lumio/ui/common/guarded_image.dart';
import 'package:lumio/ui/focus/focus_rescue.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

AddonManifest _manifest(
  String id, {
  List<String> catalogs = const ['top'],
  String url = 'https://a.example.com/tok/manifest.json',
}) => AddonManifest(
  id: id,
  version: '1.0.0',
  name: 'Addon $id',
  types: const ['movie'],
  resources: const [AddonResource('catalog')],
  catalogs: [
    for (final c in catalogs) CatalogDecl(type: 'movie', id: c, name: 'Cat $c'),
  ],
  transportUrl: Uri.parse(url),
);

MetaPreview _meta(
  String id, {
  String? cert = 'G',
  String kind = 'addon',
  String addon = 'a',
  Uri? poster,
}) => MetaPreview(
  poster: poster,
  id: id,
  type: 'movie',
  name: 'Film $id',
  sourceAddonId: addon,
  certification: cert,
  sourceKind: kind,
);

CatalogRow _row(
  String addon,
  String cat,
  List<MetaPreview> items, {
  Object? error,
}) => CatalogRow(
  addonId: addon,
  catalogId: cat,
  type: 'movie',
  title: 'Cat $cat',
  items: items,
  error: error,
);

class _FakeAggregator implements CatalogAggregator {
  _FakeAggregator(this.script);

  /// Une réponse par appel de `rows` (la dernière est répétée).
  final List<List<CatalogRow>> script;
  int calls = 0;
  Completer<void>? gate;

  @override
  Stream<CatalogRow> rows(List<AddonManifest> addons) async* {
    final rows = script[calls < script.length ? calls : script.length - 1];
    calls++;
    if (gate != null) await gate!.future;
    for (final r in rows) {
      yield r;
    }
  }

  @override
  Future<List<MetaPreview>> page(
    AddonManifest a,
    CatalogDecl c, {
    required int skip,
  }) => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Répond par URL de transport (plusieurs addons partageant un id de manifeste).
class _ByUrlAggregator implements CatalogAggregator {
  _ByUrlAggregator(this.byHost);
  final Map<String, List<CatalogRow>> byHost;

  @override
  Stream<CatalogRow> rows(List<AddonManifest> addons) async* {
    for (final a in addons) {
      for (final r in byHost[a.transportUrl.host] ?? const <CatalogRow>[]) {
        yield r;
      }
    }
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeAddons extends AddonsController {
  _FakeAddons(this.list);
  final List<InstalledAddon> list;

  @override
  Future<List<InstalledAddon>> build() async => list;
}

class _OfflineClient extends AddonClient {
  _OfflineClient() : super(_NoNet());

  @override
  Future<Map<String, dynamic>?> rawMeta(AddonManifest a, String t, String i) =>
      Future.error(StateError('hors ligne'));
}

class _NoNet implements HttpFetcher {
  @override
  Future<FetchResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) => Future.error(StateError('hors ligne'));
}

class _RecordingPlayback implements ContinuePlayback {
  final played = <String>[];

  /// Titre renvoyé à la place de « Série … » (simule un addon meta installé).
  String? label;

  @override
  Future<ContinueInfo> describe(ProgressEntry e) async =>
      ContinueInfo(title: label ?? 'Série ${e.metaId}');

  @override
  Future<void> play(BuildContext context, ProgressEntry e) async =>
      played.add('${e.videoId}@${e.position.inSeconds}');
}

InstalledAddon _installed(AddonManifest m, {bool enabled = true}) =>
    InstalledAddon(id: m.id, manifest: m, position: 0, enabled: enabled);

ProgressEntry _progress({String meta = 'tt9', String? cert}) => ProgressEntry(
  certification: cert,
  profileId: 'default',
  metaId: meta,
  videoId: '$meta:1:2',
  position: const Duration(seconds: 125),
  duration: const Duration(minutes: 40),
  watched: false,
  updatedAt: DateTime.utc(2026, 11, 18),
);

class _H {
  _H(this.tester);
  final WidgetTester tester;
  late AppDatabase db;
  late ProviderContainer container;
  final playback = _RecordingPlayback();

  Future<void> pump({
    List<InstalledAddon> addons = const [],
    CatalogAggregator? aggregator,
    List<ProgressEntry> progress = const [],
    Profile? profile,
    List<MetaPreview>? library,
    List<MetaPreview>? local,
    List<NavigatorObserver> observers = const [],
  }) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        addonsProvider.overrideWith(() => _FakeAddons(addons)),
        aggregatorFactoryProvider.overrideWithValue(
          ({required bool allowPrivate}) =>
              aggregator ?? _FakeAggregator(const [[]]),
        ),
        continueWatchingProvider.overrideWith((ref) => Stream.value(progress)),
        continuePlaybackProvider.overrideWithValue(playback),
        // La fiche ouverte par un clic ne doit jamais toucher au réseau.
        addonClientProvider.overrideWithValue(_OfflineClient()),
        if (library != null)
          libraryProvider.overrideWith((ref) => Stream.value(library)),
        if (local != null) localPreviewsProvider.overrideWithValue(local),
      ],
    );
    addTearDown(container.dispose);
    if (profile != null) {
      container.read(currentProfileProvider.notifier).select(profile);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LumioTheme.dark(),
          navigatorObservers: observers,
          home: const HomeScreen(),
        ),
      ),
    );
    await settle();
  }

  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  /// Fermeture après une navigation vers la fiche : les abonnements de la
  /// fiche à SQLite doivent être résiliés (minuteurs) avant la fermeture.
  Future<void> closeDeep() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(db.close);
  }

  Future<void> close() async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  }
}

Profile _kid() => const Profile(
  id: 'kid',
  name: 'Léa',
  createdAt: 0,
  ageLimit: 1, // age7
  isKid: true,
  locked: false,
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  group('HomeLayout', () {
    test(
      'arrange garde l\'ordre voulu, ajoute les nouvelles, ignore les inconnues',
      () {
        const l = HomeLayout(order: ['b', 'zzz', 'a']);
        expect(l.arrange(['a', 'b', 'c']), ['b', 'a', 'c']);
      },
    );

    test('visible retire les masquées ; JSON illisible = défaut', () {
      const l = HomeLayout(order: ['b'], hidden: {'a'});
      expect(l.visible(['a', 'b', 'c']), ['b', 'c']);
      expect(HomeLayout.fromJson('x').order, isEmpty);
      final r = HomeLayout.fromJson(jsonDecode(jsonEncode(l.toJson())));
      expect(r.order, ['b']);
      expect(r.hidden, {'a'});
    });

    test('persisté par profil dans settings', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final s = HomeLayoutStore(db);
      await s.save('p1', const HomeLayout(hidden: {'x'}));
      expect((await s.load('p1')).hidden, {'x'});
      expect((await s.load('p2')).hidden, isEmpty);
      final row = await (db.select(
        db.settings,
      )..where((t) => t.key.equals('home_layout:p1'))).getSingle();
      expect(jsonDecode(row.value), isA<Map<String, dynamic>>());
    });
  });

  group('image gardée', () {
    // PNG 1x1.
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
    );

    testWidgets('refuse une adresse privée sans autorisation', (t) async {
      final fetcher = _CountingFetcher(png);
      Object? error;
      await t.runAsync(() async {
        final c = Completer<void>();
        GuardedNetworkImage(
              Uri.parse('http://192.168.1.5/p.png'),
              fetcher: fetcher,
              cache: ImageBytesCache(),
            )
            .resolve(ImageConfiguration.empty)
            .addListener(
              ImageStreamListener(
                (_, _) => c.complete(),
                onError: (e, _) {
                  error = e;
                  c.complete();
                },
              ),
            );
        await c.future;
      });
      expect(error, isA<UnsafeUrlException>());
      expect(fetcher.count, 0);
    });

    testWidgets('autorise le privé si l\'addon l\'est, et met en cache', (
      t,
    ) async {
      final fetcher = _CountingFetcher(png);
      final cache = ImageBytesCache();
      final url = Uri.parse('http://192.168.1.5/p.png');
      for (var i = 0; i < 2; i++) {
        await t.runAsync(() async {
          final c = Completer<void>();
          GuardedNetworkImage(
                url,
                allowPrivate: true,
                fetcher: fetcher,
                cache: cache,
              )
              .resolve(ImageConfiguration.empty)
              .addListener(
                ImageStreamListener(
                  (_, _) => c.complete(),
                  onError: (e, _) => c.completeError(e),
                ),
              );
          await c.future;
        });
      }
      expect(fetcher.count, 1);
    });

    testWidgets('le cache ne contourne pas la garde', (t) async {
      final fetcher = _CountingFetcher(png);
      final cache = ImageBytesCache();
      final url = Uri.parse('http://192.168.1.5/p.png');
      Future<Object?> load(bool allow) => t.runAsync(() async {
        final c = Completer<Object?>();
        GuardedNetworkImage(
              url,
              allowPrivate: allow,
              fetcher: fetcher,
              cache: cache,
            )
            .resolve(ImageConfiguration.empty)
            .addListener(
              ImageStreamListener(
                (_, _) => c.complete(null),
                onError: (e, _) => c.complete(e),
              ),
            );
        return c.future;
      });
      expect(await load(true), isNull);
      expect(await load(false), isA<UnsafeUrlException>());
    });

    test('cache LRU borné', () {
      final c = ImageBytesCache(maxBytes: 10);
      c.put('a', _bytes(6));
      c.put('b', _bytes(6));
      expect(c.get('a'), isNull);
      expect(c.get('b'), isNotNull);
    });
  });

  group('accueil', () {
    MetaPreview localMeta(String id, String name) => MetaPreview(
      id: id,
      type: 'movie',
      name: name,
      sourceAddonId: 'local',
      sourceKind: 'local',
    );

    testWidgets(
      'vidéos locales sans addon : rangée « Dossiers locaux », badge Local, '
      'carte-titre sans affiche',
      (t) async {
        final h = _H(t);
        await h.pump(local: [localMeta('local:aa', 'Mon film')]);
        expect(find.text('Dossiers locaux'), findsOneWidget);
        expect(find.text('Mon film'), findsWidgets); // carte-titre + légende
        expect(find.text('Local'), findsOneWidget);
        expect(find.byType(LocalTitleCard), findsOneWidget);
        await h.close();
      },
    );

    testWidgets('profil enfant : vidéos locales masquées', (t) async {
      final h = _H(t);
      await h.pump(local: [localMeta('local:aa', 'Mon film')], profile: _kid());
      expect(find.text('Dossiers locaux'), findsNothing);
      expect(find.text('Mon film'), findsNothing);
      await h.close();
    });

    testWidgets('reprise locale d\'un autre appareil : masquée', (t) async {
      final h = _H(t);
      await h.pump(
        addons: [_installed(_manifest('a'))],
        aggregator: _FakeAggregator([
          [
            _row('a', 'top', [_meta('1')]),
          ],
        ]),
        progress: [
          _progress(meta: 'local:zz'),
          _progress(),
        ],
      );
      expect(find.text('Série tt9'), findsOneWidget);
      expect(find.text('Série local:zz'), findsNothing);
      await h.close();
    });

    testWidgets(
      '« Continuer » d\'abord, puis les catalogues ; un clic reprend',
      (t) async {
        final h = _H(t);
        final m = _manifest('a');
        await h.pump(
          addons: [_installed(m)],
          aggregator: _FakeAggregator([
            [
              _row('a', 'top', [_meta('1'), _meta('2', kind: 'local')]),
            ],
          ]),
          progress: [_progress()],
        );
        final cont = t.getTopLeft(find.text('Continuer à regarder')).dy;
        final cat = t.getTopLeft(find.text('Films · Cat top')).dy;
        expect(cont, lessThan(cat));
        expect(find.text('Film 1'), findsOneWidget);

        await t.tap(find.text('Série tt9'));
        await h.settle();
        expect(h.playback.played, ['tt9:1:2@125']);
        await h.close();
      },
    );

    testWidgets('chaque affiche indique sa source', (t) async {
      final h = _H(t);
      await h.pump(
        addons: [_installed(_manifest('a'))],
        aggregator: _FakeAggregator([
          [
            _row('a', 'top', [
              _meta('1'),
              _meta('2', kind: 'local'),
              _meta('3', kind: 'jellyfin'),
            ]),
          ],
        ]),
      );
      // Plus de badge générique « addon » : la source d'un titre de catalogue
      // n'est connue qu'à la recherche de flux (Direct / Torrent).
      expect(find.text('addon'), findsNothing);
      expect(find.text('Local'), findsOneWidget);
      expect(find.text('Jellyfin'), findsOneWidget);
      expect(find.text('IPTV'), findsNothing);
      await h.close();
    });

    testWidgets('squelettes pendant le chargement', (t) async {
      final h = _H(t);
      final agg = _FakeAggregator([
        [
          _row('a', 'top', [_meta('1')]),
        ],
      ])..gate = Completer<void>();
      await h.pump(addons: [_installed(_manifest('a'))], aggregator: agg);
      expect(find.byKey(const ValueKey('skeleton-row')), findsOneWidget);
      expect(find.text('Film 1'), findsNothing);
      agg.gate!.complete();
      await h.settle();
      expect(find.byKey(const ValueKey('skeleton-row')), findsNothing);
      expect(find.text('Film 1'), findsOneWidget);
      await h.close();
    });

    testWidgets('une rangée en erreur propose « Réessayer »', (t) async {
      final h = _H(t);
      final agg = _FakeAggregator([
        [_row('a', 'top', const [], error: const AddonException('Hors ligne'))],
        [
          _row('a', 'top', [_meta('1')]),
        ],
      ]);
      await h.pump(addons: [_installed(_manifest('a'))], aggregator: agg);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Hors ligne'), findsOneWidget);
      await t.tap(find.text('Réessayer'));
      await h.settle();
      expect(find.text('Film 1'), findsOneWidget);
      expect(find.text('Réessayer'), findsNothing);
      await h.close();
    });

    testWidgets('aucun addon : message d\'aide', (t) async {
      final h = _H(t);
      await h.pump();
      expect(find.textContaining('Ajoutez un addon'), findsOneWidget);
      expect(find.text('Gérer les addons'), findsOneWidget);
      await h.close();
    });

    testWidgets('addon désactivé ou cassé ignoré', (t) async {
      final h = _H(t);
      await h.pump(
        addons: [
          _installed(_manifest('a'), enabled: false),
          const InstalledAddon(
            id: 'b',
            manifest: null,
            position: 1,
            enabled: true,
          ),
        ],
      );
      expect(find.textContaining('Ajoutez un addon'), findsOneWidget);
      await h.close();
    });

    testWidgets('profil enfant : tout filtré -> message dédié', (t) async {
      final h = _H(t);
      await h.pump(
        addons: [_installed(_manifest('a'))],
        aggregator: _FakeAggregator([
          [
            _row('a', 'top', [_meta('1', cert: 'R'), _meta('2', cert: null)]),
          ],
        ]),
        profile: _kid(),
      );
      expect(find.text('Aucun contenu adapté à ce profil'), findsOneWidget);
      expect(find.text('Film 1'), findsNothing);
      await h.close();
    });

    testWidgets('profil enfant : seuls les titres autorisés', (t) async {
      final h = _H(t);
      await h.pump(
        addons: [_installed(_manifest('a'))],
        aggregator: _FakeAggregator([
          [
            _row('a', 'top', [_meta('1', cert: 'R'), _meta('2', cert: 'PG')]),
          ],
        ]),
        profile: _kid(),
      );
      expect(find.text('Film 2'), findsOneWidget);
      expect(find.text('Film 1'), findsNothing);
      expect(find.text('Aucun contenu adapté à ce profil'), findsNothing);
      await h.close();
    });

    testWidgets('« Ma liste » affichée depuis le dépôt', (t) async {
      final h = _H(t);
      await h.pump(
        addons: [_installed(_manifest('a'))],
        aggregator: _FakeAggregator([
          [
            _row('a', 'top', [_meta('1')]),
          ],
        ]),
      );
      expect(find.text('Ma liste'), findsNothing); // vide : pas de rangée
      final lib = h.container.read(libraryRepositoryProvider);
      await t.runAsync(() => lib.add(defaultProfileId, _meta('9')));
      await h.settle();
      expect(find.text('Ma liste'), findsOneWidget);
      expect(find.text('Film 9'), findsOneWidget);
      await h.close();
    });

    testWidgets('sélection d\'une affiche : la fiche du titre s\'ouvre', (
      t,
    ) async {
      final h = _H(t);
      await h.pump(
        addons: [_installed(_manifest('a'))],
        aggregator: _FakeAggregator([
          [
            _row('a', 'top', [_meta('1')]),
          ],
        ]),
      );
      await t.tap(find.text('Film 1'));
      await h.settle();
      expect(find.byType(DetailScreen), findsOneWidget);
      await h.closeDeep();
    });

    testWidgets(
      'retour de la fiche : le focus revient sur la carte d\'origine',
      (t) async {
        final h = _H(t);
        await h.pump(
          addons: [_installed(_manifest('a'))],
          aggregator: _FakeAggregator([
            [
              _row('a', 'top', [_meta('1'), _meta('2')]),
            ],
          ]),
          library: [_meta('9', addon: 'lib')],
          observers: [FocusRescueObserver()],
        );
        bool onCard(String film) {
          final ctx = FocusManager.instance.primaryFocus?.context;
          if (ctx == null) return false;
          return find
              .descendant(
                of: find.ancestor(
                  of: find.text(film),
                  matching: find.byType(PosterCard),
                ),
                matching: find.byWidget(ctx.widget),
              )
              .evaluate()
              .isNotEmpty;
        }

        var guard = 0;
        while (!onCard('Film 9') && guard++ < 30) {
          await t.sendKeyEvent(
            guard.isOdd
                ? LogicalKeyboardKey.arrowDown
                : LogicalKeyboardKey.arrowRight,
          );
          await t.pump(const Duration(milliseconds: 100));
        }
        expect(onCard('Film 9'), isTrue);
        await t.sendKeyEvent(LogicalKeyboardKey.select);
        await h.settle();
        expect(find.byType(DetailScreen), findsOneWidget);
        t.state<NavigatorState>(find.byType(Navigator)).pop();
        await h.settle();
        await t.pump(const Duration(seconds: 1));
        expect(find.byType(DetailScreen), findsNothing);
        expect(onCard('Film 9'), isTrue);
        await h.closeDeep();
      },
    );

    testWidgets('masquer une rangée dans l\'éditeur la retire', (t) async {
      final h = _H(t);
      await h.pump(
        addons: [
          _installed(_manifest('a', catalogs: ['top', 'new'])),
        ],
        aggregator: _FakeAggregator([
          [
            _row('a', 'top', [_meta('1')]),
            _row('a', 'new', [_meta('2')]),
          ],
        ]),
      );
      expect(find.text('Films · Cat new'), findsOneWidget);
      await t.tap(find.text('Personnaliser'));
      await h.settle();
      await t.tap(
        find.byKey(ValueKey('toggle:${catalogRowId('a', 'movie', 'new')}')),
      );
      await h.settle();
      expect(find.text('Afficher'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('tv-back')));
      await h.settle();
      expect(find.text('Films · Cat new'), findsNothing);
      expect(find.text('Films · Cat top'), findsOneWidget);
      final row = await t.runAsync(
        () => (h.db.select(
          h.db.settings,
        )..where((s) => s.key.equals('home_layout:default'))).getSingle(),
      );
      expect(row!.value, contains('cat:a|movie|new'));
      await h.close();
    });

    testWidgets(
      'même id de manifeste : l\'addon public ne reçoit pas le privé',
      (t) async {
        final h = _H(t);
        final pub = _manifest(
          'same',
          url: 'https://pub.example.com/t/manifest.json',
        );
        final priv = _manifest(
          'same',
          url: 'http://192.168.1.5:7000/manifest.json',
        );
        final poster = Uri.parse('http://192.168.1.9/p.png');
        await h.pump(
          addons: [
            InstalledAddon(
              id: 'pub',
              manifest: pub,
              position: 0,
              enabled: true,
            ),
            InstalledAddon(
              id: 'priv',
              manifest: priv,
              position: 1,
              enabled: true,
            ),
          ],
          aggregator: _ByUrlAggregator({
            'pub.example.com': [
              _row('same', 'top', [_meta('1', addon: 'same', poster: poster)]),
            ],
            '192.168.1.5': [
              _row('same', 'top', [_meta('2', addon: 'same', poster: poster)]),
            ],
          }),
        );
        expect(t.takeException(), isNull); // pas de clés dupliquées
        expect(find.text('Film 1'), findsOneWidget);
        expect(find.text('Film 2'), findsOneWidget);
        bool allow(String film) {
          final card = find.ancestor(
            of: find.text(film),
            matching: find.byType(PosterCard),
          );
          final img = t.widget<Image>(
            find.descendant(of: card, matching: find.byType(Image)),
          );
          final p =
              (img.image as ResizeImage).imageProvider as GuardedNetworkImage;
          return p.allowPrivate;
        }

        expect(allow('Film 1'), isFalse);
        expect(allow('Film 2'), isTrue);
        await h.close();
      },
    );

    testWidgets('profil enfant : « Continuer » filtré par certification', (
      t,
    ) async {
      final h = _H(t);
      await h.pump(
        addons: [_installed(_manifest('a'))],
        aggregator: _FakeAggregator([
          [
            _row('a', 'top', [_meta('1', cert: 'PG')]),
          ],
        ]),
        progress: [
          _progress(meta: 'ok', cert: 'G'),
          _progress(meta: 'adulte', cert: 'R'),
          _progress(meta: 'inconnu'),
        ],
        profile: _kid(),
      );
      expect(find.text('Série ok'), findsOneWidget);
      expect(find.text('Série adulte'), findsNothing);
      expect(find.text('Série inconnu'), findsNothing);
      await h.close();
    });

    testWidgets('profil enfant : tout filtré, Continuer et Ma liste compris', (
      t,
    ) async {
      final h = _H(t);
      await h.pump(
        addons: [_installed(_manifest('a'))],
        aggregator: _FakeAggregator([
          [
            _row('a', 'top', [_meta('1', cert: 'R')]),
          ],
        ]),
        progress: [_progress(meta: 'adulte', cert: 'R')],
        library: [_meta('9', cert: null)],
        profile: _kid(),
      );
      expect(find.text('Aucun contenu adapté à ce profil'), findsOneWidget);
      expect(find.text('Film 9'), findsNothing);
      await h.close();
    });

    testWidgets('profil enfant : « Ma liste » filtrée', (t) async {
      final h = _H(t);
      await h.pump(
        addons: [_installed(_manifest('a'))],
        aggregator: _FakeAggregator([
          [
            _row('a', 'top', [_meta('1', cert: 'G')]),
          ],
        ]),
        library: [
          _meta('8', cert: 'G'),
          _meta('9', cert: 'R'),
        ],
        profile: _kid(),
      );
      expect(find.text('Film 8'), findsWidgets);
      expect(find.text('Film 9'), findsNothing);
      await h.close();
    });

    testWidgets('addons sans aucun titre : message clair', (t) async {
      final h = _H(t);
      await h.pump(
        addons: [_installed(_manifest('a'))],
        aggregator: _FakeAggregator([
          [_row('a', 'top', const [])],
        ]),
      );
      expect(
        find.text('Vos addons ne proposent aucun catalogue'),
        findsOneWidget,
      );
      await h.close();
    });

    testWidgets('un addon installé rafraîchit les titres de « Continuer »', (
      t,
    ) async {
      final h = _H(t);
      h.playback.label = 'Titre inconnu';
      await h.pump(progress: [_progress()]);
      expect(find.text('Titre inconnu'), findsWidgets);
      h.playback.label = 'Vrai titre';
      h.container.invalidate(addonsProvider);
      await h.settle();
      expect(find.text('Vrai titre'), findsWidgets);
      expect(find.text('Titre inconnu'), findsNothing);
      await h.close();
    });

    testWidgets('sans addon, « Continuer » reste affiché', (t) async {
      final h = _H(t);
      await h.pump(progress: [_progress()]);
      expect(find.text('Continuer à regarder'), findsOneWidget);
      expect(find.textContaining('Ajoutez un addon'), findsOneWidget);
      await h.close();
    });

    testWidgets('réordonner : descendre « Continuer » après « Ma liste »', (
      t,
    ) async {
      final h = _H(t);
      await h.pump(
        addons: [_installed(_manifest('a'))],
        aggregator: _FakeAggregator([
          [
            _row('a', 'top', [_meta('1')]),
          ],
        ]),
        progress: [_progress()],
      );
      await t.tap(find.text('Personnaliser'));
      await h.settle();
      await t.tap(find.byKey(const ValueKey('down:$continueRowId')));
      await h.settle();
      final layout = h.container.read(homeLayoutProvider).value!;
      expect(layout.order.take(2), [libraryRowId, continueRowId]);
      await h.close();
    });
  });
}

class _CountingFetcher implements HttpFetcher {
  _CountingFetcher(this.body);
  final List<int> body;
  int count = 0;

  @override
  Future<FetchResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) async {
    guard?.call(url);
    count++;
    return FetchResponse(status: 200, body: body);
  }
}

Uint8List _bytes(int n) => Uint8List.fromList(List.filled(n, 1));
