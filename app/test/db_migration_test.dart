import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/db.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

/// Base v10 telle que l'ancienne version la laissait : tables de données, file
/// d'envoi de la synchronisation et déclencheurs `sync_*`.
raw.Database _v10() {
  final db = raw.sqlite3.openInMemory();
  db.execute('''
    CREATE TABLE profiles (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL,
      created_at INTEGER NOT NULL DEFAULT 0, age_limit INTEGER NOT NULL DEFAULT 0,
      is_kid INTEGER NOT NULL DEFAULT 0, locked INTEGER NOT NULL DEFAULT 0);
    CREATE TABLE settings (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL);
    CREATE TABLE sync_meta (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL);
    CREATE TABLE sync_outbox (seq INTEGER PRIMARY KEY AUTOINCREMENT,
      kind TEXT NOT NULL, key TEXT NOT NULL, UNIQUE (kind, key));
    CREATE TRIGGER sync_settings_ai AFTER INSERT ON settings
      BEGIN INSERT INTO sync_outbox (kind, key) VALUES ('settings', NEW.key); END;
    CREATE TRIGGER sync_profiles_ai AFTER INSERT ON profiles
      BEGIN INSERT INTO sync_outbox (kind, key) VALUES ('profiles', NEW.id); END;
    CREATE TABLE scrobble_queue (id INTEGER PRIMARY KEY AUTOINCREMENT,
      profile_id TEXT NOT NULL, tracker_id TEXT NOT NULL, event_json TEXT NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0, next_attempt_at INTEGER NOT NULL DEFAULT 0);
    PRAGMA user_version = 10;
  ''');
  return db;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('v10 -> v11 : synchro et Simkl supprimés, données gardées', () async {
    final old = _v10();
    // Autres tables de données : créées par Drift pour une base v10 réelle.
    final tmp = AppDatabase(NativeDatabase.memory());
    await tmp.customSelect('SELECT 1').get();
    final ddl = await tmp
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE type = 'table' AND sql IS NOT NULL "
          "AND name NOT IN ('profiles','settings','scrobble_queue') "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    for (final r in ddl) {
      old.execute(r.read<String>('sql'));
    }
    await tmp.close();

    old.execute("INSERT INTO profiles (id, name) VALUES ('p1', 'Moi')");
    old.execute("INSERT INTO settings VALUES ('ui_locale', 'fr')");
    old.execute(
      "INSERT INTO settings VALUES ('tracking_reauth:simkl:p1', '1')",
    );
    old.execute(
      "INSERT INTO settings VALUES ('tracking_reauth:trakt:p1', '1')",
    );
    old.execute(
      'INSERT INTO scrobble_queue (profile_id, tracker_id, event_json) '
      "VALUES ('p1', 'simkl', '{}'), ('p1', 'trakt', '{}')",
    );
    expect(old.select('SELECT * FROM sync_outbox'), isNotEmpty);

    final db = AppDatabase(NativeDatabase.opened(old));
    final names =
        (await db
                .customSelect(
                  'SELECT name FROM sqlite_master WHERE name LIKE ? ESCAPE ?',
                  variables: [Variable('sync\\_%'), Variable('\\')],
                )
                .get())
            .map((r) => r.read<String>('name'));
    expect(names, isEmpty); // tables et déclencheurs
    expect((await db.select(db.profiles).get()).single.name, 'Moi');
    final keys = (await db.select(db.settings).get()).map((s) => s.key);
    expect(keys, unorderedEquals(['ui_locale', 'tracking_reauth:trakt:p1']));
    final queue = await db.select(db.scrobbleQueueTable).get();
    expect(queue.map((q) => q.trackerId), ['trakt']);
    // Une écriture ordinaire fonctionne (plus de déclencheur vers la file).
    await db
        .into(db.settings)
        .insert(SettingsCompanion.insert(key: 'x', value: 'y'));
    expect(db.schemaVersion, 13);
    await db.close();
  });

  test('base neuve : aucune table de synchronisation', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final r = await db
        .customSelect("SELECT name FROM sqlite_master WHERE name LIKE 'sync%'")
        .get();
    expect(r, isEmpty);
    await db.close();
  });

  test('v11 -> v12 : titre et affiche ajoutés, progression gardée', () async {
    final old = raw.sqlite3.openInMemory();
    // Tables d'une base réelle v11 (modèle courant), sauf `progress` : celle
    // d'avant la v12, sans titre ni affiche.
    final tmp = AppDatabase(NativeDatabase.memory());
    await tmp.customSelect('SELECT 1').get();
    final ddl = await tmp
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE type = 'table' AND sql IS NOT NULL "
          "AND name <> 'progress' AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    for (final r in ddl) {
      old.execute(r.read<String>('sql'));
    }
    await tmp.close();
    old.execute('''
      CREATE TABLE progress (profile_id TEXT NOT NULL DEFAULT 'default',
        item_id TEXT NOT NULL, position_ms INTEGER NOT NULL DEFAULT 0,
        duration_ms INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL DEFAULT 0,
        meta_id TEXT NOT NULL DEFAULT '', watched INTEGER NOT NULL DEFAULT 0,
        certification TEXT, PRIMARY KEY (profile_id, item_id));
      PRAGMA user_version = 11;
    ''');
    old.execute(
      'INSERT INTO progress (profile_id, item_id, position_ms, duration_ms, '
      "updated_at, meta_id) VALUES ('p1', 'tt0458339', 66000, 888000, 5, 'tt0458339')",
    );

    final db = AppDatabase(NativeDatabase.opened(old));
    final row = (await db.select(db.progress).get()).single;
    expect(row.itemId, 'tt0458339');
    expect(row.positionMs, 66000);
    expect(row.title, isNull);
    expect(row.poster, isNull);
    expect(row.season, isNull);
    await db
        .into(db.progress)
        .insertOnConflictUpdate(
          ProgressCompanion.insert(
            profileId: const Value('p1'),
            itemId: 'tt1:1:2',
            title: const Value('Une série'),
            poster: const Value('https://img.example/p.jpg'),
            mediaType: const Value('series'),
            season: const Value(1),
            episode: const Value(2),
          ),
        );
    final n = await (db.select(
      db.progress,
    )..where((t) => t.itemId.equals('tt1:1:2'))).getSingle();
    expect((n.title, n.season, n.episode), ('Une série', 1, 2));
    expect(db.schemaVersion, 13);
    await db.close();
  });

  test('v12 -> v13 : identité du flux ajoutée, progression gardée', () async {
    final old = raw.sqlite3.openInMemory();
    final tmp = AppDatabase(NativeDatabase.memory());
    await tmp.customSelect('SELECT 1').get();
    final ddl = await tmp
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE type = 'table' AND sql IS NOT NULL "
          "AND name <> 'progress' AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    for (final r in ddl) {
      old.execute(r.read<String>('sql'));
    }
    await tmp.close();
    // `progress` telle que la v12 la laissait : titre et affiche, pas de flux.
    old.execute('''
      CREATE TABLE progress (profile_id TEXT NOT NULL DEFAULT 'default',
        item_id TEXT NOT NULL, position_ms INTEGER NOT NULL DEFAULT 0,
        duration_ms INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL DEFAULT 0,
        meta_id TEXT NOT NULL DEFAULT '', watched INTEGER NOT NULL DEFAULT 0,
        certification TEXT, title TEXT, poster TEXT, media_type TEXT,
        season INTEGER, episode INTEGER, PRIMARY KEY (profile_id, item_id));
      PRAGMA user_version = 12;
    ''');
    old.execute(
      'INSERT INTO progress (profile_id, item_id, position_ms, duration_ms, '
      "updated_at, meta_id, title) VALUES ('p1', 'tt0458339', 66000, 888000, 5, "
      "'tt0458339', 'Sintel')",
    );

    final db = AppDatabase(NativeDatabase.opened(old));
    final row = (await db.select(db.progress).get()).single;
    expect(
      (row.itemId, row.positionMs, row.title),
      ('tt0458339', 66000, 'Sintel'),
    );
    expect(row.streamAddonId, isNull);
    expect(row.streamKey, isNull);
    await db
        .into(db.progress)
        .insertOnConflictUpdate(
          ProgressCompanion.insert(
            profileId: const Value('p1'),
            itemId: 'tt0458339',
            streamAddonId: const Value('addon-1'),
            streamKey: const Value('t:abc:1'),
          ),
        );
    final n = (await db.select(db.progress).get()).single;
    expect((n.streamAddonId, n.streamKey), ('addon-1', 't:abc:1'));
    expect(db.schemaVersion, 13);
    await db.close();
  });
}
