import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lumio_core/lumio_core.dart';
import 'package:lumio_core/testing.dart';
import 'package:test/test.dart';

const _token = 'tok-SECRET-123';

JellyfinClient _client(FakeAddonServer s, {HttpFetcher? fetcher}) =>
    JellyfinClient(
      s.baseUrl,
      fetcher ?? IoHttpFetcher(),
      deviceId: 'dev-abc',
      deviceName: 'Android',
      version: '1.2.3',
      allowPrivate: true,
    );

/// Serveur jouant Jellyfin : 1 compte, 120 films.
Future<FakeAddonServer> _jellyfin() async {
  final s = await FakeAddonServer.start();
  s.routeWith('/Users/AuthenticateByName', (r) {
    final b = jsonDecode(r.bodyText) as Map;
    if (r.method == 'POST' && b['Username'] == 'ana' && b['Pw'] == 'pw') {
      return FakeResponse.json({
        'AccessToken': _token,
        'ServerName': 'Salon',
        'User': {'Id': 'u1', 'Name': 'Ana'},
      });
    }
    return FakeResponse.json({'error': 'no'}, status: 401);
  });
  FakeResponse authed(RecordedRequest r, Object body) =>
      r.headers['authorization']!.contains('Token="$_token"')
      ? FakeResponse.json(body)
      : FakeResponse.json({}, status: 401);
  s.routeWith(
    '/Users/u1/Views',
    (r) => authed(r, {
      'Items': [
        {'Id': 'lib1', 'Name': 'Films', 'CollectionType': 'movies'},
        {'Id': 'lib2', 'Name': 'Séries', 'CollectionType': 'tvshows'},
      ],
    }),
  );
  s.routeWith('/Users/u1/Items', (r) {
    final q = r.uri.queryParameters;
    final start = int.parse(q['StartIndex'] ?? '0');
    final lim = int.parse(q['Limit'] ?? '100');
    final all = List.generate(120, (i) => i);
    final page = all.skip(start).take(lim);
    return authed(r, {
      'TotalRecordCount': 120,
      'Items': [
        for (final i in page)
          {
            'Id': 'm$i',
            'Name': 'Film $i',
            'Type': 'Movie',
            'ProductionYear': 2000 + i % 20,
            'OfficialRating': i.isEven ? 'PG-13' : null,
            'ImageTags': {'Primary': 'tag$i'},
          },
      ],
    });
  });
  return s;
}

class _Throwing extends IoHttpFetcher {
  _Throwing(this.error);
  final Object error;

  @override
  Future<FetchResponse> post(
    Uri url, {
    required List<int> body,
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) async => throw error;
}

void main() {
  late FakeAddonServer server;
  setUp(() async => server = await _jellyfin());
  tearDown(() => server.close());

  test('authentification : jeton et en-tête MediaBrowser', () async {
    final c = _client(server);
    final s = await c.authenticate('ana', 'pw');
    expect(s.token, _token);
    expect(s.userId, 'u1');
    expect(s.userName, 'Ana');
    final req = server.requests.single;
    expect(req.method, 'POST');
    final auth = req.headers['authorization']!;
    expect(auth, startsWith('MediaBrowser '));
    expect(auth, contains('Client="Lumio"'));
    expect(auth, contains('Device="Android"'));
    expect(auth, contains('DeviceId="dev-abc"'));
    expect(auth, contains('Version="1.2.3"'));
    expect(auth, isNot(contains('Token=')));
    expect(req.uri.toString(), isNot(contains('pw')));
  });

  test('mauvais mot de passe 401 : JellyfinAuthException', () async {
    final c = _client(server);
    await expectLater(
      c.authenticate('ana', 'mauvais'),
      throwsA(
        isA<JellyfinAuthException>().having((e) => e.expired, 'expired', false),
      ),
    );
    expect(c.token, isNull);
  });

  test('en-tête : guillemets du nom de plateforme neutralisés', () {
    final c = JellyfinClient(
      server.baseUrl,
      IoHttpFetcher(),
      deviceId: 'a"b',
      deviceName: 'X", Token="evil',
    );
    expect(c.authorization, isNot(contains('"evil')));
    expect(RegExp('"').allMatches(c.authorization).length, 8);
  });

  test(
    'bibliothèques, avec le jeton en en-tête et jamais dans l\'URL',
    () async {
      final c = _client(server);
      await c.authenticate('ana', 'pw');
      final v = await c.views();
      expect(v.map((e) => e.name), ['Films', 'Séries']);
      expect(v.first.collectionType, 'movies');
      final req = server.requests.last;
      expect(req.headers['authorization'], contains('Token="$_token"'));
      expect(req.uri.toString(), isNot(contains(_token)));
      expect(req.uri.queryParameters.containsKey('api_key'), isFalse);
    },
  );

  test('sans connexion : JellyfinAuthException(expired) sans requête', () {
    final c = _client(server);
    expect(c.views, throwsA(isA<JellyfinAuthException>()));
    expect(server.requests, isEmpty);
  });

  test('jeton rejeté : JellyfinAuthException expirée', () async {
    final c = _client(server)
      ..token = 'faux'
      ..userId = 'u1';
    await expectLater(
      c.views(),
      throwsA(
        isA<JellyfinAuthException>().having((e) => e.expired, 'expired', true),
      ),
    );
  });

  test('pagination StartIndex / Limit', () async {
    final c = _client(server);
    await c.authenticate('ana', 'pw');
    final p1 = await c.items('lib1', limit: 50);
    expect(p1.items, hasLength(50));
    expect(p1.total, 120);
    expect(p1.hasMore, isTrue);
    final p3 = await c.items('lib1', skip: 100, limit: 50);
    expect(p3.items, hasLength(20));
    expect(p3.items.first.id, 'm100');
    expect(p3.hasMore, isFalse);
    final q = server.requests.last.uri.queryParameters;
    expect(q['StartIndex'], '100');
    expect(q['Limit'], '50');
    expect(q['ParentId'], 'lib1');
  });

  test('limite bornée et départ négatif ramené à 0', () async {
    final c = _client(server);
    await c.authenticate('ana', 'pw');
    await c.items('lib1', skip: -5, limit: 100000);
    final q = server.requests.last.uri.queryParameters;
    expect(q['StartIndex'], '0');
    expect(q['Limit'], '200');
  });

  test('éléments : année, certification, affiche, lisible', () async {
    final c = _client(server);
    await c.authenticate('ana', 'pw');
    final it = (await c.items('lib1', limit: 2)).items;
    expect(it[0].name, 'Film 0');
    expect(it[0].year, 2000);
    expect(it[0].certification, 'PG-13');
    expect(it[0].playable, isTrue);
    expect(it[1].certification, isNull);
    expect(it[0].imageTag, 'tag0');
  });

  test('URL de lecture : sans jeton, en-tête fourni à part', () async {
    final c = _client(server);
    await c.authenticate('ana', 'pw');
    final u = c.streamUrl('m1');
    expect(u.path, '/Videos/m1/stream');
    expect(u.queryParameters['static'], 'true');
    expect(u.toString(), isNot(contains(_token)));
    expect(u.queryParameters.containsKey('api_key'), isFalse);
    expect(c.streamHeaders()['Authorization'], contains('Token="$_token"'));
    expect(redactUrl(u.toString()), isNot(contains('m1')));
  });

  test('serveur sous un sous-chemin et barre finale', () async {
    final s = await FakeAddonServer.start();
    addTearDown(s.close);
    s.route(
      '/jellyfin/Users/u1/Views',
      FakeResponse.json({'Items': <Object>[]}),
    );
    final c = JellyfinClient(
      s.baseUrl.replace(path: '/jellyfin/'),
      IoHttpFetcher(),
      deviceId: 'd',
      allowPrivate: true,
      token: 't',
      userId: 'u1',
    );
    expect(c.server.path, '/jellyfin');
    expect(await c.views(), isEmpty);
  });

  test('adresse privée refusée sans accord', () async {
    final c = JellyfinClient(server.baseUrl, IoHttpFetcher(), deviceId: 'd');
    await expectLater(
      c.authenticate('ana', 'pw'),
      throwsA(isA<UnsafeUrlException>()),
    );
    expect(server.requests, isEmpty);
  });

  test('certificat invalide : CertificateException, jamais ignoré', () async {
    final c = _client(
      server,
      fetcher: _Throwing(const HandshakeException('CERTIFICATE_VERIFY_FAILED')),
    );
    await expectLater(
      c.authenticate('ana', 'pw'),
      throwsA(isA<CertificateException>()),
    );
  });

  test('erreurs réseau : codes distincts', () async {
    Future<JellyfinErrorCode> code(Object e) async {
      try {
        await _client(server, fetcher: _Throwing(e)).authenticate('a', 'b');
      } on JellyfinException catch (x) {
        return x.code;
      }
      throw StateError('aucune exception');
    }

    expect(await code(TimeoutException('t')), JellyfinErrorCode.timeout);
    expect(
      await code(const SocketException('x')),
      JellyfinErrorCode.unreachable,
    );
    expect(
      await code(const ResponseTooLargeException(1)),
      JellyfinErrorCode.tooLarge,
    );
    expect(
      await code(InsecureRedirectException(Uri.parse('http://x'))),
      JellyfinErrorCode.redirect,
    );
  });

  test('500 et réponse non JSON', () async {
    server.route(
      '/Users/AuthenticateByName',
      FakeResponse.json({}, status: 503),
    );
    await expectLater(
      _client(server).authenticate('a', 'b'),
      throwsA(
        isA<JellyfinException>().having(
          (e) => e.code,
          'code',
          JellyfinErrorCode.serverError,
        ),
      ),
    );
    server.route(
      '/Users/AuthenticateByName',
      FakeResponse.raw(utf8.encode('<html>'), contentType: 'text/html'),
    );
    await expectLater(
      _client(server).authenticate('a', 'b'),
      throwsA(
        isA<JellyfinException>().having(
          (e) => e.code,
          'code',
          JellyfinErrorCode.invalidResponse,
        ),
      ),
    );
  });

  test('POST : une redirection n\'est jamais suivie', () async {
    server.route(
      '/Users/AuthenticateByName',
      FakeResponse.raw(
        const [],
        status: 307,
        headers: {'location': 'http://127.0.0.1:1/x'},
      ),
    );
    await expectLater(
      _client(server).authenticate('a', 'b'),
      throwsA(
        isA<JellyfinException>().having(
          (e) => e.code,
          'code',
          JellyfinErrorCode.redirect,
        ),
      ),
    );
  });

  test('déconnexion : jeton oublié, erreur serveur ignorée', () async {
    server.route('/Sessions/Logout', FakeResponse.json({}, status: 500));
    final c = _client(server);
    await c.authenticate('ana', 'pw');
    await c.logout();
    expect(c.token, isNull);
    final req = server.requests.last;
    expect(req.uri.path, '/Sessions/Logout');
    expect(req.headers['authorization'], contains('Token="$_token"'));
  });

  test('adresse invalide', () {
    expect(
      () =>
          JellyfinClient(Uri.parse('ftp://x'), IoHttpFetcher(), deviceId: 'd'),
      throwsA(isA<JellyfinException>()),
    );
    expect(
      () => JellyfinClient(
        Uri.parse('http://u:p@host'),
        IoHttpFetcher(),
        deviceId: 'd',
      ),
      throwsA(isA<JellyfinException>()),
    );
  });

  test('serverHash stable (casse et barre finale)', () {
    expect(
      JellyfinClient.serverHash(Uri.parse('http://Salon.local:8096/')),
      JellyfinClient.serverHash(Uri.parse('http://salon.local:8096')),
    );
    expect(
      JellyfinClient.serverHash(Uri.parse('http://a:8096')),
      isNot(JellyfinClient.serverHash(Uri.parse('http://b:8096'))),
    );
  });

  group('jellyfinCertification', () {
    test('passe les valeurs connues, rejette les inconnues', () {
      expect(jellyfinCertification('TV-MA'), 'TV-MA');
      expect(jellyfinCertification(' pg-13 '), 'PG-13');
      expect(jellyfinCertification(null), isNull);
      expect(jellyfinCertification(''), isNull);
      expect(jellyfinCertification('NR'), isNull);
      expect(jellyfinCertification('Unrated'), isNull);
    });

    test('FSK allemand converti, et filtre enfant cohérent', () {
      expect(jellyfinCertification('FSK-12'), 'FR-12');
      expect(jellyfinCertification('DE-16'), 'FR-16');
      expect(jellyfinCertification('FSK 0'), 'G');
      expect(ratingAllows(jellyfinCertification('FSK-6'), AgeLimit.age7), true);
      expect(
        ratingAllows(jellyfinCertification('FSK-16'), AgeLimit.age12),
        false,
      );
      // Inconnu : caché aux enfants.
      expect(
        ratingAllows(jellyfinCertification('MA15+'), AgeLimit.age16),
        false,
      );
      expect(ratingAllows(jellyfinCertification('NR'), AgeLimit.age16), false);
    });
  });
}
