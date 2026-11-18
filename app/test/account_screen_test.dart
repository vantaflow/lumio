import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio/data/sync_providers.dart';
import 'package:lumio/data/sync_service.dart';
import 'package:lumio/data/sync_store.dart';
import 'package:lumio/features/settings/account_screen.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/theme.dart';

class _Http implements SyncHttp {
  final paths = <String>[];
  int verifyStatus = 200;

  @override
  Future<SyncHttpResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    String? body,
  }) async {
    paths.add('$method ${url.path}');
    switch (url.path) {
      case '/auth/request':
        return const SyncHttpResponse(202, '');
      case '/auth/verify':
        return SyncHttpResponse(
          verifyStatus,
          jsonEncode({'session': 'S', 'refresh': 'R'}),
        );
      case '/account':
        return const SyncHttpResponse(204, '');
      default:
        if (method == 'POST') return SyncHttpResponse(200, '{"version":1}');
        return SyncHttpResponse(
          200,
          jsonEncode({'items': [], 'version': 1, 'more': false}),
        );
    }
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('connexion par code, état, déconnexion', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final secrets = MemorySecretStore();
    final http = _Http();
    final api = SyncApiClient('https://sync.example.com', secrets, http: http);
    final service = SyncService(api: api, store: DriftLocalSyncStore(db));
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        syncServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LumioTheme.dark(),
          locale: const Locale('fr'),
          supportedLocales: supportedUiLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AccountScreen(),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle();
    expect(find.byKey(const ValueKey('account:email')), findsOneWidget);
    expect(find.byKey(const ValueKey('account:code')), findsNothing);

    // Adresse invalide : aucune requête.
    await tester.enterText(
      find.byKey(const ValueKey('account:email')),
      'pas-un-mail',
    );
    await tester.tap(find.byKey(const ValueKey('account:sendCode')));
    await settle();
    expect(find.text('Adresse e-mail invalide'), findsOneWidget);
    expect(http.paths, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('account:email')),
      'a@example.com',
    );
    await tester.tap(find.byKey(const ValueKey('account:sendCode')));
    await settle();
    expect(http.paths, ['POST /auth/request']);
    expect(find.byKey(const ValueKey('account:code')), findsOneWidget);

    // Mauvais code : message, toujours déconnecté.
    http.verifyStatus = 401;
    await tester.enterText(find.byKey(const ValueKey('account:code')), 'faux');
    await tester.tap(find.byKey(const ValueKey('account:signIn')));
    await settle();
    expect(find.text('Code refusé ou expiré'), findsOneWidget);
    expect(await api.isSignedIn(), isFalse);

    http.verifyStatus = 200;
    await tester.enterText(find.byKey(const ValueKey('account:code')), 'BON');
    await tester.tap(find.byKey(const ValueKey('account:signIn')));
    await settle();
    expect(find.text('Connecté : a@example.com'), findsOneWidget);
    expect(find.byKey(const ValueKey('account:signOut')), findsOneWidget);
    expect(await api.isSignedIn(), isTrue);

    await tester.tap(find.byKey(const ValueKey('account:signOut')));
    await settle();
    expect(find.byKey(const ValueKey('account:email')), findsOneWidget);
    expect(await api.isSignedIn(), isFalse);

    await tester.pumpWidget(const SizedBox());
    await container.read(syncServiceProvider)!.dispose();
    await tester.runAsync(db.close);
  });
}
