import 'dart:convert';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/profile_repository.dart';
import 'package:lumio/data/sync_store.dart';
import 'package:lumio_core/lumio_core.dart';

Future<List<(String, String)>> _outbox(AppDatabase db) async => [
  for (final r
      in await db
          .customSelect('SELECT kind, key FROM sync_outbox ORDER BY seq')
          .get())
    (r.read<String>('kind'), r.read<String>('key')),
];

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late DriftLocalSyncStore store;
  late ProfileRepository profiles;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalSyncStore(db, now: () => DateTime.utc(2026, 11, 18));
    profiles = ProfileRepository(
      db,
      hashPin: (p) async => 'h:$p',
      verifyPin: (p, s) async => s == 'h:$p',
    );
  });
  tearDown(() => db.close());

  Future<void> insertLibrary(String profile, String id) => db
      .into(db.libraryItems)
      .insert(
        LibraryItemsCompanion.insert(
          profileId: Value(profile),
          itemId: id,
          type: 'movie',
          metaJson: Value(jsonEncode({'name': id})),
          addedAt: const Value(5),
        ),
      );

  group('file d\'envoi (déclencheurs)', () {
    test(
      'bibliothèque, progression, profil et réglages sont inscrits',
      () async {
        await insertLibrary('default', 'tt1');
        await db
            .into(db.progress)
            .insert(
              ProgressCompanion.insert(
                itemId: 'tt1',
                positionMs: const Value(10),
                updatedAt: const Value(99),
              ),
            );
        await profiles.create('Léa');
        await db
            .into(db.settings)
            .insert(SettingsCompanion.insert(key: 'ui_locale', value: 'en'));
        final out = await _outbox(db);
        expect(out, contains(('library', 'default|tt1')));
        expect(out, contains(('progress', 'default|tt1')));
        expect(out.where((e) => e.$1 == 'profiles'), hasLength(1));
        expect(out, contains(('settings', 'ui_locale')));
      },
    );

    test('jamais de PIN, verrou, récupération ni profil actif', () async {
      await profiles.ensureDefault();
      await profiles.createParentPin('1234');
      await profiles.setActive('default');
      await profiles.verifyParentPin('0000'); // écrit parent_lockout
      final out = await _outbox(db);
      expect(out.where((e) => e.$1 == 'settings'), isEmpty);
    });

    test(
      'un même élément modifié deux fois : une seule ligne, seq renouvelé',
      () async {
        await insertLibrary('default', 'tt1');
        final first = (await store.pending(10)).single;
        await (db.update(
          db.libraryItems,
        )).write(const LibraryItemsCompanion(type: Value('series')));
        final second = (await store.pending(10)).single;
        expect(second.seq, greaterThan(first.seq));
        expect(second.item.payload!['type'], 'series');
      },
    );

    test('suppression : pierre tombale à l\'envoi', () async {
      await insertLibrary('default', 'tt1');
      await store.acknowledge(await store.pending(10));
      await db.delete(db.libraryItems).go();
      final p = (await store.pending(10)).single.item;
      expect(p.deleted, isTrue);
      expect(p.kind, 'library');
      expect(p.key, 'default|tt1');
    });

    test(
      'acknowledge ne retire pas une modification survenue entre-temps',
      () async {
        await insertLibrary('default', 'tt1');
        final sent = await store.pending(10);
        await (db.update(
          db.libraryItems,
        )).write(const LibraryItemsCompanion(type: Value('series')));
        await store.acknowledge(sent);
        expect(await store.pending(10), hasLength(1));
      },
    );

    test('le profil envoie nom, enfant, limite : pas de verrou', () async {
      await profiles.ensureDefault();
      await store.acknowledge(await store.pending(50));
      final kid = await profiles.create('Léa', isKid: true, locked: true);
      final p = (await store.pending(50))
          .map((c) => c.item)
          .singleWhere((i) => i.kind == 'profiles' && i.key == kid.id);
      expect(p.payload!.keys.toSet(), {'name', 'isKid', 'ageLimit'});
      expect(p.payload!['isKid'], isTrue);
      expect(isPushable(p), isTrue);
    });

    test('changer le seul verrou n\'envoie rien', () async {
      await profiles.ensureDefault();
      await store.acknowledge(await store.pending(50));
      await profiles.update('default', locked: true);
      expect(await _outbox(db), isEmpty);
    });
  });

  group('réception', () {
    test('appliquer ne remplit pas la file (pas d\'écho)', () async {
      await store.apply([
        const SyncItem(
          kind: 'library',
          key: 'default|tt9',
          payload: {
            'type': 'movie',
            'meta': {'name': 'Sintel'},
            'addedAt': 3,
          },
          version: 4,
        ),
        const SyncItem(
          kind: 'settings',
          key: 'ui_locale',
          payload: {'value': 'en'},
          version: 5,
        ),
        const SyncItem(
          kind: 'progress',
          key: 'default|tt9',
          payload: {
            'metaId': 'tt9',
            'positionMs': 5,
            'durationMs': 10,
            'watched': false,
            'updatedAt': 7,
          },
          version: 6,
        ),
      ]);
      expect(await _outbox(db), isEmpty);
      expect((await db.select(db.libraryItems).get()).single.itemId, 'tt9');
      expect((await db.select(db.progress).get()).single.positionMs, 5);
      // Le drapeau est retombé : une écriture locale est de nouveau suivie.
      await insertLibrary('default', 'tt10');
      expect(await _outbox(db), [('library', 'default|tt10')]);
    });

    test('tombstones : supprime bibliothèque, progression, réglage', () async {
      await insertLibrary('default', 'tt1');
      await db
          .into(db.progress)
          .insert(ProgressCompanion.insert(itemId: 'tt1'));
      await db
          .into(db.settings)
          .insert(SettingsCompanion.insert(key: 'ui_locale', value: 'en'));
      await store.acknowledge(await store.pending(50));
      await store.apply([
        const SyncItem(
          kind: 'library',
          key: 'default|tt1',
          deleted: true,
          version: 2,
        ),
        const SyncItem(
          kind: 'progress',
          key: 'default|tt1',
          deleted: true,
          version: 2,
        ),
        const SyncItem(
          kind: 'settings',
          key: 'ui_locale',
          deleted: true,
          version: 2,
        ),
      ]);
      expect(await db.select(db.libraryItems).get(), isEmpty);
      expect(await db.select(db.progress).get(), isEmpty);
      expect(await db.select(db.settings).get(), isEmpty);
      expect(await _outbox(db), isEmpty);
    });

    test(
      'une clé avec un changement local en attente est laissée intacte',
      () async {
        await insertLibrary('default', 'tt1');
        await store.apply([
          const SyncItem(
            kind: 'library',
            key: 'default|tt1',
            deleted: true,
            version: 2,
          ),
        ]);
        expect(await db.select(db.libraryItems).get(), hasLength(1));
        expect(await _outbox(db), [('library', 'default|tt1')]);
      },
    );

    test(
      'SÉCURITÉ : réglages hors liste blanche ignorés (PIN, verrou…)',
      () async {
        await profiles.ensureDefault();
        final code = await profiles.createParentPin('1234');
        expect(code, isNotEmpty);
        final before = await db.select(db.settings).get();
        await store.apply([
          for (final k in [
            'parent_pin_hash',
            'parent_recovery_hash',
            'parent_lockout',
            'active_profile',
            'sync.session',
          ])
            SyncItem(
              kind: 'settings',
              key: k,
              payload: const {'value': 'x'},
              version: 3,
            ),
          const SyncItem(
            kind: 'settings',
            key: 'parent_pin_hash',
            deleted: true,
            version: 4,
          ),
        ]);
        final after = await db.select(db.settings).get();
        expect(
          {for (final s in after) s.key: s.value},
          {for (final s in before) s.key: s.value},
        );
        expect(await profiles.hasParentPin(), isTrue);
        expect(await profiles.verifyParentPin('1234'), PinResult.ok);
      },
    );

    test(
      'profil reçu : nom rogné, âge borné, enfant jamais « adulte »',
      () async {
        await store.apply([
          SyncItem(
            kind: 'profiles',
            key: 'pk1',
            payload: {'name': '  ${'N' * 80}  ', 'isKid': true, 'ageLimit': 4},
            version: 1,
          ),
          const SyncItem(
            kind: 'profiles',
            key: 'pk2',
            payload: {'name': 'Hors bornes', 'isKid': false, 'ageLimit': 99},
            version: 2,
          ),
          const SyncItem(
            kind: 'profiles',
            key: 'pk3',
            payload: {'name': '   ', 'isKid': false, 'ageLimit': 1},
            version: 3,
          ),
        ]);
        final all = {
          for (final p in await db.select(db.profiles).get()) p.id: p,
        };
        expect(all['pk1']!.name.length, 40);
        expect(all['pk1']!.isKid, isTrue);
        expect(all['pk1']!.ageLimit, AgeLimit.age12.index);
        expect(all['pk2']!.ageLimit, AgeLimit.adult.index);
        expect(all.containsKey('pk3'), isFalse);
        expect(all['pk1']!.locked, isFalse);
      },
    );

    test(
      'profil reçu : au plus 6 profils ; le dernier profil local est gardé',
      () async {
        await profiles.ensureDefault();
        await store.apply([
          for (var i = 0; i < 8; i++)
            SyncItem(
              kind: 'profiles',
              key: 'x$i',
              payload: {'name': 'P$i', 'isKid': false, 'ageLimit': 4},
              version: i + 1,
            ),
        ]);
        expect(await db.select(db.profiles).get(), hasLength(6));
        final solo = AppDatabase(NativeDatabase.memory());
        addTearDown(solo.close);
        final s2 = DriftLocalSyncStore(solo);
        await ProfileRepository(solo).ensureDefault();
        await s2.apply([
          const SyncItem(
            kind: 'profiles',
            key: 'default',
            deleted: true,
            version: 2,
          ),
        ]);
        expect(await solo.select(solo.profiles).get(), hasLength(1));
      },
    );

    test('profil supprimé à distance : ses données locales aussi', () async {
      await profiles.ensureDefault();
      final kid = await profiles.create('Léa');
      await insertLibrary(kid.id, 'tt1');
      await store.acknowledge(await store.pending(50));
      await store.apply([
        SyncItem(kind: 'profiles', key: kid.id, deleted: true, version: 2),
      ]);
      expect((await db.select(db.profiles).get()).map((p) => p.id), [
        'default',
      ]);
      expect(await db.select(db.libraryItems).get(), isEmpty);
    });

    test('éléments malformés ignorés sans erreur', () async {
      await store.apply([
        const SyncItem(
          kind: 'library',
          key: 'sans-barre',
          payload: {'type': 'movie'},
          version: 1,
        ),
        const SyncItem(
          kind: 'library',
          key: 'p|x',
          payload: {'type': 3},
          version: 2,
        ),
        const SyncItem(
          kind: 'progress',
          key: 'p|x',
          payload: {'updatedAt': 'hier'},
          version: 3,
        ),
        const SyncItem(
          kind: 'settings',
          key: 'ui_locale',
          payload: {'value': 5},
          version: 4,
        ),
        const SyncItem(
          kind: 'addons',
          key: 'default',
          payload: {'blob': 'AAAA'},
          version: 5,
        ),
      ]);
      expect(await db.select(db.libraryItems).get(), isEmpty);
      expect(await db.select(db.progress).get(), isEmpty);
      expect(await db.select(db.settings).get(), isEmpty);
    });

    test('curseur de version persistant et remise à zéro', () async {
      expect(await store.lastVersion(), 0);
      await store.setLastVersion(12);
      expect(await store.lastVersion(), 12);
      await insertLibrary('default', 'tt1');
      await store.reset();
      expect(await store.lastVersion(), 0);
      expect(await _outbox(db), isEmpty);
    });

    test(
      'markAllDirty : tout le contenu synchronisable, rien d\'autre',
      () async {
        await profiles.ensureDefault();
        await profiles.createParentPin('1234');
        await insertLibrary('default', 'tt1');
        await db
            .into(db.settings)
            .insert(
              SettingsCompanion.insert(key: 'home_layout:default', value: '{}'),
            );
        await store.reset();
        await store.markAllDirty();
        final out = await _outbox(db);
        expect(out.toSet(), {
          ('library', 'default|tt1'),
          ('profiles', 'default'),
          ('settings', 'home_layout:default'),
        });
      },
    );
  });

  test('migration v6 vers v7 : file créée et données existantes inscrites', () async {
    final old = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE profiles (id TEXT NOT NULL PRIMARY KEY, '
            'name TEXT NOT NULL, created_at INTEGER NOT NULL DEFAULT 0, '
            'age_limit INTEGER NOT NULL DEFAULT 4, '
            'is_kid INTEGER NOT NULL DEFAULT 0, locked INTEGER NOT NULL DEFAULT 0)',
          );
          raw.execute(
            "INSERT INTO profiles (id, name) VALUES ('default', 'Moi')",
          );
          raw.execute(
            'CREATE TABLE library_items (profile_id TEXT NOT NULL DEFAULT \'default\', '
            'item_id TEXT NOT NULL, type TEXT NOT NULL, '
            'meta_json TEXT NOT NULL DEFAULT \'{}\', '
            'added_at INTEGER NOT NULL DEFAULT 0, certification TEXT, '
            'PRIMARY KEY (profile_id, item_id))',
          );
          raw.execute(
            "INSERT INTO library_items (item_id, type) VALUES ('tt1', 'movie')",
          );
          raw.execute(
            'CREATE TABLE progress (profile_id TEXT NOT NULL DEFAULT \'default\', '
            'item_id TEXT NOT NULL, position_ms INTEGER NOT NULL DEFAULT 0, '
            'duration_ms INTEGER NOT NULL DEFAULT 0, '
            'updated_at INTEGER NOT NULL DEFAULT 0, '
            'meta_id TEXT NOT NULL DEFAULT \'\', '
            'watched INTEGER NOT NULL DEFAULT 0, certification TEXT, '
            'PRIMARY KEY (profile_id, item_id))',
          );
          raw.execute(
            "INSERT INTO progress (item_id, updated_at) VALUES ('tt1', 4)",
          );
          raw.execute(
            'CREATE TABLE settings (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)',
          );
          raw.execute("INSERT INTO settings VALUES ('ui_locale', 'en')");
          raw.execute(
            "INSERT INTO settings VALUES ('parent_pin_hash', 'pbkdf2\$secret')",
          );
          raw.execute('PRAGMA user_version = 6');
        },
      ),
    );
    addTearDown(old.close);
    final out = await _outbox(old);
    expect(out.toSet(), {
      ('library', 'default|tt1'),
      ('progress', 'default|tt1'),
      ('profiles', 'default'),
      ('settings', 'ui_locale'),
    });
    // Les déclencheurs sont actifs après la migration.
    await old
        .into(old.settings)
        .insert(
          SettingsCompanion.insert(key: 'subtitle_lang:default', value: 'fr'),
        );
    expect(await _outbox(old), contains(('settings', 'subtitle_lang:default')));
    expect((await old.select(old.libraryItems).get()), hasLength(1));
  });

  test('base neuve (onCreate) : file et déclencheurs présents', () async {
    await insertLibrary('default', 'tt1');
    expect(await _outbox(db), [('library', 'default|tt1')]);
  });
}
