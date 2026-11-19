import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/player/player_screen.dart';
import 'package:lumio_core/lumio_core.dart';

void main() {
  final film = Meta(id: 'tt1', type: 'movie', name: 'Sintel');
  final serie = Meta(
    id: 'tt2',
    type: 'series',
    name: 'Dark',
    videos: const [
      Video(id: 'tt2:1:2', title: 'Épisode 2', season: 1, episode: 2),
    ],
  );

  test('film : le titre du film, pas le nom du flux', () {
    expect(playerTitle(film, 'tt1', 'Flux de test'), 'Sintel');
  });
  test('série : titre et SxEy', () {
    expect(playerTitle(serie, 'tt2:1:2', 'Flux'), 'Dark · S1E2');
  });
  test('fiche inconnue : repli sur le nom du flux', () {
    expect(playerTitle(null, 'tt1', 'Flux de test'), 'Flux de test');
    expect(
      playerTitle(Meta(id: 'x', type: 'movie', name: ' '), 'x', 'Flux'),
      'Flux',
    );
  });
}
