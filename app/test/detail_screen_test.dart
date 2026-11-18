import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/progress_repository.dart';
import 'package:lumio/data/stream_prefs.dart';
import 'package:lumio/features/detail/detail_screen.dart';
import 'package:lumio/features/detail/playback_service.dart';
import 'package:lumio/features/detail/streams_list.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/features/library/library_screen.dart';
import 'package:lumio/player/player_screen.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/torrent/torrent_engine.dart';
import 'package:lumio/torrent/torrent_playback.dart';
import 'package:lumio/torrent/torrent_providers.dart';
import 'package:lumio/ui/common/guarded_image.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

import 'support/fake_addon_fetcher.dart';
import 'support/fake_torrent_engine.dart';
import 'support/recording_player.dart';

AddonManifest _manifest(
  String id, {
  String url = 'https://a.example.com/tok/manifest.json',
}) => AddonManifest(
  id: id,
  version: '1.0.0',
  name: 'Addon $id',
  types: const ['movie', 'series'],
  resources: const [
    AddonResource('meta'),
    AddonResource('stream'),
    AddonResource('subtitles'),
  ],
  catalogs: const [],
  transportUrl: Uri.parse(url),
);

InstalledAddon _installed(String storageId, AddonManifest m) =>
    InstalledAddon(id: storageId, manifest: m, position: 0, enabled: true);

/// Délègue à [_inner] en notant le niveau de confiance réseau demandé.
class _Recording extends AddonClient {
  _Recording(this._inner, this._trust, this.seen, [this.calls])
    : super(FakeAddonFetcher());

  final _FakeClient _inner;
  final bool _trust;
  final Map<String, bool> seen;
  final List<String>? calls;

  void _note(AddonManifest a) {
    seen[a.id] = _trust;
    calls?.add(a.id);
  }

  @override
  Future<Map<String, dynamic>?> rawMeta(AddonManifest a, String t, String i) {
    _note(a);
    return _inner.rawMeta(a, t, i);
  }

  @override
  Future<List<Map<String, dynamic>>> rawStreams(
    AddonManifest a,
    String t,
    String i,
  ) {
    _note(a);
    return Future.value([
      {'name': 'x', 'title': 'x', 'url': 'https://cdn.example.com/${a.id}.mp4'},
    ]);
  }

  @override
  Future<List<Map<String, dynamic>>> rawSubtitles(
    AddonManifest a,
    String t,
    String i,
  ) {
    _note(a);
    return Future.value([
      {'id': a.id, 'url': 'https://cdn.example.com/${a.id}.srt', 'lang': 'fr'},
    ]);
  }
}

class _FakeAddons extends AddonsController {
  _FakeAddons(this.list);
  final List<InstalledAddon> list;

  @override
  Future<List<InstalledAddon>> build() async => list;
}

/// Client d'addons simulé, par identifiant de manifeste.
class _FakeClient extends AddonClient {
  _FakeClient() : super(FakeAddonFetcher());

  final Map<String, Map<String, dynamic>?> metas = {};
  final Map<String, List<Map<String, dynamic>>> streams = {};
  final Map<String, List<Map<String, dynamic>>> subtitles = {};
  final Set<String> failingStreams = {};
  final List<String> streamCalls = [];

  @override
  Future<Map<String, dynamic>?> rawMeta(
    AddonManifest a,
    String type,
    String id,
  ) async => metas[a.id];

  @override
  Future<List<Map<String, dynamic>>> rawStreams(
    AddonManifest a,
    String type,
    String id,
  ) async {
    streamCalls.add('${a.id}|$id');
    if (failingStreams.contains(a.id)) throw StateError('hors ligne');
    return streams['${a.id}|$id'] ?? streams[a.id] ?? const [];
  }

  @override
  Future<List<Map<String, dynamic>>> rawSubtitles(
    AddonManifest a,
    String type,
    String id,
  ) async => subtitles[a.id] ?? const [];
}

Map<String, dynamic> _direct(String name, String url, {String? desc}) => {
  'name': name,
  'title': desc ?? name,
  'url': url,
};

Map<String, dynamic> _torrent(String name, {String? desc}) => {
  'name': name,
  'title': desc ?? name,
  'infoHash': 'a' * 40,
};

MetaPreview _preview({
  String id = 'tt1',
  String type = 'movie',
  String? cert,
}) => MetaPreview(
  id: id,
  type: type,
  name: 'Titre $id',
  sourceAddonId: 'org.a',
  certification: cert,
);

class _H {
  _H(this.t);
  final WidgetTester t;
  late AppDatabase db;
  late ProviderContainer container;
  final client = _FakeClient();
  final players = <PlayerScreen>[];

  Future<void> pump({
    required MetaPreview preview,
    List<InstalledAddon>? addons,
    Profile? profile,
    StreamPrefs? prefs,
    Widget? home,
    Future<void> Function(ProviderContainer c)? seed,
    List<Override> overrides = const [],
  }) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        addonsProvider.overrideWith(
          () => _FakeAddons(addons ?? [_installed('s1', _manifest('org.a'))]),
        ),
        addonClientProvider.overrideWithValue(client),
        playerBuilderProvider.overrideWithValue((screen) {
          players.add(screen);
          return const Scaffold(body: Text('PLAYER'));
        }),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    if (profile != null) {
      container.read(currentProfileProvider.notifier).select(profile);
    }
    if (prefs != null) {
      await t.runAsync(
        () => container
            .read(streamPrefsStoreProvider)
            .save(container.read(currentProfileIdProvider), prefs),
      );
    }
    if (seed != null) await t.runAsync(() => seed(container));
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LumioTheme.dark(),
          home: home ?? DetailScreen(preview: preview),
        ),
      ),
    );
    await settle();
  }

  Future<void> settle() async {
    for (var i = 0; i < 12; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> close() async {
    await t.pumpWidget(const SizedBox());
    container.dispose();
    await t.pump(const Duration(milliseconds: 50));
    await t.runAsync(db.close);
  }
}

const _kid = Profile(
  id: 'kid',
  name: 'Enfant',
  ageLimit: 1, // AgeLimit.age7
  isKid: true,
  locked: false,
  createdAt: 0,
);

void main() {
  testWidgets('film : synopsis, flux groupés par addon, aimant et seeders', (
    t,
  ) async {
    final h = _H(t);
    final a = _manifest('org.a');
    final b = _manifest('org.b', url: 'https://b.example.com/manifest.json');
    h.client.metas['org.a'] = {
      'name': 'Big Buck Bunny',
      'description': 'Un lapin géant.',
    };
    h.client.streams['org.a'] = [
      _direct('1080p', 'https://cdn.example.com/a.mp4', desc: 'Film VF 1080p'),
    ];
    h.client.streams['org.b'] = [_torrent('Torrent', desc: 'Film 720p 👤 120')];
    await h.pump(
      preview: _preview(),
      addons: [_installed('s1', a), _installed('s2', b)],
    );
    expect(find.text('Un lapin géant.'), findsOneWidget);
    expect(find.text('Addon org.a'), findsOneWidget);
    expect(find.text('Addon org.b'), findsOneWidget);
    expect(find.byType(MagnetIcon), findsOneWidget);
    expect(find.byIcon(Icons.link), findsOneWidget);
    await h.close();
  });

  testWidgets(
    'titre importé (sourceAddonId vide) : fiche résolue par les addons '
    'activés',
    (t) async {
      final h = _H(t);
      h.client.metas['org.a'] = {
        'name': 'Big Buck Bunny',
        'description': 'Un lapin géant.',
      };
      h.client.streams['org.a'] = [
        _direct('1080p', 'https://cdn.example.com/a.mp4'),
      ];
      await h.pump(
        preview: const MetaPreview(
          id: 'tt1',
          type: 'movie',
          name: 'Importé',
          sourceAddonId: '',
        ),
      );
      expect(find.text('Un lapin géant.'), findsOneWidget);
      expect(find.text('Addon org.a'), findsOneWidget);
      await h.close();
    },
  );

  testWidgets('aucun flux : « Vérifiez vos addons »', (t) async {
    final h = _H(t);
    await h.pump(preview: _preview());
    expect(find.textContaining('Vérifiez vos addons'), findsOneWidget);
    await h.close();
  });

  testWidgets('aucun meta : données minimales du catalogue (AC 1.3 #3)', (
    t,
  ) async {
    final h = _H(t);
    await h.pump(preview: _preview());
    expect(find.text('Titre tt1'), findsWidgets);
    await h.close();
  });

  testWidgets('addon de flux en échec : santé signalée, l\'autre s\'affiche', (
    t,
  ) async {
    final h = _H(t);
    h.client.failingStreams.add('org.b');
    h.client.streams['org.a'] = [_direct('x', 'https://cdn.example.com/a.mp4')];
    await h.pump(
      preview: _preview(),
      addons: [
        _installed('s1', _manifest('org.a')),
        _installed('s2', _manifest('org.b')),
      ],
    );
    expect(find.text('Ne répond pas'), findsOneWidget);
    expect(find.text('1 flux'), findsOneWidget);
    await h.close();
  });

  testWidgets('préférence « 1080p, fr » : le flux correspondant est recommandé '
      'et lancé par « Lecture auto »', (t) async {
    final h = _H(t);
    h.client.streams['org.a'] = [
      _direct('en', 'https://cdn.example.com/en.mp4', desc: 'Film EN 1080p'),
      _direct('fr720', 'https://cdn.example.com/fr7.mp4', desc: 'Film VF 720p'),
      _direct('fr', 'https://cdn.example.com/fr.mp4', desc: 'Film VF 1080p'),
    ];
    await h.pump(preview: _preview(), prefs: const StreamPrefs());
    expect(find.text('Recommandé'), findsOneWidget);
    await t.tap(find.textContaining('Lecture auto'));
    await h.settle();
    expect(h.players, hasLength(1));
    expect(
      h.players.single.item.url.toString(),
      'https://cdn.example.com/fr.mp4',
    );
    await h.close();
  });

  testWidgets('câblage du lecteur : profil, titre, épisode, meta, suivant, '
      'sous-titres et réseau privé par addon', (t) async {
    final h = _H(t);
    final priv = _manifest(
      'org.priv',
      url: 'http://192.168.1.5:7000/manifest.json',
    );
    final pub = _manifest('org.pub');
    h.client.metas['org.pub'] = {
      'name': 'Série',
      'videos': [
        {'id': 'tt9:1:1', 'season': 1, 'episode': 1, 'title': 'Pilote'},
        {'id': 'tt9:1:2', 'season': 1, 'episode': 2, 'title': 'Suite'},
      ],
    };
    h.client.streams['org.priv'] = [
      _direct('p', 'http://192.168.1.5:7000/v.mp4', desc: 'VF 1080p'),
    ];
    h.client.subtitles['org.priv'] = [
      {'id': 's', 'url': 'http://192.168.1.5:7000/s.srt', 'lang': 'fre'},
    ];
    h.client.subtitles['org.pub'] = [
      {'id': 's2', 'url': 'https://cdn.example.com/s.srt', 'lang': 'eng'},
    ];
    await h.pump(
      preview: _preview(id: 'tt9', type: 'series'),
      addons: [_installed('priv-1', priv), _installed('pub-1', pub)],
    );
    await t.tap(find.textContaining('Lecture auto'));
    await h.settle();
    final p = h.players.single;
    expect(p.metaId, 'tt9');
    expect(p.videoId, 'tt9:1:1');
    expect(p.profileId, defaultProfileId);
    expect(p.meta!.videos, hasLength(2));
    expect(p.item.addonId, 'priv-1'); // identifiant de stockage
    expect(p.allowPrivate, isTrue);
    expect(p.allowPrivateForAddon!('priv-1'), isTrue);
    expect(p.allowPrivateForAddon!('pub-1'), isFalse);
    expect([for (final s in p.subtitles) s.addonId], ['priv-1', 'pub-1']);
    // Épisode suivant : flux direct préféré, ou null s'il n'y en a pas.
    h.client.streams['org.priv'] = [
      _direct('n', 'http://192.168.1.5:7000/n.mp4', desc: 'VF 1080p'),
      _torrent('t'),
    ];
    final next = await t.runAsync(() => p.resolveNext!(p.meta!.videos[1]));
    expect(next!.url.toString(), 'http://192.168.1.5:7000/n.mp4');
    expect(h.client.streamCalls.last.endsWith('tt9:1:2'), isTrue);
    // Un torrent seul est désormais lisible : il est proposé comme suivant.
    h.client.streams['org.priv'] = [_torrent('t')];
    final nextTorrent = await t.runAsync(
      () => p.resolveNext!(p.meta!.videos[1]),
    );
    expect(nextTorrent!.isTorrent, isTrue);
    h.client.streams['org.priv'] = [];
    expect(await t.runAsync(() => p.resolveNext!(p.meta!.videos[1])), isNull);
    await h.close();
  });

  testWidgets('flux torrent : lu via le moteur, URL locale en trustedLocal', (
    t,
  ) async {
    final h = _H(t);
    final engine = FakeTorrentEngine(
      fileList: const [
        TorrentFile(index: 0, name: 'a.mkv', size: 10, streamable: true),
        TorrentFile(index: 1, name: 'b.mkv', size: 900, streamable: true),
      ],
    );
    final ctl = RecordingPlayerController();
    h.client.streams['org.a'] = [_torrent('T', desc: 'Film 1080p 👤 80')];
    await h.pump(
      preview: _preview(),
      overrides: [
        torrentPlaybackFactoryProvider.overrideWithValue(
          () => TorrentPlayback(engine: engine),
        ),
        playerBuilderProvider.overrideWithValue(
          (screen) => PlayerScreen(
            item: screen.item,
            allowPrivate: screen.allowPrivate,
            controller: ctl,
            videoBuilder: (_) => const ColoredBox(color: Colors.black),
            tracksBackend: (_) => NoTracksBackend(),
          ),
        ),
      ],
    );
    expect(find.byType(MagnetIcon), findsOneWidget);
    await t.tap(find.textContaining('Film 1080p').first);
    await h.settle();
    expect(find.textContaining('bientôt'), findsNothing);
    expect(ctl.opened, hasLength(1));
    expect(ctl.opened.single.url.toString(), startsWith('http://127.0.0.1'));
    expect(ctl.trusted.single, isTrue);
    expect(engine.streamedIndexes, [1]); // plus grand fichier lisible
    expect(ctl.failures, isEmpty);
    await h.close();
    expect(engine.stopDeleteData, [true]); // sortie du lecteur : nettoyage
  });

  testWidgets('série : saisons, épisodes, coche « vu », flux par épisode', (
    t,
  ) async {
    final h = _H(t);
    h.client.metas['org.a'] = {
      'name': 'Série',
      'videos': [
        {'id': 'tt9:1:1', 'season': 1, 'episode': 1, 'title': 'Pilote'},
        {'id': 'tt9:1:2', 'season': 1, 'episode': 2, 'title': 'Suite'},
        {'id': 'tt9:2:1', 'season': 2, 'episode': 1, 'title': 'Retour'},
      ],
    };
    h.client.streams['org.a'] = [_direct('x', 'https://cdn.example.com/x.mp4')];
    await h.pump(
      preview: _preview(id: 'tt9', type: 'series'),
      // Épisode 1 déjà vu (progression >= 90 %).
      seed: (c) => c
          .read(progressRepositoryProvider)
          .save(
            defaultProfileId,
            'tt9',
            'tt9:1:1',
            const Duration(minutes: 44),
            const Duration(minutes: 45),
          ),
    );
    await h.settle();
    expect(find.text('Saison 1'), findsWidgets);
    expect(find.text('Saison 2'), findsOneWidget);
    expect(find.text('Pilote'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('episode:tt9:1:1')),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('episode:tt9:1:2')),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsNothing,
    );
    // Au départ : premier épisode non vu (S1E2).
    expect(h.client.streamCalls.first, 'org.a|tt9:1:2');
    await t.tap(find.text('Saison 2'));
    await h.settle();
    expect(find.text('Retour'), findsOneWidget);
    await t.tap(find.text('Retour'));
    await h.settle();
    expect(h.client.streamCalls.last, 'org.a|tt9:2:1');
    await h.close();
  });

  testWidgets('Ma liste : ajout puis retrait depuis la fiche', (t) async {
    final h = _H(t);
    await h.pump(preview: _preview(cert: 'G'));
    final repo = h.container.read(libraryRepositoryProvider);
    await t.tap(find.text('Ajouter à ma liste'));
    await h.settle();
    expect(
      await t.runAsync(() => repo.contains(defaultProfileId, 'tt1')),
      isTrue,
    );
    expect(find.text('Retirer de ma liste'), findsOneWidget);
    await t.tap(find.text('Retirer de ma liste'));
    await h.settle();
    expect(
      await t.runAsync(() => repo.contains(defaultProfileId, 'tt1')),
      isFalse,
    );
    await h.close();
  });

  testWidgets('« Ma liste » vide : l\'aide explique comment ajouter', (
    t,
  ) async {
    final h = _H(t);
    await h.pump(preview: _preview(), home: const LibraryScreen());
    expect(find.textContaining('Votre liste est vide'), findsOneWidget);
    expect(find.textContaining('Ajouter à ma liste'), findsOneWidget);
    await h.close();
  });

  testWidgets('« Ma liste » : titres du profil, filtre enfant', (t) async {
    final h = _H(t);
    await h.pump(
      preview: _preview(),
      profile: _kid,
      home: const LibraryScreen(),
      seed: (c) async {
        final repo = c.read(libraryRepositoryProvider);
        await repo.add('kid', _preview(id: 'ok', cert: 'G'));
        await repo.add('kid', _preview(id: 'no', cert: 'R'));
        await repo.add('kid', _preview(id: 'unk'));
        await repo.add('autre', _preview(id: 'other', cert: 'G'));
      },
    );
    expect(find.text('Titre ok'), findsOneWidget);
    expect(find.text('Titre no'), findsNothing);
    expect(find.text('Titre unk'), findsNothing);
    expect(find.text('Titre other'), findsNothing);
    await h.close();
  });

  testWidgets('profil enfant : certification refusée, aucun flux demandé', (
    t,
  ) async {
    final h = _H(t);
    h.client.streams['org.a'] = [_direct('x', 'https://cdn.example.com/x.mp4')];
    await h.pump(
      preview: _preview(cert: 'R'),
      profile: _kid,
    );
    expect(find.textContaining('pas autorisé'), findsOneWidget);
    expect(h.client.streamCalls, isEmpty);
    await h.close();
  });

  testWidgets('profil enfant : certification inconnue refusée (recherche)', (
    t,
  ) async {
    final h = _H(t);
    await h.pump(preview: _preview(), profile: _kid);
    expect(find.textContaining('pas autorisé'), findsOneWidget);
    expect(h.client.streamCalls, isEmpty);
    await h.close();
  });

  testWidgets('profil enfant : la certification du meta compte', (t) async {
    final h = _H(t);
    h.client.metas['org.a'] = {'name': 'X', 'certification': 'R'};
    await h.pump(
      preview: _preview(cert: 'G'),
      profile: _kid,
    );
    expect(find.textContaining('pas autorisé'), findsOneWidget);
    expect(h.client.streamCalls, isEmpty);
    await h.close();
  });

  testWidgets('profil enfant : titre autorisé affiché', (t) async {
    final h = _H(t);
    h.client.streams['org.a'] = [_direct('x', 'https://cdn.example.com/x.mp4')];
    await h.pump(
      preview: _preview(cert: 'G'),
      profile: _kid,
    );
    expect(find.textContaining('pas autorisé'), findsNothing);
    expect(h.client.streamCalls, isNotEmpty);
    await h.close();
  });

  group('affiche : confiance réseau suivant la vraie source', () {
    bool? posterAllow(WidgetTester t) {
      for (final i in t.widgetList<Image>(find.byType(Image))) {
        final p = i.image;
        if (p is GuardedNetworkImage) return p.allowPrivate;
      }
      return null;
    }

    testWidgets('affiche privée fournie par un addon public : refusée', (
      t,
    ) async {
      final h = _H(t);
      final priv = _manifest(
        'org.priv',
        url: 'http://192.168.1.5:7000/manifest.json',
      );
      h.client.metas['org.pub'] = {'poster': 'http://192.168.1.9/p.jpg'};
      await h.pump(
        preview: MetaPreview(
          id: 'tt1',
          type: 'movie',
          name: 'T',
          sourceAddonId: 'org.priv',
        ),
        addons: [
          _installed('p1', priv),
          _installed('s2', _manifest('org.pub')),
        ],
      );
      expect(posterAllow(t), isFalse);
      await h.close();
    });

    testWidgets('affiche du catalogue d\'un addon privé : autorisée', (
      t,
    ) async {
      final h = _H(t);
      final priv = _manifest(
        'org.priv',
        url: 'http://192.168.1.5:7000/manifest.json',
      );
      await h.pump(
        preview: MetaPreview(
          id: 'tt1',
          type: 'movie',
          name: 'T',
          poster: Uri.parse('http://192.168.1.5:7000/p.jpg'),
          sourceAddonId: 'org.priv',
        ),
        addons: [_installed('p1', priv)],
      );
      expect(posterAllow(t), isTrue);
      await h.close();
    });
  });

  group('RoutingAddonClient', () {
    test(
      'allowPrivate par addon selon son URL ; ids de stockage conservés',
      () async {
        final seen = <String, bool>{};
        final inner = <bool, _FakeClient>{};
        AddonClient factory({required bool allowPrivate}) {
          final c = inner.putIfAbsent(allowPrivate, () => _FakeClient());
          return _Recording(c, allowPrivate, seen);
        }

        final priv = _manifest(
          'org.priv',
          url: 'http://192.168.1.5:7000/manifest.json',
        );
        // Hostile : l'id de manifeste de l'addon public = id de stockage privé.
        final pub = _manifest('p1');
        final db = AppDatabase(NativeDatabase.memory());
        final c = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            addonsProvider.overrideWith(
              () =>
                  _FakeAddons([_installed('p1', priv), _installed('s2', pub)]),
            ),
            addonClientProvider.overrideWithValue(
              RoutingAddonClient(factory: factory),
            ),
          ],
        );
        addTearDown(() async {
          c.dispose();
          await db.close();
        });
        final l = c.read(playbackLauncherProvider);
        final groups = await l.loadStreams('movie', 'tt1').toList();
        final subs = await l.loadSubtitles('movie', 'tt1');
        await l.loadMeta(_preview());
        expect(seen['org.priv'], isTrue);
        expect(seen['p1'], isFalse);
        expect({for (final g in groups) g.addonId}, {'p1', 's2'});
        final fromPublic = groups.firstWhere((g) => g.addonId == 's2');
        expect(fromPublic.items.single.addonId, 's2');
        expect({for (final s in subs) s.addonId}, {'p1', 's2'});
        expect(l.allowPrivateFor('p1'), isTrue);
        expect(l.allowPrivateFor('s2'), isFalse);
      },
    );

    test('aucune requête après annulation du consommateur', () async {
      final calls = <String>[];
      final c0 = _FakeClient();
      AddonClient factory({required bool allowPrivate}) =>
          _Recording(c0, allowPrivate, {}, calls);
      final db = AppDatabase(NativeDatabase.memory());
      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          addonsProvider.overrideWith(
            () => _FakeAddons([_installed('s1', _manifest('org.a'))]),
          ),
          addonClientProvider.overrideWithValue(
            RoutingAddonClient(factory: factory),
          ),
        ],
      );
      addTearDown(() async {
        c.dispose();
        await db.close();
      });
      final sub = c
          .read(playbackLauncherProvider)
          .loadStreams('movie', 'tt1')
          .listen((_) {});
      await sub.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(calls, isEmpty);
    });
  });

  testWidgets('« Lecture auto » : à égalité de préférences, lien direct', (
    t,
  ) async {
    final h = _H(t);
    h.client.streams['org.a'] = [
      _torrent('T', desc: 'Film VF 1080p 👤 500'),
      _direct('d', 'https://cdn.example.com/d.mp4', desc: 'Film VF 1080p'),
    ];
    await h.pump(preview: _preview());
    await t.tap(find.textContaining('Lecture auto'));
    await h.settle();
    expect(
      h.players.single.item.url.toString(),
      'https://cdn.example.com/d.mp4',
    );
    await h.close();
  });

  testWidgets('« Lecture auto » : le classement des préférences décide', (
    t,
  ) async {
    // Meilleure qualité côté torrent : il est choisi (aucune règle spéciale).
    final h = _H(t);
    h.client.streams['org.a'] = [
      _torrent('T', desc: 'Film VF 1080p 👤 500'),
      _direct('d', 'https://cdn.example.com/d.mp4', desc: 'Film VF 720p'),
    ];
    await h.pump(
      preview: _preview(),
      overrides: [
        torrentPlaybackFactoryProvider.overrideWithValue(
          () => TorrentPlayback(engine: FakeTorrentEngine()),
        ),
      ],
    );
    await t.tap(find.textContaining('Lecture auto'));
    await h.settle();
    expect(h.players.single.item.isTorrent, isTrue);
    await h.close();
  });

  group('reprise en un clic', () {
    ProgressEntry entry({String? cert}) => ProgressEntry(
      profileId: defaultProfileId,
      metaId: 'tt9',
      videoId: 'tt9:1:2',
      position: const Duration(minutes: 5),
      duration: const Duration(minutes: 40),
      watched: false,
      updatedAt: DateTime.utc(2026, 11, 18),
      certification: cert,
    );

    testWidgets('describe : titre et SxEy ; play : lecteur au flux préféré', (
      t,
    ) async {
      final h = _H(t);
      h.client.metas['org.a'] = {
        'name': 'Ma série',
        'poster': 'https://img.example.com/p.jpg',
        'videos': [
          {'id': 'tt9:1:2', 'season': 1, 'episode': 2, 'title': 'Suite'},
        ],
      };
      h.client.streams['org.a'] = [
        _direct('x', 'https://cdn.example.com/x.mp4', desc: 'VF 1080p'),
      ];
      late BuildContext ctx;
      await h.pump(
        preview: _preview(),
        home: Builder(
          builder: (c) {
            ctx = c;
            return const Scaffold(body: Text('ACCUEIL'));
          },
        ),
      );
      final playback = h.container.read(continuePlaybackProvider);
      final info = await t.runAsync(() => playback.describe(entry()));
      expect(info!.title, 'Ma série');
      expect(info.subtitle, 'S1E2');
      expect(info.poster.toString(), 'https://img.example.com/p.jpg');
      unawaited(playback.play(ctx, entry()));
      await h.settle();
      expect(h.players.single.videoId, 'tt9:1:2');
      expect(h.players.single.metaId, 'tt9');
      expect(
        h.players.single.item.url.toString(),
        'https://cdn.example.com/x.mp4',
      );
      expect(h.client.streamCalls, ['org.a|tt9:1:2']);
      await h.close();
    });

    testWidgets('sans source : message, pas de lecteur', (t) async {
      final h = _H(t);
      late BuildContext ctx;
      await h.pump(
        preview: _preview(),
        home: Builder(
          builder: (c) {
            ctx = c;
            return const Scaffold(body: Text('ACCUEIL'));
          },
        ),
      );
      unawaited(h.container.read(continuePlaybackProvider).play(ctx, entry()));
      await h.settle();
      expect(h.players, isEmpty);
      expect(find.textContaining('Vérifiez vos addons'), findsOneWidget);
      await h.close();
    });

    testWidgets('profil enfant : contenu non autorisé refusé', (t) async {
      final h = _H(t);
      h.client.streams['org.a'] = [
        _direct('x', 'https://cdn.example.com/x.mp4'),
      ];
      late BuildContext ctx;
      await h.pump(
        preview: _preview(),
        profile: _kid,
        home: Builder(
          builder: (c) {
            ctx = c;
            return const Scaffold(body: Text('ACCUEIL'));
          },
        ),
      );
      unawaited(
        h.container.read(continuePlaybackProvider).play(ctx, entry(cert: 'R')),
      );
      await h.settle();
      expect(h.players, isEmpty);
      expect(h.client.streamCalls, isEmpty);
      expect(find.textContaining('pas autorisé'), findsOneWidget);
      await h.close();
    });
  });
}
