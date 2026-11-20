import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/backup_files.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/profile_repository.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio/data/library_repository.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/features/settings/backup_section.dart';
import 'package:lumio/features/settings/settings_providers.dart';
import 'package:lumio/features/settings/settings_screen.dart';
import 'package:lumio/features/settings/stremio_import_screen.dart';
import 'package:lumio/l10n/app_localizations.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

import 'support/fake_addon_fetcher.dart';

const _urlA = 'https://a.example.com/tok-secret-a/manifest.json';
const _urlB = 'https://b.example.com/tok-secret-b/manifest.json';
const _lan = 'http://192.168.1.20:7000/lan-secret/manifest.json';

class _FakeFiles implements BackupFiles {
  _FakeFiles({this.picker = true});

  final bool picker;
  BackupFile? next;
  List<BackupFile> local = [];
  bool anyJsonAsked = false;

  @override
  bool get hasPicker => picker;

  @override
  Future<String> get directory async => '/stockage/backups';

  @override
  Future<String?> save(String name, String text) async => null;

  @override
  Future<BackupFile?> pick() async => next;

  @override
  Future<List<BackupFile>> listLocal({bool anyJson = false}) async {
    anyJsonAsked = anyJson;
    return local;
  }
}

BackupFile _file(String name, String text) {
  final bytes = utf8.encode(text);
  return BackupFile(name: name, length: bytes.length, read: () async => bytes);
}

String _addons(List<Map<String, Object?>> list) => jsonEncode({
  'result': {'addons': list},
});

class _H {
  _H(
    this.tester, {
    bool picker = true,
    List<Override> overrides = const [],
    Map<String, Map<String, Object?>> manifests = const {},
  }) : files = _FakeFiles(picker: picker) {
    db = AppDatabase(NativeDatabase.memory());
    repo = AddonRepository(
      db,
      MemorySecretStore(),
      clientFactory: ({required allowPrivate}) => AddonClient(
        FakeAddonFetcher({
          _urlA: sampleManifest(id: 'a', name: 'Alpha'),
          _urlB: sampleManifest(id: 'b', name: 'Bravo'),
          _lan: sampleManifest(id: 'lan', name: 'Maison'),
          ...manifests,
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
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
  }

  final WidgetTester tester;
  final _FakeFiles files;
  late AppDatabase db;
  late AddonRepository repo;
  late ProviderContainer container;

  Future<T> run<T>(Future<T> Function() f) async =>
      (await tester.runAsync(f)) as T;

  Future<void> settle([int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> pump({Widget home = const StremioImportScreen()}) async {
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
          home: home,
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

  Future<void> paste(String key, String text) async {
    await tester.enterText(find.byKey(ValueKey(key)), text);
    await tester.pump();
  }

  Future<List<LibraryItem>> library() =>
      run(() => db.select(db.libraryItems).get());

  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('tuile dans les réglages, texte neutre', (tester) async {
    final h = _H(tester);
    await h.pump(home: const SettingsScreen());
    await tester.tap(find.byKey(const ValueKey('rail:backup')));
    await h.settle();
    final tile = find.byKey(const ValueKey('setting:otherImport'));
    await tester.ensureVisible(tile);
    expect(find.text('Importer depuis un autre client'), findsOneWidget);
    await tester.tap(tile);
    await h.settle();
    expect(find.byKey(const ValueKey('otherImport:help')), findsOneWidget);
    await h.dispose();
  });

  testWidgets('à l\'ouverture, un bouton a le focus', (tester) async {
    final h = _H(tester);
    await h.pump();
    expect(find.byKey(const ValueKey('focus-ring')), findsWidgets);
    await h.dispose();
  });

  testWidgets('addons collés : installés, doublon compté, adresse locale '
      'en attente puis autorisée', (tester) async {
    final h = _H(tester);
    await h.run(() => h.repo.install(_urlA));
    await h.pump();

    await h.paste(
      'otherImport:addons:text',
      _addons([
        {
          'transportUrl': _urlA,
          'manifest': {'id': 'a', 'name': 'Alpha'},
        },
        {
          'transportUrl': _urlB,
          'manifest': {'id': 'b', 'name': 'Bravo'},
        },
        {
          'transportUrl': _lan,
          'manifest': {'id': 'lan', 'name': 'Maison'},
        },
        {
          'manifest': {'id': 'x', 'name': 'Sans adresse'},
        },
        {
          'transportUrl': 'https://v3-cinemeta.strem.io/manifest.json',
          'manifest': {'id': 'cinemeta', 'name': 'Cinemeta'},
          'flags': {'official': true},
        },
      ]),
    );
    await h.tapKey('otherImport:run');

    expect(find.text('Import terminé'), findsOneWidget);
    expect(find.text('1 addon(s) installé(s)'), findsOneWidget);
    expect(find.text('1 addon(s) déjà présent(s)'), findsOneWidget);
    expect(find.text('1 addon(s) en attente (adresse locale)'), findsOneWidget);
    expect(find.textContaining('2 élément(s) ignoré(s)'), findsOneWidget);
    // Seul l'hôte est montré, jamais le jeton.
    expect(find.textContaining('lan-secret'), findsNothing);
    expect((await h.run(() => h.repo.list())).map((a) => a.manifest?.id), [
      'a',
      'b',
    ]);

    await h.tapKey('otherImport:allow:192.168.1.20');
    expect(find.text('2 addon(s) installé(s)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('otherImport:allow:192.168.1.20')),
      findsNothing,
    );
    expect((await h.run(() => h.repo.list())), hasLength(3));
    await h.dispose();
  });

  testWidgets('adresse locale ignorée : rien n\'est installé', (tester) async {
    final h = _H(tester);
    await h.pump();
    await h.paste(
      'otherImport:addons:text',
      _addons([
        {
          'transportUrl': _lan,
          'manifest': {'id': 'lan', 'name': 'Maison'},
        },
      ]),
    );
    await h.tapKey('otherImport:run');
    await h.tapKey('otherImport:ignore:192.168.1.20');
    expect(find.text('0 addon(s) installé(s)'), findsNothing);
    expect(await h.run(() => h.repo.list()), isEmpty);
    await h.dispose();
  });

  testWidgets('bibliothèque : removed écarté, ajoutée au profil, 2e import = '
      'déjà présents', (tester) async {
    final h = _H(tester);
    await h.pump();
    final json = jsonEncode({
      'result': [
        {'_id': 'tt1', 'name': 'Élan', 'type': 'movie', 'removed': false},
        {'_id': 'tt2', 'name': 'Parti', 'type': 'movie', 'removed': true},
        {
          '_id': 'tt3',
          'name': 'Série',
          'type': 'series',
          'poster': 'https://img.example.com/p.jpg',
        },
      ],
    });
    await h.paste('otherImport:library:text', json);
    await h.tapKey('otherImport:run');
    expect(find.text('2 titre(s) ajouté(s) à la liste'), findsOneWidget);
    expect(
      find.textContaining('1 élément(s) ignoré(s) : Parti'),
      findsOneWidget,
    );
    final items = await h.library();
    expect(items.map((i) => i.itemId).toSet(), {'tt1', 'tt3'});

    await tester.pumpWidget(const SizedBox());
    await h.pump();
    await h.paste('otherImport:library:text', json);
    await h.tapKey('otherImport:run');
    expect(find.text('2 titre(s) déjà dans la liste'), findsOneWidget);
    expect((await h.library()), hasLength(2));
    await h.dispose();
  });

  testWidgets('fichier choisi sur TV : liste tous les .json', (tester) async {
    final h = _H(tester, picker: false);
    h.files.local = [
      _file(
        'library.json',
        jsonEncode([
          {'_id': 'tt1', 'name': 'Élan', 'type': 'movie'},
        ]),
      ),
    ];
    await h.pump();
    await h.tapKey('otherImport:library:pick');
    expect(h.files.anyJsonAsked, isTrue);
    await h.tapKey('otherImport:file:library.json');
    expect(find.text('Fichier : library.json'), findsOneWidget);
    await h.tapKey('otherImport:run');
    expect(find.text('1 titre(s) ajouté(s) à la liste'), findsOneWidget);
    await h.dispose();
  });

  testWidgets('aucun fichier sur TV : message avec le dossier', (tester) async {
    final h = _H(tester, picker: false);
    await h.pump();
    await h.tapKey('otherImport:addons:pick');
    expect(find.textContaining('/stockage/backups'), findsOneWidget);
    await h.dispose();
  });

  testWidgets('contenu illisible : erreur claire, rien d\'écrit', (
    tester,
  ) async {
    final h = _H(tester);
    await h.pump();
    await h.paste('otherImport:addons:text', '{pas du json');
    await h.tapKey('otherImport:run');
    expect(find.textContaining("n'est pas un export reconnu"), findsOneWidget);
    expect(find.byKey(const ValueKey('otherImport:run')), findsOneWidget);

    await h.paste('otherImport:addons:text', '"texte"');
    await h.tapKey('otherImport:run');
    expect(find.textContaining("n'est pas un export reconnu"), findsOneWidget);
    expect(await h.run(() => h.repo.list()), isEmpty);
    await h.dispose();
  });

  testWidgets('rien de saisi : demande de choisir un fichier', (tester) async {
    final h = _H(tester);
    await h.pump();
    await h.tapKey('otherImport:run');
    expect(
      find.text('Choisissez ou collez au moins un fichier.'),
      findsOneWidget,
    );
    await h.dispose();
  });

  testWidgets('fichier de plus de 10 Mo refusé avant lecture', (tester) async {
    final h = _H(tester);
    var read = false;
    h.files.next = BackupFile(
      name: 'gros.json',
      length: Backup.maxBytes + 1,
      read: () async {
        read = true;
        return const [];
      },
    );
    await h.pump();
    await h.tapKey('otherImport:addons:pick');
    expect(find.textContaining('trop volumineux'), findsOneWidget);
    expect(read, isFalse);
    await h.dispose();
  });

  testWidgets('export sans aucun addon utilisable : rien à importer', (
    tester,
  ) async {
    final h = _H(tester);
    await h.pump();
    await h.paste('otherImport:addons:text', _addons([]));
    await h.tapKey('otherImport:run');
    expect(find.text('Rien à importer dans ces fichiers.'), findsOneWidget);
    await h.dispose();
  });

  testWidgets('échec en base pendant la liste : le bilan complet reste', (
    tester,
  ) async {
    final h = _H(
      tester,
      overrides: [
        libraryRepositoryProvider.overrideWith(
          (ref) => _FlakyLibrary(ref.watch(appDatabaseProvider), {'tt2'}),
        ),
      ],
    );
    await h.pump();
    await h.paste(
      'otherImport:addons:text',
      _addons([
        {
          'transportUrl': _urlB,
          'manifest': {'id': 'b', 'name': 'Bravo'},
        },
      ]),
    );
    await h.paste(
      'otherImport:library:text',
      jsonEncode([
        {'_id': 'tt1', 'name': 'Un', 'type': 'movie'},
        {'_id': 'tt2', 'name': 'Deux', 'type': 'movie'},
        {'_id': 'tt3', 'name': 'Trois', 'type': 'movie'},
      ]),
    );
    await h.tapKey('otherImport:run');
    expect(find.text('Import terminé'), findsOneWidget);
    expect(find.text('1 addon(s) installé(s)'), findsOneWidget);
    expect(find.text('2 titre(s) ajouté(s) à la liste'), findsOneWidget);
    expect(
      find.text("1 titre(s) n'ont pas pu être ajoutés à la liste"),
      findsOneWidget,
    );
    await h.dispose();
  });

  testWidgets('échecs d\'addons ventilés par cause', (tester) async {
    const bad = 'https://bad.example.com/manifest.json';
    const down = 'https://down.example.com/manifest.json';
    final h = _H(
      tester,
      manifests: {
        bad: {'id': 'bad'},
      },
    );
    await h.pump();
    await h.paste(
      'otherImport:addons:text',
      _addons([
        {'transportUrl': bad},
        {'transportUrl': down},
      ]),
    );
    await h.tapKey('otherImport:run');
    expect(
      find.text('1 addon(s) refusé(s) : manifeste invalide'),
      findsOneWidget,
    );
    expect(find.text('1 addon(s) injoignable(s)'), findsOneWidget);
    await h.dispose();
  });

  test('titres importés : masqués pour un profil enfant, visibles sinon', () {
    final items = parseStremioLibrary([
      {'_id': 'tt1', 'name': 'Un', 'type': 'movie'},
    ]).library;
    const kid = Profile(
      id: 'kid',
      name: 'Enfant',
      ageLimit: 1,
      isKid: true,
      locked: false,
      createdAt: 0,
    );
    const adult = Profile(
      id: 'adult',
      name: 'Moi',
      ageLimit: 4,
      isKid: false,
      locked: false,
      createdAt: 0,
    );
    expect(visibleItems(items, kid), isEmpty);
    expect(visibleItems(items, adult), hasLength(1));
  });

  testWidgets('fichier dont la taille annoncée ment : refusé après lecture', (
    tester,
  ) async {
    final h = _H(tester);
    h.files.next = BackupFile(
      name: 'menteur.json',
      length: 10,
      read: () async => List.filled(Backup.maxBytes + 1, 32),
    );
    await h.pump();
    await h.tapKey('otherImport:addons:pick');
    expect(find.textContaining('trop volumineux'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('otherImport:addons:fileName')),
      findsNothing,
    );
    await h.dispose();
  });
}

class _FlakyLibrary extends LibraryRepository {
  _FlakyLibrary(super.db, this.failing);

  final Set<String> failing;

  @override
  Future<void> add(String profileId, MetaPreview item) async {
    if (failing.contains(item.id)) throw StateError('disque plein');
    return super.add(profileId, item);
  }
}
