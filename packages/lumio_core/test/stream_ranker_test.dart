import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

StreamItem _direct(
  String path, {
  String addon = 'a',
  Quality q = Quality.hd1080,
  String? lang,
  int? size,
  int? seeders,
}) => StreamItem(
  addonId: addon,
  title: path,
  url: Uri.parse('https://cdn.example.com/$path'),
  quality: q,
  language: lang,
  sizeBytes: size,
  seeders: seeders,
);

StreamItem _torrent(
  String hash, {
  String addon = 'a',
  Quality q = Quality.hd1080,
  String? lang,
  int? seeders,
  int? fileIdx,
}) => StreamItem(
  addonId: addon,
  title: hash,
  infoHash: hash * 40,
  fileIdx: fileIdx,
  quality: q,
  language: lang,
  seeders: seeders,
);

void _record(HealthTracker h, String id, int ok, int ko, {int ms = 100}) {
  for (var i = 0; i < ok; i++) {
    h.record(id, Duration(milliseconds: ms), true);
  }
  for (var i = 0; i < ko; i++) {
    h.record(id, Duration(milliseconds: ms), false);
  }
}

void main() {
  const prefs = StreamPrefs(maxQuality: Quality.hd1080, languages: ['fr']);
  late HealthTracker health;
  setUp(() => health = HealthTracker());
  tearDown(() => health.dispose());

  group('score', () {
    test('fr 1080p devant en 2160p avec prefs (1080p, fr)', () {
      final fr = _direct('fr.mkv', lang: 'fr');
      final en = _direct('en.mkv', q: Quality.uhd2160, lang: 'en');
      expect(StreamRanker.rank([en, fr], prefs, health).first, same(fr));
    });

    test('la qualité la plus haute sous le plafond passe devant', () {
      final hd = _direct('a', q: Quality.hd1080, lang: 'fr');
      final sd = _direct('b', q: Quality.sd, lang: 'fr');
      final hd7 = _direct('c', q: Quality.hd720, lang: 'fr');
      expect(StreamRanker.rank([sd, hd7, hd], prefs, health), [hd, hd7, sd]);
    });

    test('au-dessus du plafond après la qualité plafonnée', () {
      final ok = _direct('a', q: Quality.hd720, lang: 'fr');
      final over = _direct('b', q: Quality.uhd2160, lang: 'fr');
      expect(StreamRanker.rank([over, ok], prefs, health), [ok, over]);
    });

    test('le lien direct passe devant un torrent si preferDirect', () {
      final d = _direct('a', lang: 'fr');
      final t = _torrent('b', lang: 'fr', seeders: 50);
      expect(StreamRanker.rank([t, d], prefs, health), [d, t]);
    });

    test('sans preferDirect, les sources font la différence', () {
      final d = _direct('a', lang: 'fr');
      final t = _torrent('b', lang: 'fr', seeders: 5000);
      final p = prefs.copyWith(preferDirect: false);
      expect(StreamRanker.rank([d, t], p, health), [t, d]);
    });

    test('à égalité, plus de sources d\'abord, puis ordre d\'origine', () {
      final few = _torrent('a', lang: 'fr', seeders: 3);
      final many = _torrent('b', lang: 'fr', seeders: 300);
      expect(StreamRanker.rank([few, many], prefs, health), [many, few]);
      final x = _torrent('c', lang: 'fr');
      final y = _torrent('d', lang: 'fr');
      expect(StreamRanker.rank([x, y], prefs, health), [x, y]);
    });

    test('multi convient à la langue préférée, la 1re langue prime', () {
      final p = prefs.copyWith(languages: ['fr', 'en']);
      final multi = _direct('m', lang: 'multi');
      final en = _direct('e', lang: 'en');
      final fr = _direct('f', lang: 'fr');
      final none = _direct('n');
      expect(StreamRanker.rank([none, en, multi, fr], p, health), [
        multi,
        fr,
        en,
        none,
      ]);
    });
  });

  group('dédoublonnage', () {
    test('mêmes liens sans paramètres volatils : un seul, le mieux noté', () {
      final a = StreamItem(
        addonId: 'a',
        title: 'un',
        url: Uri.parse('https://cdn.example.com/f.mkv?token=1'),
        quality: Quality.hd720,
      );
      final b = StreamItem(
        addonId: 'b',
        title: 'deux',
        url: Uri.parse('https://cdn.example.com/f.mkv?token=2'),
        quality: Quality.hd1080,
      );
      final out = StreamRanker.rank([a, b], prefs, health);
      expect(out, hasLength(1));
      expect(out.single, same(b));
    });

    test('même torrent (infoHash + fileIdx) chez deux addons', () {
      final a = _torrent('a', addon: 'x', fileIdx: 1, seeders: 1);
      final b = _torrent('a', addon: 'y', fileIdx: 1, seeders: 90);
      final c = _torrent('a', addon: 'y', fileIdx: 2);
      final out = StreamRanker.rank([a, b, c], prefs, health);
      expect(out, [b, c]);
    });

    test('le doublon d\'un addon défaillant cède à celui d\'un addon sain', () {
      _record(health, 'bad', 2, 10);
      final bad = _torrent('a', addon: 'bad', seeders: 500);
      final good = _torrent('a', addon: 'good', seeders: 2);
      expect(StreamRanker.rank([bad, good], prefs, health).single, same(good));
    });

    test('sort garde les doublons', () {
      final a = _torrent('a');
      final b = _torrent('a');
      expect(StreamRanker.sort([a, b], prefs, health), hasLength(2));
    });
  });

  group('fiabilité des addons', () {
    test('un addon défaillant est relégué', () {
      _record(health, 'bad', 2, 10);
      final bad = _direct('a', addon: 'bad', lang: 'fr');
      final ok = _direct('b', addon: 'good', q: Quality.sd, lang: 'fr');
      expect(StreamRanker.rank([bad, ok], prefs, health), [ok, bad]);
    });

    test('un addon lent perd 20 %, un inconnu ne change rien', () {
      _record(health, 'slow', 12, 0, ms: 5000);
      expect(health.stats('slow').level, HealthLevel.slow);
      final s = _direct('a', addon: 'slow', lang: 'fr');
      final u = _direct('b', addon: 'unknown', lang: 'fr');
      expect(
        StreamRanker.score(s, prefs, health),
        closeTo(StreamRanker.score(u, prefs, health) * 0.8, 1e-9),
      );
    });

    test('un addon défaillant vaut 0,3 fois le score', () {
      _record(health, 'bad', 0, 10);
      final b = _direct('a', addon: 'bad', lang: 'fr');
      final u = _direct('a', addon: 'unknown', lang: 'fr');
      expect(
        StreamRanker.score(b, prefs, health),
        closeTo(StreamRanker.score(u, prefs, health) * 0.3, 1e-9),
      );
    });

    test('le score reste positif même au-dessus du plafond', () {
      _record(health, 'bad', 0, 10);
      final over = _direct('a', q: Quality.uhd2160, addon: 'bad');
      expect(StreamRanker.score(over, prefs, health), greaterThan(0));
    });
  });

  group('préférences', () {
    test('JSON : aller-retour et valeurs par défaut', () {
      const p = StreamPrefs(
        maxQuality: Quality.hd720,
        languages: ['en', 'fr'],
        preferDirect: false,
      );
      final back = StreamPrefs.fromJson(p.toJson());
      expect(back.maxQuality, Quality.hd720);
      expect(back.languages, ['en', 'fr']);
      expect(back.preferDirect, isFalse);
      final old = StreamPrefs.fromJson({'maxQuality': 'hd720'});
      expect(old.preferDirect, isTrue);
    });

    test('preferred : aucun flux', () {
      expect(StreamRanker.preferred(const [], prefs, health), isNull);
    });
  });
}
