import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/backup_files.dart';
import 'package:lumio/data/backup_service.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/profile_repository.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio/features/settings/backup_section.dart';
import 'package:lumio/features/settings/settings_providers.dart';
import 'package:lumio/features/settings/settings_screen.dart';
import 'package:lumio/l10n/app_localizations.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

import 'support/fake_addon_fetcher.dart';

const _urlA = 'https://a.example.com/tok-secret-a/manifest.json';
const _lan = 'http://192.168.1.20:7000/lan-secret/manifest.json';
const _pass = 'une phrase assez longue';

class _FakeFiles implements BackupFiles {
  _FakeFiles({this.picker = true});

  final bool picker;
  final saved = <String, String>{};
  BackupFile? next;
  List<BackupFile> local = [];

  @override
  bool get hasPicker => picker;

  @override
  Future<String> get directory async => '/stockage/backups';

  @override
  Future<String?> save(String name, String text) async {
    saved[name] = text;
    return '/stockage/backups/$name';
  }

  @override
  Future<BackupFile?> pick() async => next;

  @override
  Future<List<BackupFile>> listLocal() async => local;
}

BackupFile _file(String name, String text) {
  final bytes = utf8.encode(text);
  return BackupFile(name: name, length: bytes.length, read: () async => bytes);
}

class _H {
  _H(this.tester, {bool picker = true}) : files = _FakeFiles(picker: picker) {
    db = AppDatabase(NativeDatabase.memory());
    secrets = MemorySecretStore();
    repo = AddonRepository(
      db,
      secrets,
      clientFactory: ({required allowPrivate}) => AddonClient(
        FakeAddonFetcher({
          _urlA: sampleManifest(id: 'a', name: 'Alpha'),
          _lan: sampleManifest(id: 'lan', name: 'Maison'),
        }),
        allowPrivate: allowPrivate,
        retries: 0,
      ),
    );
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        addonRepositoryProvider.overrideWithValue(repo),
        appVersionProvider.overrideWith((ref) async => '1.0.0'),
        backupFilesProvider.overrideWithValue(files),
      ],
    );
    addTearDown(container.dispose);
  }

  final WidgetTester tester;
  final _FakeFiles files;
  late AppDatabase db;
  late MemorySecretStore secrets;
  late AddonRepository repo;
  late ProviderContainer container;

  Future<T> run<T>(Future<T> Function() f) async =>
      (await tester.runAsync(f)) as T;

  Future<void> settle([int rounds = 4]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  /// Attend (vraie horloge) la fin d'un chiffrement.
  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 400 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await settle();
  }

  Future<void> pump() async {
    tester.view.physicalSize = const Size(1920, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await run(() => ProfileRepository(db).ensureDefault());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LumioTheme.dark(),
          locale: const Locale('fr'),
          supportedLocales: const [Locale('fr'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SettingsScreen(),
        ),
      ),
    );
    await settle();
  }

  Future<void> tapKey(String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.tap(f);
    await settle();
  }

  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('export sans secrets : fichier en clair, sans adresse', (
    tester,
  ) async {
    final h = _H(tester);
    await h.run(() => h.repo.install(_urlA));
    await h.pump();
    expect(find.text('Sauvegarde'), findsOneWidget);

    await h.tapKey('setting:backupExport');
    expect(
      find.textContaining("Ce fichier contiendra vos adresses d'addons"),
      findsOneWidget,
    );
    await h.tapKey('backup:withoutSecrets');

    expect(h.files.saved, hasLength(1));
    final name = h.files.saved.keys.single;
    expect(name, endsWith('.lumio.json'));
    final text = h.files.saved.values.single;
    expect(text, isNot(contains('tok-secret-a')));
    expect(Backup.isEncrypted(text), isFalse);
    expect(jsonDecode(text)['format'], 'lumio-backup');
    expect(find.textContaining('Sauvegarde enregistrée'), findsOneWidget);
    await h.dispose();
  });

  testWidgets('export avec adresses : phrase exigée, fichier chiffré', (
    tester,
  ) async {
    final h = _H(tester);
    await h.run(() => h.repo.install(_urlA));
    await h.pump();

    await h.tapKey('setting:backupExport');
    await h.tapKey('backup:withSecrets');
    await tester.enterText(
      find.byKey(const ValueKey('backup:phrase')),
      'court',
    );
    await tester.enterText(
      find.byKey(const ValueKey('backup:phraseConfirm')),
      'court',
    );
    await h.tapKey('backup:phraseOk');
    expect(find.text('12 caractères au moins'), findsOneWidget);
    expect(h.files.saved, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('backup:phrase')), _pass);
    await tester.enterText(
      find.byKey(const ValueKey('backup:phraseConfirm')),
      '$_pass!',
    );
    await h.tapKey('backup:phraseOk');
    expect(find.text('Les deux phrases sont différentes'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('backup:phraseConfirm')),
      _pass,
    );
    await h.tapKey('backup:phraseOk');
    await h.until(() => h.files.saved.isNotEmpty);

    final text = h.files.saved.values.single;
    expect(Backup.isEncrypted(text), isTrue);
    expect(text, isNot(contains('tok-secret-a')));
    expect(text, isNot(contains('a.example.com')));
    await h.dispose();
  });

  testWidgets('import : fichier d\'une version future ou invalide refusé', (
    tester,
  ) async {
    final h = _H(tester);
    await h.pump();

    h.files.next = _file(
      'f.lumio.json',
      jsonEncode({'format': 'lumio-backup', 'version': 2}),
    );
    await h.tapKey('setting:backupImport');
    expect(find.textContaining('version plus récente'), findsOneWidget);
    expect(find.byKey(const ValueKey('backup:confirmImport')), findsNothing);

    h.files.next = _file('g.lumio.json', 'pas du json');
    await h.tapKey('setting:backupImport');
    expect(find.textContaining('illisible ou abîmée'), findsOneWidget);

    h.files.next = _file('h.lumio.json', jsonEncode({'autre': 1}));
    await h.tapKey('setting:backupImport');
    expect(
      find.textContaining("n'est pas une sauvegarde Lumio"),
      findsOneWidget,
    );

    h.files.next = BackupFile(
      name: 'gros.lumio.json',
      length: Backup.maxBytes + 1,
      read: () async => throw StateError('lu malgré la taille'),
    );
    await h.tapKey('setting:backupImport');
    expect(find.textContaining('trop volumineuse'), findsOneWidget);
    await h.dispose();
  });

  testWidgets(
    'import chiffré : mauvaise phrase, bonne phrase, adresse locale à confirmer',
    (tester) async {
      // Appareil source : produit le fichier chiffré.
      final src = AppDatabase(NativeDatabase.memory());
      final srcSecrets = MemorySecretStore();
      final fetcher = FakeAddonFetcher({
        _urlA: sampleManifest(id: 'a', name: 'Alpha'),
        _lan: sampleManifest(id: 'lan', name: 'Maison'),
      });
      final srcRepo = AddonRepository(
        src,
        srcSecrets,
        clientFactory: ({required allowPrivate}) =>
            AddonClient(fetcher, allowPrivate: allowPrivate, retries: 0),
      );
      await tester.runAsync(() async {
        await ProfileRepository(src).ensureDefault();
        await ProfileRepository(
          src,
          hashPin: (p) async => p,
          verifyPin: (p, s) async => true,
        ).create('Léa', isKid: true, limit: AgeLimit.age7);
        await srcRepo.install(_urlA);
        await srcRepo.install(_lan, allowPrivate: true);
      });
      final text = (await tester.runAsync(
        () => BackupService(
          src,
          srcRepo,
        ).export(includeSecrets: true, passphrase: _pass),
      ))!;
      await tester.runAsync(src.close);

      final h = _H(tester);
      await h.pump();
      h.files.next = _file('x.lumio.json', text);
      await h.tapKey('setting:backupImport');
      expect(find.byKey(const ValueKey('backup:importPhrase')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('backup:importPhrase')),
        'mauvaise phrase!!',
      );
      await h.tapKey('backup:importPhraseOk');
      await h.until(
        () => find
            .text('Phrase secrète incorrecte, ou fichier abîmé.')
            .evaluate()
            .isNotEmpty,
      );
      expect(
        find.text('Phrase secrète incorrecte, ou fichier abîmé.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('backup:importPhrase')),
        _pass,
      );
      await h.tapKey('backup:importPhraseOk');
      await h.until(
        () => find
            .byKey(const ValueKey('backup:confirmImport'))
            .evaluate()
            .isNotEmpty,
      );
      expect(
        find.byKey(const ValueKey('backup:confirmImport')),
        findsOneWidget,
      );
      await h.tapKey('backup:confirmOk');
      await h.until(
        () => find.byKey(const ValueKey('backup:report')).evaluate().isNotEmpty,
      );

      expect(find.textContaining('1 profil(s) ajouté(s)'), findsOneWidget);
      expect(find.textContaining('1 addon(s) installé(s)'), findsOneWidget);
      expect(
        find.textContaining('créez d\'abord un PIN parent'),
        findsOneWidget,
      );
      expect((await h.run(() => h.repo.list())).map((a) => a.id), ['a']);

      await h.tapKey('backup:reportOk');
      // Adresse locale : confirmation explicite, jamais automatique.
      expect(
        find.byKey(const ValueKey('backup:private:Maison')),
        findsOneWidget,
      );
      await h.tapKey('backup:privateAllow');
      await h.settle(8);
      expect(
        (await h.run(() => h.repo.list())).map((a) => a.id),
        containsAll(['a', 'lan']),
      );
      await h.dispose();
    },
  );

  testWidgets('TV sans sélecteur : liste des sauvegardes du dossier', (
    tester,
  ) async {
    final h = _H(tester, picker: false);
    await h.pump();
    await h.tapKey('setting:backupImport');
    expect(find.textContaining('/stockage/backups'), findsOneWidget);
    expect(find.textContaining('.lumio.json'), findsOneWidget);

    h.files.local = [
      _file(
        'a.lumio.json',
        jsonEncode({'format': 'lumio-backup', 'version': 3}),
      ),
    ];
    await h.tapKey('setting:backupImport');
    await h.tapKey('backup:file:a.lumio.json');
    expect(find.textContaining('version plus récente'), findsOneWidget);
    await h.dispose();
  });
}
