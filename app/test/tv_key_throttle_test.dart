import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/ui/focus/tv_key_throttle.dart';

Widget _app() => MaterialApp(
  actions: tvActions(),
  home: Scaffold(
    body: Row(
      children: [
        for (var i = 0; i < 12; i++)
          Focus(
            debugLabel: 'c$i',
            autofocus: i == 0,
            child: const SizedBox(width: 50, height: 50),
          ),
      ],
    ),
  ),
);

String? _f() => FocusManager.instance.primaryFocus?.debugLabel;

void main() {
  late Duration now;
  setUp(() {
    now = const Duration(seconds: 10);
    TvKeyThrottle.reset();
    TvKeyThrottle.clock = () => now;
  });
  tearDown(TvKeyThrottle.reset);

  testWidgets('un appui court déplace d\'un seul élément', (t) async {
    await t.pumpWidget(_app());
    await t.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await t.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    expect(_f(), 'c1');
  });

  testWidgets('deux appuis courts rapprochés déplacent chacun d\'un cran', (
    t,
  ) async {
    await t.pumpWidget(_app());
    for (var i = 0; i < 3; i++) {
      await t.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await t.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      now += const Duration(milliseconds: 60);
    }
    expect(_f(), 'c3');
  });

  testWidgets('appui maintenu : premier cran immédiat, répétitions limitées', (
    t,
  ) async {
    await t.pumpWidget(_app());
    await t.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    expect(_f(), 'c1');
    // Une seconde de répétitions toutes les 33 ms.
    for (var ms = 33; ms <= 1000; ms += 33) {
      now += const Duration(milliseconds: 33);
      await t.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    }
    await t.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    final moved = int.parse(_f()!.substring(1));
    // Au plus 1 + 1000/140 déplacements, et nettement moins que 30 répétitions.
    expect(moved, lessThanOrEqualTo(1 + 1000 ~/ 140 + 1));
    expect(moved, greaterThanOrEqualTo(5));
  });

  testWidgets('une répétition après l\'intervalle passe', (t) async {
    await t.pumpWidget(_app());
    await t.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    now += const Duration(milliseconds: 150);
    await t.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    expect(_f(), 'c2');
  });
}
