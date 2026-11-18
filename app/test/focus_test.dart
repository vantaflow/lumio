import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/ui/focus/focus_memory.dart';
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/focus/tv_row.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/theme.dart';

Widget _app(Widget home, {ProviderContainer? container, bool reduce = false}) {
  final app = MaterialApp(
    theme: LumioTheme.dark(),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Scaffold(body: home),
    ),
  );
  return container == null
      ? ProviderScope(child: app)
      : UncontrolledProviderScope(container: container, child: app);
}

void main() {
  testWidgets('flèche droite déplace le focus vers la carte suivante', (
    t,
  ) async {
    final a = FocusNode(), b = FocusNode();
    await t.pumpWidget(
      _app(
        Row(
          children: [
            FocusableCard(
              focusNode: a,
              autofocus: true,
              onSelect: () {},
              child: const SizedBox(width: 100, height: 60),
            ),
            const SizedBox(width: 40),
            FocusableCard(
              focusNode: b,
              onSelect: () {},
              child: const SizedBox(width: 100, height: 60),
            ),
          ],
        ),
      ),
    );
    await t.pump();
    expect(a.hasFocus, isTrue);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    expect(b.hasFocus, isTrue);
  });

  testWidgets(
    'select appelle onSelect ; anneau décalé sans changer la taille',
    (t) async {
      var n = 0;
      await t.pumpWidget(
        _app(
          Center(
            child: FocusableCard(
              autofocus: true,
              onSelect: () => n++,
              child: const SizedBox(key: ValueKey('c'), width: 100, height: 60),
            ),
          ),
        ),
      );
      await t.pump();
      final before = t.getSize(find.byKey(const ValueKey('c')));
      await t.sendKeyEvent(LogicalKeyboardKey.select);
      await t.pump();
      expect(n, 1);
      await t.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(n, 3);
      final ring = t.getRect(find.byKey(const ValueKey('focus-ring')));
      final box = t.getRect(find.byKey(const ValueKey('c')));
      expect(
        ring.width - box.width,
        closeTo(2 * (lumioFocusOffset + lumioFocusWidth), 0.01),
      );
      expect(t.getSize(find.byKey(const ValueKey('c'))), before);
    },
  );

  testWidgets('appui long Select (>= 500 ms) appelle onLongPress seul', (
    t,
  ) async {
    var sel = 0, long = 0;
    await t.pumpWidget(
      _app(
        FocusableCard(
          autofocus: true,
          onSelect: () => sel++,
          onLongPress: () => long++,
          child: const SizedBox(width: 100, height: 60),
        ),
      ),
    );
    await t.pump();
    await t.sendKeyDownEvent(LogicalKeyboardKey.select);
    await t.pump(const Duration(milliseconds: 600));
    await t.sendKeyUpEvent(LogicalKeyboardKey.select);
    expect((sel, long), (0, 1));
    // appui court : onSelect
    await t.sendKeyDownEvent(LogicalKeyboardKey.select);
    await t.pump(const Duration(milliseconds: 100));
    await t.sendKeyUpEvent(LogicalKeyboardKey.select);
    expect((sel, long), (1, 1));
  });

  testWidgets('échelle au focus, sans animation si réduite', (t) async {
    for (final reduce in [false, true]) {
      await t.pumpWidget(
        _app(
          FocusableCard(
            autofocus: true,
            onSelect: () {},
            child: const SizedBox(width: 100, height: 60),
          ),
          reduce: reduce,
        ),
      );
      await t.pump();
      final s = t.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(s.scale, 1.06);
      expect(s.duration, reduce ? Duration.zero : LumioMotion.scaleCard);
    }
  });

  testWidgets('TvRow : retour sur la route restaure la carte mémorisée', (
    t,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final nodes = List.generate(6, (_) => FocusNode());
    Widget row() => TvRow(
      title: 'Films',
      restorationId: 'films',
      itemExtent: 200,
      items: [
        for (var i = 0; i < 6; i++)
          FocusableCard(
            focusNode: nodes[i],
            autofocus: i == 0,
            onSelect: () {},
            child: const SizedBox(width: 200, height: 170),
          ),
      ],
    );
    await t.pumpWidget(_app(row(), container: container));
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pumpAndSettle();
    expect(nodes[2].hasFocus, isTrue);
    expect(
      container.read(focusMemoryProvider.notifier).restore('/'),
      'films#2',
    );

    // Quitter la route (écran vide) puis revenir.
    await t.pumpWidget(_app(const SizedBox(), container: container));
    for (final n in nodes) {
      n.unfocus();
    }
    final fresh = List.generate(6, (_) => FocusNode());
    await t.pumpWidget(
      _app(
        TvRow(
          title: 'Films',
          restorationId: 'films',
          itemExtent: 200,
          items: [
            for (var i = 0; i < 6; i++)
              FocusableCard(
                focusNode: fresh[i],
                onSelect: () {},
                child: const SizedBox(width: 200, height: 170),
              ),
          ],
        ),
        container: container,
      ),
    );
    await t.pumpAndSettle();
    expect(fresh[2].hasFocus, isTrue);
  });

  testWidgets('TvRow : la carte focalisée est entièrement visible', (t) async {
    final nodes = List.generate(12, (_) => FocusNode());
    await t.pumpWidget(
      _app(
        TvRow(
          title: 'Séries',
          itemExtent: 300,
          items: [
            for (var i = 0; i < 12; i++)
              FocusableCard(
                focusNode: nodes[i],
                autofocus: i == 0,
                onSelect: () {},
                child: SizedBox(key: ValueKey('i$i'), width: 300, height: 170),
              ),
          ],
        ),
      ),
    );
    await t.pump();
    for (var k = 0; k < 6; k++) {
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pumpAndSettle();
    }
    final r = t.getRect(find.byKey(const ValueKey('i6')));
    final screen = t.view.physicalSize / t.view.devicePixelRatio;
    expect(r.left, greaterThanOrEqualTo(0));
    expect(r.right, lessThanOrEqualTo(screen.width));
  });

  testWidgets('TvScaffold : Retour ferme le panneau ouvert (BackGuard)', (
    t,
  ) async {
    var open = true;
    await t.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (c, set) => TvScaffold(
            child: BackGuard(
              isOpen: open,
              onClose: () => set(() => open = false),
              child: const Scaffold(body: Text('ecran')),
            ),
          ),
        ),
      ),
    );
    await t.binding.handlePopRoute();
    await t.pump();
    expect(open, isFalse);
  });

  testWidgets('TvScaffold : touche média appelle onPlayPause', (t) async {
    var n = 0;
    await t.pumpWidget(
      MaterialApp(
        home: TvScaffold(
          onPlayPause: () => n++,
          child: const Focus(autofocus: true, child: SizedBox()),
        ),
      ),
    );
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
    expect(n, 1);
  });
}
