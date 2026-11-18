import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/addon_sync.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio/data/sync_providers.dart';
import 'package:lumio/data/sync_service.dart';
import 'package:lumio/data/sync_store.dart';
import 'package:lumio/features/settings/account_screen.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

/// Serveur qui ne renvoie rien ; garde le dernier envoi.
class _Http implements SyncHttp {
  final posts = <Map<String, Object?>>[];
  Map<String, Object?>? remoteAddons;

  @override
  Future<SyncHttpResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    String? body,
  }) async {
    if (method == 'POST') {
      for (final i in (jsonDecode(body!) as Map)['items'] as List) {
        posts.add(Map<String, Object?>.from(i as Map));
      }
      return const SyncHttpResponse(200, '{"version":1}');
    }
    return SyncHttpResponse(
      200,
      jsonEncode({
        'items': [?remoteAddons],
        'version': remoteAddons == null ? 0 : 1,
        'more': false,
      }),
    );
  }
}

Future<String> _seal(String plain, String pass) async =>
    'v1.${base64Url.encode(utf8.encode(pass))}.${base64Url.encode(utf8.encode(plain))}';

Future<String> _open(String sealed, String pass) async {
  final p = sealed.split('.');
  if (utf8.decode(base64Url.decode(p[1])) != pass) {
    throw const WrongPassphraseException();
  }
  return utf8.decode(base64Url.decode(p[2]));
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<
    ({
      ProviderContainer container,
      AddonSync sync,
      SyncService service,
      _Http http,
      Future<void> Function() settle,
      MemorySecretStore secrets,
      Future<void> Function() close,
    })
  >
  pump(WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final secrets = MemorySecretStore();
    await secrets.write(SyncSecretKeys.session, 'S');
    await secrets.write(SyncSecretKeys.refresh, 'R');
    await secrets.write(SyncSecretKeys.email, 'a@example.com');
    final http = _Http();
    final repo = AddonRepository(db, secrets);
    final sync = AddonSync(
      db,
      secrets,
      repo,
      seal: _seal,
      open: _open,
      fingerprint: (p, s) async => p,
    );
    final service = SyncService(
      api: SyncApiClient('https://sync.example.com', secrets, http: http),
      store: DriftLocalSyncStore(db, addons: sync),
      addons: sync,
    );
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(secrets),
        addonSyncProvider.overrideWithValue(sync),
        syncServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await tester.runAsync(db.close);
    });
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
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.runAsync(service.start);
    await settle();
    return (
      container: container,
      sync: sync,
      service: service,
      http: http,
      settle: settle,
      secrets: secrets,
      close: () async {
        await tester.pumpWidget(const SizedBox());
        await service.dispose();
      },
    );
  }

  testWidgets('sans phrase : état affiché, saisie validée puis enregistrée', (
    tester,
  ) async {
    final h = await pump(tester);
    expect(
      find.text('Pas de phrase secrète : vos addons ne sont pas synchronisés.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('account:passphrase')));
    await h.settle();
    expect(find.text('Phrase secrète de synchronisation'), findsWidgets);

    // Trop courte.
    await tester.enterText(
      find.byKey(const ValueKey('passphrase:phrase')),
      'courte',
    );
    await tester.enterText(
      find.byKey(const ValueKey('passphrase:confirm')),
      'courte',
    );
    await tester.tap(find.byKey(const ValueKey('passphrase:save')));
    await h.settle();
    expect(find.text('12 caractères au moins'), findsOneWidget);

    // Confirmation différente.
    await tester.enterText(
      find.byKey(const ValueKey('passphrase:phrase')),
      'une phrase assez longue',
    );
    await tester.enterText(
      find.byKey(const ValueKey('passphrase:confirm')),
      'une phrase assez longuE',
    );
    await tester.tap(find.byKey(const ValueKey('passphrase:save')));
    await h.settle();
    expect(find.text('Les deux phrases sont différentes'), findsOneWidget);
    expect(await h.sync.passphrase(), isNull);

    // Valide : enregistrée sur l'appareil, retour au compte, synchronisé.
    await tester.enterText(
      find.byKey(const ValueKey('passphrase:confirm')),
      'une phrase assez longue',
    );
    await tester.tap(find.byKey(const ValueKey('passphrase:save')));
    await h.settle();
    expect(await h.sync.passphrase(), 'une phrase assez longue');
    expect(find.byKey(const ValueKey('passphrase:phrase')), findsNothing);
    expect(
      find.text(
        'Vos addons sont synchronisés, chiffrés avec votre phrase secrète.',
      ),
      findsOneWidget,
    );
    // Le serveur n'a reçu aucune phrase.
    expect(jsonEncode(h.http.posts), isNot(contains('assez longue')));
    await h.close();
  });

  testWidgets('mauvaise phrase : message exact, réinitialisation confirmée', (
    tester,
  ) async {
    final h = await pump(tester);
    h.http.remoteAddons = {
      'kind': 'addons',
      'key': 'all',
      'payload': {'blob': await _seal('[]', 'la vraie phrase secrete')},
      'version': 1,
      'deleted': 0,
    };
    await tester.runAsync(() => h.sync.setPassphrase('une mauvaise phrase 1'));
    await tester.runAsync(h.service.syncNow);
    h.container.invalidate(addonSyncStateProvider);
    await h.settle();
    expect(
      find.text(
        'Phrase secrète incorrecte : vos addons ne sont pas synchronisés',
      ),
      findsOneWidget,
    );

    // Annuler la réinitialisation ne change rien.
    await tester.tap(find.byKey(const ValueKey('account:resetAddons')));
    await h.settle();
    await tester.tap(find.text('Annuler'));
    await h.settle();
    expect(h.http.posts.where((p) => p['kind'] == 'addons'), isEmpty);

    await tester.tap(find.byKey(const ValueKey('account:resetAddons')));
    await h.settle();
    await tester.tap(find.byKey(const ValueKey('account:resetConfirm')));
    await h.settle();
    final tomb = h.http.posts.where((p) => p['kind'] == 'addons').toList();
    expect(tomb, hasLength(1));
    expect(tomb.single['deleted'], true);
    expect(tomb.single['payload'], isNull);
    expect(await h.sync.passphrase(), isNull);
    await h.close();
  });
}
