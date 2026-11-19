import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/ui/focus/row_traversal.dart';

Widget _row(String name, int n, {double top = 0}) => Padding(
  padding: EdgeInsets.only(top: top),
  child: Row(
    children: [
      for (var i = 0; i < n; i++)
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Focus(
            debugLabel: '$name$i',
            child: Builder(
              builder: (c) => Container(
                key: ValueKey('$name$i'),
                width: 100,
                height: 60,
                color: Focus.of(c).hasFocus ? Colors.orange : Colors.grey,
              ),
            ),
          ),
        ),
    ],
  ),
);

String? _focused() => FocusManager.instance.primaryFocus?.debugLabel;

void main() {
  testWidgets('bas : la rangée voisine, même à une seule carte en colonne 0', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RowTraversalGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_row('a', 3), _row('b', 1), _row('c', 3)],
            ),
          ),
        ),
      ),
    );
    FocusManager.instance.rootScope.descendants
        .firstWhere((n) => n.debugLabel == 'a1')
        .requestFocus();
    await t.pump();
    expect(_focused(), 'a1');
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump();
    expect(_focused(), 'b0');
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump();
    expect(_focused(), 'c0');
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pump();
    expect(_focused(), 'b0');
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pump();
    expect(_focused(), 'a0');
  });

  testWidgets('bas : carte la plus proche horizontalement dans la rangée', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RowTraversalGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_row('a', 4), _row('b', 4)],
            ),
          ),
        ),
      ),
    );
    FocusManager.instance.rootScope.descendants
        .firstWhere((n) => n.debugLabel == 'a2')
        .requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump();
    expect(_focused(), 'b2');
  });

  testWidgets('gauche et droite : parcours par défaut', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RowTraversalGroup(child: Column(children: [_row('a', 3)])),
        ),
      ),
    );
    FocusManager.instance.rootScope.descendants
        .firstWhere((n) => n.debugLabel == 'a0')
        .requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    expect(_focused(), 'a1');
  });

  testWidgets('dernière rangée : bas ne fait rien, ne plante pas', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RowTraversalGroup(child: Column(children: [_row('a', 2)])),
        ),
      ),
    );
    FocusManager.instance.rootScope.descendants
        .firstWhere((n) => n.debugLabel == 'a1')
        .requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump();
    expect(_focused(), 'a1');
  });
}
