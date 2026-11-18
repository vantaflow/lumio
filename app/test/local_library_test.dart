import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/local_library.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:path/path.dart' as p;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory tmp;
  late DateTime clock;
  late LocalLibrary lib;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    tmp = Directory.systemTemp.createTempSync('lumio_local_');
    clock = DateTime.utc(2026, 11, 18, 12);
    lib = LocalLibrary(db, now: () => clock);
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  File touch(String rel, [String content = 'x']) {
    final f = File(p.join(tmp.path, rel))..createSync(recursive: true);
    f.writeAsStringSync(content);
    return f;
  }

  test(
    'migration v8 vers v9 : tables locales créées, données conservées',
    () async {
      final old = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(
              'CREATE TABLE settings (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)',
            );
            raw.execute("INSERT INTO settings VALUES ('ui_locale', 'en')");
            raw.execute('PRAGMA user_version = 8');
          },
        ),
      );
      addTearDown(old.close);
      expect(await old.select(old.localFolders).get(), isEmpty);
      expect(await old.select(old.localItems).get(), isEmpty);
      expect((await old.select(old.settings).get()).single.value, 'en');
      // Les nouvelles tables sont utilisables.
      final l = LocalLibrary(old, scanner: (_) async => const []);
      expect(await l.addFolder(tmp.path), 0);
      expect(await l.grantedFolders(), [normalizeFolder(tmp.path)]);
    },
  );

  group('analyse', () {
    test('extensions, profondeur ≤ 6, dossiers et fichiers cachés', () {
      touch('Film (2019).mkv');
      touch('a.MP4');
      touch('b.txt');
      touch('c.srt');
      touch('.cache/hidden.mkv');
      touch('.cache2.mkv');
      touch('d1/d2/d3/d4/d5/d6/ok.avi'); // profondeur 6 : gardé
      touch('d1/d2/d3/d4/d5/d6/d7/trop.avi'); // profondeur 7 : ignoré
      for (final e in ['m4v', 'ts', 'webm']) {
        touch('x.$e');
      }
      final names = scanLocalFolder(tmp.path).map((f) => f.fileName).toSet();
      expect(names, {
        'Film (2019).mkv',
        'a.MP4',
        'ok.avi',
        'x.m4v',
        'x.ts',
        'x.webm',
      });
    });

    test('titre et année analysés', () {
      touch('The.Show.S01E02.1080p.x265.mkv');
      touch('Film (2019).mp4');
      final byName = {for (final f in scanLocalFolder(tmp.path)) f.fileName: f};
      final ep = byName['The.Show.S01E02.1080p.x265.mkv']!;
      expect((ep.title, ep.season, ep.episode), ('The Show', 1, 2));
      expect(byName['Film (2019).mp4']!.year, 2019);
    });

    test('boucle de liens symboliques : terminé, sans doublon', () {
      touch('a/film.mkv');
      Link(p.join(tmp.path, 'a', 'loop')).createSync(tmp.path);
      final files = scanLocalFolder(tmp.path);
      expect(files, hasLength(1));
    });

    test('lien vers l\'extérieur du dossier : ignoré', () {
      final outside = Directory.systemTemp.createTempSync('lumio_out_');
      addTearDown(() => outside.deleteSync(recursive: true));
      File(p.join(outside.path, 'secret.mkv')).writeAsStringSync('x');
      Link(p.join(tmp.path, 'dir')).createSync(outside.path);
      Link(
        p.join(tmp.path, 'f.mkv'),
      ).createSync(p.join(outside.path, 'secret.mkv'));
      touch('ok.mkv');
      expect(scanLocalFolder(tmp.path).map((f) => f.fileName), ['ok.mkv']);
    });

    test('dossier absent : LocalScanException(missing)', () {
      expect(
        () => scanLocalFolder(p.join(tmp.path, 'nope')),
        throwsA(
          isA<LocalScanException>().having(
            (e) => e.failure,
            'failure',
            LocalScanFailure.missing,
          ),
        ),
      );
    });
  });

  group('LocalLibrary', () {
    test('ajout : analyse dans un isolat, éléments listés', () async {
      touch('Film (2019).mp4');
      touch('Show.S01E02.mkv');
      final n = await lib.addFolder(tmp.path);
      expect(n, 2);
      final items = await db.select(db.localItems).get();
      expect(items.map((i) => i.title).toSet(), {'Film', 'Show'});
      final film = items.firstWhere((i) => i.title == 'Film');
      expect(film.id, localItemId(film.path));
      expect(film.id, startsWith('local:'));
      expect(film.id.length, 'local:'.length + 40);
      expect(film.folderPath, normalizeFolder(tmp.path));
    });

    test(
      'correction manuelle conservée à la réanalyse, rétablissable',
      () async {
        touch('xyz_123.mp4');
        await lib.addFolder(tmp.path);
        var item = (await db.select(db.localItems).get()).single;
        expect(item.displayTitle, 'xyz 123');
        await lib.setTitle(item.id, '  Mon film ');
        await lib.scan(tmp.path);
        item = (await db.select(db.localItems).get()).single;
        expect(item.title, 'xyz 123');
        expect(item.displayTitle, 'Mon film');
        expect(item.toPreview().name, 'Mon film');
        await lib.setTitle(item.id, '');
        item = (await db.select(db.localItems).get()).single;
        expect(item.displayTitle, 'xyz 123');
      },
    );

    test('fichier disparu retiré, nouveau ajouté', () async {
      final a = touch('a.mkv');
      await lib.addFolder(tmp.path);
      a.deleteSync();
      touch('b.mkv');
      expect(await lib.scan(tmp.path), 1);
      expect((await db.select(db.localItems).get()).single.fileName, 'b.mkv');
    });

    test('dossier retiré : éléments retirés, fichiers intacts', () async {
      final f = touch('a.mkv');
      await lib.addFolder(tmp.path);
      await lib.removeFolder(normalizeFolder(tmp.path));
      expect(await db.select(db.localItems).get(), isEmpty);
      expect(await db.select(db.localFolders).get(), isEmpty);
      expect(f.existsSync(), isTrue);
    });

    test('dossier qui se recoupe : refusé', () async {
      touch('sub/a.mkv');
      await lib.addFolder(tmp.path);
      await expectLater(
        lib.addFolder(p.join(tmp.path, 'sub')),
        throwsA(isA<LocalFolderOverlapException>()),
      );
      await expectLater(
        lib.addFolder(tmp.parent.path),
        throwsA(isA<LocalFolderOverlapException>()),
      );
    });

    test('dossier introuvable : refusé et non gardé', () async {
      await expectLater(
        lib.addFolder(p.join(tmp.path, 'nope')),
        throwsA(isA<LocalScanException>()),
      );
      expect(await db.select(db.localFolders).get(), isEmpty);
    });

    test('échec d\'une réanalyse : état précédent gardé', () async {
      touch('a.mkv');
      await lib.addFolder(tmp.path);
      Directory(tmp.path).deleteSync(recursive: true);
      await expectLater(lib.scan(tmp.path), throwsA(isA<LocalScanException>()));
      expect(await db.select(db.localItems).get(), hasLength(1));
      await lib.rescanAll(force: true); // n'échoue pas
      tmp.createSync();
    });

    test('réanalyse au démarrage limitée dans le temps', () async {
      var calls = 0;
      final counting = LocalLibrary(
        db,
        now: () => clock,
        scanner: (_) async {
          calls++;
          return const [];
        },
      );
      await counting.addFolder(tmp.path);
      expect(calls, 1);
      await counting.rescanAll(); // trop tôt
      expect(calls, 1);
      clock = clock.add(rescanInterval + const Duration(minutes: 1));
      await counting.rescanAll();
      expect(calls, 2);
      await counting.rescanAll(force: true);
      expect(calls, 3);
    });

    test(
      'deux analyses simultanées du même dossier n\'en font qu\'une',
      () async {
        var calls = 0;
        final slow = LocalLibrary(
          db,
          scanner: (_) async {
            calls++;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return const [];
          },
        );
        await db
            .into(db.localFolders)
            .insert(LocalFoldersCompanion.insert(path: tmp.path));
        await Future.wait([slow.scan(tmp.path), slow.scan(tmp.path)]);
        expect(calls, 1);
      },
    );

    test('profil enfant : élément local sans certification masqué', () async {
      touch('a.mkv');
      await lib.addFolder(tmp.path);
      final previews = [
        for (final i in await db.select(db.localItems).get()) i.toPreview(),
      ];
      expect(previews.single.sourceKind, 'local');
      expect(previews.single.certification, isNull);
      final kid = Profile(
        id: 'k',
        name: 'Enfant',
        createdAt: 0,
        ageLimit: 0,
        isKid: true,
        locked: false,
      );
      expect(visibleItems(previews, kid), isEmpty);
      expect(visibleItems(previews, null), hasLength(1));
    });
  });
}
