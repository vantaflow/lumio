import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

Video ep(String id, int s, int e, [String? released]) => Video(
  id: id,
  title: id,
  season: s,
  episode: e,
  released: released == null ? null : DateTime.parse(released),
);

Meta series(String id, String name, List<Video> videos) =>
    Meta(id: id, type: 'series', name: name, videos: videos);

void main() {
  final now = DateTime.utc(2026, 11, 18, 12);

  test('tri par date, épisodes passés exclus', () {
    final a = series('a', 'A', [
      ep('a:1:1', 1, 1, '2026-11-10T00:00:00Z'),
      ep('a:1:2', 1, 2, '2026-11-25T00:00:00Z'),
    ]);
    final b = series('b', 'B', [ep('b:1:1', 1, 1, '2026-11-20T00:00:00Z')]);
    final r = upcoming([a, b], now);
    expect([for (final e in r) e.video?.id], ['b:1:1', 'a:1:2']);
    expect(r.every((e) => !e.unknown), isTrue);
    expect(r.first.date, DateTime.utc(2026, 11, 20));
  });

  test('fenêtre de 30 jours (borne incluse), au-delà exclu', () {
    final end = now.add(const Duration(days: 30));
    final a = series('a', 'A', [
      ep('a:1:1', 1, 1, end.toIso8601String()),
      ep('a:1:2', 1, 2, end.add(const Duration(seconds: 1)).toIso8601String()),
    ]);
    expect(
      [
        for (final e in upcoming([a], now)) e.video?.id,
      ],
      ['a:1:1'],
    );
    final custom = upcoming([a], now, days: 7);
    expect(custom, isEmpty); // dates connues mais hors fenêtre
  });

  test('série sans date : « date inconnue » en fin de liste', () {
    final dated = series('d', 'D', [ep('d:1:1', 1, 1, '2026-12-01T00:00:00Z')]);
    final none = series('n', 'N', [ep('n:1:1', 1, 1)]);
    final empty = series('e', 'E', const []);
    final r = upcoming([none, dated, empty], now);
    expect([for (final e in r) e.series.id], ['d', 'n', 'e']);
    expect(r[1].unknown, isTrue);
    expect(r[1].video, isNull);
    expect(r[1].date, isNull);
  });

  test(
    'série dont les sorties futures sont hors fenêtre : ni date ni inconnue',
    () {
      final far = series('f', 'F', [ep('f:1:1', 1, 1, '2027-06-01T00:00:00Z')]);
      expect(upcoming([far], now), isEmpty);
    },
  );

  test('égalité de date : ordre stable par nom puis épisode', () {
    final a = series('a', 'Zed', [
      ep('a:1:2', 1, 2, '2026-11-20T00:00:00Z'),
      ep('a:1:1', 1, 1, '2026-11-20T00:00:00Z'),
    ]);
    final b = series('b', 'Alpha', [ep('b:1:1', 1, 1, '2026-11-20T00:00:00Z')]);
    final r = upcoming([a, b], now);
    expect([for (final e in r) e.video?.id], ['b:1:1', 'a:1:1', 'a:1:2']);
  });

  test('now local converti en UTC', () {
    final a = series('a', 'A', [ep('a:1:1', 1, 1, '2026-11-18T13:00:00Z')]);
    expect(
      upcoming([a], DateTime.utc(2026, 11, 18, 12).toLocal()),
      hasLength(1),
    );
  });
}
