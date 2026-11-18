import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/profile_repository.dart';
import 'package:lumio/data/sync_store.dart';
import 'package:lumio/features/profiles/profile_picker_screen.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

/// Profil enfant arrivé par la synchronisation sur un appareil sans PIN
/// parent : il n'est pas sélectionnable avant la création d'un PIN.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<void> type(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  const kidFromSync = SyncItem(
    kind: 'profiles',
    key: 'pkid',
    payload: {'name': 'Léa', 'isKid': true, 'ageLimit': 1},
    version: 3,
  );

  test('règle : enfant sans PIN = pas sélectionnable', () {
    final kid = Profile(
      id: 'k',
      name: 'Léa',
      createdAt: 0,
      ageLimit: 1,
      isKid: true,
      locked: false,
    );
    final adult = Profile(
      id: 'a',
      name: 'Moi',
      createdAt: 0,
      ageLimit: 4,
      isKid: false,
      locked: false,
    );
    expect(kidProfileNeedsPin(kid, hasPin: false), isTrue);
    expect(kidProfileNeedsPin(kid, hasPin: true), isFalse);
    expect(kidProfileNeedsPin(adult, hasPin: false), isFalse);
  });

  testWidgets('profil enfant reçu sans PIN : PIN exigé avant la sélection', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = ProfileRepository(
      db,
      hashPin: (p) async => 'h:$p',
      verifyPin: (p, s) async => s == 'h:$p',
    );
    await tester.runAsync(() async {
      await repo.ensureDefault();
      await DriftLocalSyncStore(db).apply([kidFromSync]);
    });
    expect(await tester.runAsync(repo.hasParentPin), isFalse);

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        profileRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LumioTheme.dark(),
          home: const ProfileGate(child: Scaffold(body: Text('ACCUEIL'))),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Qui regarde ?'), findsOneWidget);

    // Appui sur le profil enfant : invitation à créer un PIN, pas d'accueil.
    await tester.tap(find.text('Léa'));
    await settle(tester);
    expect(find.text('Choisissez un PIN'), findsOneWidget);
    expect(container.read(currentProfileProvider), isNull);

    // Abandon : le profil reste non sélectionné.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.text('ACCUEIL'), findsNothing);
    expect(container.read(currentProfileProvider), isNull);
    expect(await tester.runAsync(repo.hasParentPin), isFalse);

    // PIN créé : le profil devient sélectionnable.
    await tester.tap(find.text('Léa'));
    await settle(tester);
    await type(tester, '1234');
    await settle(tester);
    await type(tester, '1234');
    await settle(tester);
    expect(find.text('Code de récupération'), findsOneWidget);
    await tester.tap(find.text('J\'ai noté le code'));
    await settle(tester);
    expect(await tester.runAsync(repo.hasParentPin), isTrue);
    expect(find.text('ACCUEIL'), findsOneWidget);
    expect(container.read(currentProfileProvider)?.id, 'pkid');

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });

  testWidgets('profil enfant unique reçu : jamais choisi d\'office', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = ProfileRepository(db);
    await tester.runAsync(() async {
      await DriftLocalSyncStore(db).apply([kidFromSync]);
    });
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        profileRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LumioTheme.dark(),
          home: const ProfileGate(child: Scaffold(body: Text('ACCUEIL'))),
        ),
      ),
    );
    await settle(tester);
    // « Moi » n'a pas été créé (la liste n'est pas vide) : le sélecteur est là.
    expect(find.text('Qui regarde ?'), findsOneWidget);
    expect(find.text('ACCUEIL'), findsNothing);
    expect(container.read(currentProfileProvider), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
}
