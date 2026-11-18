import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/title_settings_store.dart';
import 'package:lumio/player/subtitle_style.dart';
import 'package:lumio_core/lumio_core.dart';

void main() {
  test(
    'migration v1 vers v2 : crée title_settings sans perdre les données',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(
              'CREATE TABLE profiles (id TEXT NOT NULL PRIMARY KEY, '
              'name TEXT NOT NULL, created_at INTEGER NOT NULL DEFAULT 0)',
            );
            raw.execute(
              'CREATE TABLE settings (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)',
            );
            raw.execute(
              'CREATE TABLE progress (profile_id TEXT NOT NULL DEFAULT \'default\', '
              'item_id TEXT NOT NULL, position_ms INTEGER NOT NULL DEFAULT 0, '
              'duration_ms INTEGER NOT NULL DEFAULT 0, '
              'updated_at INTEGER NOT NULL DEFAULT 0, '
              'PRIMARY KEY (profile_id, item_id))',
            );
            raw.execute("INSERT INTO settings VALUES ('k', 'v')");
            raw.execute('PRAGMA user_version = 1');
          },
        ),
      );
      addTearDown(db.close);
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE name = 'title_settings'",
          )
          .get();
      expect(rows, hasLength(1));
      final kept = await db.select(db.settings).get();
      expect(kept.single.value, 'v');
      final store = DriftTitleSettingsStore(db);
      store.save('p', 'tt1:1:1', const TitleSettings(subtitleDelayMs: 300));
      await store.flush();
    },
  );

  test('réglages persistés puis rechargés, clé par série', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final a = DriftTitleSettingsStore(db);
    a.save(
      'p',
      'tt1:1:1',
      const TitleSettings(audioLang: 'fr', subtitleDelayMs: 300),
    );
    await a.flush();
    final b = DriftTitleSettingsStore(db);
    await b.load('p');
    final s = b.forTitle('p', 'tt1:3:7');
    expect(s.subtitleDelayMs, 300);
    expect(s.audioLang, 'fr');
    expect(b.forTitle('q', 'tt1').subtitleDelayMs, 0);
  });

  test('style des sous-titres persisté', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final st = SubtitleStyleStore(db);
    expect((await st.load()).size, SubtitleSize.m);
    await st.save(
      const SubtitleStyle(size: SubtitleSize.xl, opaqueBackground: true),
    );
    final back = await st.load();
    expect(back.size, SubtitleSize.xl);
    expect(back.opaqueBackground, isTrue);
  });
}
