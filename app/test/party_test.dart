import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/party_client.dart';
import 'package:lumio/data/title_settings_store.dart';
import 'package:lumio/l10n/app_localizations.dart';
import 'package:lumio/player/play_router.dart' show LocalFileSource;
import 'package:lumio/player/player_controller.dart';
import 'package:lumio/player/player_screen.dart';
import 'package:lumio/player/subtitle_style.dart';
import 'package:lumio/player/tracks_controller.dart';
import 'package:lumio/providers.dart';
import 'package:lumio_core/lumio_core.dart' show StreamItem;
import 'package:lumio/features/party/party_providers.dart';
import 'package:lumio/features/party/party_screen.dart';
import 'package:lumio/features/party/party_session.dart';
import 'package:lumio/ui/theme.dart';
import 'package:qr_flutter/qr_flutter.dart';

const roomId = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';
const code = 'KR74PQ2X';

class FakeHttp implements PartyHttp {
  final requests =
      <({String method, Uri url, Map<String, String> headers, String? body})>[];
  PartyHttpResponse Function(String method, Uri url)? handler;

  @override
  Future<PartyHttpResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    String? body,
  }) async {
    requests.add((method: method, url: url, headers: headers, body: body));
    return handler!(method, url);
  }
}

class FakeChannel implements PartyChannel {
  final incoming = StreamController<String>();
  final sent = <Map<String, dynamic>>[];
  bool closed = false;

  @override
  Stream<String> get messages => incoming.stream;

  @override
  void send(String message) =>
      sent.add(jsonDecode(message) as Map<String, dynamic>);

  @override
  Future<void> close() async => closed = true;

  void emit(Map<String, dynamic> m) => incoming.add(jsonEncode(m));
  Iterable<Map<String, dynamic>> sentOf(String type) =>
      sent.where((m) => m['type'] == type);
}

class FakePlayer implements PartyPlayer {
  @override
  Duration position = Duration.zero;
  @override
  bool playing = false;
  final seeks = <Duration>[];
  final plays = <bool>[];

  @override
  Future<void> seek(Duration p) async {
    seeks.add(p);
    position = p;
  }

  @override
  Future<void> setPlaying(bool v) async {
    plays.add(v);
    playing = v;
  }
}

Map<String, dynamic> hello({
  bool host = false,
  bool allControl = false,
  int participants = 1,
  Map<String, dynamic>? state,
  String? metaId,
  String? mediaType,
}) => {
  'type': 'hello',
  'participants': participants,
  'host': host,
  'allControl': allControl,
  'metaId': metaId,
  'mediaType': mediaType,
  'expiresAt': DateTime.now()
      .add(const Duration(hours: 6))
      .millisecondsSinceEpoch,
  'state': state,
};

void main() {
  late FakeHttp http;
  late FakeChannel channel;
  late List<({Uri url, List<String> protocols})> connects;
  Object? connectError;

  setUp(() async {
    http = FakeHttp();
    channel = FakeChannel();
    connects = [];
    connectError = null;
  });

  PartyClient client() => PartyClient(
    'https://api.example.com',
    http: http,
    connector: (url, protocols) async {
      connects.add((url: url, protocols: protocols));
      final e = connectError;
      if (e != null) {
        connectError = null;
        throw e;
      }
      return channel;
    },
  );

  group('lien d\'invitation', () {
    test('aller-retour et tolérance au texte autour', () {
      final link = partyLink(roomId, code).toString();
      expect(link, 'lumio://party?room=$roomId&code=$code');
      final p = parsePartyLink('Rejoins-moi : $link  à ce soir');
      expect(p, (roomId: roomId, code: code));
      expect(parsePartyLink(link.toLowerCase())?.code, code);
    });

    test('refuse un lien invalide', () {
      expect(parsePartyLink(''), isNull);
      expect(
        parsePartyLink('https://x.example/?room=$roomId&code=$code'),
        isNull,
      );
      expect(parsePartyLink('lumio://party?room=zz&code=$code'), isNull);
      expect(parsePartyLink('lumio://party?room=$roomId&code=ABC'), isNull);
      expect(
        parsePartyLink('lumio://party?room=$roomId&code=O0O0O0O0'),
        isNull,
      );
    });
  });

  group('PartyClient', () {
    test('create : POST sans compte, ne transmet que le metaId', () async {
      http.handler = (m, u) => PartyHttpResponse(
        201,
        jsonEncode({
          'roomId': roomId,
          'inviteCode': code,
          'hostKey': 'hk1',
          'expiresAt': 1800000000000,
        }),
      );
      final info = await client().create(metaId: 'tt1', type: 'series');
      expect(info.roomId, roomId);
      expect(info.inviteCode, code);
      final r = http.requests.single;
      expect(r.url.path, '/rooms');
      expect(r.headers.containsKey('authorization'), isFalse);
      expect(info.hostKey, 'hk1');
      expect(jsonDecode(r.body!), {'metaId': 'tt1', 'type': 'series'});
    });

    test('create : 429 et erreurs serveur traduits', () async {
      http.handler = (m, u) => const PartyHttpResponse(429, '{}');
      await expectLater(
        client().create(),
        throwsA(
          isA<PartyException>().having(
            (e) => e.code,
            'code',
            PartyErrorCode.rateLimited,
          ),
        ),
      );
      http.handler = (m, u) => const PartyHttpResponse(500, '{}');
      await expectLater(
        client().create(),
        throwsA(
          isA<PartyException>().having(
            (e) => e.code,
            'code',
            PartyErrorCode.unavailable,
          ),
        ),
      );
    });

    test(
      'connect : wss, code en paramètre, aucune clé pour un invité',
      () async {
        await client().connect(roomId, code);
        final c = connects.single;
        expect(c.url.scheme, 'wss');
        expect(c.url.path, '/room/$roomId');
        expect(c.url.queryParameters, {'code': code});
        expect(c.protocols, ['lumio.v1']);
      },
    );

    test(
      'connect : la clé de l\'hôte part dans le sous-protocole seulement',
      () async {
        await client().connect(roomId, code, hostKey: 'hk1');
        final c = connects.single;
        expect(c.url.toString(), isNot(contains('hk1')));
        expect(c.protocols, ['lumio.v1', 'hk1']);
      },
    );

    test('adresse non https refusée (sauf localhost)', () {
      expect(
        () => PartyClient('http://example.com'),
        throwsA(isA<PartyException>()),
      );
      expect(() => PartyClient(''), throwsA(isA<PartyException>()));
      expect(PartyClient('http://localhost:8787'), isA<PartyClient>());
    });

    test('connect : statuts HTTP traduits', () async {
      for (final (status, expected) in [
        (403, PartyErrorCode.wrongCode),
        (404, PartyErrorCode.notFound),
        (409, PartyErrorCode.full),
        (429, PartyErrorCode.rateLimited),
      ]) {
        connectError = WebSocketException(
          'was not upgraded to websocket, HTTP status code: $status',
        );
        await expectLater(
          client().connect(roomId, code),
          throwsA(
            isA<PartyException>().having((e) => e.code, 'code', expected),
          ),
          reason: '$status',
        );
      }
    });
  });

  group('PartySession', () {
    late DateTime clock;
    PartySession session({bool host = false}) => PartySession(
      client: client(),
      roomId: roomId,
      inviteCode: code,
      host: host,
      now: () => clock,
      heartbeat: const Duration(hours: 1),
      pingEvery: const Duration(hours: 1),
    );
    setUp(() => clock = DateTime(2026, 11, 18, 20));
    Future<void> pump() => Future<void>.delayed(Duration.zero);

    test(
      'hello : nombre, rôle, titre ; le retardataire se cale sur la position',
      () async {
        final s = session();
        final p = FakePlayer()..position = const Duration(seconds: 3);
        s.attach(p);
        await s.start();
        channel.emit(
          hello(
            participants: 3,
            metaId: 'tt9',
            state: {'positionMs': 60000, 'playing': true, 'sentAt': 1},
          ),
        );
        await pump();
        expect(s.value.status, PartyStatus.connected);
        expect(s.value.participants, 3);
        expect(s.value.metaId, 'tt9');
        expect(s.value.host, isFalse);
        expect(p.seeks, [const Duration(seconds: 60)]);
        expect(p.plays, [true]);
        s.dispose();
      },
    );

    test('état distant : seek si > 1,5 s, rien sinon', () async {
      final s = session();
      final p = FakePlayer()
        ..position = const Duration(seconds: 100)
        ..playing = true;
      s.attach(p);
      await s.start();
      channel.emit(hello());
      channel.emit({
        'type': 'state',
        'positionMs': 100500,
        'playing': true,
        'sentAt': 1,
      });
      await pump();
      expect(p.seeks, isEmpty);
      channel.emit({
        'type': 'state',
        'positionMs': 103000,
        'playing': true,
        'sentAt': 1,
      });
      await pump();
      expect(p.seeks, [const Duration(seconds: 103)]);
      channel.emit({
        'type': 'state',
        'positionMs': 103000,
        'playing': false,
        'sentAt': 1,
      });
      await pump();
      expect(p.plays, [false]);
      s.dispose();
    });

    test('compte de participants et bascule de contrôle suivis', () async {
      final s = session();
      await s.start();
      channel.emit(hello());
      channel.emit({'type': 'join', 'participants': 2});
      await pump();
      expect(s.value.participants, 2);
      channel.emit({'type': 'leave', 'participants': 1});
      channel.emit({'type': 'control', 'allControl': true});
      await pump();
      expect(s.value.participants, 1);
      expect(s.value.allControl, isTrue);
      s.dispose();
    });

    test(
      'l\'hôte diffuse pause/lecture et sauts ; seuls position et état partent',
      () async {
        final s = session(host: true);
        final p = FakePlayer()..position = const Duration(seconds: 10);
        s.attach(p);
        await s.start();
        channel.emit(hello(host: true));
        await pump();
        s.localChanged(); // premier état
        expect(channel.sentOf('state'), hasLength(1));
        clock = clock.add(const Duration(seconds: 1));
        p.playing = true;
        s.localChanged(); // lecture démarrée
        expect(channel.sentOf('state'), hasLength(2));
        expect(channel.sentOf('state').last['playing'], isTrue);
        clock = clock.add(const Duration(seconds: 1));
        p.position = const Duration(seconds: 80); // saut
        s.localChanged();
        expect(channel.sentOf('state'), hasLength(3));
        for (final m in channel.sentOf('state')) {
          expect(m.keys.toSet(), {'type', 'positionMs', 'playing', 'sentAt'});
        }
        // Pas de changement : rien d'envoyé.
        clock = clock.add(const Duration(milliseconds: 500));
        p.position = const Duration(seconds: 80, milliseconds: 500);
        s.localChanged();
        expect(channel.sentOf('state'), hasLength(3));
        s.dispose();
      },
    );

    test('un invité sans droit d\'écriture ne diffuse rien', () async {
      final s = session();
      final p = FakePlayer();
      s.attach(p);
      await s.start();
      channel.emit(hello());
      await pump();
      p.playing = true;
      s.localChanged();
      expect(channel.sentOf('state'), isEmpty);
      // Avec « tout le monde peut contrôler », il diffuse.
      channel.emit({'type': 'control', 'allControl': true});
      await pump();
      s.localChanged();
      expect(channel.sentOf('state'), hasLength(1));
      s.dispose();
    });

    test(
      'pas d\'écho : le mouvement causé par une correction distante n\'est pas renvoyé',
      () async {
        final s = session();
        final p = FakePlayer();
        s.attach(p);
        await s.start();
        channel.emit(hello(allControl: true));
        await pump();
        channel.emit({
          'type': 'state',
          'positionMs': 50000,
          'playing': true,
          'sentAt': 1,
        });
        await pump();
        expect(p.playing, isTrue);
        s.localChanged();
        expect(channel.sentOf('state'), isEmpty);
        clock = clock.add(const Duration(seconds: 2));
        p.position = const Duration(seconds: 99);
        s.localChanged();
        expect(channel.sentOf('state'), hasLength(1));
        s.dispose();
      },
    );

    test(
      'control_denied : l\'invité le sait, effacé quand l\'hôte ouvre le contrôle',
      () async {
        final s = session();
        await s.start();
        channel.emit(hello(mediaType: 'series'));
        channel.emit({'type': 'control_denied'});
        await pump();
        expect(s.value.controlDenied, isTrue);
        expect(s.value.canControl, isFalse);
        expect(s.value.mediaType, 'series');
        channel.emit({'type': 'control', 'allControl': true});
        await pump();
        expect(s.value.controlDenied, isFalse);
        expect(s.value.canControl, isTrue);
        s.dispose();
      },
    );

    test('RTT mesuré avec les pongs', () async {
      final s = session();
      await s.start();
      final ping = channel.sentOf('ping').single;
      clock = clock.add(const Duration(milliseconds: 80));
      channel.emit({'type': 'pong', 'sentAt': ping['sentAt']});
      await pump();
      expect(s.rtt, const Duration(milliseconds: 80));
      s.dispose();
    });

    test(
      'quitter : message leave, canal fermé ; échec de connexion : état failed',
      () async {
        final s = session();
        await s.start();
        channel.emit(hello());
        await pump();
        await s.leave();
        expect(channel.sentOf('leave'), hasLength(1));
        expect(channel.closed, isTrue);
        expect(s.value.status, PartyStatus.ended);
        s.dispose();

        connectError = const WebSocketException('HTTP status code: 409');
        final f = session();
        await f.start();
        expect(f.value.status, PartyStatus.failed);
        expect(f.value.error, PartyErrorCode.full);
        f.dispose();
      },
    );

    test('coupure du canal par le serveur : état failed', () async {
      final s = session();
      await s.start();
      channel.emit(hello());
      await pump();
      await channel.incoming.close();
      await pump();
      expect(s.value.status, PartyStatus.failed);
      s.dispose();
    });
  });

  group('PartyScreen', () {
    Future<void> settle(WidgetTester t) async {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump();
    }

    Widget app(PartyClient c, {Widget? child}) => ProviderScope(
      child: MaterialApp(
        theme: LumioTheme.dark(),
        home: child ?? PartyScreen(client: c),
      ),
    );

    testWidgets('créer : code groupé, QR du lien, nombre, interrupteur hôte', (
      t,
    ) async {
      http.handler = (m, u) {
        if (u.path == '/rooms') {
          return PartyHttpResponse(
            201,
            jsonEncode({
              'roomId': roomId,
              'inviteCode': code,
              'hostKey': 'hk1',
              'expiresAt': 1800000000000,
            }),
          );
        }
        return const PartyHttpResponse(204, '');
      };
      await t.pumpWidget(app(client()));
      await t.tap(find.byKey(const ValueKey('party:create')));
      await settle(t);
      channel.emit(hello(host: true, participants: 1));
      await settle(t);
      expect(find.byKey(const ValueKey('party:code')), findsOneWidget);
      expect(find.text('KR74-PQ2X'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('1 participant'), findsOneWidget);
      channel.emit({'type': 'join', 'participants': 3});
      await settle(t);
      expect(find.text('3 participants'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('party:allControl')));
      await t.pump();
      final control = http.requests.lastWhere(
        (r) => r.url.path.endsWith('/control'),
      );
      expect(jsonDecode(control.body!), {'allControl': true});
      expect(control.headers['authorization'], 'Bearer hk1');

      await t.ensureVisible(find.byKey(const ValueKey('party:leave')));
      await t.tap(find.byKey(const ValueKey('party:leave')));
      await settle(t);
      expect(find.byKey(const ValueKey('party:create')), findsOneWidget);
      expect(channel.sentOf('leave'), hasLength(1));
    });

    testWidgets('rejoindre : lien invalide refusé, lien valide connecte', (
      t,
    ) async {
      await t.pumpWidget(app(client()));
      await t.enterText(
        find.byKey(const ValueKey('party:link')),
        'n importe quoi',
      );
      await t.tap(find.byKey(const ValueKey('party:join')));
      await t.pump();
      expect(find.byKey(const ValueKey('party:error')), findsOneWidget);
      expect(
        find.text('Ce lien d\'invitation n\'est pas valide.'),
        findsOneWidget,
      );
      expect(connects, isEmpty);

      await t.enterText(
        find.byKey(const ValueKey('party:link')),
        partyLink(roomId, code).toString(),
      );
      await t.tap(find.byKey(const ValueKey('party:join')));
      await settle(t);
      expect(connects.single.url.queryParameters['code'], code);
      channel.emit(hello(participants: 2, metaId: 'tt5', mediaType: 'series'));
      await settle(t);
      expect(find.text('2 participants'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('party:allControl')),
        findsNothing,
      ); // invité
      expect(find.byKey(const ValueKey('party:code')), findsNothing);
      String? opened;
      await t.pumpWidget(
        app(
          client(),
          child: PartyScreen(
            client: client(),
            onOpenTitle: (_, id, type) => opened = '$id|$type',
          ),
        ),
      );
      await t.pump();
      await t.tap(find.byKey(const ValueKey('party:openTitle')));
      expect(opened, 'tt5|series');
      await t.tap(find.byKey(const ValueKey('party:leave')));
      await settle(t);
    });

    testWidgets('salle pleine : message clair', (t) async {
      connectError = const WebSocketException('HTTP status code: 409');
      await t.pumpWidget(app(client()));
      await t.enterText(
        find.byKey(const ValueKey('party:link')),
        partyLink(roomId, code).toString(),
      );
      await t.tap(find.byKey(const ValueKey('party:join')));
      await settle(t);
      expect(find.text('La salle est pleine (8 personnes).'), findsOneWidget);
    });
  });

  testWidgets('lecteur : un invité sans droit ne commande pas la lecture', (
    t,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final s = PartySession(
      client: client(),
      roomId: roomId,
      inviteCode: code,
      heartbeat: const Duration(hours: 1),
      pingEvery: const Duration(hours: 1),
    );
    await t.runAsync(() async {
      await s.start();
      channel.emit(hello());
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    final ctl = _Ctl();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          titleSettingsStoreProvider.overrideWith(
            (ref) async => DriftTitleSettingsStore(db),
          ),
          subtitleStyleStoreProvider.overrideWithValue(SubtitleStyleStore(db)),
          partySessionProvider.overrideWith((ref) => s),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [LumioColors.dark]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: PlayerScreen(
            item: StreamItem(
              addonId: 'ad',
              title: 'Film',
              url: Uri.parse('https://x.test/v.mp4'),
            ),
            controller: ctl,
            videoBuilder: (_) => const ColoredBox(color: Colors.black),
            tracksBackend: (_) => _Backend(),
            castEnabled: false,
            partyEnabled: false,
          ),
        ),
      ),
    );
    await t.pump();
    await t.tap(find.bySemanticsLabel('Lecture'));
    await t.pump();
    expect(ctl.playPauses, 0);
    expect(
      find.text("Seul l'hôte contrôle la lecture dans cette salle."),
      findsOneWidget,
    );
    // L'hôte ouvre le contrôle : la commande passe.
    await t.runAsync(() async {
      channel.emit({'type': 'control', 'allControl': true});
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await t.tap(find.bySemanticsLabel('Lecture'));
    await t.pump();
    expect(ctl.playPauses, 1);
    s.dispose();
  });

  test('partyClientProvider : nul sans backend configuré', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(partyClientProvider), isNull); // backendUrl vide par défaut
  });
}

class _Ctl extends Fake implements PlayerController {
  final _state = ValueNotifier<PlayerState>(
    const PlayerState(phase: PlayerPhase.paused),
  );
  int playPauses = 0;
  @override
  ValueListenable<PlayerState> get stateListenable => _state;
  @override
  PlayerState get state => _state.value;
  @override
  Future<void> playPause() async => playPauses++;
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
