import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/app_settings.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/local_library.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio/features/local/local_providers.dart';
import 'package:lumio/features/onboarding/onboarding_flow.dart';
import 'package:lumio/features/settings/settings_providers.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

import 'support/fake_addon_fetcher.dart';
import 'support/fake_catalog.dart';

class _FixedPicker implements FolderPicker {
  _FixedPicker(this.path);
  final String path;

  @override
  Future<String?> pick() async => path;
}

class _AllowStorage implements StoragePermission {
  @override
  Future<bool> ensure() async => true;
}

const _url = 'https://a.example.com/tok-a/manifest.json';

class _H {
  _H(this.tester);
  final WidgetTester tester;
  late AppDatabase db;
  late ProviderContainer container;

  Future<T> run<T>(Future<T> Function() f) async =>
      (await tester.runAsync(f)) as T;

  Future<void> start({
    Map<String, String> settings = const {},
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    db = AppDatabase(NativeDatabase.memory());
    final store = AppSettingsStore(db);
    for (final e in settings.entries) {
      await run(() => store.write(e.key, e.value));
    }
    final fetcher = FakeAddonFetcher({
      _url: sampleManifest(id: 'a', name: 'Alpha'),
    });
    final repo = AddonRepository(
      db,
      MemorySecretStore(),
      clientFactory: ({required allowPrivate}) =>
          AddonClient(fetcher, allowPrivate: allowPrivate, retries: 0),
    );
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        addonRepositoryProvider.overrideWithValue(repo),
        catalogOverride(FakeCatalogSite(offline: true)),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: LumioTheme.dark(),
            locale: ref.watch(localeProvider),
            supportedLocales: supportedUiLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: OnboardingGate(
              child: Scaffold(
                body: Column(
                  children: [
                    SourcesReminderCard(onAdd: () {}),
                    const Text('ACCUEIL'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settle();
  }

  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 700));
    }
  }

  Future<void> tapKey(String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await settle();
  }

  Future<String?> setting(String key) =>
      run(() => AppSettingsStore(db).read(key));

  Future<void> close() async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  }

  List<String> allTexts() => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .toList();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('premier lancement : assistant, langue appliquée aussitôt', (
    tester,
  ) async {
    final h = _H(tester);
    await h.start();
    expect(find.text('Choisissez votre langue'), findsOneWidget);
    expect(find.text('ACCUEIL'), findsNothing);
    await h.tapKey('lang-en');
    expect(find.text('Choose your language'), findsOneWidget);
    await h.close();
  });

  testWidgets('Retour revient à l\'étape précédente, profil renommé', (
    tester,
  ) async {
    final h = _H(tester);
    await h.start();
    await h.tapKey('onboarding-next');
    expect(find.text('Votre profil'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('onboarding-name')),
      'Lilou',
    );
    await h.tapKey('onboarding-next');
    expect(find.text('Ajoutez vos sources'), findsOneWidget);
    await h.tapKey('onboarding-back');
    expect(find.text('Votre profil'), findsOneWidget);
    await h.tapKey('onboarding-back');
    expect(find.text('Choisissez votre langue'), findsOneWidget);
    final names = await h.run(
      () => h.container.read(profileRepositoryProvider).list(),
    );
    expect(names.single.name, 'Lilou');
    await h.close();
  });

  testWidgets('chaque étape donne le focus à son action principale', (
    tester,
  ) async {
    final h = _H(tester);
    await h.start();
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('lang-fr')),
        matching: find.byElementPredicate((e) => e == focused),
      ),
      findsOneWidget,
    );
    await h.tapKey('onboarding-next');
    final next = tester.widget<FilledButton>(
      find.byKey(const ValueKey('onboarding-next')),
    );
    expect(next.autofocus, isTrue);
    await h.tapKey('onboarding-next');
    final add = tester.widget<FilledButton>(
      find.byKey(const ValueKey('onboarding-add-addon')),
    );
    expect(add.autofocus, isTrue);
    await h.close();
  });

  testWidgets('Passer : accueil avec rappel discret, masquable et mémorisé', (
    tester,
  ) async {
    final h = _H(tester);
    await h.start();
    await h.tapKey('onboarding-skip');
    expect(find.text('ACCUEIL'), findsOneWidget);
    expect(find.byKey(const ValueKey('sources-reminder')), findsOneWidget);
    expect(await h.setting(AppSettingsStore.onboardingDoneKey), '1');
    await h.tapKey('sources-reminder-dismiss');
    expect(find.byKey(const ValueKey('sources-reminder')), findsNothing);
    expect(await h.setting(AppSettingsStore.sourcesReminderDismissedKey), '1');
    await h.close();
  });

  testWidgets('second lancement : pas d\'assistant ; rappel masqué mémorisé', (
    tester,
  ) async {
    final h = _H(tester);
    await h.start(
      settings: {
        AppSettingsStore.onboardingDoneKey: '1',
        AppSettingsStore.onboardingSkippedKey: '1',
        AppSettingsStore.sourcesReminderDismissedKey: '1',
      },
    );
    expect(find.text('ACCUEIL'), findsOneWidget);
    expect(find.text('Choisissez votre langue'), findsNothing);
    expect(find.byKey(const ValueKey('sources-reminder')), findsNothing);
    await h.close();
  });

  testWidgets('installer un addon : « 1 addon installé », puis accueil', (
    tester,
  ) async {
    final h = _H(tester);
    await h.start();
    await h.tapKey('onboarding-next');
    await h.tapKey('onboarding-next');
    await h.tapKey('onboarding-add-addon');
    await tester.tap(find.byKey(const ValueKey('addtab:link')));
    await h.settle();
    await tester.enterText(find.byType(TextField), _url);
    await h.settle();
    await tester.tap(find.byKey(const ValueKey('link-install')));
    await h.settle();
    expect(find.text('1 addon installé'), findsOneWidget);
    await h.tapKey('onboarding-finish');
    expect(find.text('ACCUEIL'), findsOneWidget);
    expect(find.byKey(const ValueKey('sources-reminder')), findsNothing);
    expect(await h.setting(AppSettingsStore.onboardingSkippedKey), isNull);
    await h.close();
  });

  testWidgets(
    '« Ajouter un dossier » : visible à l\'étape 3, dossier analysé',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('lumio_ob_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final h = _H(tester);
      late LocalLibrary lib;
      await h.start(
        overrides: [
          localLibraryProvider.overrideWith((ref) {
            lib = LocalLibrary(
              ref.watch(appDatabaseProvider),
              scanner: (_) async => const ScanResult([]),
            );
            return lib;
          }),
          folderPickerProvider.overrideWithValue(_FixedPicker(dir.path)),
          storagePermissionProvider.overrideWithValue(_AllowStorage()),
        ],
      );
      await h.tapKey('onboarding-next');
      await h.tapKey('onboarding-next');
      expect(find.text('Ajouter un dossier'), findsOneWidget);
      await h.tapKey('onboarding-add-folder');
      expect(find.textContaining('Dossier ajouté'), findsOneWidget);
      expect(await h.run(lib.grantedFolders), [normalizeFolder(dir.path)]);
      await h.close();
    },
  );

  testWidgets('aucun texte de l\'assistant ne contient d\'URL d\'addon', (
    tester,
  ) async {
    final h = _H(tester);
    await h.start();
    final seen = <String>[...h.allTexts()];
    await h.tapKey('onboarding-next');
    seen.addAll(h.allTexts());
    await h.tapKey('onboarding-next');
    seen.addAll(h.allTexts());
    expect(seen, isNotEmpty);
    for (final t in seen) {
      expect(t, isNot(contains('http')));
      expect(t, isNot(contains('://')));
      expect(t, isNot(contains('manifest')));
      expect(t, isNot(contains('.com')));
    }
    // Pas de bouton « Saisir depuis mon téléphone » sans backendUrl.
    expect(find.byKey(const ValueKey('onboarding-pair')), findsNothing);
    await h.close();
  });
}
