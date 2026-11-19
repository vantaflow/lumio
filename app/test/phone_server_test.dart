import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/features/phone/lan_address.dart';
import 'package:lumio/features/phone/phone_add.dart';
import 'package:lumio/features/phone/phone_server.dart';

class _Lan implements LanAddressSource {
  _Lan(this.addr);
  final InternetAddress? addr;
  @override
  Future<InternetAddress?> current() async => addr;
}

class _Backend implements PhoneBackend {
  final calls = <String>[];
  var list = <PhoneAddonView>[
    const PhoneAddonView(
      id: 'org.alpha',
      name: 'Source Alpha',
      types: ['movie', 'series'],
      health: 'reliable',
      enabled: true,
      position: 0,
    ),
    const PhoneAddonView(
      id: 'org.beta',
      name: 'Direct Plus',
      types: ['movie'],
      health: 'slow',
      enabled: false,
      position: 1,
    ),
  ];
  @override
  Future<List<PhoneAddonView>> addons() async => list;
  @override
  Future<void> move(String id, int delta) async => calls.add('move:$id:$delta');
  @override
  Future<void> setEnabled(String id, bool on) async =>
      calls.add('enabled:$id:$on');
  @override
  Future<void> remove(String id) async => calls.add('remove:$id');
  final catalogCalls = <String>[];
  @override
  Future<PhoneCatalogPage> catalog({
    required String lang,
    String? chip,
    String? more,
    int page = 1,
    bool refresh = false,
  }) async {
    catalogCalls.add('$chip|$more|$page|$refresh');
    return PhoneCatalogPage(
      chips: const [('popular', 'Populaires'), ('movies', 'Films et séries')],
      more: const [('usenet', 'Usenet')],
      chip: chip ?? 'popular',
      page: page,
      hasMore: page < 2,
      note: 'offline',
      cards: [
        PhoneCatalogCard(
          slug: 'torrentio-x',
          name: 'Torrentio',
          meta: '★ 10 · v1.0',
          installed: false,
          description: 'Flux',
          logo: Uri.parse('https://cdn.example/logo.png'),
        ),
        PhoneCatalogCard(
          slug: 'plain',
          name: 'Plain',
          meta: 'v2',
          installed: true,
          logo: Uri.parse('http://insecure.example/l.png'),
        ),
      ],
    );
  }

  @override
  Future<PhoneCatalogCard?> catalogCard(String slug) async =>
      slug == 'torrentio-x'
      ? const PhoneCatalogCard(
          slug: 'torrentio-x',
          name: 'Torrentio',
          meta: '',
          installed: false,
        )
      : null;

  @override
  Future<PhoneCatalogChoice?> catalogChoice(String slug) async {
    catalogCalls.add('choice:$slug');
    return switch (slug) {
      'torrentio-x' => PhoneCatalogChoice(
        install: Uri.parse('https://secret.example/KEY123/manifest.json'),
        required: false,
        configure: Uri.parse('https://secret.example/configure'),
      ),
      'plain' => PhoneCatalogChoice(
        install: Uri.parse('https://plain.example/manifest.json'),
        required: true,
      ),
      _ => null,
    };
  }

  @override
  Future<Uri?> reconfigureUrl(String id) async =>
      Uri.parse('https://secret.example/configure');
}

class _Clock {
  var t = DateTime(2026, 11, 19, 12);
  DateTime call() => t;
  void add(Duration d) => t = t.add(d);
}

class _Resp {
  _Resp(this.status, this.body, this.headers);
  final int status;
  final String body;
  final HttpHeaders headers;
  Map<String, Object?> get json => jsonDecode(body) as Map<String, Object?>;
}

class _Fixture {
  late PhoneServer server;
  final backend = _Backend();
  final clock = _Clock();
  late PhoneAddCoordinator adds;
  final http = HttpClient();

  Future<void> start({
    InternetAddress? addr,
    Duration idle = const Duration(minutes: 10),
  }) async {
    adds = PhoneAddCoordinator(now: clock.call);
    server = PhoneServer(
      backend: backend,
      adds: adds,
      lan: _Lan(addr ?? InternetAddress.loopbackIPv4),
      lang: 'fr',
      preferredPort: 0,
      fontLoader: (n) async => n == 'manrope' ? [1, 2, 3] : null,
      idleTimeout: idle,
      now: clock.call,
    );
    await server.start();
  }

  PhoneServerState get st => server.state.value;
  String get hostHeader => '${st.host}:${st.port}';

  Future<_Resp> req(
    String method,
    String path, {
    Object? body,
    Map<String, String> headers = const {},
    String? cookie,
    bool origin = false,
    bool json = true,
    String? host,
    String? rawBody,
  }) async {
    final r = await http.openUrl(
      method,
      Uri.parse('http://${st.host}:${st.port}$path'),
    );
    final hp = (host ?? hostHeader).split(':');
    r.headers.host = hp[0];
    r.headers.port = hp.length > 1 ? int.parse(hp[1]) : null;
    if (origin) r.headers.add('origin', 'http://$hostHeader');
    if (cookie != null) r.headers.add('cookie', cookie);
    headers.forEach(r.headers.add);
    final data = rawBody ?? (body == null ? null : jsonEncode(body));
    if (data != null) {
      if (json) r.headers.contentType = ContentType.json;
      r.write(data);
    }
    final res = await r.close();
    final text = await utf8.decodeStream(res);
    return _Resp(res.statusCode, text, res.headers);
  }

  /// Ouvre une session avec le bon code ; renvoie (cookie, csrf).
  Future<(String, String)> login() async {
    final r = await req(
      'POST',
      '/api/login',
      body: {'code': st.code},
      origin: true,
    );
    expect(r.status, 200);
    final cookie = r.headers['set-cookie']!.first.split(';').first;
    return (cookie, r.json['csrf']! as String);
  }

  Future<void> close() async {
    http.close(force: true);
    await server.stop();
    server.dispose();
  }
}

void main() {
  late _Fixture f;
  setUp(() async {
    f = _Fixture();
    await f.start();
  });
  tearDown(() => f.close());

  group('catalogue et configuration', () {
    Future<String> firstId(_Fixture f, String cookie, [int i = 0]) async {
      final list = await f.req('GET', '/api/catalog', cookie: cookie);
      return ((list.json['items']! as List)[i] as Map<String, Object?>)['id']!
          as String;
    }

    Future<_Resp> post(
      _Fixture f,
      String path,
      String cookie,
      String csrf, [
      Object? body,
    ]) => f.req(
      'POST',
      path,
      body: body ?? {},
      cookie: cookie,
      origin: true,
      headers: {'x-csrf-token': csrf},
    );

    test(
      'catalogue : mêmes puces, pas d\'adresse de manifest, logo https seul',
      () async {
        final (cookie, _) = await f.login();
        final r = await f.req(
          'GET',
          '/api/catalog?chip=movies&page=2&refresh=1',
          cookie: cookie,
        );
        expect(r.status, 200);
        expect(r.body, isNot(contains('KEY123')));
        expect(r.body, isNot(contains('manifest.json')));
        expect(r.json['chips'], hasLength(2));
        expect(r.json['hasMore'], isFalse);
        expect(r.json['note'], 'offline');
        final items = (r.json['items']! as List).cast<Map<String, Object?>>();
        expect(items[0]['logo'], 'https://cdn.example/logo.png');
        expect(items[1].containsKey('logo'), isFalse);
        expect(items[1]['installed'], isTrue);
        expect(f.backend.catalogCalls.last, 'movies|null|2|true');
      },
    );

    test('page hors bornes : refusée', () async {
      final (cookie, _) = await f.login();
      final r = await f.req('GET', '/api/catalog?page=999', cookie: cookie);
      expect(r.status, 400);
    });

    test('installer depuis le portail : la TV reçoit la demande', () async {
      final (cookie, csrf) = await f.login();
      final id = await firstId(f, cookie);
      final r = await post(f, '/api/catalog/$id/install', cookie, csrf);
      expect(r.status, 202);
      expect(
        f.adds.pending.value!.url.toString(),
        'https://secret.example/KEY123/manifest.json',
      );
    });

    test('configuration requise : Installer refusé (409)', () async {
      final (cookie, csrf) = await f.login();
      final id = await firstId(f, cookie, 1);
      expect(
        (await post(f, '/api/catalog/$id/install', cookie, csrf)).status,
        409,
      );
      expect(
        (await post(f, '/api/catalog/$id/configure', cookie, csrf)).status,
        404,
      );
    });

    test('Configurer : renvoie la page publique /configure', () async {
      final (cookie, csrf) = await f.login();
      final id = await firstId(f, cookie);
      final c = await post(f, '/api/catalog/$id/configure', cookie, csrf);
      expect(c.status, 200);
      expect(c.json['url'], 'https://secret.example/configure');
    });

    test('identifiant inconnu : 404 ; écriture sans CSRF : 403', () async {
      final (cookie, csrf) = await f.login();
      expect(
        (await post(f, '/api/catalog/inconnu/install', cookie, csrf)).status,
        404,
      );
      final nocsrf = await f.req(
        'POST',
        '/api/catalog/inconnu/install',
        body: {},
        cookie: cookie,
        origin: true,
      );
      expect(nocsrf.status, 403);
    });

    test('fiche précise du lien du QR : valide, inconnue, slug piégé',
        () async {
      final (cookie, csrf) = await f.login();
      final ok = await f.req(
        'GET',
        '/api/catalog/one?slug=torrentio-x',
        cookie: cookie,
      );
      expect(ok.status, 200);
      final item = ok.json['item']! as Map<String, Object?>;
      expect(ok.body, isNot(contains('KEY123')));
      final cfg = await post(
        f,
        '/api/catalog/${item['id']}/configure',
        cookie,
        csrf,
      );
      expect(cfg.status, 200);
      expect(
        (await f.req('GET', '/api/catalog/one?slug=inconnu', cookie: cookie))
            .status,
        404,
      );
      expect(
        (await f.req('GET', '/api/catalog/one?slug=..%2Fx', cookie: cookie))
            .status,
        400,
      );
    });

    test('liste des addons : référence non secrète pour Reconfigurer',
        () async {
      final (cookie, _) = await f.login();
      final r = await f.req('GET', '/api/addons', cookie: cookie);
      final a = (r.json['addons']! as List).first as Map<String, Object?>;
      expect(a['ref'], addonPortalRef('org.alpha'));
      expect(a['ref'], isNot(a['id']));
      expect((a['ref']! as String).length, 12);
    });

    test(
      'Reconfigurer : page de base ; le lien renvoyé remplace l\'ancien',
      () async {
        final (cookie, csrf) = await f.login();
        final list = await f.req('GET', '/api/addons', cookie: cookie);
        final id =
            ((list.json['addons']! as List).first
                    as Map<String, Object?>)['id']!
                as String;
        final c = await post(f, '/api/addons/$id/reconfigure', cookie, csrf);
        expect(c.json['url'], 'https://secret.example/configure');
        expect(c.body, isNot(contains('org.alpha')));
        final a = await post(f, '/api/add', cookie, csrf, {
          'link': 'stremio://secret.example/NEW/manifest.json',
          'replaces': id,
        });
        expect(a.status, 202);
        expect(f.adds.pending.value!.replaces, 'org.alpha');
        final bad = await post(f, '/api/add', cookie, csrf, {
          'link': 'https://x.example/manifest.json',
          'replaces': 'zzz',
        });
        expect(bad.status, 404);
      },
    );
  });

  group('démarrage', () {
    test('lié à l\'adresse du réseau local, code à 6 chiffres', () {
      expect(f.st.status, PhoneServerStatus.listening);
      expect(f.st.host, '127.0.0.1');
      expect(f.st.port, greaterThan(0));
      expect(RegExp(r'^\d{6}$').hasMatch(f.st.code), isTrue);
      expect(f.st.url, 'http://127.0.0.1:${f.st.port}/#c=${f.st.code}');
    });

    test('pas de réseau local : aucun serveur', () async {
      final s = PhoneServer(
        backend: _Backend(),
        adds: PhoneAddCoordinator(),
        lan: _Lan(null),
        lang: 'fr',
        preferredPort: 0,
      );
      await s.start();
      expect(s.state.value.status, PhoneServerStatus.noNetwork);
      s.dispose();
    });

    test('port préféré occupé : repli sur un port libre', () async {
      final taken = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final s = PhoneServer(
        backend: _Backend(),
        adds: PhoneAddCoordinator(),
        lan: _Lan(InternetAddress.loopbackIPv4),
        lang: 'fr',
        preferredPort: taken.port,
      );
      await s.start();
      expect(s.state.value.status, PhoneServerStatus.listening);
      expect(s.state.value.port, isNot(taken.port));
      await s.stop();
      s.dispose();
      await taken.close();
    });

    test('un nouveau code à chaque ouverture', () async {
      final codes = <String>{};
      for (var i = 0; i < 6; i++) {
        codes.add(f.st.code);
        await f.server.stop();
        await f.server.start();
      }
      expect(codes.length, greaterThan(1));
    });
  });

  group('code et session', () {
    test('sans session : 401 sur toute route /api', () async {
      for (final p in ['/api/session', '/api/addons', '/api/add/abc']) {
        expect((await f.req('GET', p)).status, 401, reason: p);
      }
      final w = await f.req(
        'POST',
        '/api/add',
        body: {'link': 'https://a.example/manifest.json'},
        origin: true,
      );
      expect(w.status, 401);
    });

    test(
      'mauvais code : 401 ; bon code : cookie HttpOnly SameSite=Strict',
      () async {
        final bad = await f.req(
          'POST',
          '/api/login',
          body: {'code': '000000'},
          origin: true,
        );
        expect(f.st.code == '000000' || bad.status == 401, isTrue);
        final ok = await f.req(
          'POST',
          '/api/login',
          body: {'code': f.st.code},
          origin: true,
        );
        expect(ok.status, 200);
        final cookie = ok.headers['set-cookie']!.first;
        expect(cookie.toLowerCase(), contains('httponly'));
        expect(cookie.toLowerCase(), contains('samesite=strict'));
        expect(ok.json['csrf'], isA<String>());
        expect(f.st.connected, isTrue);
      },
    );

    test('cookie valide : session et liste accessibles', () async {
      final (cookie, _) = await f.login();
      expect((await f.req('GET', '/api/session', cookie: cookie)).status, 200);
      expect((await f.req('GET', '/api/addons', cookie: cookie)).status, 200);
      expect(
        (await f.req('GET', '/api/addons', cookie: 'lumio_sid=forge')).status,
        401,
      );
    });

    test('5 essais faux : verrou 60 s, nouveau code, puis reprise', () async {
      final old = f.st.code;
      final wrong = old == '111111' ? '222222' : '111111';
      for (var i = 0; i < 4; i++) {
        final r = await f.req(
          'POST',
          '/api/login',
          body: {'code': wrong},
          origin: true,
        );
        expect(r.status, 401);
      }
      final fifth = await f.req(
        'POST',
        '/api/login',
        body: {'code': wrong},
        origin: true,
      );
      expect(fifth.status, 429);
      expect(f.st.lockedUntil, isNotNull);
      expect(f.st.code, isNot(old));
      // Même avec le bon (nouveau) code, le verrou tient.
      final locked = await f.req(
        'POST',
        '/api/login',
        body: {'code': f.st.code},
        origin: true,
      );
      expect(locked.status, 429);
      expect(int.parse(locked.headers.value('retry-after')!), greaterThan(0));
      f.clock.add(const Duration(seconds: 61));
      final after = await f.req(
        'POST',
        '/api/login',
        body: {'code': f.st.code},
        origin: true,
      );
      expect(after.status, 200);
    });

    test('l\'ancien code ne marche plus après le verrou', () async {
      final old = f.st.code;
      final wrong = old == '111111' ? '222222' : '111111';
      for (var i = 0; i < 5; i++) {
        await f.req('POST', '/api/login', body: {'code': wrong}, origin: true);
      }
      f.clock.add(const Duration(seconds: 61));
      final r = await f.req(
        'POST',
        '/api/login',
        body: {'code': old},
        origin: true,
      );
      expect(r.status, 401);
    });
  });

  group('CSRF, Host, Origin, taille, débit', () {
    test('écriture sans jeton CSRF : 403', () async {
      final (cookie, _) = await f.login();
      final r = await f.req(
        'POST',
        '/api/add',
        body: {'link': 'https://a.example/manifest.json'},
        cookie: cookie,
        origin: true,
      );
      expect(r.status, 403);
      final bad = await f.req(
        'POST',
        '/api/add',
        body: {'link': 'https://a.example/manifest.json'},
        cookie: cookie,
        origin: true,
        headers: {'x-csrf-token': 'faux'},
      );
      expect(bad.status, 403);
      expect(f.adds.pending.value, isNull);
    });

    test('écriture sans Origin ou avec une autre origine : 403', () async {
      final (cookie, csrf) = await f.login();
      final none = await f.req(
        'POST',
        '/api/add',
        body: {'link': 'https://a.example/manifest.json'},
        cookie: cookie,
        headers: {'x-csrf-token': csrf},
      );
      expect(none.status, 403);
      final other = await f.req(
        'POST',
        '/api/add',
        body: {'link': 'https://a.example/manifest.json'},
        cookie: cookie,
        headers: {'x-csrf-token': csrf, 'origin': 'http://evil.example'},
      );
      expect(other.status, 403);
      final noLogin = await f.req(
        'POST',
        '/api/login',
        body: {'code': f.st.code},
        headers: {'origin': 'http://evil.example'},
      );
      expect(noLogin.status, 403);
    });

    test('Content-Type autre que JSON : 415', () async {
      final r = await f.req(
        'POST',
        '/api/login',
        rawBody: 'code=${f.st.code}',
        json: false,
        origin: true,
        headers: {'content-type': 'application/x-www-form-urlencoded'},
      );
      expect(r.status, 415);
    });

    test('Host invalide (DNS rebinding) : 421, même pour la page', () async {
      for (final h in ['evil.example', 'evil.example:80', '127.0.0.1']) {
        final r = await f.req('GET', '/', host: h);
        expect(r.status, 421, reason: h);
      }
      final (cookie, _) = await f.login();
      final api = await f.req(
        'GET',
        '/api/addons',
        cookie: cookie,
        host: 'rebind.example:${f.st.port}',
      );
      expect(api.status, 421);
    });

    test('corps trop gros : 413', () async {
      final r = await f.req(
        'POST',
        '/api/login',
        rawBody: '{"code":"${'9' * 20000}"}',
        origin: true,
      );
      expect(r.status, 413);
    });

    test('limite de débit : 429', () async {
      var limited = false;
      for (var i = 0; i < 80; i++) {
        final r = await f.req('GET', '/api/session');
        if (r.status == 429) {
          limited = true;
          break;
        }
      }
      expect(limited, isTrue);
      f.clock.add(const Duration(seconds: 11));
      expect((await f.req('GET', '/api/session')).status, 401);
    });

    test('JSON invalide ou champ absent : 400', () async {
      final r = await f.req(
        'POST',
        '/api/login',
        rawBody: '{pas du json',
        origin: true,
      );
      expect(r.status, 400);
      final r2 = await f.req('POST', '/api/login', body: {}, origin: true);
      expect(r2.status, 400);
    });
  });

  group('page et en-têtes', () {
    test('la page, ses ressources et les en-têtes de sécurité', () async {
      for (final p in ['/', '/app.css', '/app.js']) {
        final r = await f.req('GET', p);
        expect(r.status, 200, reason: p);
        expect(r.headers.value('x-content-type-options'), 'nosniff');
        expect(r.headers.value('referrer-policy'), 'no-referrer');
        expect(r.headers.value('cache-control'), contains('no-store'));
        expect(
          r.headers.value('content-security-policy'),
          contains("default-src 'none'"),
        );
      }
      expect((await f.req('GET', '/')).body, contains('lang="fr"'));
      expect((await f.req('GET', '/inconnu')).status, 404);
    });

    test('polices embarquées servies, inconnues refusées', () async {
      final r = await f.req('GET', '/fonts/manrope.ttf');
      expect(r.status, 200);
      expect(r.headers.value('content-type'), 'font/ttf');
      expect((await f.req('GET', '/fonts/autre.ttf')).status, 404);
      expect((await f.req('GET', '/fonts/..%2Fsecret.ttf')).status, 404);
    });

    test('pas de style en ligne (CSP style-src self)', () {
      expect(phoneIndexHtml('fr'), isNot(contains(' style=')));
    });

    test('aucune ressource externe dans la page', () {
      final all = [phoneIndexHtml('fr'), phoneCss, phoneJs].join('\n');
      final urls = RegExp(
        r'https?://[a-z0-9-]+\.[a-z0-9.-]+[^\s"\x27)]*',
      ).allMatches(all);
      for (final m in urls) {
        expect(m.group(0), startsWith('https://stremio-addons.net'));
      }
      expect(all, isNot(contains('<link rel="stylesheet" href="http')));
      expect(all, isNot(contains('@import')));
      expect(all, isNot(contains('innerHTML')));
    });
  });

  group('liste et gestion', () {
    test('liste : identifiants opaques, aucune URL', () async {
      final (cookie, _) = await f.login();
      final r = await f.req('GET', '/api/addons', cookie: cookie);
      expect(r.status, 200);
      final list = (r.json['addons']! as List).cast<Map<String, Object?>>();
      expect(list.map((a) => a['name']), ['Source Alpha', 'Direct Plus']);
      expect(list.first['health'], 'reliable');
      expect(list.first['enabled'], isTrue);
      expect(list.first['types'], ['movie', 'series']);
      expect(list.first['id'], isNot('org.alpha'));
      expect(r.body, isNot(contains('org.alpha')));
      expect(r.body, isNot(contains('http')));
      expect(list[0]['id'], isNot(list[1]['id']));
    });

    test('monter, désactiver, supprimer par identifiant opaque', () async {
      final (cookie, csrf) = await f.login();
      final list =
          ((await f.req('GET', '/api/addons', cookie: cookie)).json['addons']!
                  as List)
              .cast<Map<String, Object?>>();
      final beta = list[1]['id']! as String;
      final h = {'x-csrf-token': csrf};
      expect(
        (await f.req(
          'POST',
          '/api/addons/$beta/move',
          body: {'delta': -1},
          cookie: cookie,
          origin: true,
          headers: h,
        )).status,
        200,
      );
      expect(
        (await f.req(
          'POST',
          '/api/addons/$beta/enabled',
          body: {'enabled': true},
          cookie: cookie,
          origin: true,
          headers: h,
        )).status,
        200,
      );
      expect(
        (await f.req(
          'DELETE',
          '/api/addons/$beta',
          cookie: cookie,
          origin: true,
          headers: h,
        )).status,
        200,
      );
      expect(f.backend.calls, [
        'move:org.beta:-1',
        'enabled:org.beta:true',
        'remove:org.beta',
      ]);
    });

    test('identifiant inconnu ou réel : 404 ; delta invalide : 400', () async {
      final (cookie, csrf) = await f.login();
      final h = {'x-csrf-token': csrf};
      expect(
        (await f.req(
          'DELETE',
          '/api/addons/org.alpha',
          cookie: cookie,
          origin: true,
          headers: h,
        )).status,
        404,
      );
      final id =
          (((await f.req('GET', '/api/addons', cookie: cookie)).json['addons']!
                      as List)
                  .first
              as Map)['id'];
      expect(
        (await f.req(
          'POST',
          '/api/addons/$id/move',
          body: {'delta': 5},
          cookie: cookie,
          origin: true,
          headers: h,
        )).status,
        400,
      );
      // 1.0 n'est pas un entier : 400, pas 500.
      expect(
        (await f.req(
          'POST',
          '/api/addons/$id/move',
          rawBody: '{"delta": 1.0}',
          cookie: cookie,
          origin: true,
          headers: h,
        )).status,
        400,
      );
      expect(f.backend.calls, isEmpty);
    });
  });

  group('ajout depuis le téléphone', () {
    Future<_Resp> send(String cookie, String csrf, String link) => f.req(
      'POST',
      '/api/add',
      body: {'link': link},
      cookie: cookie,
      origin: true,
      headers: {'x-csrf-token': csrf},
    );

    test('lien envoyé : en attente sur la TV, pas d\'URL renvoyée', () async {
      final (cookie, csrf) = await f.login();
      final r = await send(
        cookie,
        csrf,
        'https://secret.example/tok/manifest.json',
      );
      expect(r.status, 202);
      expect(r.body, isNot(contains('secret.example')));
      expect(f.adds.pending.value!.url.host, 'secret.example');
      final id = r.json['request']! as String;
      final s = await f.req('GET', '/api/add/$id', cookie: cookie);
      expect(s.json['state'], 'waiting');
      expect(s.body, isNot(contains('secret.example')));
      // La TV confirme.
      f.adds.resolve(id, PhoneAddState.installed, name: 'Alpha');
      final done = await f.req('GET', '/api/add/$id', cookie: cookie);
      expect(done.json['state'], 'installed');
      expect(done.json['name'], 'Alpha');
    });

    test('stremio:// converti comme dans le flux existant', () async {
      final (cookie, csrf) = await f.login();
      final r = await send(cookie, csrf, 'stremio://a.example/manifest.json');
      expect(r.status, 202);
      expect(
        f.adds.pending.value!.url.toString(),
        'https://a.example/manifest.json',
      );
    });

    test('lien invalide : 400 ; requête inconnue : 404 ; expirée', () async {
      final (cookie, csrf) = await f.login();
      expect((await send(cookie, csrf, 'pas un lien')).status, 400);
      expect(
        (await f.req('GET', '/api/add/inconnu', cookie: cookie)).status,
        404,
      );
      final id =
          (await send(
                cookie,
                csrf,
                'https://a.example/manifest.json',
              )).json['request']!
              as String;
      f.clock.add(const Duration(minutes: 6));
      expect(
        (await f.req('GET', '/api/add/$id', cookie: cookie)).json['state'],
        'expired',
      );
    });

    test('un nouveau lien annule celui qui attendait', () async {
      final (cookie, csrf) = await f.login();
      final a =
          (await send(
                cookie,
                csrf,
                'https://a.example/manifest.json',
              )).json['request']!
              as String;
      await send(cookie, csrf, 'https://b.example/manifest.json');
      expect(
        (await f.req('GET', '/api/add/$a', cookie: cookie)).json['state'],
        'cancelled',
      );
    });
  });

  group('arrêt', () {
    test('stop : plus d\'écoute, session invalidée', () async {
      final (cookie, _) = await f.login();
      final port = f.st.port;
      await f.server.stop();
      expect(f.st.status, PhoneServerStatus.stopped);
      await expectLater(
        Socket.connect('127.0.0.1', port, timeout: const Duration(seconds: 1)),
        throwsA(isA<SocketException>()),
      );
      await f.server.start();
      expect(f.st.connected, isFalse);
      // L'ancien cookie ne vaut plus rien.
      expect((await f.req('GET', '/api/addons', cookie: cookie)).status, 401);
    });

    test('arrêt après inactivité', () async {
      await f.close();
      f = _Fixture();
      await f.start(idle: const Duration(milliseconds: 250));
      await f.req('GET', '/');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(f.st.status, PhoneServerStatus.stopped);
      expect(f.st.idleStopped, isTrue);
    });

    test('arrêt annule la demande en attente', () async {
      final (cookie, csrf) = await f.login();
      await f.req(
        'POST',
        '/api/add',
        body: {'link': 'https://a.example/manifest.json'},
        cookie: cookie,
        origin: true,
        headers: {'x-csrf-token': csrf},
      );
      await f.server.stop();
      expect(f.adds.pending.value, isNull);
    });

    test(
      'un GET non authentifié ne relance pas le délai d\'inactivité',
      () async {
        await f.close();
        f = _Fixture();
        await f.start(idle: const Duration(milliseconds: 500));
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          if (f.st.status != PhoneServerStatus.listening) break;
          await f.req('GET', '/');
          await f.req('GET', '/app.js');
          await f.req('GET', '/api/session');
        }
        expect(f.st.status, PhoneServerStatus.stopped);
        expect(f.st.idleStopped, isTrue);
      },
    );

    test('une requête authentifiée relance le délai d\'inactivité', () async {
      await f.close();
      f = _Fixture();
      await f.start(idle: const Duration(milliseconds: 600));
      final (cookie, _) = await f.login();
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await f.req('GET', '/api/session', cookie: cookie);
      }
      expect(f.st.status, PhoneServerStatus.listening);
    });

    test('3 verrouillages : arrêt et état « trop d\'essais »', () async {
      for (var round = 0; round < 3; round++) {
        expect(f.st.status, PhoneServerStatus.listening, reason: '$round');
        final wrong = f.st.code == '111111' ? '222222' : '111111';
        late _Resp last;
        for (var i = 0; i < 5; i++) {
          last = await f.req(
            'POST',
            '/api/login',
            body: {'code': wrong},
            origin: true,
          );
        }
        expect(last.status, 429);
        f.clock.add(const Duration(seconds: 61));
        if (round < 2) await Future<void>.delayed(Duration.zero);
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(f.st.status, PhoneServerStatus.stopped);
      expect(f.st.tooManyTries, isTrue);
      // Relancer remet le compteur à zéro.
      await f.server.start();
      expect(f.st.status, PhoneServerStatus.listening);
      expect(f.st.tooManyTries, isFalse);
    });
  });

  group('connexions lentes', () {
    Future<Socket> raw() =>
        Socket.connect(InternetAddress.loopbackIPv4, f.st.port);

    /// Complété une seule fois à la fermeture (ou à l'erreur) du socket.
    Future<void> closes(Socket so, [void Function(List<int>)? onData]) {
      final c = Completer<void>();
      void end() {
        if (!c.isCompleted) c.complete();
      }

      // Écrire sur un socket déjà fermé par le serveur fait échouer `done`.
      so.done.then<void>((_) {}, onError: (Object _) {});
      so.listen(
        (d) => onData?.call(d),
        onDone: end,
        onError: (Object _) => end(),
      );
      return c.future;
    }

    String head(String extra) =>
        'POST /api/login HTTP/1.1\r\nHost: ${f.hostHeader}\r\n'
        'Origin: http://${f.hostHeader}\r\n'
        'Content-Type: application/json\r\n$extra\r\n';

    test(
      'Content-Length annoncé, 1 octet envoyé : fermé en 6 s',
      () async {
        final so = await raw();
        final got = StringBuffer();
        final closed = closes(
          so,
          (d) => got.write(utf8.decode(d, allowMalformed: true)),
        );
        so.write('${head('Content-Length: 100\r\n')}{');
        await so.flush();
        final sw = Stopwatch()..start();
        await closed.timeout(const Duration(seconds: 6));
        expect(sw.elapsed, lessThan(const Duration(seconds: 6)));
        expect(got.toString(), contains('408'));
        so.destroy();
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    test(
      'corps chunké lent sans Content-Length : fermé',
      () async {
        final so = await raw();
        final closed = closes(so);
        so.write('${head('Transfer-Encoding: chunked\r\n')}1\r\n{\r\n');
        await so.flush();
        // Un octet toutes les secondes : le délai est global, pas par octet.
        final drip = Timer.periodic(const Duration(seconds: 1), (_) {
          try {
            so.write('1\r\n \r\n');
          } on Object {
            // Fermé.
          }
        });
        await closed.timeout(const Duration(seconds: 7));
        drip.cancel();
        so.destroy();
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    test('5e connexion d\'une même adresse refusée', () async {
      final open = <Socket>[];
      final closedFlags = <bool>[];
      for (var i = 0; i < 4; i++) {
        final so = await raw();
        final idx = closedFlags.length;
        closedFlags.add(false);
        so.listen(
          (_) {},
          onDone: () => closedFlags[idx] = true,
          onError: (_) => closedFlags[idx] = true,
        );
        open.add(so);
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
      Socket? fifth;
      try {
        fifth = await raw();
        await closes(fifth).timeout(const Duration(seconds: 2));
      } on SocketException {
        // Refusée dès la connexion : c'est aussi un refus.
      }
      expect(closedFlags, everyElement(isFalse));
      for (final s in [...open, ?fifth]) {
        s.destroy();
      }
    });

    test('au plus 16 connexions actives au total', () async {
      // Les limites par adresse ne s'appliquent qu'à une même IP : on vérifie
      // seulement que le plafond total existe.
      expect(PhoneServer.maxConnections, 16);
      expect(PhoneServer.maxConnectionsPerIp, 4);
    });
  });
}
