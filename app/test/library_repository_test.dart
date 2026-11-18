import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/library_repository.dart';
import 'package:lumio/data/stream_prefs.dart';
import 'package:lumio_core/lumio_core.dart';

MetaPreview _m(String id, {String? cert, String name = 'Film'}) => MetaPreview(
  id: id,
  type: 'movie',
  name: '$name $id',
  poster: Uri.parse('https://img.example.com/$id.jpg'),
  releaseInfo: '2020',
  certification: cert,
  sourceAddonId: 'org.a',
);

StreamItem _s(
  String t, {
  Quality q = Quality.hd1080,
  String? lang,
  int? seeders,
  bool torrent = false,
}) => StreamItem(
  addonId: 'a',
  title: t,
  url: torrent ? null : Uri.parse('https://cdn.example.com/$t.mp4'),
  infoHash: torrent ? 'a' * 40 : null,
  quality: q,
  language: lang,
  seeders: seeders,
);

void main() {
  late AppDatabase db;
  late LibraryRepository repo;
  var clock = DateTime.utc(2026, 11, 18);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = DateTime.utc(2026, 11, 18);
    repo = LibraryRepository(
      db,
      now: () => clock = clock.add(const Duration(seconds: 1)),
    );
  });
  tearDown(() => db.close());

  group('LibraryRepository', () {
    test('ajout puis retrait', () async {
      await repo.add('p', _m('1'));
      expect(await repo.contains('p', '1'), isTrue);
      expect((await repo.watch('p').first).single.name, 'Film 1');
      await repo.remove('p', '1');
      expect(await repo.contains('p', '1'), isFalse);
      expect(await repo.watch('p').first, isEmpty);
    });

    test('ajout en double : une seule entrée, la première date', () async {
      await repo.add('p', _m('1'));
      await repo.add('p', _m('2'));
      await repo.add('p', _m('1', name: 'Autre'));
      final l = await repo.watch('p').first;
      expect([for (final m in l) m.id], ['2', '1']); // récent en tête
      expect(l.last.name, 'Film 1');
    });

    test('une liste par profil', () async {
      await repo.add('a', _m('1'));
      await repo.add('b', _m('2'));
      expect((await repo.watch('a').first).single.id, '1');
      expect((await repo.watch('b').first).single.id, '2');
      await repo.remove('a', '2');
      expect(await repo.contains('b', '2'), isTrue);
    });

    test('conserve affiche, certification et source', () async {
      await repo.add('p', _m('1', cert: 'PG'));
      final m = (await repo.watch('p').first).single;
      expect(m.certification, 'PG');
      expect(m.poster.toString(), 'https://img.example.com/1.jpg');
      expect(m.sourceAddonId, 'org.a');
      expect(m.releaseInfo, '2020');
    });

    test('le flux se met à jour à chaque changement', () async {
      final seen = <int>[];
      final sub = repo.watch('p').listen((l) => seen.add(l.length));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await repo.add('p', _m('1'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await repo.remove('p', '1');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      expect(seen, [0, 1, 0]);
    });

    test('ligne illisible ignorée', () async {
      await repo.add('p', _m('1'));
      await db.customStatement(
        "UPDATE library_items SET meta_json = 'pas du json'",
      );
      expect(await repo.watch('p').first, isEmpty);
    });
  });

  test(
    'migration v5 vers v6 : ajoute certification, garde « Ma liste »',
    () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final old = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(
              'CREATE TABLE library_items (profile_id TEXT NOT NULL DEFAULT '
              "'default', item_id TEXT NOT NULL, type TEXT NOT NULL, "
              "meta_json TEXT NOT NULL DEFAULT '{}', "
              'added_at INTEGER NOT NULL DEFAULT 0, '
              'PRIMARY KEY (profile_id, item_id))',
            );
            raw.execute(
              "INSERT INTO library_items VALUES ('p', 'tt1', 'movie', "
              '\'{"name":"Vieux"}\', 5)',
            );
            raw.execute('PRAGMA user_version = 5');
          },
        ),
      );
      addTearDown(old.close);
      final rows = await old.select(old.libraryItems).get();
      expect(rows.single.itemId, 'tt1');
      expect(rows.single.certification, isNull);
      final list = await LibraryRepository(old).watch('p').first;
      expect(list.single.name, 'Vieux');
      await LibraryRepository(old).add('p', _m('2', cert: 'G'));
      expect((await LibraryRepository(old).watch('p').first).length, 2);
    },
  );

  group('préférences de flux', () {
    const prefs = StreamPrefs(); // 1080p, fr
    final health = HealthTracker();

    test('langue d\'abord : un 720p fr bat un 1080p en', () {
      final best = StreamRanker.preferred(
        [_s('en1080', lang: 'en'), _s('fr720', q: Quality.hd720, lang: 'fr')],
        prefs,
        health,
      );
      expect(best!.title, 'fr720');
    });

    test('qualité sous le plafond : 1080p devant 4K et 720p', () {
      final best = StreamRanker.preferred(
        [
          _s('4k', q: Quality.uhd2160, lang: 'fr'),
          _s('720', q: Quality.hd720, lang: 'fr'),
          _s('1080', lang: 'fr'),
        ],
        prefs,
        health,
      );
      expect(best!.title, '1080');
    });

    test('seul le 4K existe : il reste choisi (au-dessus du plafond)', () {
      expect(
        StreamRanker.preferred(
          [_s('4k', q: Quality.uhd2160, lang: 'fr')],
          prefs,
          health,
        )!.title,
        '4k',
      );
    });

    test('lien direct avant torrent à score égal, puis seeders', () {
      final sorted = StreamRanker.sort(
        [
          _s('t10', lang: 'fr', torrent: true, seeders: 10),
          _s('t90', lang: 'fr', torrent: true, seeders: 90),
          _s('d', lang: 'fr'),
        ],
        prefs,
        health,
      );
      expect([for (final s in sorted) s.title], ['d', 't90', 't10']);
    });

    test('aucun flux : null', () {
      expect(StreamRanker.preferred(const [], prefs, health), isNull);
    });

    test('préférence 720p / en : respectée', () {
      const p = StreamPrefs(maxQuality: Quality.hd720, languages: ['en']);
      final best = StreamRanker.preferred(
        [
          _s('fr1080', lang: 'fr'),
          _s('en1080', lang: 'en'),
          _s('en720', q: Quality.hd720, lang: 'en'),
        ],
        p,
        health,
      );
      expect(best!.title, 'en720');
    });

    test('stockage par profil, valeur illisible = défauts', () async {
      final store = StreamPrefsStore(db);
      expect((await store.load('p')).languages, ['fr']);
      await store.save(
        'p',
        const StreamPrefs(maxQuality: Quality.hd720, languages: ['en', 'fr']),
      );
      final back = await store.load('p');
      expect(back.maxQuality, Quality.hd720);
      expect(back.languages, ['en', 'fr']);
      expect((await store.load('q')).maxQuality, Quality.hd1080);
      await db.customStatement("UPDATE settings SET value = '{'");
      expect((await store.load('p')).maxQuality, Quality.hd1080);
    });
  });
}
