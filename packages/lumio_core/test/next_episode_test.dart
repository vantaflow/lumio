import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

Video v(String id, int s, int e) =>
    Video(id: id, title: id, season: s, episode: e);

void main() {
  final meta = Meta(
    id: 'tt1',
    type: 'series',
    name: 'S',
    videos: [
      v('tt1:1:1', 1, 1),
      v('tt1:1:2', 1, 2),
      v('tt1:2:1', 2, 1),
      v('tt1:0:1', 0, 1),
      v('tt1:0:2', 0, 2),
    ],
  );

  test('dernier épisode de la saison 1 : premier de la saison 2', () {
    expect(nextEpisode(meta, 'tt1:1:2')?.id, 'tt1:2:1');
  });

  test('épisode suivant dans la saison', () {
    expect(nextEpisode(meta, 'tt1:1:1')?.id, 'tt1:1:2');
  });

  test('dernier de la série : null (les spéciaux sont sautés)', () {
    expect(nextEpisode(meta, 'tt1:2:1'), isNull);
  });

  test('depuis un spécial : le spécial suivant', () {
    expect(nextEpisode(meta, 'tt1:0:1')?.id, 'tt1:0:2');
    expect(nextEpisode(meta, 'tt1:0:2'), isNull);
  });

  test('épisode inconnu : null', () {
    expect(nextEpisode(meta, 'nope'), isNull);
  });
}
