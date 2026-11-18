import 'dart:convert';

import 'package:lumio_core/lumio_core.dart';
import 'package:lumio_core/testing.dart';
import 'package:test/test.dart';

ScrobbleEvent _event({
  ScrobbleAction a = ScrobbleAction.stop,
  double p = 95,
  int? season,
  int? episode,
}) => ScrobbleEvent(
  action: a,
  imdbId: 'tt1',
  season: season,
  episode: episode,
  progress: p,
  at: DateTime.utc(2026, 1, 1, 20),
);

void main() {
  late FakeAddonServer server;
  final now = DateTime.utc(2026, 1, 1);

  SimklClient client({String id = 'cid', TrackerToken? token}) => SimklClient(
    IoHttpFetcher(),
    clientId: id,
    token: token,
    baseUrl: server.baseUrl,
    now: () => now,
    allowPrivate: true,
  );

  TrackerToken valid() => TrackerToken(
    access: 'acc-0',
    refresh: '',
    expiresAt: now.add(const Duration(days: 36500)),
  );

  DeviceCode code() => DeviceCode(
    deviceCode: 'PIN12',
    userCode: 'PIN12',
    verificationUrl: Uri.parse('https://simkl.com/pin/'),
    expiresIn: const Duration(minutes: 15),
    interval: Duration.zero,
  );

  setUp(() async => server = await FakeAddonServer.start());
  tearDown(() => server.close());

  group('PIN', () {
    test('startDeviceAuth : code, adresse, intervalle, clé d\'API', () async {
      server.route(
        '/oauth/pin',
        FakeResponse.json({
          'result': 'OK',
          'device_code': 'dev',
          'user_code': 'AB12C',
          'verification_url': 'https://simkl.com/pin/',
          'expires_in': 900,
          'interval': 5,
        }),
      );
      final c = await client().startDeviceAuth();
      expect(c.userCode, 'AB12C');
      expect(c.verificationUrl.toString(), 'https://simkl.com/pin/');
      expect(c.expiresIn, const Duration(minutes: 15));
      expect(c.interval, const Duration(seconds: 5));
      final r = server.requests.single;
      expect(r.method, 'GET');
      expect(r.uri.queryParameters['client_id'], 'cid');
      expect(r.headers['simkl-api-key'], 'cid');
    });

    test('PIN approuvé : le jeton est rendu, sans renouvellement', () async {
      server.routeWith(
        '/oauth/pin/PIN12',
        (r) => FakeResponse.json({'result': 'OK', 'access_token': 'acc-1'}),
      );
      final t = await client().pollToken(code());
      expect(t!.access, 'acc-1');
      expect(t.refresh, isEmpty);
      expect(t.expiresWithin(const Duration(days: 3650), now), isFalse);
      expect(server.requests.single.uri.queryParameters['client_id'], 'cid');
    });

    test('en attente, puis approuvé (boucle d\'attente)', () async {
      var n = 0;
      server.routeWith(
        '/oauth/pin/PIN12',
        (r) => ++n < 3
            ? FakeResponse.json({
                'result': 'KO',
                'message': 'Authorization pending',
              })
            : FakeResponse.json({'result': 'OK', 'access_token': 'acc-2'}),
      );
      final t = await waitForDeviceToken(client(), code(), sleep: (_) async {});
      expect(t.access, 'acc-2');
      expect(n, 3);
    });

    test('code inconnu : expiré ; 429 : ralentir', () async {
      await expectLater(
        client().pollToken(code()),
        throwsA(isA<TrackerAuthExpired>()),
      );
      server.route('/oauth/pin/PIN12', FakeResponse.json({}, status: 429));
      await expectLater(
        client().pollToken(code()),
        throwsA(isA<TrackerSlowDown>()),
      );
    });

    test('expiration du PIN : TrackerAuthExpired', () async {
      server.route('/oauth/pin/PIN12', FakeResponse.json({'result': 'KO'}));
      var t = DateTime.utc(2026);
      await expectLater(
        waitForDeviceToken(
          client(),
          code(),
          sleep: (d) async => t = t.add(const Duration(minutes: 10)),
          now: () => t,
        ),
        throwsA(isA<TrackerAuthExpired>()),
      );
    });
  });

  group('historique', () {
    test('film à 95 % : POST /sync/history', () async {
      server.route('/sync/history', FakeResponse.json({}, status: 201));
      await client(token: valid()).scrobble(_event());
      final r = server.requests.single;
      expect(r.method, 'POST');
      expect(r.headers['authorization'], 'Bearer acc-0');
      expect(r.headers['simkl-api-key'], 'cid');
      final b = jsonDecode(r.bodyText) as Map<String, dynamic>;
      final m = (b['movies'] as List).single as Map<String, dynamic>;
      expect(m['ids'], {'imdb': 'tt1'});
      expect(m['watched_at'], '2026-01-01T20:00:00.000Z');
      expect(b.containsKey('shows'), isFalse);
    });

    test('épisode : show + saison + épisode', () async {
      server.route('/sync/history', FakeResponse.json({}, status: 201));
      await client(
        token: valid(),
      ).scrobble(_event(season: 2, episode: 5, p: 80));
      final b = jsonDecode(server.requests.single.bodyText) as Map;
      final show = (b['shows'] as List).single as Map;
      expect(show['ids'], {'imdb': 'tt1'});
      final season = (show['seasons'] as List).single as Map;
      expect(season['number'], 2);
      expect(((season['episodes'] as List).single as Map)['number'], 5);
      expect(b.containsKey('movies'), isFalse);
    });

    test(
      'règle des 80 % : sous le seuil, start et pause = rien envoyé',
      () async {
        final c = client(token: valid());
        await c.scrobble(_event(p: 79.9));
        await c.scrobble(_event(a: ScrobbleAction.start, p: 95));
        await c.scrobble(_event(a: ScrobbleAction.pause, p: 95));
        expect(server.requests, isEmpty);
        expect(SimklClient.wants(_event(p: 79.9)), isFalse);
        expect(SimklClient.wants(_event(p: 80)), isTrue);
        expect(SimklClient.wants(_event(a: ScrobbleAction.start)), isFalse);
      },
    );

    test('401 : TrackerReauthRequired, sans nouvel essai', () async {
      server.route('/sync/history', FakeResponse.json({}, status: 401));
      await expectLater(
        client(token: valid()).scrobble(_event()),
        throwsA(isA<TrackerReauthRequired>()),
      );
      expect(server.requests, hasLength(1));
    });

    test('sans jeton : réauth ; 5xx : indisponible ; 4xx : refusé', () async {
      await expectLater(
        client().scrobble(_event()),
        throwsA(isA<TrackerReauthRequired>()),
      );
      expect(server.requests, isEmpty);
      server.route('/sync/history', FakeResponse.json({}, status: 503));
      await expectLater(
        client(token: valid()).scrobble(_event()),
        throwsA(isA<TrackerUnavailable>()),
      );
      server.route('/sync/history', FakeResponse.json({}, status: 400));
      await expectLater(
        client(token: valid()).scrobble(_event()),
        throwsA(isA<TrackerRejected>()),
      );
    });
  });

  group('garde et configuration', () {
    test('adresse privée refusée par défaut : rien d\'envoyé', () async {
      final c = SimklClient(
        IoHttpFetcher(),
        clientId: 'cid',
        token: valid(),
        baseUrl: server.baseUrl,
      );
      await expectLater(c.scrobble(_event()), throwsA(isA<TrackerRejected>()));
      await expectLater(c.startDeviceAuth(), throwsA(isA<TrackerRejected>()));
      await expectLater(c.pollToken(code()), throwsA(isA<TrackerRejected>()));
      expect(server.requests, isEmpty);
    });

    test('identifiant vide : TrackerNotConfigured, rien d\'envoyé', () async {
      final c = client(id: '', token: valid());
      expect(c.startDeviceAuth(), throwsA(isA<TrackerNotConfigured>()));
      expect(c.pollToken(code()), throwsA(isA<TrackerNotConfigured>()));
      expect(c.scrobble(_event()), throwsA(isA<TrackerNotConfigured>()));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(server.requests, isEmpty);
    });

    test('réseau coupé : TrackerUnavailable', () async {
      final c = client(token: valid());
      await server.close();
      await expectLater(
        c.scrobble(_event()),
        throwsA(isA<TrackerUnavailable>()),
      );
      server = await FakeAddonServer.start();
    });

    test('toString ne révèle ni jeton ni code', () {
      expect(valid().toString(), isNot(contains('acc-0')));
      expect(code().toString(), isNot(contains('PIN12')));
    });
  });
}
