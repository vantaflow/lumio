import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/player/player_screen.dart';

void main() {
  PlayerKeyAction a(LogicalKeyboardKey k, bool visible) =>
      mapPlayerKey(k, controlsVisible: visible);

  test('commandes masquées : ←/→ = ∓10 s, OK affiche', () {
    expect(a(LogicalKeyboardKey.arrowLeft, false), PlayerKeyAction.seekBack);
    expect(
      a(LogicalKeyboardKey.arrowRight, false),
      PlayerKeyAction.seekForward,
    );
    expect(a(LogicalKeyboardKey.enter, false), PlayerKeyAction.showControls);
    expect(a(LogicalKeyboardKey.select, false), PlayerKeyAction.showControls);
  });
  test('Espace bascule la lecture, commandes visibles ou non', () {
    expect(a(LogicalKeyboardKey.space, false), PlayerKeyAction.togglePlay);
    expect(a(LogicalKeyboardKey.space, true), PlayerKeyAction.togglePlay);
    expect(
      a(LogicalKeyboardKey.mediaPlayPause, true),
      PlayerKeyAction.togglePlay,
    );
  });
  test('commandes visibles : flèches laissées à la navigation', () {
    expect(a(LogicalKeyboardKey.arrowLeft, true), PlayerKeyAction.none);
    expect(a(LogicalKeyboardKey.enter, true), PlayerKeyAction.none);
  });
  test('formatClock', () {
    expect(formatClock(const Duration(seconds: 75)), '1:15');
    expect(
      formatClock(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });
}
