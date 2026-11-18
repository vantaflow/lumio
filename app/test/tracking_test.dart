import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio/data/tracking_repository.dart';
import 'package:lumio/features/settings/settings_screen.dart';
import 'package:lumio/features/tracking/tracking_providers.dart';
import 'package:lumio/features/tracking/tracking_screen.dart';
import 'package:lumio/l10n/app_localizations_fr.dart';
import 'package:lumio/l10n/error_messages.dart';
import 'package:lumio/player/play_router.dart' show LocalFileSource;
import 'package:lumio/player/playback_events.dart';
import 'package:lumio/player/playback_events_provider.dart';
import 'package:lumio/player/player_controller.dart';
import 'package:lumio/player/player_screen.dart';
import 'package:lumio/player/subtitle_style.dart';
import 'package:lumio/player/tracks_controller.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'support/app_harness.dart';

/// Faux Trakt en mémoire : journal des POST et statut des scrobbles.
class _MemTrakt implements HttpPostFetcher {
  final posts = <(String, Map<String, dynamic>, Map<String, String>)>[];
  int scrobbleStatus = 201;
  int deviceTokenStatus = 400;
  int tokenCalls = 0;

  FetchResponse _json(Object o, [int status = 200]) =>
      FetchResponse(status: status, body: utf8.encode(jsonEncode(o)));

  @override
  Future<FetchResponse> post(
    Uri url, {
    required List<int> body,
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) async {
    final b = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
    posts.add((url.path, b, headers));
    switch (url.path) {
      case '/oauth/device/code':
        return _json({
          'device_code': 'dev-1',
          'user_code': 'ABCD1234',
          'verification_url': 'https://trakt.tv/activate',
          'expires_in': 600,
          'interval': 5,
        });
      case '/oauth/device/token':
        tokenCalls++;
        return deviceTokenStatus == 200
            ? _json({
                'access_token': 'acc-new',
                'refresh_token': 'ref-new',
                'expires_in': 7776000,
                'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              })
            : _json({}, deviceTokenStatus);
      case '/oauth/revoke':
        return _json({});
      default:
        return _json({}, scrobbleStatus);
    }
  }

  @override
  Future<FetchResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) => throw UnimplementedError();

  List<String> get scrobblePaths =>
      posts.map((p) => p.$1).where((p) => p.startsWith('/scrobble')).toList();
}

class _FakeCtl extends Fake implements PlayerController {
  final value = ValueNotifier<PlayerState>(
    const PlayerState(phase: PlayerPhase.opening),
  );
  @override
  ValueListenable<PlayerState> get stateListenable => value;
  @override
  PlayerState get state => value.value;
  @override
  Future<void> open(
    StreamItem s, {
    bool allowPrivate = false,
    bool trustedLocal = false,
    LocalFileSource? local,
    Duration start = Duration.zero,
  }) async {}
}

class _Backend implements TracksBackend {
  @override
  final audioTracks = const <TrackOption>[];
  @override
  final subtitleTracks = const <TrackOption>[];
  @override
  String? get selectedAudioId => null;
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

Future<void> _withDb(Future<void> Function(AppDatabase db) body) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = AppDatabase(NativeDatabase.memory());
  try {
    await body(db);
  } finally {
    await db.close();
  }
}

ScrobbleEvent _ev(String id, {ScrobbleAction a = ScrobbleAction.stop}) =>
    ScrobbleEvent(
      action: a,
      imdbId: id,
      progress: 50,
      at: DateTime.utc(2026, 1, 1),
    );

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('migration v9 vers v10 : file créée, données conservées', () async {
    final old = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE settings (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)',
          );
          raw.execute("INSERT INTO settings VALUES ('ui_locale', 'en')");
          raw.execute('PRAGMA user_version = 9');
        },
      ),
    );
    addTearDown(old.close);
    expect(await old.select(old.scrobbleQueueTable).get(), isEmpty);
    expect((await old.select(old.settings).get()).single.value, 'en');
    final store = DriftScrobbleStore(old);
    final id = await store.add(
      'p',
      'trakt',
      _ev('tt1'),
      DateTime.utc(2026, 1, 1, 1),
    );
    final row = (await store.all()).single;
    expect((row.id, row.profileId, row.event.imdbId), (id, 'p', 'tt1'));
    expect(row.nextAttemptAt, DateTime.utc(2026, 1, 1, 1));
    await store.markFailed(id, 2, DateTime.utc(2026, 1, 1, 2));
    expect((await store.all()).single.attempts, 2);
    await store.remove(id);
    expect(await store.all(), isEmpty);
  });

  group('service de suivi', () {
    late AppDatabase db;
    late MemorySecretStore secrets;
    late _MemTrakt net;
    late ProviderContainer c;
    var now = DateTime.utc(2026, 1, 1, 12);

    ProviderContainer make({
      String id = 'cid',
      String secret = 'sec',
      bool token = true,
    }) {
      db = AppDatabase(NativeDatabase.memory());
      secrets = MemorySecretStore();
      net = _MemTrakt();
      now = DateTime.now().toUtc();
      if (token) {
        secrets.write(
          'trakt.token.default',
          jsonEncode(
            TrackerToken(
              access: 'acc-0',
              refresh: 'ref-0',
              expiresAt: now.add(const Duration(days: 30)),
            ).toJson(),
          ),
        );
      }
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          secretStoreProvider.overrideWithValue(secrets),
          trackingFetcherProvider.overrideWithValue(net),
          trackingClockProvider.overrideWithValue(() => now),
          traktCredentialsProvider.overrideWithValue((id: id, secret: secret)),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      return container;
    }

    PlaybackEvent play(
      PlaybackAction a, {
      String meta = 'tt1',
      String? video,
      String profile = defaultProfileId,
      double p = 30,
    }) => PlaybackEvent(
      action: a,
      profileId: profile,
      metaId: meta,
      videoId: video ?? meta,
      progress: p,
    );

    test(
      'lecture : start/pause/stop envoyés avec les en-têtes Trakt',
      () async {
        c = make();
        final svc = c.read(trackingServiceProvider);
        await svc.onPlayback(play(PlaybackAction.start, p: 1));
        await svc.onPlayback(play(PlaybackAction.pause, p: 30));
        await svc.onPlayback(play(PlaybackAction.stop, p: 95));
        expect(net.scrobblePaths, [
          '/scrobble/start',
          '/scrobble/pause',
          '/scrobble/stop',
        ]);
        final first = net.posts.first;
        expect(first.$3['trakt-api-key'], 'cid');
        expect(first.$3['trakt-api-version'], '2');
        expect(first.$3['authorization'], 'Bearer acc-0');
        expect(first.$2['progress'], 1);
      },
    );

    test('épisode : identifiant IMDb de la série, saison, numéro', () async {
      c = make();
      await c
          .read(trackingServiceProvider)
          .onPlayback(
            play(PlaybackAction.start, meta: 'tt7', video: 'tt7:2:3'),
          );
      final b = net.posts.single.$2;
      expect(b['show'], {
        'ids': {'imdb': 'tt7'},
      });
      expect(b['episode'], {'season': 2, 'number': 3});
    });

    test('sans identifiant IMDb (local, Jellyfin) : rien d\'envoyé', () async {
      c = make();
      final svc = c.read(trackingServiceProvider);
      await svc.onPlayback(play(PlaybackAction.start, meta: 'local:abc'));
      await svc.onPlayback(
        play(PlaybackAction.start, meta: 'jellyfin:s:i', video: 'jellyfin:s:i'),
      );
      expect(net.posts, isEmpty);
    });

    test('non configuré : rien d\'envoyé, rien en file', () async {
      c = make(id: '', secret: '');
      await c
          .read(trackingServiceProvider)
          .onPlayback(play(PlaybackAction.stop));
      expect(net.posts, isEmpty);
      expect(await c.read(scrobbleQueueProvider).pending(), 0);
    });

    test('non connecté : rien d\'envoyé', () async {
      c = make(token: false);
      await c
          .read(trackingServiceProvider)
          .onPlayback(play(PlaybackAction.stop));
      expect(net.posts, isEmpty);
    });

    test('Trakt en panne : mis en file puis rejoué', () async {
      c = make();
      net.scrobbleStatus = 503;
      final svc = c.read(trackingServiceProvider);
      await svc.onPlayback(play(PlaybackAction.stop, p: 96));
      expect(await c.read(scrobbleQueueProvider).pending(), 1);
      net.scrobbleStatus = 201;
      now = now.add(const Duration(minutes: 2));
      final r = await svc.flush();
      expect(r.sent, 1);
      expect(await c.read(scrobbleQueueProvider).pending(), 0);
      expect(net.scrobblePaths, ['/scrobble/stop', '/scrobble/stop']);
    });

    test('profil enfant : bloqué sauf autorisation parentale', () async {
      c = make();
      final kid = await c
          .read(profileRepositoryProvider)
          .create('Léa', isKid: true);
      await secrets.write(
        'trakt.token.${kid.id}',
        await secrets.read('trakt.token.default') ?? '',
      );
      final svc = c.read(trackingServiceProvider);
      await svc.onPlayback(play(PlaybackAction.stop, profile: kid.id));
      expect(net.posts, isEmpty);
      await c.read(trackingRepositoryProvider).setKidAllowed(kid.id, true);
      await svc.onPlayback(play(PlaybackAction.stop, profile: kid.id));
      expect(net.scrobblePaths, ['/scrobble/stop']);
    });

    test(
      'deux profils : chaque requête porte le jeton de son profil',
      () async {
        c = make();
        final other = await c.read(profileRepositoryProvider).create('Bob');
        await secrets.write(
          'trakt.token.${other.id}',
          jsonEncode(
            TrackerToken(
              access: 'acc-bob',
              refresh: 'ref-bob',
              expiresAt: now.add(const Duration(days: 30)),
            ).toJson(),
          ),
        );
        final svc = c.read(trackingServiceProvider);
        await svc.onPlayback(play(PlaybackAction.stop, meta: 'tt1'));
        await svc.onPlayback(
          play(PlaybackAction.stop, meta: 'tt2', profile: other.id),
        );
        final auth = net.posts.map((p) => p.$3['authorization']).toList();
        expect(auth, ['Bearer acc-0', 'Bearer acc-bob']);
      },
    );

    test('jeton refusé (401 persistant) : drapeau de reconnexion', () async {
      c = make();
      net.scrobbleStatus = 401;
      await c
          .read(trackingServiceProvider)
          .onPlayback(play(PlaybackAction.stop));
      final repo = c.read(trackingRepositoryProvider);
      expect(await repo.reauthRequired(traktId, defaultProfileId), isTrue);
      expect(await c.read(scrobbleQueueProvider).pending(), 1);
      // Un seul renouvellement tenté.
      expect(net.posts.where((p) => p.$1 == '/oauth/token'), hasLength(1));
    });

    test('déconnexion : jeton révoqué et supprimé, file vidée', () async {
      c = make();
      net.scrobbleStatus = 503;
      final svc = c.read(trackingServiceProvider);
      await svc.onPlayback(play(PlaybackAction.stop));
      await svc.disconnect(defaultProfileId, traktId);
      expect(secrets.snapshot.keys.where((k) => k.contains('token')), isEmpty);
      expect(await c.read(scrobbleQueueProvider).pending(), 0);
      expect(net.posts.any((p) => p.$1 == '/oauth/revoke'), isTrue);
    });

    test('jetons : jamais dans SQLite', () async {
      c = make();
      net.scrobbleStatus = 503;
      await c
          .read(trackingServiceProvider)
          .onPlayback(play(PlaybackAction.stop));
      final rows = await db.select(db.scrobbleQueueTable).get();
      expect(rows.single.eventJson, isNot(contains('acc-0')));
      expect(rows.single.eventJson, isNot(contains('ref-0')));
    });

    test('profil enfant sans réglage ni jeton : aucun service actif', () async {
      c = make(token: false);
      expect(
        await c.read(trackingServiceProvider).activeTrackers(defaultProfileId),
        isEmpty,
      );
    });
  });

  group('lecteur', () {
    testWidgets('émet start, pause, stop avec l\'avancement', (t) async {
      await _withDb((db) async {
        final events = PlaybackEvents();
        final got = <PlaybackEvent>[];
        events.addListener(got.add);
        final ctl = _FakeCtl();
        await t.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              playbackEventsProvider.overrideWithValue(events),
            ],
            child: MaterialApp(
              theme: ThemeData(extensions: const [LumioColors.dark]),
              home: PlayerScreen(
                item: StreamItem(
                  addonId: 'ad',
                  title: 'Film',
                  url: Uri.parse('https://x.test/v.mp4'),
                ),
                metaId: 'tt1',
                controller: ctl,
                videoBuilder: (_) => const ColoredBox(color: Colors.black),
                tracksBackend: (_) => _Backend(),
              ),
            ),
          ),
        );
        ctl.value.value = const PlayerState(
          phase: PlayerPhase.playing,
          position: Duration(seconds: 10),
          duration: Duration(seconds: 100),
        );
        ctl.value.value = const PlayerState(
          phase: PlayerPhase.paused,
          position: Duration(seconds: 40),
          duration: Duration(seconds: 100),
        );
        ctl.value.value = const PlayerState(
          phase: PlayerPhase.playing,
          position: Duration(seconds: 40),
          duration: Duration(seconds: 100),
        );
        await t.pumpWidget(const SizedBox());
        expect(got.map((e) => e.action), [
          PlaybackAction.start,
          PlaybackAction.pause,
          PlaybackAction.start,
          PlaybackAction.stop,
        ]);
        expect(got.first.progress, closeTo(10, 0.01));
        expect(got[1].progress, closeTo(40, 0.01));
        expect(got.last.metaId, 'tt1');
        await t.pump(const Duration(milliseconds: 100));
      });
    });

    testWidgets('sans identifiant de titre : aucun événement', (t) async {
      await _withDb((db) async {
        final events = PlaybackEvents();
        final got = <PlaybackEvent>[];
        events.addListener(got.add);
        final ctl = _FakeCtl();
        await t.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              playbackEventsProvider.overrideWithValue(events),
            ],
            child: MaterialApp(
              theme: ThemeData(extensions: const [LumioColors.dark]),
              home: PlayerScreen(
                item: StreamItem(
                  addonId: 'ad',
                  title: 'Film',
                  url: Uri.parse('https://x.test/v.mp4'),
                ),
                controller: ctl,
                videoBuilder: (_) => const ColoredBox(color: Colors.black),
                tracksBackend: (_) => _Backend(),
              ),
            ),
          ),
        );
        ctl.value.value = const PlayerState(phase: PlayerPhase.playing);
        await t.pumpWidget(const SizedBox());
        expect(got, isEmpty);
        await t.pump(const Duration(milliseconds: 100));
      });
    });

    test('un écouteur défaillant ne casse pas l\'émission', () {
      final events = PlaybackEvents();
      var n = 0;
      events.addListener((_) => throw StateError('x'));
      events.addListener((_) async => throw StateError('y'));
      events.addListener((_) => n++);
      events.emit(
        const PlaybackEvent(
          action: PlaybackAction.start,
          profileId: 'p',
          metaId: 'tt1',
          videoId: 'tt1',
          progress: 0,
        ),
      );
      expect(n, 1);
    });
  });

  group('écran', () {
    late _MemTrakt net;
    List<Override> over({String id = 'cid', String secret = 'sec'}) {
      net = _MemTrakt();
      return [
        trackingFetcherProvider.overrideWithValue(net),
        traktCredentialsProvider.overrideWithValue((id: id, secret: secret)),
        trackingSleepProvider.overrideWithValue(
          (_) => Future<void>.delayed(const Duration(milliseconds: 30)),
        ),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
      ];
    }

    testWidgets('réglages : section Suivi (Trakt, Simkl)', (t) async {
      final h = AppHarness(t);
      await h.pump(const SettingsScreen(), extra: over());
      expect(find.text('Suivi (Trakt, Simkl)'), findsWidgets);
      expect(
        find.byKey(const ValueKey('setting:tracking'), skipOffstage: false),
        findsOneWidget,
      );
      await h.close();
    });

    testWidgets('non configuré : message et aucun bouton de connexion', (
      t,
    ) async {
      final h = AppHarness(t);
      await h.pump(
        const TrackingScreen(),
        extra: over(id: '', secret: ''),
      );
      expect(find.textContaining('Non configuré'), findsOneWidget);
      expect(find.byKey(const ValueKey('tracking-connect')), findsNothing);
      expect(net.posts, isEmpty);
      await h.close();
    });

    testWidgets('connexion : code, adresse et QR, puis jeton enregistré', (
      t,
    ) async {
      final h = AppHarness(t);
      await h.pump(const TrackingScreen(), extra: over());
      expect(find.textContaining('Non connecté'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('tracking-connect')));
      await h.settle(3);
      expect(find.byKey(const ValueKey('tracking-auth-code')), findsOneWidget);
      expect(find.text('ABCD1234'), findsOneWidget);
      expect(find.text('https://trakt.tv/activate'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      // L'utilisateur autorise : le prochain sondage rend le jeton.
      net.deviceTokenStatus = 200;
      await h.settle(4);
      expect(find.byKey(const ValueKey('tracking-auth-code')), findsNothing);
      expect(find.textContaining('Connecté'), findsWidgets);
      expect(find.byKey(const ValueKey('tracking-disconnect')), findsOneWidget);
      await h.close();
    });

    testWidgets('code refusé : message et nouveau code', (t) async {
      final h = AppHarness(t);
      await h.pump(const TrackingScreen(), extra: over());
      await t.tap(find.byKey(const ValueKey('tracking-connect')));
      await h.settle(2);
      net.deviceTokenStatus = 418;
      await h.settle(4);
      expect(find.byKey(const ValueKey('tracking-auth-error')), findsOneWidget);
      expect(find.byKey(const ValueKey('tracking-auth-new')), findsOneWidget);
      await h.close();
    });

    testWidgets('profil enfant : interrupteur parental, connexion bloquée', (
      t,
    ) async {
      final h = AppHarness(t);
      await h.pump(const TrackingScreen(), extra: over());
      final kid = await t.runAsync(
        () => h.container
            .read(profileRepositoryProvider)
            .create('Léa', isKid: true),
      );
      h.container.read(currentProfileProvider.notifier).select(kid);
      await h.settle();
      final connect = find.byKey(const ValueKey('tracking-connect'));
      expect(tester(t, connect).onPressed, isNull);
      await t.tap(find.byKey(const ValueKey('tracking-kid')));
      await h.settle();
      expect(tester(t, connect).onPressed, isNotNull);
      await h.close();
    });
  });

  test('messages d\'erreur de suivi', () {
    final l = AppLocalizationsFr();
    expect(
      l10nForError(l, const TrackerNotConfigured()),
      l.trackingNotConfigured,
    );
    expect(l10nForError(l, const TrackerReauthRequired()), l.trackingReauth);
    expect(l10nForError(l, const TrackerAuthDenied()), l.trackingAuthDenied);
    expect(l10nForError(l, const TrackerAuthExpired()), l.trackingAuthExpired);
    expect(
      l10nForError(l, const TrackerUnavailable()),
      l.trackingAuthUnavailable,
    );
  });
}

ButtonStyleButton tester(WidgetTester t, Finder f) =>
    t.widget<ButtonStyleButton>(f);
