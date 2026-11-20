import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/app_settings.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/progress_repository.dart';
import 'package:lumio/data/title_settings_store.dart';
import 'package:lumio/player/next_episode_overlay.dart';
import 'package:lumio/player/play_router.dart' show LocalFileSource;
import 'package:lumio/player/player_controller.dart';
import 'package:lumio/player/player_screen.dart';
import 'package:lumio/player/subtitle_style.dart';
import 'package:lumio/player/tracks_controller.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/torrent/torrent_playback.dart';
import 'package:lumio/torrent/torrent_providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

import 'support/fake_network.dart';
import 'support/fake_torrent_engine.dart';

class FakeCtl extends Fake implements PlayerController {
  final _state = ValueNotifier<PlayerState>(
    const PlayerState(phase: PlayerPhase.playing),
  );
  final opened = <(String, Duration)>[];

  void emit(PlayerState s) => _state.value = s;

  @override
  ValueListenable<PlayerState> get stateListenable => _state;
  @override
  PlayerState get state => _state.value;
  @override
  Future<void> open(
    StreamItem s, {
    bool allowPrivate = false,
    bool trustedLocal = false,
    LocalFileSource? local,
    Duration start = Duration.zero,
  }) async => opened.add((s.title, start));
  @override
  void showOpening() {}
  @override
  Future<Duration?> creditsStart() async => null;
  @override
  Future<void> seekBy(Duration delta) async {}
}

class Backend implements TracksBackend {
  @override
  final audioTracks = const [
    TrackOption(id: '1', label: 'Français', lang: 'fr'),
    TrackOption(id: '2', label: 'English', lang: 'en'),
  ];
  @override
  final subtitleTracks = const <TrackOption>[];
  @override
  String? get selectedAudioId => '1';
  @override
  String? get selectedSubtitleId => null;
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  Future<void> selectAudio(String id) async {}
  @override
  Future<void> selectSubtitle(String? id) async {}
  @override
  Future<void> loadExternalSubtitle(
    String path, {
    String? title,
    String? lang,
  }) async {}
  @override
  Future<void> setSubtitleDelay(int ms) async {}
  @override
  Future<void> applySubtitleStyle(SubtitleStyle style) async {}
}

Widget host(Widget child) => MaterialApp(
  theme: ThemeData(extensions: const [LumioColors.dark]),
  home: Scaffold(body: child),
);

void main() {
  test('shouldOfferNext : 30 s avant la fin ou au chapitre générique', () {
    const dur = Duration(minutes: 40);
    expect(
      shouldOfferNext(const Duration(minutes: 39, seconds: 45), dur),
      isTrue,
    );
    expect(shouldOfferNext(const Duration(minutes: 30), dur), isFalse);
    expect(shouldOfferNext(const Duration(minutes: 1), Duration.zero), isFalse);
    expect(
      shouldOfferNext(
        const Duration(minutes: 36),
        dur,
        creditsStart: const Duration(minutes: 35),
      ),
      isTrue,
    );
  });

  test('shouldOfferNext : vidéo courte, position 0, avant 60 %', () {
    const short = Duration(seconds: 20);
    expect(shouldOfferNext(Duration.zero, short), isFalse);
    expect(shouldOfferNext(const Duration(seconds: 15), short), isFalse);
    const forty = Duration(seconds: 40);
    expect(shouldOfferNext(const Duration(seconds: 15), forty), isFalse);
    expect(shouldOfferNext(const Duration(seconds: 25), forty), isTrue);
    // Chapitre trop tôt : borné à 60 %.
    expect(
      shouldOfferNext(
        const Duration(minutes: 10),
        const Duration(minutes: 40),
        creditsStart: const Duration(minutes: 5),
      ),
      isFalse,
    );
  });

  group('parseCreditsStart', () {
    const dur = Duration(minutes: 40);
    test('Credits en fin d\'épisode', () {
      expect(
        parseCreditsStart(
          '[{"title":"Intro","time":0.0},{"title":"Credits","time":2400.5}]',
          duration: const Duration(minutes: 45),
        ),
        const Duration(milliseconds: 2400500),
      );
      expect(
        parseCreditsStart(
          '[{"title":"Générique de fin","time":2300}]',
          duration: dur,
        ),
        const Duration(seconds: 2300),
      );
    });
    test('« Opening Credits » et génériques d\'ouverture ignorés', () {
      expect(
        parseCreditsStart(
          '[{"title":"Opening Credits","time":0},'
          '{"title":"Générique d\'ouverture","time":5},'
          '{"title":"Générique de début","time":10}]',
          duration: dur,
        ),
        isNull,
      );
    });
    test('avant 50 % ignoré ; titre « de fin » préféré', () {
      expect(
        parseCreditsStart('[{"title":"Credits","time":600}]', duration: dur),
        isNull,
      );
      expect(
        parseCreditsStart(
          '[{"title":"Credits","time":1300},{"title":"End Credits","time":2300}]',
          duration: dur,
        ),
        const Duration(seconds: 2300),
      );
    });
    test('durée inconnue ou JSON illisible : null', () {
      expect(
        parseCreditsStart(
          '[{"title":"Credits","time":2300}]',
          duration: Duration.zero,
        ),
        isNull,
      );
      expect(parseCreditsStart('pas du json', duration: dur), isNull);
    });
  });

  testWidgets('décompte de 10 s puis lancement automatique', (t) async {
    var played = 0;
    await t.pumpWidget(
      host(
        NextEpisodeOverlay(
          episodeTitle: 'Épisode 2',
          onPlayNow: () => played++,
          onCancel: () => fail('annulé'),
        ),
      ),
    );
    expect(find.text('Épisode suivant dans 10 s'), findsOneWidget);
    await t.pump(const Duration(seconds: 4));
    expect(find.text('Épisode suivant dans 6 s'), findsOneWidget);
    await t.pump(const Duration(seconds: 6));
    expect(played, 1);
    await t.pump(const Duration(seconds: 5));
    expect(played, 1);
  });

  testWidgets('le décompte est suspendu en pause', (t) async {
    var played = 0;
    Widget build(bool paused) => host(
      NextEpisodeOverlay(
        episodeTitle: 'E2',
        paused: paused,
        onPlayNow: () => played++,
        onCancel: () {},
      ),
    );
    await t.pumpWidget(build(false));
    await t.pump(const Duration(seconds: 3));
    await t.pumpWidget(build(true));
    await t.pump(const Duration(seconds: 20));
    expect(played, 0);
    expect(find.text('Épisode suivant dans 7 s'), findsOneWidget);
    await t.pumpWidget(build(false));
    await t.pump(const Duration(seconds: 7));
    expect(played, 1);
  });

  testWidgets('Annuler arrête le décompte', (t) async {
    var played = 0;
    var cancelled = 0;
    await t.pumpWidget(
      host(
        NextEpisodeOverlay(
          episodeTitle: 'Épisode 2',
          onPlayNow: () => played++,
          onCancel: () => cancelled++,
        ),
      ),
    );
    await t.tap(find.text('Annuler'));
    await t.pump(const Duration(seconds: 15));
    expect((played, cancelled), (0, 1));
  });

  testWidgets('focus sur « Lire maintenant », OK au D-pad lance', (t) async {
    var played = 0;
    await t.pumpWidget(
      host(
        NextEpisodeOverlay(
          episodeTitle: 'Épisode 2',
          onPlayNow: () => played++,
          onCancel: () {},
        ),
      ),
    );
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.select);
    await t.pump();
    expect(played, 1);
  });

  group('écran du lecteur', () {
    late AppDatabase db;
    late FakeCtl ctl;
    final meta = Meta(
      id: 'tt1',
      type: 'series',
      name: 'S',
      videos: const [
        Video(id: 'tt1:1:1', title: 'Un', season: 1, episode: 1),
        Video(id: 'tt1:1:2', title: 'Deux', season: 1, episode: 2),
      ],
    );

    Future<void> pumpScreen(
      WidgetTester t, {
      required Future<StreamItem?> Function(Video) resolve,
      String videoId = 'tt1:1:1',
      StreamItem? item,
      List<Override> extra = const [],
    }) async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            titleSettingsStoreProvider.overrideWith(
              (ref) async => DriftTitleSettingsStore(db),
            ),
            subtitleStyleStoreProvider.overrideWithValue(
              SubtitleStyleStore(db),
            ),
            ...extra,
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: const [LumioColors.dark]),
            home: PlayerScreen(
              item:
                  item ??
                  StreamItem(
                    addonId: 'ad',
                    title: 'Un',
                    url: Uri.parse('https://x.test/1.mp4'),
                  ),
              metaId: 'tt1',
              videoId: videoId,
              meta: meta,
              resolveNext: resolve,
              profileId: 'p',
              controller: ctl,
              videoBuilder: (_) => const ColoredBox(color: Colors.black),
              tracksBackend: (_) => Backend(),
            ),
          ),
        ),
      );
      await t.pump();
    }

    Future<void> leave(WidgetTester t) async {
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 6));
    }

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      ctl = FakeCtl();
    });
    tearDown(() => db.close());

    testWidgets('invite à 30 s de la fin, décompte, ouvre le suivant', (
      t,
    ) async {
      var resolved = 0;
      await pumpScreen(
        t,
        resolve: (v) async {
          resolved++;
          return StreamItem(
            addonId: 'ad',
            title: v.title,
            url: Uri.parse('https://x.test/2.mp4'),
          );
        },
      );
      ctl.emit(
        const PlayerState(
          phase: PlayerPhase.playing,
          position: Duration(minutes: 20),
          duration: Duration(minutes: 40),
        ),
      );
      await t.pump();
      expect(find.text('Lire maintenant'), findsNothing);
      ctl.emit(
        const PlayerState(
          phase: PlayerPhase.playing,
          position: Duration(minutes: 39, seconds: 40),
          duration: Duration(minutes: 40),
        ),
      );
      await t.pump();
      expect(find.text('Lire maintenant'), findsOneWidget);
      await t.pump(const Duration(seconds: 10));
      await t.pump();
      expect(resolved, 1);
      expect(ctl.opened.map((e) => e.$1), ['Un', 'Deux']);
      expect(find.text('Lire maintenant'), findsNothing);
      // L'épisode terminé est vu, le suivant est proposé à 0 s.
      final list = await t.runAsync(
        () => ProgressRepository(db).continueWatching('p').first,
      );
      expect(list!.single.videoId, 'tt1:1:2');
      await leave(t);
    });

    testWidgets('Annuler : rien ne se lance, pas de nouvelle invite', (
      t,
    ) async {
      await pumpScreen(t, resolve: (v) async => fail('résolu'));
      ctl.emit(
        const PlayerState(
          phase: PlayerPhase.playing,
          position: Duration(minutes: 39, seconds: 40),
          duration: Duration(minutes: 40),
        ),
      );
      await t.pump();
      await t.tap(find.text('Annuler'));
      await t.pump(const Duration(seconds: 12));
      expect(find.text('Lire maintenant'), findsNothing);
      ctl.emit(
        const PlayerState(
          phase: PlayerPhase.playing,
          position: Duration(minutes: 39, seconds: 50),
          duration: Duration(minutes: 40),
        ),
      );
      await t.pump();
      expect(find.text('Lire maintenant'), findsNothing);
      expect(ctl.opened, hasLength(1));
      await leave(t);
    });

    testWidgets('retour en arrière avant le déclenchement : invite effacée', (
      t,
    ) async {
      await pumpScreen(t, resolve: (v) async => fail('résolu'));
      ctl.emit(
        const PlayerState(
          phase: PlayerPhase.playing,
          position: Duration(minutes: 39, seconds: 40),
          duration: Duration(minutes: 40),
        ),
      );
      await t.pump();
      expect(find.text('Lire maintenant'), findsOneWidget);
      ctl.emit(
        const PlayerState(
          phase: PlayerPhase.playing,
          position: Duration(minutes: 20),
          duration: Duration(minutes: 40),
        ),
      );
      await t.pump();
      expect(find.text('Lire maintenant'), findsNothing);
      await leave(t);
    });

    testWidgets('vidéo de 20 s : jamais d\'invite', (t) async {
      await pumpScreen(t, resolve: (v) async => fail('résolu'));
      ctl.emit(
        const PlayerState(
          phase: PlayerPhase.playing,
          position: Duration(seconds: 1),
          duration: Duration(seconds: 20),
        ),
      );
      await t.pump();
      expect(find.text('Lire maintenant'), findsNothing);
      await leave(t);
    });

    testWidgets('flux introuvable : « Épisode suivant indisponible »', (
      t,
    ) async {
      await pumpScreen(t, resolve: (v) async => null);
      ctl.emit(
        const PlayerState(
          phase: PlayerPhase.playing,
          position: Duration(minutes: 39, seconds: 40),
          duration: Duration(minutes: 40),
        ),
      );
      await t.pump();
      await t.tap(find.text('Lire maintenant'));
      await t.pump();
      await t.pump();
      expect(find.text('Épisode suivant indisponible'), findsOneWidget);
      expect(ctl.opened, hasLength(1));
      await leave(t);
    });

    testWidgets('dernier épisode : aucune invite', (t) async {
      await pumpScreen(
        t,
        videoId: 'tt1:1:2',
        resolve: (v) async => fail('résolu'),
      );
      ctl.emit(
        const PlayerState(
          phase: PlayerPhase.playing,
          position: Duration(minutes: 39, seconds: 40),
          duration: Duration(minutes: 40),
        ),
      );
      await t.pump();
      expect(find.text('Lire maintenant'), findsNothing);
      await leave(t);
    });

    testWidgets('reprise à la position enregistrée (40 %)', (t) async {
      await ProgressRepository(db).save(
        'p',
        'tt1',
        'tt1:1:1',
        const Duration(minutes: 16),
        const Duration(minutes: 40),
      );
      await pumpScreen(t, resolve: (v) async => null);
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await t.pump();
      expect(ctl.opened.single.$2, const Duration(minutes: 16));
      await leave(t);
    });

    testWidgets('sortie : la position est enregistrée', (t) async {
      await pumpScreen(t, resolve: (v) async => null);
      ctl.emit(
        const PlayerState(
          phase: PlayerPhase.playing,
          position: Duration(minutes: 8),
          duration: Duration(minutes: 40),
        ),
      );
      await t.pump();
      await t.pumpWidget(const SizedBox());
      final e = await t.runAsync(
        () => ProgressRepository(db).get('p', 'tt1:1:1'),
      );
      expect(e!.position, const Duration(minutes: 8));
    });

    testWidgets('sortie : l\'identité du flux regardé est enregistrée', (
      t,
    ) async {
      await pumpScreen(t, resolve: (v) async => null);
      ctl.emit(
        const PlayerState(
          phase: PlayerPhase.playing,
          position: Duration(minutes: 8),
          duration: Duration(minutes: 40),
        ),
      );
      await t.pump();
      await t.pumpWidget(const SizedBox());
      final e = await t.runAsync(
        () => ProgressRepository(db).get('p', 'tt1:1:1'),
      );
      final played = StreamItem(
        addonId: 'ad',
        title: 'Un',
        url: Uri.parse('https://x.test/1.mp4'),
      );
      expect(e!.streamAddonId, 'ad');
      expect(e.streamKey, played.identityKey);
      // Jamais l'URL en clair dans la progression.
      expect(e.streamKey, isNot(contains('x.test')));
    });

    testWidgets('torrent : identité infoHash+fileIdx, reprise à la position', (
      t,
    ) async {
      final torrent = StreamItem(
        addonId: 'ad',
        title: 'Sintel',
        infoHash: '08ada5a7a6183aae1e09d831df6748d566095a10',
        fileIdx: 2,
      );
      await ProgressRepository(db).save(
        'p',
        'tt1',
        'tt1:1:1',
        const Duration(minutes: 16),
        const Duration(minutes: 40),
      );
      await pumpScreen(
        t,
        resolve: (v) async => null,
        item: torrent,
        extra: [
          torrentPrivacyProvider.overrideWithValue(
            OpenPrivacy(AppSettingsStore(db)),
          ),
          torrentPlaybackFactoryProvider.overrideWithValue(
            () => TorrentPlayback(engine: FakeTorrentEngine()),
          ),
        ],
      );
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await t.pump();
      // Le moteur démarré, la position enregistrée est celle du démarrage.
      expect(ctl.opened.single.$2, const Duration(minutes: 16));
      ctl.emit(
        const PlayerState(
          phase: PlayerPhase.playing,
          position: Duration(minutes: 17),
          duration: Duration(minutes: 40),
        ),
      );
      await t.pump();
      await t.pumpWidget(const SizedBox());
      final e = await t.runAsync(
        () => ProgressRepository(db).get('p', 'tt1:1:1'),
      );
      expect(e!.streamKey, 't:08ada5a7a6183aae1e09d831df6748d566095a10:2');
      expect(e.streamAddonId, 'ad');
    });
  });
}
