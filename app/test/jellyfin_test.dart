import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/jellyfin_repository.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio/features/detail/playback_service.dart';
import 'package:lumio/features/jellyfin/jellyfin_providers.dart';
import 'package:lumio/features/jellyfin/jellyfin_screen.dart';
import 'package:lumio/l10n/app_localizations_fr.dart';
import 'package:lumio/l10n/error_messages.dart';
import 'package:lumio/player/player_screen.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';
import 'package:lumio_core/testing.dart';

const _token = 'tok-SECRET-999';

/// Faux Jellyfin en mémoire (sans socket) pour les tests de widgets.
class _MemJellyfin implements HttpPostFetcher {
  String? rating = 'PG';
  final seen = <Uri>[];
  Object? postError;

  FetchResponse _json(Object o, [int status = 200]) =>
      FetchResponse(status: status, body: utf8.encode(jsonEncode(o)));

  @override
  Future<FetchResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) async {
    guard?.call(url);
    seen.add(url);
    if (url.path == '/Users/u1/Views') {
      return _json({
        'Items': [
          {'Id': 'lib1', 'Name': 'Films'},
        ],
      });
    }
    if (url.path == '/Users/u1/Items') {
      return _json({
        'TotalRecordCount': 2,
        'Items': [
          {
            'Id': 'm1',
            'Name': 'Sintel',
            'Type': 'Movie',
            'OfficialRating': 'G',
          },
          {'Id': 'm2', 'Name': 'Inconnu', 'Type': 'Movie'},
        ],
      });
    }
    if (url.path == '/Users/u1/Items/m1') {
      return _json({
        'Id': 'm1',
        'Name': 'Sintel',
        'Type': 'Movie',
        'OfficialRating': rating,
      });
    }
    return _json({}, 404);
  }

  @override
  Future<FetchResponse> post(
    Uri url, {
    required List<int> body,
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) async {
    guard?.call(url);
    if (postError != null) throw postError!;
    if (url.path == '/Users/AuthenticateByName') {
      return _json({
        'AccessToken': _token,
        'User': {'Id': 'u1', 'Name': 'Ana'},
      });
    }
    return _json({});
  }
}

Future<FakeAddonServer> _server() async {
  final s = await FakeAddonServer.start();
  s.routeWith('/Users/AuthenticateByName', (r) {
    final b = jsonDecode(r.bodyText) as Map;
    return b['Pw'] == 'pw'
        ? FakeResponse.json({
            'AccessToken': _token,
            'ServerName': 'Salon',
            'User': {'Id': 'u1', 'Name': 'Ana'},
          })
        : FakeResponse.json({}, status: 401);
  });
  s.route('/Sessions/Logout', FakeResponse.json({}));
  return s;
}

const _kid = Profile(
  id: 'kid',
  name: 'Léa',
  createdAt: 0,
  ageLimit: 1,
  isKid: true,
  locked: false,
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('JellyfinRepository', () {
    late FakeAddonServer server;
    late MemorySecretStore store;
    late JellyfinRepository repo;

    // flutter_test remplace HttpClient par un faux qui répond 400 : vrai
    // réseau (boucle locale) pour ces tests.
    setUpAll(() => HttpOverrides.global = null);

    setUp(() async {
      server = await _server();
      store = MemorySecretStore();
      repo = JellyfinRepository(store, IoHttpFetcher(), version: '1.0.0');
    });
    tearDown(() => server.close());

    test('ajout : jeton dans le SecretStore, absent de la liste', () async {
      final s = await repo.addServer(server.baseUrl, 'ana', 'pw');
      expect(s.name, 'Salon');
      expect(s.allowPrivate, isTrue, reason: 'adresse saisie = accord');
      expect(store.snapshot['jellyfin.token.${s.id}'], _token);
      expect(store.snapshot['jellyfin.servers'], isNot(contains(_token)));
      expect(store.snapshot['jellyfin.servers'], isNot(contains('pw')));
      expect((await repo.list()).single.id, s.id);
      final c = await repo.client(s.id);
      expect(c!.token, _token);
      expect(c.allowPrivate, isTrue);
    });

    test('identifiant d\'appareil stable', () async {
      final a = await repo.deviceId();
      expect(a, hasLength(32));
      expect(await repo.deviceId(), a);
      await repo.addServer(server.baseUrl, 'ana', 'pw');
      expect(
        server.requests.first.headers['authorization'],
        contains('DeviceId="$a"'),
      );
    });

    test('mauvais mot de passe : rien d\'enregistré', () async {
      await expectLater(
        repo.addServer(server.baseUrl, 'ana', 'faux'),
        throwsA(isA<JellyfinAuthException>()),
      );
      expect(await repo.list(), isEmpty);
      expect(store.snapshot.keys.where((k) => k.contains('token')), isEmpty);
    });

    test('http public : confirmation obligatoire, aucun envoi', () async {
      await expectLater(
        repo.addServer(Uri.parse('http://jellyfin.example.com'), 'a', 'b'),
        throwsA(isA<JellyfinInsecureException>()),
      );
      expect(server.requests, isEmpty);
    });

    test(
      'déconnexion : jeton supprimé même si le serveur est absent',
      () async {
        final s = await repo.addServer(server.baseUrl, 'ana', 'pw');
        await server.close();
        await repo.remove(s.id);
        expect(await repo.list(), isEmpty);
        expect(store.snapshot.keys.where((k) => k.contains('token')), isEmpty);
        expect(await repo.client(s.id), isNull);
        server = await _server();
      },
    );

    test('déconnexion : le serveur reçoit Logout', () async {
      final s = await repo.addServer(server.baseUrl, 'ana', 'pw');
      await repo.remove(s.id);
      expect(server.requests.last.uri.path, '/Sessions/Logout');
    });

    test('identifiants jellyfin:<serveur>:<id>', () {
      final id = jellyfinItemId('abc', 'it:1');
      expect(id, 'jellyfin:abc:it:1');
      final p = parseJellyfinId(id)!;
      expect(p.serverId, 'abc');
      expect(p.itemId, 'it:1');
      expect(parseJellyfinId('tt1'), isNull);
      expect(parseJellyfinId('jellyfin:abc'), isNull);
    });

    test('aperçu : badge Jellyfin et certification pour le filtre', () async {
      final s = await repo.addServer(server.baseUrl, 'ana', 'pw');
      final c = (await repo.client(s.id))!;
      final m = repo.preview(
        s,
        c,
        const JellyfinItem(
          id: 'x',
          name: 'Film',
          type: 'Movie',
          officialRating: 'TV-MA',
          imageTag: 't',
        ),
      );
      expect(m.sourceKind, 'jellyfin');
      expect(m.id, 'jellyfin:${s.id}:x');
      expect(m.certification, 'TV-MA');
      expect(m.poster.toString(), isNot(contains(_token)));
      expect(ratingAllows(m.certification, AgeLimit.age12), isFalse);
    });
  });

  group('l10nForError', () {
    final l = AppLocalizationsFr();
    test('erreurs Jellyfin traduites, certificat explicite', () {
      expect(l10nForError(l, const JellyfinAuthException()), l.jellyfinErrAuth);
      expect(
        l10nForError(l, const JellyfinAuthException(expired: true)),
        l.jellyfinErrExpired,
      );
      expect(
        l10nForError(l, const CertificateException('x')),
        contains('Certificat'),
      );
      expect(
        l10nForError(l, const JellyfinException(JellyfinErrorCode.timeout)),
        l.jellyfinErrTimeout,
      );
      expect(
        l10nForError(l, const JellyfinInsecureException()),
        contains('en clair'),
      );
    });
  });

  group('lecture', () {
    late _MemJellyfin net;
    late ProviderContainer container;
    late AppDatabase db;
    final screens = <PlayerScreen>[];

    Future<JellyfinServer> start(WidgetTester t, {Profile? profile}) async {
      net = _MemJellyfin();
      screens.clear();
      db = AppDatabase(NativeDatabase.memory());
      final store = MemorySecretStore();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          secretStoreProvider.overrideWithValue(store),
          jellyfinFetcherProvider.overrideWithValue(net),
          playerBuilderProvider.overrideWithValue((s) {
            screens.add(s);
            return const Scaffold(body: Text('LECTEUR'));
          }),
        ],
      );
      addTearDown(container.dispose);
      final server = await container
          .read(jellyfinRepositoryProvider)
          .addServer(Uri.parse('http://192.168.1.20:8096'), 'ana', 'pw');
      if (profile != null) {
        container.read(currentProfileProvider.notifier).select(profile);
      }
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: LumioTheme.dark(),
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  key: const ValueKey('go'),
                  onPressed: () => playJellyfinFromWidget(
                    context,
                    ref,
                    serverId: server.id,
                    itemId: 'm1',
                  ),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      );
      return server;
    }

    testWidgets('flux via le proxy : jeton en en-tête, jamais dans l\'URL', (
      t,
    ) async {
      final server = await start(t);
      expect(server.allowPrivate, isTrue);
      await t.tap(find.byKey(const ValueKey('go')));
      await t.pumpAndSettle();
      expect(screens, hasLength(1));
      final s = screens.single;
      expect(s.item.url.toString(), isNot(contains(_token)));
      expect(s.item.url!.queryParameters.containsKey('api_key'), isFalse);
      expect(s.item.requestHeaders['Authorization'], contains(_token));
      expect(s.allowPrivate, isTrue);
      expect(s.metaId, 'jellyfin:${server.id}:m1');
      expect(s.videoId, s.metaId);
      expect(s.meta?.certification, 'PG');
      // Jamais de lecture directe : c'est routePlayback qui passe par le proxy
      // pour tout flux d'addon (pas de trustedLocal dans le PlayerScreen).
      await t.runAsync(db.close);
    });

    testWidgets('profil enfant : classification inconnue, lecture refusée', (
      t,
    ) async {
      await start(t, profile: _kid);
      net.rating = null;
      await t.tap(find.byKey(const ValueKey('go')));
      await t.pumpAndSettle();
      expect(screens, isEmpty);
      expect(find.textContaining('pas autorisé'), findsOneWidget);
      await t.runAsync(db.close);
    });

    testWidgets('profil enfant : classification trop haute refusée', (t) async {
      await start(t, profile: _kid);
      net.rating = 'TV-MA';
      await t.tap(find.byKey(const ValueKey('go')));
      await t.pumpAndSettle();
      expect(screens, isEmpty);
      await t.runAsync(db.close);
    });

    testWidgets('profil enfant : classification permise, lecture lancée', (
      t,
    ) async {
      await start(t, profile: _kid);
      net.rating = 'G';
      await t.tap(find.byKey(const ValueKey('go')));
      await t.pumpAndSettle();
      expect(screens, hasLength(1));
      await t.runAsync(db.close);
    });
  });

  group('accueil et réglages', () {
    late _MemJellyfin net;
    late ProviderContainer container;
    late AppDatabase db;

    Future<void> pumpServers(WidgetTester t) async {
      net = _MemJellyfin();
      db = AppDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          secretStoreProvider.overrideWithValue(MemorySecretStore()),
          jellyfinFetcherProvider.overrideWithValue(net),
        ],
      );
      addTearDown(container.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: LumioTheme.dark(),
            home: const JellyfinServersScreen(),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    Future<void> fill(WidgetTester t, String url) async {
      await t.tap(find.byKey(const ValueKey('jellyfin-add')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('jellyfin-url')), url);
      await t.enterText(find.byKey(const ValueKey('jellyfin-user')), 'ana');
      await t.enterText(find.byKey(const ValueKey('jellyfin-pass')), 'pw');
      await t.tap(find.byKey(const ValueKey('jellyfin-connect')));
      await t.pumpAndSettle();
    }

    testWidgets('liste vide puis ajout en https', (t) async {
      await pumpServers(t);
      expect(find.textContaining('Aucun serveur'), findsOneWidget);
      await fill(t, 'jellyfin.example.com');
      expect(find.byKey(const ValueKey('jellyfin-insecure')), findsNothing);
      expect(find.textContaining('Connecté en tant que Ana'), findsOneWidget);
      await t.runAsync(db.close);
    });

    testWidgets('http public : avertissement, refus = aucune connexion', (
      t,
    ) async {
      await pumpServers(t);
      await fill(t, 'http://jellyfin.example.com');
      expect(
        find.textContaining('votre mot de passe circulerait en clair'),
        findsOneWidget,
      );
      await t.tap(find.text('Annuler').last);
      await t.pumpAndSettle();
      expect(await container.read(jellyfinRepositoryProvider).list(), isEmpty);
      await t.runAsync(db.close);
    });

    testWidgets('http public confirmé : serveur ajouté', (t) async {
      await pumpServers(t);
      await fill(t, 'http://jellyfin.example.com');
      await t.tap(find.byKey(const ValueKey('jellyfin-insecure-ok')));
      await t.pumpAndSettle();
      expect(
        await container.read(jellyfinRepositoryProvider).list(),
        hasLength(1),
      );
      await t.runAsync(db.close);
    });

    testWidgets('http en réseau privé : pas d\'avertissement', (t) async {
      await pumpServers(t);
      await fill(t, 'http://192.168.1.20:8096');
      expect(find.byKey(const ValueKey('jellyfin-insecure')), findsNothing);
      expect(
        await container.read(jellyfinRepositoryProvider).list(),
        hasLength(1),
      );
      await t.runAsync(db.close);
    });

    testWidgets('certificat invalide : erreur explicite, rien d\'enregistré', (
      t,
    ) async {
      await pumpServers(t);
      net.postError = const HandshakeException('CERTIFICATE_VERIFY_FAILED');
      await fill(t, 'https://jellyfin.example.com');
      expect(
        find.textContaining('Certificat du serveur invalide'),
        findsOneWidget,
      );
      expect(await container.read(jellyfinRepositoryProvider).list(), isEmpty);
      await t.runAsync(db.close);
    });

    testWidgets('retrait : jeton supprimé du SecretStore', (t) async {
      await pumpServers(t);
      await fill(t, 'http://192.168.1.20:8096');
      final id =
          (await container.read(jellyfinRepositoryProvider).list()).single.id;
      await t.tap(find.byKey(ValueKey('jellyfin-remove:$id')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('jellyfin-remove-ok')));
      await t.pumpAndSettle();
      expect(await container.read(jellyfinRepositoryProvider).list(), isEmpty);
      expect(
        await container.read(jellyfinRepositoryProvider).client(id),
        isNull,
      );
      await t.runAsync(db.close);
    });

    test(
      'rangées : une par bibliothèque ; erreur isolée par serveur',
      () async {
        net = _MemJellyfin();
        final store = MemorySecretStore();
        final c = ProviderContainer(
          overrides: [
            secretStoreProvider.overrideWithValue(store),
            jellyfinFetcherProvider.overrideWithValue(net),
          ],
        );
        addTearDown(c.dispose);
        final repo = c.read(jellyfinRepositoryProvider);
        final s = await repo.addServer(
          Uri.parse('http://192.168.1.20:8096'),
          'a',
          'pw',
        );
        c.invalidate(jellyfinServersProvider);
        final rows = await c.read(jellyfinRowsProvider.future);
        expect(rows.single.id, 'jf:${s.id}|lib1');
        expect(rows.single.items.map((e) => e.sourceKind).toSet(), {
          'jellyfin',
        });
        expect(rows.single.allowPrivate, isTrue);
        // Filtre enfant : l'élément sans classification est masqué.
        final kid = rows.single.items
            .where((m) => ratingAllows(m.certification, AgeLimit.age7))
            .map((m) => m.name);
        expect(kid, ['Sintel']);
        // Jeton perdu : rangée d'erreur « session expirée ».
        await store.delete('jellyfin.token.${s.id}');
        c.invalidate(jellyfinRowsProvider);
        final failed = await c.read(jellyfinRowsProvider.future);
        expect(failed.single.id, 'jf:${s.id}|error');
        expect(failed.single.error, isA<JellyfinAuthException>());
      },
    );
  });
}
