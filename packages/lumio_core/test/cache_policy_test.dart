import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

const _mb = 1024 * 1024;
const _gb = 1024 * _mb;

void main() {
  group('defaultCacheBytes', () {
    test('TV avec 4,6 Go libres : 30 % du libre, soit 1,38 Go', () {
      final free = (4.6 * _gb).round();
      final v = defaultCacheBytes(freeBytes: free, isTv: true);
      expect(v, free * 3 ~/ 10);
      expect(v / _gb, closeTo(1.38, 0.001));
    });

    test('TV avec beaucoup de place : plafonné à 1,5 Go', () {
      expect(
        defaultCacheBytes(freeBytes: 100 * _gb, isTv: true),
        (1.5 * _gb).round(),
      );
    });

    test('autres appareils : plafonné à 5 Go, sinon 30 % du libre', () {
      expect(defaultCacheBytes(freeBytes: 100 * _gb, isTv: false), 5 * _gb);
      expect(defaultCacheBytes(freeBytes: 10 * _gb, isTv: false), 3 * _gb);
    });

    test('200 Mo libres : espace insuffisant', () {
      expect(
        () => defaultCacheBytes(freeBytes: 200 * _mb, isTv: true),
        throwsA(isA<InsufficientStorageException>()),
      );
    });

    test('30 % du libre sous 300 Mo : espace insuffisant', () {
      // 900 Mo libres : 30 % = 270 Mo < 300 Mo.
      expect(
        () => defaultCacheBytes(freeBytes: 900 * _mb, isTv: false),
        throwsA(isA<InsufficientStorageException>()),
      );
      // 1000 Mo libres : 300 Mo, accepté.
      expect(defaultCacheBytes(freeBytes: 1000 * _mb, isTv: false), 300 * _mb);
    });
  });

  group('effectiveCacheBytes', () {
    test('le réglage de l\'utilisateur prime, borné à 30 % du libre', () {
      expect(
        effectiveCacheBytes(
          requestedBytes: 2 * _gb,
          freeBytes: 100 * _gb,
          isTv: false,
        ),
        2 * _gb,
      );
      expect(
        effectiveCacheBytes(
          requestedBytes: 5 * _gb,
          freeBytes: 10 * _gb,
          isTv: false,
        ),
        3 * _gb,
      );
    });

    test('sans réglage : valeur par défaut', () {
      expect(
        effectiveCacheBytes(
          requestedBytes: null,
          freeBytes: 10 * _gb,
          isTv: true,
        ),
        (1.5 * _gb).round(),
      );
    });

    test('espace insuffisant même avec un réglage', () {
      expect(
        () => effectiveCacheBytes(
          requestedBytes: 1 * _gb,
          freeBytes: 200 * _mb,
          isTv: false,
        ),
        throwsA(isA<InsufficientStorageException>()),
      );
    });
  });

  group('evictionPlan', () {
    CachedTorrent t(String id, int mb, int day) => CachedTorrent(
      id: id,
      bytes: mb * _mb,
      lastUsed: DateTime.utc(2026, 1, day),
    );

    int total(List<CachedTorrent> l) => l.fold(0, (a, b) => a + b.bytes);

    test('rien à supprimer sous la limite', () {
      expect(evictionPlan([t('a', 100, 1)], 200 * _mb, null), isEmpty);
    });

    test('plus anciens d\'abord, jusqu\'à passer sous la limite', () {
      final all = [t('new', 300, 3), t('old', 300, 1), t('mid', 300, 2)];
      final plan = evictionPlan(all, 500 * _mb, null);
      expect(plan.map((e) => e.id), ['old', 'mid']);
      final kept = all.where((e) => !plan.contains(e)).toList();
      expect(total(kept), lessThanOrEqualTo(500 * _mb));
    });

    test('n\'épargne jamais le torrent en lecture', () {
      final all = [t('playing', 300, 1), t('b', 300, 2), t('c', 300, 3)];
      final plan = evictionPlan(all, 400 * _mb, 'playing');
      expect(plan.map((e) => e.id), isNot(contains('playing')));
      final kept = all.where((e) => !plan.contains(e)).toList();
      expect(total(kept), lessThanOrEqualTo(400 * _mb));
    });

    test('le torrent en lecture seul dépasse la limite : il reste', () {
      final all = [t('playing', 900, 1), t('b', 100, 2)];
      final plan = evictionPlan(all, 500 * _mb, 'playing');
      expect(plan.map((e) => e.id), ['b']);
    });

    test('ne modifie pas la liste d\'entrée', () {
      final all = [t('b', 300, 2), t('a', 300, 1)];
      evictionPlan(all, 100 * _mb, null);
      expect(all.map((e) => e.id), ['b', 'a']);
    });
  });
}
