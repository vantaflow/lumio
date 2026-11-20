import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/progress_repository.dart';

const _min = Duration(minutes: 1);

void main() {
  group('ProgressRecorder', () {
    late DateTime clock;
    late List<Duration> saved;
    late ProgressRecorder rec;
    const dur = Duration(minutes: 100);

    setUp(() {
      clock = DateTime.utc(2026);
      saved = [];
      rec = ProgressRecorder(
        save: (pos, d) async => saved.add(pos),
        now: () => clock,
      );
    });

    test('une écriture toutes les 10 s en lecture, pas de tempête', () {
      for (var s = 1; s <= 25; s++) {
        clock = DateTime.utc(2026).add(Duration(seconds: s));
        rec.tick(Duration(seconds: s), dur);
      }
      expect(saved, [const Duration(seconds: 10), const Duration(seconds: 20)]);
    });

    test('pause : écrit tout de suite, mais au plus une fois par seconde', () {
      clock = clock.add(const Duration(seconds: 3));
      rec.flush(const Duration(seconds: 3), dur);
      rec.flush(const Duration(seconds: 4), dur);
      expect(saved, [const Duration(seconds: 3)]);
      clock = clock.add(const Duration(seconds: 2));
      rec.flush(const Duration(seconds: 5), dur);
      expect(saved, hasLength(2));
    });

    test('échecs d\'écriture : une seule alerte après 3 échecs', () async {
      var notices = 0;
      final failing = ProgressRecorder(
        save: (pos, d) async => throw StateError('disque plein'),
        onError: () => notices++,
        now: () => clock,
      );
      for (var i = 1; i <= 5; i++) {
        clock = clock.add(const Duration(seconds: 11));
        failing.tick(Duration(seconds: i), dur);
        await Future<void>.delayed(Duration.zero);
      }
      expect(notices, 1);
    });

    test('sortie forcée, mais jamais position 0 ni durée inconnue', () {
      rec.flush(const Duration(seconds: 3), dur, force: true);
      rec.flush(const Duration(seconds: 4), dur, force: true);
      rec.flush(Duration.zero, dur, force: true);
      rec.flush(const Duration(seconds: 5), Duration.zero, force: true);
      expect(saved, [const Duration(seconds: 3), const Duration(seconds: 4)]);
    });
  });

  late AppDatabase db;
  late DateTime clock;
  late ProgressRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = DateTime.utc(2026, 11, 18, 12);
    repo = ProgressRepository(db, now: () => clock);
  });
  tearDown(() => db.close());

  Future<void> save(
    String meta,
    String video,
    int posMin, {
    int durMin = 100,
    String? next,
    String profile = 'p',
  }) async {
    clock = clock.add(const Duration(seconds: 5));
    await repo.save(
      profile,
      meta,
      video,
      _min * posMin,
      _min * durMin,
      nextVideoId: next,
    );
  }

  test(
    'titre, affiche et épisode mémorisés, gardés aux écritures suivantes',
    () async {
      await repo.save(
        'p',
        'tt1',
        'tt1:2:3',
        _min * 10,
        _min * 100,
        title: 'Une série',
        poster: 'https://img.example/p.jpg',
        mediaType: 'series',
        season: 2,
        episode: 3,
      );
      // Écriture sans titre (lecture lancée sans fiche) : l'existant est gardé.
      await repo.save('p', 'tt1', 'tt1:2:3', _min * 20, _min * 100);
      final e = (await repo.get('p', 'tt1:2:3'))!;
      expect(e.title, 'Une série');
      expect(e.poster, 'https://img.example/p.jpg');
      expect((e.mediaType, e.season, e.episode), ('series', 2, 3));
      final cont = (await repo.continueWatching('p').first).single;
      expect(cont.title, 'Une série');
    },
  );

  test('identité du flux mémorisée, remplacée par le flux suivant', () async {
    await repo.save(
      'p',
      'tt1',
      'tt1',
      _min * 10,
      _min * 100,
      streamAddonId: 'addon-1',
      streamKey: 't:${'a' * 40}:2',
    );
    // Écriture sans identité (ancien appelant) : l'existant est gardé.
    await repo.save('p', 'tt1', 'tt1', _min * 20, _min * 100);
    var e = (await repo.get('p', 'tt1'))!;
    expect((e.streamAddonId, e.streamKey), ('addon-1', 't:${'a' * 40}:2'));
    // Un autre flux (repli, « choisir une autre source ») le remplace.
    await repo.save(
      'p',
      'tt1',
      'tt1',
      _min * 30,
      _min * 100,
      streamAddonId: 'addon-2',
      streamKey: 'u:${'b' * 64}',
    );
    e = (await repo.get('p', 'tt1'))!;
    expect((e.streamAddonId, e.streamKey), ('addon-2', 'u:${'b' * 64}'));
    final cont = (await repo.continueWatching('p').first).single;
    expect(cont.streamKey, 'u:${'b' * 64}');
  });

  test(
    'migration v2 vers v3 : ajoute metaId et watched, garde les lignes',
    () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final old = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(
              'CREATE TABLE profiles (id TEXT NOT NULL PRIMARY KEY, '
              'name TEXT NOT NULL, created_at INTEGER NOT NULL DEFAULT 0)',
            );
            raw.execute(
              'CREATE TABLE progress (profile_id TEXT NOT NULL DEFAULT \'default\', '
              'item_id TEXT NOT NULL, position_ms INTEGER NOT NULL DEFAULT 0, '
              'duration_ms INTEGER NOT NULL DEFAULT 0, '
              'updated_at INTEGER NOT NULL DEFAULT 0, '
              'PRIMARY KEY (profile_id, item_id))',
            );
            raw.execute("INSERT INTO progress VALUES ('p', 'tt1', 40, 100, 7)");
            raw.execute('PRAGMA user_version = 2');
          },
        ),
      );
      addTearDown(old.close);
      final rows = await old.select(old.progress).get();
      expect(rows.single.itemId, 'tt1');
      expect(rows.single.metaId, '');
      expect(rows.single.watched, isFalse);
    },
  );

  test(
    'migration v4 vers v5 : ajoute certification (nulle), garde les lignes',
    () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final old = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(
              'CREATE TABLE progress (profile_id TEXT NOT NULL DEFAULT \'default\', '
              'item_id TEXT NOT NULL, position_ms INTEGER NOT NULL DEFAULT 0, '
              'duration_ms INTEGER NOT NULL DEFAULT 0, '
              'updated_at INTEGER NOT NULL DEFAULT 0, '
              'meta_id TEXT NOT NULL DEFAULT \'\', '
              'watched INTEGER NOT NULL DEFAULT 0, '
              'PRIMARY KEY (profile_id, item_id))',
            );
            raw.execute(
              "INSERT INTO progress VALUES ('p', 'tt1', 40, 100, 7, 'tt1', 0)",
            );
            raw.execute('PRAGMA user_version = 4');
          },
        ),
      );
      addTearDown(old.close);
      final rows = await old.select(old.progress).get();
      expect(rows.single.itemId, 'tt1');
      expect(rows.single.certification, isNull);
    },
  );

  test(
    'certification : mémorisée, conservée quand une sauvegarde l\'ignore',
    () async {
      await repo.save(
        'p',
        'tt1',
        'tt1',
        _min * 10,
        _min * 100,
        certification: 'PG',
      );
      await repo.save('p', 'tt1', 'tt1', _min * 20, _min * 100);
      expect((await repo.get('p', 'tt1'))!.certification, 'PG');
      expect(
        (await repo.continueWatching('p').first).single.certification,
        'PG',
      );
    },
  );

  test('get : renvoie la progression enregistrée, null sinon', () async {
    expect(await repo.get('p', 'tt1'), isNull);
    await save('tt1', 'tt1', 40);
    final e = (await repo.get('p', 'tt1'))!;
    expect(e.position, _min * 40);
    expect(e.duration, _min * 100);
    expect(e.watched, isFalse);
    await save('tt1', 'tt1', 50);
    expect((await repo.get('p', 'tt1'))!.position, _min * 50);
  });

  test('95 % : marqué comme vu', () async {
    await save('tt1', 'tt1', 95);
    expect((await repo.get('p', 'tt1'))!.watched, isTrue);
  });

  test('continueWatching : trié par date, exclut les vus et < 2 %', () async {
    await save('a', 'a', 40);
    await save('b', 'b', 95);
    await save('c', 'c', 1);
    await save('d', 'd', 10);
    final list = await repo.continueWatching('p').first;
    expect(list.map((e) => e.videoId), ['d', 'a']);
  });

  test('continueWatching : une entrée par série, la plus récente', () async {
    await save('s', 's:1:1', 30);
    await save('s', 's:1:2', 20);
    await save('x', 'x', 10);
    final list = await repo.continueWatching('p').first;
    expect(list.map((e) => e.videoId), ['x', 's:1:2']);
  });

  test('épisode vu avec suivant : le suivant apparaît à 0 s', () async {
    await save('s', 's:1:1', 95, next: 's:1:2');
    final list = await repo.continueWatching('p').first;
    expect(list, hasLength(1));
    expect(list.single.videoId, 's:1:2');
    expect(list.single.position, Duration.zero);
  });

  test('épisode vu sans suivant : la série disparaît', () async {
    await save('s', 's:1:1', 95);
    expect(await repo.continueWatching('p').first, isEmpty);
  });

  test('suivant déjà entamé : sa progression est conservée', () async {
    await save('s', 's:1:2', 30);
    await save('s', 's:1:1', 95, next: 's:1:2');
    final list = await repo.continueWatching('p').first;
    expect(list.single.videoId, 's:1:2');
    expect(list.single.position, _min * 30);
  });

  test('suivant déjà vu : jamais réinitialisé', () async {
    await save('s', 's:1:2', 95);
    await save('s', 's:1:1', 95, next: 's:1:2');
    final e = (await repo.get('p', 's:1:2'))!;
    expect(e.watched, isTrue);
    expect(e.position, _min * 95);
    expect(await repo.continueWatching('p').first, isEmpty);
  });

  test('au plus 20 entrées, profils isolés, flux mis à jour', () async {
    for (var i = 0; i < 25; i++) {
      await save('m$i', 'm$i', 40);
    }
    await save('z', 'z', 40, profile: 'autre');
    final stream = repo.continueWatching('p');
    expect((await stream.first), hasLength(20));
    final next = expectLater(
      stream.map((l) => l.first.videoId),
      emitsThrough('m99'),
    );
    await save('m99', 'm99', 40);
    await next;
  });
}
