import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/ui/focus/focus_memory.dart';
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/focus/row_traversal.dart';
import 'package:lumio/ui/focus/tv_key_throttle.dart';
import 'package:lumio/ui/focus/tv_row.dart';
import 'package:lumio/ui/theme.dart';

/// Un appui haut/bas = exactement une rangée, un seul déplacement de focus,
/// même quand le défilement construit des rangées paresseuses dont la carte
/// mémorisée (première) ne doit pas reprendre le focus.
void main() {
  testWidgets('haut/bas : une rangée et un seul focus par appui', (t) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Chaque rangée a déjà été visitée : carte mémorisée = la première.
    final memory = container.read(focusMemoryProvider.notifier);
    for (var r = 0; r < 12; r++) {
      memory.remember('/', '0', row: 'r$r');
    }
    memory.remember('/', 'r0', row: lastFocusedRowKey);
    final bar = FocusNode(debugLabel: 'bar');
    addTearDown(bar.dispose);
    final labels = <String>[];
    void onFocus() {
      final f = FocusManager.instance.primaryFocus;
      if (f != null && f is! FocusScopeNode) labels.add(f.debugLabel ?? '?');
    }

    FocusManager.instance.addListener(onFocus);
    addTearDown(() => FocusManager.instance.removeListener(onFocus));

    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LumioTheme.dark(),
          actions: tvActions(),
          home: Scaffold(
            body: RowTraversalGroup(
              preferUp: bar,
              child: Column(
                children: [
                  Focus(
                    focusNode: bar,
                    child: const SizedBox(width: 200, height: 80),
                  ),
                  Expanded(
                    child: ListView.builder(
                      cacheExtent: 1500,
                      itemCount: 12,
                      itemBuilder: (_, r) => TvRow(
                        title: 'Rangée $r',
                        restorationId: 'r$r',
                        itemExtent: 200,
                        routeKey: '/',
                        items: [
                          for (var i = 0; i < 6; i++)
                            FocusableCard(
                              autofocus: r == 0 && i == 2,
                              onSelect: () {},
                              child: SizedBox(
                                key: ValueKey('c$r.$i'),
                                width: 200,
                                height: 170,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final startX = FocusManager.instance.primaryFocus!.rect.center.dx;
    for (var k = 0; k < 9; k++) {
      labels.clear();
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pumpAndSettle();
      expect(labels.length, 1, reason: 'appui ${k + 1} : un seul focus');
      final f = FocusManager.instance.primaryFocus!;
      final row = f.context!.findAncestorWidgetOfExactType<TvRow>()!;
      expect(row.title, 'Rangée ${k + 1}', reason: 'une rangée par appui');
      expect(f.rect.center.dx, closeTo(startX, 1), reason: 'même colonne');
    }
    for (var k = 8; k >= 0; k--) {
      labels.clear();
      await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await t.pumpAndSettle();
      expect(labels.length, 1, reason: 'haut : un seul focus');
      final row = FocusManager.instance.primaryFocus!.context!
          .findAncestorWidgetOfExactType<TvRow>()!;
      expect(row.title, 'Rangée $k', reason: 'haut : une rangée par appui');
    }
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pumpAndSettle();
    expect(
      bar.hasPrimaryFocus,
      isTrue,
      reason: 'depuis la 1re rangée : la barre',
    );
  });
}
