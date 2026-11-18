import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/party_client.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio/data/sync_service.dart';
import 'package:lumio/features/party/party_providers.dart';
import 'package:lumio/features/party/party_screen.dart';
import 'package:lumio/features/party/party_session.dart';
import 'package:lumio/ui/theme.dart';
import 'package:qr_flutter/qr_flutter.dart';

const roomId = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';
const code = 'KR74PQ2X';

class FakeHttp implements SyncHttp {
  final requests =
      <({String method, Uri url, Map<String, String> headers, String? body})>[];
  SyncHttpResponse Function(String method, Uri url)? handler;

  @override
  Future<SyncHttpResponse> send(
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
}) => {
  'type': 'hello',
  'participants': participants,
  'host': host,
  'allControl': allControl,
  'metaId': metaId,
  'expiresAt': DateTime.now()
      .add(const Duration(hours: 6))
      .millisecondsSinceEpoch,
  'state': state,
};

void main() {
  late MemorySecretStore secrets;
  late FakeHttp http;
  late SyncApiClient api;
  late FakeChannel channel;
  late List<({Uri url, List<String> protocols})> connects;
  Object? connectError;

  setUp(() async {
    secrets = MemorySecretStore();
    await secrets.write(SyncSecretKeys.session, 'sess1');
    await secrets.write(SyncSecretKeys.refresh, 'ref1');
    http = FakeHttp();
    api = SyncApiClient('https://api.example.com', secrets, http: http);
    channel = FakeChannel();
    connects = [];
    connectError = null;
  });

  PartyClient client() => PartyClient(
    api,
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
    test('create : POST authentifié, ne transmet que le metaId', () async {
      http.handler = (m, u) => SyncHttpResponse(
        201,
        jsonEncode({
          'roomId': roomId,
          'inviteCode': code,
          'expiresAt': 1800000000000,
        }),
      );
      final info = await client().create(metaId: 'tt1');
      expect(info.roomId, roomId);
      expect(info.inviteCode, code);
      final r = http.requests.single;
      expect(r.url.path, '/rooms');
      expect(r.headers['Authorization'], 'Bearer sess1');
      expect(jsonDecode(r.body!), {'metaId': 'tt1'});
    });

    test('create : 429 et erreurs serveur traduits', () async {
      http.handler = (m, u) => const SyncHttpResponse(429, '{}');
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
      http.handler = (m, u) => const SyncHttpResponse(500, '{}');
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
      'connect : wss, code en paramètre, jeton dans le sous-protocole seulement',
      () async {
        await client().connect(roomId, code);
        final c = connects.single;
        expect(c.url.scheme, 'wss');
        expect(c.url.path, '/room/$roomId');
        expect(c.url.queryParameters, {'code': code});
        expect(c.url.toString(), isNot(contains('sess1')));
        expect(c.protocols, ['lumio.v1', 'sess1']);
      },
    );

    test(
      'connect : 401 -> renouvelle la session puis réessaie une fois',
      () async {
        http.handler = (m, u) => SyncHttpResponse(
          200,
          jsonEncode({'session': 'sess2', 'refresh': 'ref2'}),
        );
        connectError = const WebSocketException(
          'was not upgraded to websocket, HTTP status code: 401',
        );
        await client().connect(roomId, code);
        expect(connects.map((c) => c.protocols.last), ['sess1', 'sess2']);
      },
    );

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

    test('connect : sans session -> signedOut', () async {
      await secrets.delete(SyncSecretKeys.session);
      await secrets.delete(SyncSecretKeys.refresh);
      await expectLater(
        client().connect(roomId, code),
        throwsA(
          isA<PartyException>().having(
            (e) => e.code,
            'code',
            PartyErrorCode.signedOut,
          ),
        ),
      );
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
          return SyncHttpResponse(
            201,
            jsonEncode({
              'roomId': roomId,
              'inviteCode': code,
              'expiresAt': 1800000000000,
            }),
          );
        }
        return const SyncHttpResponse(204, '');
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
      channel.emit(hello(participants: 2, metaId: 'tt5'));
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
            onOpenTitle: (_, id) => opened = id,
          ),
        ),
      );
      await t.pump();
      await t.tap(find.byKey(const ValueKey('party:openTitle')));
      expect(opened, 'tt5');
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

  test('partyClientProvider : nul sans backend configuré', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(partyClientProvider), isNull); // backendUrl vide par défaut
  });
}
