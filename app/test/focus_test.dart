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
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
      child: child!,
    ),
    home: Scaffold(body: home),
  );
  return container == null
      ? ProviderScope(child: app)
      : UncontrolledProviderScope(container: container, child: app);
}

void _size(WidgetTester t, Size s) {
  t.view.physicalSize = s;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  const tv = Size(1920, 1080), phone = Size(400, 800);

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
      container.read(focusMemoryProvider.notifier).restore('/', row: 'films'),
      '2',
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
          restorationId: 'series',
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

  testWidgets('relâchement orphelin : onSelect non appelé', (t) async {
    var sel = 0;
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
            FocusableCard(
              focusNode: b,
              onSelect: () => sel++,
              onLongPress: () {},
              child: const SizedBox(width: 100, height: 60),
            ),
          ],
        ),
      ),
    );
    await t.pump();
    await t.sendKeyDownEvent(LogicalKeyboardKey.select);
    b.requestFocus();
    await t.pump();
    await t.sendKeyUpEvent(LogicalKeyboardKey.select);
    expect(sel, 0);
  });

  testWidgets('maintenir une flèche ne déclenche jamais l\'appui long', (
    t,
  ) async {
    var long = 0;
    await t.pumpWidget(
      _app(
        FocusableCard(
          autofocus: true,
          onSelect: () {},
          onLongPress: () => long++,
          child: const SizedBox(width: 100, height: 60),
        ),
      ),
    );
    await t.pump();
    await t.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await t.pump(const Duration(seconds: 2));
    await t.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    expect(long, 0);
  });

  testWidgets('perte de focus pendant l\'appui annule l\'appui long', (
    t,
  ) async {
    var long = 0;
    final n = FocusNode();
    await t.pumpWidget(
      _app(
        FocusableCard(
          focusNode: n,
          autofocus: true,
          onSelect: () {},
          onLongPress: () => long++,
          child: const SizedBox(width: 100, height: 60),
        ),
      ),
    );
    await t.pump();
    await t.sendKeyDownEvent(LogicalKeyboardKey.select);
    n.unfocus();
    await t.pump(const Duration(seconds: 1));
    expect(long, 0);
  });

  testWidgets('enabled -> false annule le minuteur d\'appui long', (t) async {
    var long = 0;
    Widget w(bool en) => _app(
      FocusableCard(
        autofocus: true,
        enabled: en,
        onSelect: () {},
        onLongPress: () => long++,
        child: const SizedBox(width: 100, height: 60),
      ),
    );
    await t.pumpWidget(w(true));
    await t.pump();
    await t.sendKeyDownEvent(LogicalKeyboardKey.select);
    await t.pumpWidget(w(false));
    await t.pump(const Duration(seconds: 1));
    expect(long, 0);
  });

  testWidgets('TvRow : haut/bas quittent la rangée ; échelle 1,08', (t) async {
    _size(t, tv);
    final top = FocusNode(), bottom = FocusNode();
    Widget row(String id, FocusNode n, {bool auto = false}) => TvRow(
      title: id,
      restorationId: id,
      items: [
        FocusableCard(
          focusNode: n,
          autofocus: auto,
          onSelect: () {},
          child: const SizedBox(width: 300, height: 170),
        ),
      ],
    );
    await t.pumpWidget(
      _app(Column(children: [row('a', top, auto: true), row('b', bottom)])),
    );
    await t.pump();
    expect(
      t.widget<AnimatedScale>(find.byType(AnimatedScale).first).scale,
      1.08,
    );
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump();
    expect(bottom.hasFocus, isTrue);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pump();
    expect(top.hasFocus, isTrue);
  });

  testWidgets('TvRow : mémoire distincte par rangée (A, B, A)', (t) async {
    _size(t, tv);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    List<FocusNode> mk() => List.generate(4, (_) => FocusNode());
    Widget row(String id, List<FocusNode> ns, {bool auto = false}) => TvRow(
      title: id,
      restorationId: id,
      itemExtent: 300,
      items: [
        for (var i = 0; i < 4; i++)
          FocusableCard(
            focusNode: ns[i],
            autofocus: auto && i == 0,
            onSelect: () {},
            child: const SizedBox(width: 300, height: 170),
          ),
      ],
    );
    final a = mk(), b = mk();
    await t.pumpWidget(
      _app(
        Column(children: [row('a', a, auto: true), row('b', b)]),
        container: container,
      ),
    );
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pumpAndSettle();
    final mem = container.read(focusMemoryProvider.notifier);
    expect(mem.restore('/', row: 'a'), '2');
    expect(mem.restore('/', row: 'b'), isNotNull);

    await t.pumpWidget(_app(const SizedBox(), container: container));
    final a2 = mk(), b2 = mk();
    await t.pumpWidget(
      _app(
        Column(children: [row('a', a2), row('b', b2)]),
        container: container,
      ),
    );
    await t.pumpAndSettle();
    // les deux rangées demandent le focus ; la mémoire de chacune est intacte
    expect(mem.restore('/', row: 'a'), '2');
    expect(a2[2].hasFocus || b2.any((n) => n.hasFocus), isTrue);
  });

  testWidgets('TvRow : carte focalisée centrée après un long déplacement', (
    t,
  ) async {
    _size(t, tv);
    final nodes = List.generate(20, (_) => FocusNode());
    await t.pumpWidget(
      _app(
        TvRow(
          title: 'R',
          restorationId: 'r',
          itemExtent: 300,
          items: [
            for (var i = 0; i < 20; i++)
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
    for (var k = 0; k < 10; k++) {
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pumpAndSettle();
    }
    final r = t.getRect(find.byKey(const ValueKey('i10')));
    expect(r.center.dx, closeTo(1920 / 2, 1.5));
  });

  testWidgets('TvRow : restauration à l\'index 30 sans itemExtent', (t) async {
    _size(t, tv);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(focusMemoryProvider.notifier)
        .remember('/', '30', row: 'big');
    final nodes = List.generate(40, (_) => FocusNode());
    await t.pumpWidget(
      _app(
        TvRow(
          title: 'Big',
          restorationId: 'big',
          items: [
            for (var i = 0; i < 40; i++)
              FocusableCard(
                focusNode: nodes[i],
                onSelect: () {},
                child: const SizedBox(width: 300, height: 170),
              ),
          ],
        ),
        container: container,
      ),
    );
    await t.pumpAndSettle();
    expect(nodes[30].hasFocus, isTrue);
  });

  testWidgets('TvScaffold : Échap et goBack déclenchent Retour (téléphone)', (
    t,
  ) async {
    _size(t, phone);
    var n = 0;
    await t.pumpWidget(
      MaterialApp(
        home: TvScaffold(
          onBack: () => n++,
          child: const Focus(autofocus: true, child: SizedBox()),
        ),
      ),
    );
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(n, 1);
    // goBack n'a pas de touche physique simulable : on vérifie le mappage.
    expect(
      tvShortcuts[const SingleActivator(LogicalKeyboardKey.goBack)],
      isA<BackIntent>(),
    );
  });
}
