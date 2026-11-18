import 'dart:convert';

import 'package:lumio_core/lumio_core.dart';
import 'package:lumio_core/testing.dart';
import 'package:test/test.dart';

const _secret = 'SECRET-xyz';

FakeResponse _tokenJson({
  String access = 'acc-1',
  String refresh = 'ref-1',
  int expiresIn = 7776000,
}) => FakeResponse.json({
  'access_token': access,
  'refresh_token': refresh,
  'expires_in': expiresIn,
  'created_at': 1700000000,
});

ScrobbleEvent _event([ScrobbleAction a = ScrobbleAction.start]) =>
    ScrobbleEvent(
      action: a,
      imdbId: 'tt1',
      progress: 12.5,
      at: DateTime.utc(2026, 1, 1),
    );

void main() {
  late FakeAddonServer server;
  var now = DateTime.utc(2023, 11, 14, 23);

  TraktClient client({
    String id = 'cid',
    String secret = _secret,
    TrackerToken? token,
    Future<void> Function(TrackerToken?)? onToken,
  }) => TraktClient(
    IoHttpFetcher(),
    clientId: id,
    clientSecret: secret,
    token: token,
    onToken: onToken,
    baseUrl: server.baseUrl,
    now: () => now,
    allowPrivate: true,
  );

  TrackerToken valid() => TrackerToken(
    access: 'acc-0',
    refresh: 'ref-0',
    expiresAt: now.add(const Duration(days: 30)),
  );

  setUp(() async {
    server = await FakeAddonServer.start();
    now = DateTime.utc(2023, 11, 14, 23);
  });
  tearDown(() => server.close());

  test('adresse privée refusée par défaut : rien d\'envoyé', () async {
    final c = TraktClient(
      IoHttpFetcher(),
      clientId: 'cid',
      clientSecret: _secret,
      token: valid(),
      baseUrl: server.baseUrl,
    );
    await expectLater(c.scrobble(_event()), throwsA(isA<TrackerRejected>()));
    await expectLater(c.startDeviceAuth(), throwsA(isA<TrackerRejected>()));
    expect(server.requests, isEmpty);
  });

  test('deux scrobbles concurrents : un seul renouvellement', () async {
    server.route('/oauth/token', _tokenJson(access: 'acc-2'));
    server.route('/scrobble/start', FakeResponse.json({}, status: 201));
    final c = client(
      token: TrackerToken(
        access: 'acc-0',
        refresh: 'ref-0',
        expiresAt: now.add(const Duration(minutes: 10)),
      ),
    );
    await Future.wait([c.scrobble(_event()), c.scrobble(_event())]);
    expect(
      server.requests.where((r) => r.uri.path == '/oauth/token'),
      hasLength(1),
    );
    expect(
      server.requests
          .where((r) => r.uri.path == '/scrobble/start')
          .map((r) => r.headers['authorization']),
      everyElement('Bearer acc-2'),
    );
  });

  test('401 concurrents : un seul renouvellement', () async {
    server.route('/oauth/token', _tokenJson(access: 'acc-2'));
    server.routeWith(
      '/scrobble/start',
      (r) => r.headers['authorization'] == 'Bearer acc-2'
          ? FakeResponse.json({}, status: 201)
          : FakeResponse.json({}, status: 401),
    );
    final c = client(token: valid());
    await Future.wait([c.scrobble(_event()), c.scrobble(_event())]);
    expect(
      server.requests.where((r) => r.uri.path == '/oauth/token'),
      hasLength(1),
    );
  });

  group('configuration', () {
    test('identifiants vides : TrackerNotConfigured, rien d\'envoyé', () async {
      final c = client(id: '', secret: '');
      expect(c.startDeviceAuth(), throwsA(isA<TrackerNotConfigured>()));
      expect(c.scrobble(_event()), throwsA(isA<TrackerNotConfigured>()));
      expect(
        c.pollToken(
          DeviceCode(
            deviceCode: 'd',
            userCode: 'u',
            verificationUrl: Uri.parse('https://x'),
            expiresIn: Duration.zero,
            interval: Duration.zero,
          ),
        ),
        throwsA(isA<TrackerNotConfigured>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(server.requests, isEmpty);
    });
  });

  group('flux d\'appareil', () {
    setUp(() {
      server.route(
        '/oauth/device/code',
        FakeResponse.json({
          'device_code': 'dev-1',
          'user_code': 'ABCD1234',
          'verification_url': 'https://trakt.tv/activate',
          'expires_in': 600,
          'interval': 5,
        }),
      );
    });

    test('code d\'appareil : requête et réponse', () async {
      final c = await client().startDeviceAuth();
      expect(c.userCode, 'ABCD1234');
      expect(c.verificationUrl.toString(), 'https://trakt.tv/activate');
      expect(c.interval, const Duration(seconds: 5));
      expect(c.expiresIn, const Duration(minutes: 10));
      final r = server.requests.single;
      expect(r.method, 'POST');
      expect(r.headers['trakt-api-version'], '2');
      expect(r.headers['trakt-api-key'], 'cid');
      expect(jsonDecode(r.bodyText), {'client_id': 'cid'});
      expect(c.toString(), isNot(contains('ABCD1234')));
    });

    test('authorization_pending puis jeton', () async {
      final c = await client().startDeviceAuth();
      var calls = 0;
      server.routeWith(
        '/oauth/device/token',
        (_) => ++calls < 3
            ? FakeResponse.json({'error': 'pending'}, status: 400)
            : _tokenJson(),
      );
      final sleeps = <Duration>[];
      final t = await waitForDeviceToken(
        client(),
        c,
        sleep: (d) async => sleeps.add(d),
      );
      expect(t.access, 'acc-1');
      expect(t.refresh, 'ref-1');
      expect(
        t.expiresAt,
        DateTime.utc(
          2023,
          11,
          14,
          22,
          13,
          20,
        ).add(const Duration(seconds: 7776000)),
      );
      expect(calls, 3);
      expect(sleeps, everyElement(const Duration(seconds: 5)));
      final body = jsonDecode(server.requests.last.bodyText) as Map;
      expect(body['code'], 'dev-1');
      expect(body['client_secret'], _secret);
    });

    test('429 : intervalle allongé de 5 s', () async {
      final c = await client().startDeviceAuth();
      var calls = 0;
      server.routeWith(
        '/oauth/device/token',
        (_) => ++calls == 1 ? FakeResponse.json({}, status: 429) : _tokenJson(),
      );
      final sleeps = <Duration>[];
      await waitForDeviceToken(client(), c, sleep: (d) async => sleeps.add(d));
      expect(sleeps, [const Duration(seconds: 5), const Duration(seconds: 10)]);
    });

    for (final (status, matcher) in [
      (404, isA<TrackerAuthExpired>()),
      (409, isA<TrackerAuthExpired>()),
      (410, isA<TrackerAuthExpired>()),
      (418, isA<TrackerAuthDenied>()),
    ]) {
      test('statut $status', () async {
        final c = await client().startDeviceAuth();
        server.route(
          '/oauth/device/token',
          FakeResponse.json({}, status: status),
        );
        await expectLater(client().pollToken(c), throwsA(matcher));
      });
    }

    test('code expiré côté client : TrackerAuthExpired', () async {
      final c = await client().startDeviceAuth();
      server.route('/oauth/device/token', FakeResponse.json({}, status: 400));
      await expectLater(
        waitForDeviceToken(
          client(),
          c,
          sleep: (d) async => now = now.add(const Duration(minutes: 4)),
          now: () => now,
        ),
        throwsA(isA<TrackerAuthExpired>()),
      );
    });

    test('annulation', () async {
      final c = await client().startDeviceAuth();
      await expectLater(
        waitForDeviceToken(
          client(),
          c,
          sleep: (_) async {},
          isCancelled: () => true,
        ),
        throwsA(isA<CancelledPoll>()),
      );
    });
  });

  group('scrobble', () {
    test('film : chemin, en-têtes, corps', () async {
      server.route('/scrobble/start', FakeResponse.json({}, status: 201));
      await client(token: valid()).scrobble(_event());
      final r = server.requests.single;
      expect(r.method, 'POST');
      expect(r.headers['authorization'], 'Bearer acc-0');
      expect(r.headers['trakt-api-version'], '2');
      expect(r.headers['trakt-api-key'], 'cid');
      expect(jsonDecode(r.bodyText), {
        'movie': {
          'ids': {'imdb': 'tt1'},
        },
        'progress': 12.5,
      });
    });

    test('épisode : show + saison/numéro, pause et stop', () async {
      server.route('/scrobble/pause', FakeResponse.json({}, status: 201));
      server.route('/scrobble/stop', FakeResponse.json({}, status: 201));
      final c = client(token: valid());
      ScrobbleEvent ep(ScrobbleAction a) => ScrobbleEvent(
        action: a,
        imdbId: 'tt9',
        season: 2,
        episode: 3,
        progress: 99,
        at: now,
      );
      await c.scrobble(ep(ScrobbleAction.pause));
      await c.scrobble(ep(ScrobbleAction.stop));
      expect(server.requests.map((r) => r.uri.path), [
        '/scrobble/pause',
        '/scrobble/stop',
      ]);
      expect(jsonDecode(server.requests.first.bodyText), {
        'show': {
          'ids': {'imdb': 'tt9'},
        },
        'episode': {'season': 2, 'number': 3},
        'progress': 99,
      });
    });

    test('503 : TrackerUnavailable', () async {
      server.route('/scrobble/start', FakeResponse.json({}, status: 503));
      await expectLater(
        client(token: valid()).scrobble(_event()),
        throwsA(isA<TrackerUnavailable>()),
      );
    });

    test('serveur absent : TrackerUnavailable', () async {
      final c = client(token: valid());
      await server.close();
      await expectLater(
        c.scrobble(_event()),
        throwsA(isA<TrackerUnavailable>()),
      );
      server = await FakeAddonServer.start();
    });

    test('404 : TrackerRejected, 409 : accepté', () async {
      server.route('/scrobble/start', FakeResponse.json({}, status: 404));
      await expectLater(
        client(token: valid()).scrobble(_event()),
        throwsA(isA<TrackerRejected>()),
      );
      server.route('/scrobble/start', FakeResponse.json({}, status: 409));
      await client(token: valid()).scrobble(_event());
    });

    test('sans jeton : TrackerReauthRequired', () async {
      await expectLater(
        client().scrobble(_event()),
        throwsA(isA<TrackerReauthRequired>()),
      );
      expect(server.requests, isEmpty);
    });
  });

  group('renouvellement du jeton', () {
    test(
      'avant expiration : refresh puis envoi avec le nouveau jeton',
      () async {
        server.route(
          '/oauth/token',
          _tokenJson(access: 'acc-2', refresh: 'ref-2'),
        );
        server.route('/scrobble/start', FakeResponse.json({}, status: 201));
        TrackerToken? saved;
        final c = client(
          token: TrackerToken(
            access: 'acc-0',
            refresh: 'ref-0',
            expiresAt: now.add(const Duration(minutes: 10)),
          ),
          onToken: (t) async => saved = t,
        );
        await c.scrobble(_event());
        expect(saved!.access, 'acc-2');
        final refresh = jsonDecode(server.requests.first.bodyText) as Map;
        expect(refresh['grant_type'], 'refresh_token');
        expect(refresh['refresh_token'], 'ref-0');
        expect(server.requests.last.headers['authorization'], 'Bearer acc-2');
      },
    );

    test('401 : un renouvellement puis rejeu', () async {
      server.route('/oauth/token', _tokenJson(access: 'acc-2'));
      server.routeWith(
        '/scrobble/start',
        (r) => r.headers['authorization'] == 'Bearer acc-2'
            ? FakeResponse.json({}, status: 201)
            : FakeResponse.json({}, status: 401),
      );
      await client(token: valid()).scrobble(_event());
      expect(server.requests.map((r) => r.uri.path), [
        '/scrobble/start',
        '/oauth/token',
        '/scrobble/start',
      ]);
    });

    test(
      '401 persistant : TrackerReauthRequired, un seul renouvellement',
      () async {
        server.route('/oauth/token', _tokenJson(access: 'acc-2'));
        server.route('/scrobble/start', FakeResponse.json({}, status: 401));
        await expectLater(
          client(token: valid()).scrobble(_event()),
          throwsA(isA<TrackerReauthRequired>()),
        );
        expect(
          server.requests.where((r) => r.uri.path == '/oauth/token'),
          hasLength(1),
        );
      },
    );

    test('refresh refusé : jeton oublié, reconnexion demandée', () async {
      server.route('/oauth/token', FakeResponse.json({}, status: 401));
      server.route('/scrobble/start', FakeResponse.json({}, status: 401));
      TrackerToken? saved = valid();
      final c = client(token: valid(), onToken: (t) async => saved = t);
      await expectLater(
        c.scrobble(_event()),
        throwsA(isA<TrackerReauthRequired>()),
      );
      expect(saved, isNull);
      expect(c.token, isNull);
    });
  });

  test('aucune exception ne contient jeton ni secret', () {
    for (final e in <Object>[
      const TrackerUnavailable(503),
      const TrackerReauthRequired(),
      const TrackerRejected(404),
      TrackerToken(
        access: 'acc-0',
        refresh: 'r',
        expiresAt: DateTime.utc(2030),
      ),
    ]) {
      expect(e.toString(), isNot(contains('acc-0')));
    }
  });

  group('identifiants Lumio', () {
    ScrobbleEvent? ev(String? meta, [String? video]) => scrobbleEventFor(
      metaId: meta,
      videoId: video,
      action: ScrobbleAction.start,
      progress: 5,
      at: now,
    );

    test('film, épisode, autres ignorés', () {
      expect(ev('tt123')!.isEpisode, isFalse);
      final e = ev('tt123', 'tt123:2:5')!;
      expect((e.imdbId, e.season, e.episode), ('tt123', 2, 5));
      expect(ev('local:abc'), isNull);
      expect(ev('jellyfin:a:b'), isNull);
      expect(ev(null), isNull);
      expect(ev('kitsu:1'), isNull);
    });

    test('avancement borné 0..100', () {
      ScrobbleEvent e(double p) => scrobbleEventFor(
        metaId: 'tt1',
        videoId: 'tt1',
        action: ScrobbleAction.stop,
        progress: p,
        at: now,
      )!;
      expect(e(150).progress, 100);
      expect(e(-3).progress, 0);
      expect(e(double.nan).progress, 0);
    });

    test('JSON aller-retour', () {
      final e = ScrobbleEvent.fromJson(
        jsonDecode(jsonEncode(ev('tt1', 'tt1:1:2')!.toJson()))
            as Map<String, dynamic>,
      );
      expect((e.imdbId, e.season, e.episode, e.progress), ('tt1', 1, 2, 5.0));
    });
  });
}
