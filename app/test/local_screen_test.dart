import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/local_library.dart';
import 'package:lumio/data/progress_repository.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/features/detail/detail_screen.dart';
import 'package:lumio/features/detail/playback_service.dart';
import 'package:lumio/features/local/local_providers.dart';
import 'package:lumio/features/local/local_screen.dart';
import 'package:lumio/player/player_screen.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:path/path.dart' as p;

class _Picker implements FolderPicker {
  _Picker(this.result, {this.fail = false});
  final String? result;
  final bool fail;
  int calls = 0;

  @override
  Future<String?> pick() async {
    calls++;
    if (fail) throw StateError('pas de sélecteur');
    return result;
  }
}

class _Perm implements StoragePermission {
  _Perm(this.granted);
  final bool granted;

  @override
  Future<bool> ensure() async => granted;
}

class _H {
  _H(this.tester);
  final WidgetTester tester;
  late AppDatabase db;
  late ProviderContainer container;
  late Directory dir;
  final screens = <PlayerScreen>[];

  late LocalLibrary library;

  /// Un fichier réel (la lecture vérifie son existence).
  late File movie;

  Future<void> start({
    Widget home = const LocalFoldersScreen(),
    FolderPicker? picker,
    bool permission = true,
    Profile? profile,
  }) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    dir = Directory.systemTemp.createTempSync('lumio_ls_');
    addTearDown(() => dir.deleteSync(recursive: true));
    movie = File(p.join(dir.path, 'xyz_123.mp4'))..writeAsStringSync('x');
    db = AppDatabase(NativeDatabase.memory());
    library = LocalLibrary(
      db,
      scanner: (d) async => [
        ScannedFile(
          path: p.join(d, 'xyz_123.mp4'),
          fileName: 'xyz_123.mp4',
          title: 'xyz 123',
          sizeBytes: 1,
          modifiedAt: 0,
        ),
      ],
    );
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        localLibraryProvider.overrideWithValue(library),
        folderPickerProvider.overrideWithValue(picker ?? _Picker(dir.path)),
        storagePermissionProvider.overrideWithValue(_Perm(permission)),
        playerBuilderProvider.overrideWithValue((s) {
          screens.add(s);
          return const Scaffold(body: Text('LECTEUR'));
        }),
      ],
    );
    addTearDown(container.dispose);
    if (profile != null) {
      container.read(currentProfileProvider.notifier).select(profile);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: LumioTheme.dark(), home: home),
      ),
    );
    await settle();
  }

  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> tapKey(String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await settle();
  }

  Future<void> close() async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  }
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

  group('dossiers', () {
    testWidgets('vide : message ; ajout par le sélecteur, vidéos listées', (
      t,
    ) async {
      final h = _H(t);
      await h.start();
      expect(find.textContaining('Aucun dossier'), findsOneWidget);
      await h.tapKey('local-add');
      expect(find.text('xyz 123'), findsOneWidget);
      expect(find.textContaining('1 vidéo'), findsWidgets);
      expect(find.textContaining('Dossier ajouté'), findsOneWidget);
      await h.close();
    });

    testWidgets('permission refusée : message, aucun dossier', (t) async {
      final h = _H(t);
      await h.start(permission: false);
      await h.tapKey('local-add');
      expect(find.textContaining('accéder à vos vidéos'), findsOneWidget);
      expect(await h.library.grantedFolders(), isEmpty);
      await h.close();
    });

    testWidgets('sélecteur indisponible : saisie du chemin', (t) async {
      final h = _H(t);
      await h.start(picker: _Picker(null, fail: true));
      await h.tapKey('local-add');
      expect(find.textContaining('sélecteur de dossier'), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('local-path')), h.dir.path);
      await h.tapKey('local-path-ok');
      expect(find.text('xyz 123'), findsOneWidget);
      await h.close();
    });

    testWidgets('annulation du sélecteur : rien ne change', (t) async {
      final h = _H(t);
      await h.start(picker: _Picker(null));
      await h.tapKey('local-add');
      expect(find.textContaining('Aucun dossier'), findsOneWidget);
      await h.close();
    });

    testWidgets('titre illisible : correction manuelle conservée', (t) async {
      final h = _H(t);
      await h.start();
      await h.tapKey('local-add');
      final item = (await t.runAsync(
        () => h.db.select(h.db.localItems).get(),
      ))!.single;
      await h.tapKey('local-edit:${item.id}');
      expect(find.text('Détecté : xyz 123'), findsOneWidget);
      await t.enterText(
        find.byKey(const ValueKey('local-fix-field')),
        'Mon film',
      );
      await h.tapKey('local-fix-save');
      expect(find.text('Mon film'), findsOneWidget);
      await t.runAsync(() => h.library.scan(item.folderPath));
      await h.settle();
      expect(find.text('Mon film'), findsOneWidget);
      // Rétablir le titre détecté.
      await h.tapKey('local-edit:${item.id}');
      await h.tapKey('local-fix-reset');
      expect(find.text('xyz 123'), findsOneWidget);
      await h.close();
    });

    testWidgets('retrait : éléments retirés, fichier intact', (t) async {
      final h = _H(t);
      await h.start();
      await h.tapKey('local-add');
      final folder = (await t.runAsync(h.library.grantedFolders))!.single;
      await h.tapKey('local-remove:$folder');
      expect(find.textContaining('Aucun dossier'), findsOneWidget);
      expect(h.movie.existsSync(), isTrue);
      await h.close();
    });
  });

  group('fiche et lecture', () {
    Future<LocalItem> addOne(_H h) async {
      await h.tester.runAsync(() => h.library.addFolder(h.dir.path));
      return (await h.tester.runAsync(
        () => h.db.select(h.db.localItems).get(),
      ))!.single;
    }

    testWidgets('lecture : lecteur ouvert avec LocalFileSource du dossier', (
      t,
    ) async {
      final h = _H(t);
      await h.start(home: const SizedBox());
      final item = await addOne(h);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: MaterialApp(
            theme: LumioTheme.dark(),
            home: LocalDetailScreen(id: item.id),
          ),
        ),
      );
      await h.settle();
      expect(find.text('xyz 123'), findsWidgets);
      await h.tapKey('local-play');
      expect(find.text('LECTEUR'), findsOneWidget);
      final s = h.screens.single;
      expect(s.metaId, item.id);
      expect(s.videoId, item.id);
      expect(s.local!.path, item.path);
      expect(s.local!.grantedFolders, [normalizeFolder(h.dir.path)]);
      expect(s.item.url, Uri.file(item.path));
      expect(s.item.addonId, 'local');
      await h.close();
    });

    testWidgets('fichier disparu : message, pas de lecteur', (t) async {
      final h = _H(t);
      await h.start(home: const SizedBox());
      final item = await addOne(h);
      h.movie.deleteSync();
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: MaterialApp(
            theme: LumioTheme.dark(),
            home: LocalDetailScreen(id: item.id),
          ),
        ),
      );
      await h.settle();
      await h.tapKey('local-play');
      expect(find.textContaining('Fichier introuvable'), findsOneWidget);
      expect(h.screens, isEmpty);
      await h.close();
    });

    testWidgets('profil enfant : fiche refusée, aucune lecture', (t) async {
      final h = _H(t);
      await h.start(home: const SizedBox(), profile: _kid);
      final item = await addOne(h);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: MaterialApp(
            theme: LumioTheme.dark(),
            home: LocalDetailScreen(id: item.id),
          ),
        ),
      );
      await h.settle();
      expect(find.byKey(const ValueKey('local-play')), findsNothing);
      expect(find.textContaining('profil'), findsWidgets);
      await h.close();
    });

    testWidgets('openDetail route un aperçu local vers la fiche locale', (
      t,
    ) async {
      final h = _H(t);
      await h.start(home: const SizedBox());
      final item = await addOne(h);
      late BuildContext ctx;
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: MaterialApp(
            theme: LumioTheme.dark(),
            home: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      openDetail(ctx, item.toPreview());
      await h.settle();
      expect(find.byType(LocalDetailScreen), findsOneWidget);
      await h.close();
    });

    testWidgets('Continuer : reprise locale décrite puis lue', (t) async {
      final h = _H(t);
      await h.start(home: const SizedBox());
      final item = await addOne(h);
      late BuildContext ctx;
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: MaterialApp(
            theme: LumioTheme.dark(),
            home: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final entry = ProgressEntry(
        profileId: 'default',
        metaId: item.id,
        videoId: item.id,
        position: const Duration(minutes: 5),
        duration: const Duration(minutes: 90),
        watched: false,
        updatedAt: DateTime.utc(2026),
      );
      final playback = h.container.read(continuePlaybackProvider);
      final info = await t.runAsync(() => playback.describe(entry));
      expect(info!.title, 'xyz 123');
      unawaited(playback.play(ctx, entry));
      await h.settle();
      expect(h.screens.single.local!.path, item.path);
      await h.close();
    });
  });
}
