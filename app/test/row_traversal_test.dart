import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/ui/focus/row_traversal.dart';
import 'package:lumio/ui/focus/tv_key_throttle.dart';

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
  _scrollTests();
  _placeholderTests();
  testWidgets('haut : la cible préférée de la rangée voisine passe devant', (
    t,
  ) async {
    final pref = FocusNode(debugLabel: 'pref');
    addTearDown(pref.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RowTraversalGroup(
            preferUp: pref,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Focus(
                      focusNode: pref,
                      child: const SizedBox(width: 100, height: 60),
                    ),
                    const SizedBox(width: 20),
                    _row('t', 3),
                  ],
                ),
                _row('c', 3, top: 100),
              ],
            ),
          ),
        ),
      ),
    );
    FocusManager.instance.rootScope.descendants
        .firstWhere((n) => n.debugLabel == 'c2')
        .requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pump();
    expect(_focused(), 'pref');
  });

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

  testWidgets('bas depuis une carte à droite : le héros (2 boutons à gauche)', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RowTraversalGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_row('n', 6), _row('h', 2), _row('c', 6)],
            ),
          ),
        ),
      ),
    );
    FocusManager.instance.rootScope.descendants
        .firstWhere((n) => n.debugLabel == 'n5')
        .requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump();
    expect(_focused(), 'h1');
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump();
    expect(_focused(), 'c1');
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

  testWidgets('rangée stricte : gauche/droite restent dans la rangée', (
    t,
  ) async {
    // Puces à droite, au même niveau que le haut de la rangée de cartes
    // (cas de la grille de résultats à demi masquée sous l'en-tête).
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(left: 600, top: 20, child: _row('chip', 2)),
              Positioned(
                left: 0,
                top: 40,
                child: RowTraversalGroup(strictRow: true, child: _row('a', 3)),
              ),
            ],
          ),
        ),
      ),
    );
    void focus(String l) => FocusManager.instance.rootScope.descendants
        .firstWhere((n) => n.debugLabel == l)
        .requestFocus();
    focus('a0');
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    expect(_focused(), 'a1');
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    expect(_focused(), 'a2');
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    expect(_focused(), 'a2', reason: 'fin de rangée : on reste, pas de saut');
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.pump();
    expect(_focused(), 'a1');
  });
}

void _scrollTests() {
  testWidgets(
    'bas dans une longue liste : défilement doux, un cran par appui',
    (t) async {
      final c = ScrollController();
      addTearDown(c.dispose);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusTraversalGroup(
              policy: TvTraversalPolicy(),
              child: ListView.builder(
                controller: c,
                itemCount: 40,
                itemBuilder: (_, i) => Focus(
                  debugLabel: 'r$i',
                  autofocus: i == 0,
                  child: const SizedBox(height: 100),
                ),
              ),
            ),
          ),
        ),
      );
      // Vue de 600 px : 6 lignes ; descendre de 8 lignes force le défilement.
      for (var i = 0; i < 8; i++) {
        await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        expect(_focused(), 'r${i + 1}');
      }
      await t.pumpAndSettle();
      // Pas de saut : juste après l'appui, la liste n'est pas arrivée.
      final before = c.offset;
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pump(const Duration(milliseconds: 10));
      expect(c.offset, lessThan(before + 100));
      await t.pumpAndSettle();
      expect(c.offset, greaterThan(before));
      // Remonter ne fait pas sauter la liste en arrière de plus d'une ligne.
      final top = c.offset;
      await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await t.pumpAndSettle();
      expect(c.offset, greaterThanOrEqualTo(top - 100));
    },
  );
}

void _placeholderTests() {
  testWidgets('bas : une rangée en chargement n\'est pas sautée', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RowTraversalGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('a', 3),
                const RowPlaceholder(child: SizedBox(height: 60, width: 300)),
                _row('b', 3, top: 40),
              ],
            ),
          ),
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('a1')));
    FocusManager.instance.primaryFocus?.unfocus();
    Focus.of(t.element(find.byKey(const ValueKey('a1')))).requestFocus();
    await t.pump();
    expect(_focused(), 'a1');
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(_focused(), 'a1', reason: 'la rangée suivante charge encore');
    expect(find.byType(RowPlaceholder), findsOneWidget);
  });
}
