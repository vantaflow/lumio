import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio/data/sync_service.dart';
import 'package:lumio/data/sync_store.dart';

class FakeReq {
  FakeReq(this.method, this.url, this.headers, this.body);
  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String? body;
}

class FakeHttp implements SyncHttp {
  final requests = <FakeReq>[];
  SyncHttpResponse Function(FakeReq r)? handler;
  bool offline = false;

  @override
  Future<SyncHttpResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    String? body,
  }) async {
    final r = FakeReq(method, url, headers, body);
    requests.add(r);
    if (offline) throw const SyncException(SyncErrorCode.unavailable);
    return handler!(r);
  }
}

class FakeTimer implements Timer {
  FakeTimer(this.duration, this.callback);
  final Duration duration;
  final void Function() callback;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;
}

SyncHttpResponse _json(int status, Object body, [Map<String, String>? h]) =>
    SyncHttpResponse(status, jsonEncode(body), h ?? const {});

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late DriftLocalSyncStore store;
  late MemorySecretStore secrets;
  late FakeHttp http;
  late SyncApiClient api;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalSyncStore(db);
    secrets = MemorySecretStore();
    http = FakeHttp();
    api = SyncApiClient('https://sync.example.com', secrets, http: http);
  });
  tearDown(() => db.close());

  Future<void> signIn() async {
    await secrets.write(SyncSecretKeys.session, 'sess1');
    await secrets.write(SyncSecretKeys.refresh, 'ref1');
    await secrets.write(SyncSecretKeys.email, 'a@example.com');
  }

  test('adresse du serveur : https obligatoire (http seulement en local)', () {
    expect(
      () => SyncApiClient('http://sync.example.com', secrets),
      throwsA(isA<SyncException>()),
    );
    expect(
      () => SyncApiClient('https://u:p@sync.example.com', secrets),
      throwsA(isA<SyncException>()),
    );
    expect(
      SyncApiClient('http://localhost:8787', secrets).baseUrl.host,
      'localhost',
    );
  });

  group('connexion', () {
    test(
      'code par e-mail puis session mémorisée dans le SecretStore',
      () async {
        http.handler = (r) {
          if (r.url.path == '/auth/request') {
            return const SyncHttpResponse(202, '');
          }
          return _json(200, {
            'session': 'S',
            'refresh': 'R',
            'expiresIn': 3600,
          });
        };
        await api.requestCode(' a@example.com ');
        expect(jsonDecode(http.requests.last.body!), {
          'email': 'a@example.com',
        });
        await api.verifyCode('A@Example.com', ' CODE-1 ');
        expect(jsonDecode(http.requests.last.body!), {'token': 'CODE-1'});
        expect(secrets.snapshot[SyncSecretKeys.session], 'S');
        expect(secrets.snapshot[SyncSecretKeys.refresh], 'R');
        expect(await api.email(), 'a@example.com');
        expect(await api.isSignedIn(), isTrue);
      },
    );

    test('code refusé : erreur « rejected », rien de stocké', () async {
      http.handler = (r) => _json(401, {'error': 'x'});
      await expectLater(
        api.verifyCode('a@example.com', 'mauvais'),
        throwsA(
          isA<SyncException>().having(
            (e) => e.code,
            'code',
            SyncErrorCode.rejected,
          ),
        ),
      );
      expect(secrets.snapshot, isEmpty);
    });

    test('429 : délai du serveur conservé', () async {
      http.handler = (r) =>
          const SyncHttpResponse(429, '', {'retry-after': '42'});
      await expectLater(
        api.requestCode('a@example.com'),
        throwsA(
          isA<SyncException>()
              .having((e) => e.code, 'code', SyncErrorCode.rateLimited)
              .having(
                (e) => e.retryAfter,
                'retryAfter',
                const Duration(seconds: 42),
              ),
        ),
      );
    });

    test('déconnexion : jetons effacés', () async {
      await signIn();
      await api.signOut();
      expect(secrets.snapshot, isEmpty);
      expect(await api.isSignedIn(), isFalse);
    });
  });

  group('session', () {
    test(
      '401 : renouvellement puis nouvel essai avec le nouveau jeton',
      () async {
        await signIn();
        http.handler = (r) {
          if (r.url.path == '/auth/refresh') {
            expect(jsonDecode(r.body!), {'refresh': 'ref1'});
            return _json(200, {'session': 'sess2', 'refresh': 'ref2'});
          }
          if (r.headers['Authorization'] == 'Bearer sess1') {
            return _json(401, {});
          }
          return _json(200, {'items': [], 'version': 0, 'more': false});
        };
        final page = await api.pull(0);
        expect(page.items, isEmpty);
        expect(secrets.snapshot[SyncSecretKeys.refresh], 'ref2');
        expect(http.requests.map((r) => r.url.path), [
          '/sync',
          '/auth/refresh',
          '/sync',
        ]);
      },
    );

    test('renouvellement refusé : déconnexion et erreur signedOut', () async {
      await signIn();
      http.handler = (r) => _json(401, {});
      await expectLater(
        api.pull(0),
        throwsA(
          isA<SyncException>().having(
            (e) => e.code,
            'code',
            SyncErrorCode.signedOut,
          ),
        ),
      );
      expect(secrets.snapshot, isEmpty);
    });

    test('appels simultanés : un seul renouvellement', () async {
      await signIn();
      var refreshes = 0;
      http.handler = (r) {
        if (r.url.path == '/auth/refresh') {
          refreshes++;
          return _json(200, {'session': 'sess2', 'refresh': 'ref2'});
        }
        if (r.headers['Authorization'] == 'Bearer sess1') return _json(401, {});
        return _json(200, {'items': [], 'version': 0, 'more': false});
      };
      await Future.wait([api.pull(0), api.pull(0), api.pull(0)]);
      expect(refreshes, 1);
    });

    test(
      'suppression du compte : DELETE /account puis jetons effacés',
      () async {
        await signIn();
        http.handler = (r) => const SyncHttpResponse(204, '');
        await api.deleteAccount();
        expect(http.requests.single.method, 'DELETE');
        expect(http.requests.single.url.path, '/account');
        expect(secrets.snapshot, isEmpty);
      },
    );

    test('réponse de pull illisible : erreur propre', () async {
      await signIn();
      http.handler = (r) => const SyncHttpResponse(200, '{pas du json');
      await expectLater(api.pull(0), throwsA(isA<SyncException>()));
    });
  });

  group('service', () {
    late List<FakeTimer> timers;
    late SyncService service;
    var applied = 0;

    SyncService make() => SyncService(
      api: api,
      store: store,
      onApplied: () => applied++,
      timer: (d, cb) {
        final t = FakeTimer(d, cb);
        timers.add(t);
        return t;
      },
    );

    setUp(() {
      timers = [];
      applied = 0;
      service = make();
    });
    tearDown(() => service.dispose());

    Future<void> insertLibrary(String id) => db
        .into(db.libraryItems)
        .insert(
          LibraryItemsCompanion.insert(
            itemId: id,
            type: 'movie',
            metaJson: const Value('{"name":"x"}'),
          ),
        );

    test(
      'connecté : envoie le contenu local avec le jeton, puis tire',
      () async {
        await insertLibrary('tt1');
        final pushed = <Map<String, dynamic>>[];
        http.handler = (r) {
          if (r.method == 'POST') {
            expect(r.headers['Authorization'], 'Bearer sess1');
            pushed.addAll(
              ((jsonDecode(r.body!) as Map)['items'] as List)
                  .cast<Map<String, dynamic>>(),
            );
            return _json(200, {'version': 1});
          }
          return _json(200, {
            'items': [
              {
                'kind': 'library',
                'key': 'default|tt2',
                'payload': {
                  'type': 'movie',
                  'meta': {'name': 'Sintel'},
                },
                'version': 2,
                'deleted': 0,
              },
            ],
            'version': 2,
            'more': false,
          });
        };
        await signIn();
        await service.start();
        await service.syncNow();
        expect(pushed.map((e) => e['key']), contains('default|tt1'));
        expect(pushed.every((e) => e['kind'] != 'addons'), isTrue);
        expect(
          (await db.select(db.libraryItems).get()).map((r) => r.itemId).toSet(),
          {'tt1', 'tt2'},
        );
        expect(await store.lastVersion(), 2);
        expect(service.status, SyncStatus.idle);
        expect(applied, greaterThan(0));
        expect(timers.last.duration, const Duration(seconds: 15));
      },
    );

    test(
      'hors ligne : ne lève jamais, recul exponentiel plafonné, file conservée',
      () async {
        await signIn();
        await insertLibrary('tt1');
        http.offline = true;
        await service.start();
        final delays = <Duration>[];
        for (var i = 0; i < 9; i++) {
          await service.syncNow();
          delays.add(timers.last.duration);
        }
        expect(service.status, SyncStatus.offline);
        expect(delays.first, const Duration(seconds: 30));
        expect(delays[1], const Duration(seconds: 60));
        expect(delays.last, const Duration(minutes: 5));
        expect(await store.pendingCount(), greaterThan(0));
        // Retour du réseau : tout part, le délai revient à 15 s.
        http.offline = false;
        http.handler = (r) => r.method == 'POST'
            ? _json(200, {'version': 1})
            : _json(200, {'items': [], 'version': 1, 'more': false});
        await service.syncNow();
        expect(service.status, SyncStatus.idle);
        expect(timers.last.duration, const Duration(seconds: 15));
        expect(await store.pendingCount(), 0);
      },
    );

    test('429 : on respecte le Retry-After du serveur', () async {
      await signIn();
      http.handler = (r) =>
          const SyncHttpResponse(429, '', {'retry-after': '120'});
      await service.start();
      await service.syncNow();
      expect(timers.last.duration, const Duration(seconds: 120));
    });

    test('pause de lecture : un cycle rapproché (1 s)', () async {
      await signIn();
      http.handler = (r) =>
          _json(200, {'items': [], 'version': 0, 'more': false});
      await service.start();
      await service.syncNow();
      service.syncSoon();
      expect(timers.last.duration, const Duration(seconds: 1));
      expect(timers.where((t) => !t.cancelled), hasLength(1));
    });

    test('arrière-plan : plus de cycle planifié', () async {
      await signIn();
      http.handler = (r) =>
          _json(200, {'items': [], 'version': 0, 'more': false});
      await service.start();
      await service.syncNow();
      service.stop();
      expect(timers.where((t) => !t.cancelled), isEmpty);
    });

    test('non connecté : aucun appel réseau', () async {
      await service.start();
      await service.syncNow();
      expect(http.requests, isEmpty);
      expect(service.status, SyncStatus.signedOut);
    });

    test(
      'session expirée pendant un cycle : état déconnecté, pas de boucle',
      () async {
        await signIn();
        http.handler = (r) => _json(401, {});
        await service.start();
        await service.syncNow();
        expect(service.status, SyncStatus.signedOut);
        final calls = http.requests.length;
        await service.syncNow();
        expect(
          http.requests.length,
          calls,
          reason: 'plus aucune requête une fois déconnecté',
        );
      },
    );

    test('signIn : curseur remis à zéro, contenu local proposé', () async {
      await insertLibrary('tt1');
      await store.setLastVersion(77);
      http.handler = (r) {
        if (r.url.path == '/auth/verify') {
          return _json(200, {'session': 'S', 'refresh': 'R'});
        }
        if (r.method == 'POST') return _json(200, {'version': 1});
        return _json(200, {'items': [], 'version': 1, 'more': false});
      };
      await service.start();
      await service.signIn('a@example.com', 'CODE');
      await service.syncNow();
      final get = http.requests.firstWhere((r) => r.method == 'GET');
      expect(get.url.queryParameters['since'], '0');
      expect(
        http.requests.any((r) => r.method == 'POST' && r.url.path == '/sync'),
        isTrue,
      );
    });

    test(
      'signOut : file et curseur oubliés, données locales gardées',
      () async {
        await signIn();
        await insertLibrary('tt1');
        await store.setLastVersion(5);
        await service.signOut();
        expect(await store.pendingCount(), 0);
        expect(await store.lastVersion(), 0);
        expect(await db.select(db.libraryItems).get(), hasLength(1));
        expect(service.status, SyncStatus.signedOut);
      },
    );

    test('deleteAccount : serveur puis local', () async {
      await signIn();
      http.handler = (r) => const SyncHttpResponse(204, '');
      await service.deleteAccount();
      expect(http.requests.single.method, 'DELETE');
      expect(await api.isSignedIn(), isFalse);
    });
  });
}
