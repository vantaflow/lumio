import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/ui/focus/focus_rescue.dart';
import 'package:lumio/ui/focus/focus_return.dart';

class _Host extends StatefulWidget {
  const _Host({required this.a, required this.b, required this.c});
  final FocusNode a;
  final FocusNode b;
  final FocusNode c;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool showB = true;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextButton(
          focusNode: widget.a,
          onPressed: () {},
          child: const Text('A'),
        ),
        if (showB)
          TextButton(
            focusNode: widget.b,
            onPressed: () {},
            child: const Text('B'),
          ),
        TextButton(
          focusNode: widget.c,
          onPressed: () {},
          child: const Text('C'),
        ),
      ],
    ),
  );
}

Future<void> _pump(WidgetTester t, FocusNode a, FocusNode b, FocusNode c) =>
    t.pumpWidget(
      MaterialApp(
        navigatorObservers: [FocusRescueObserver()],
        home: _Host(a: a, b: b, c: c),
      ),
    );

void main() {
  testWidgets('retour : l\'élément d\'origine reprend le focus même volé', (
    t,
  ) async {
    final a = FocusNode(), b = FocusNode(), c = FocusNode();
    addTearDown(() {
      a.dispose();
      b.dispose();
      c.dispose();
    });
    await _pump(t, a, b, c);
    b.requestFocus();
    await t.pump();
    final nav = t.state<NavigatorState>(find.byType(Navigator));
    nav.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('F'))),
    );
    await t.pumpAndSettle();
    nav.pop();
    // Un autre élément (onglet « Accueil ») prend le focus pendant le retour.
    await t.pump(const Duration(milliseconds: 60));
    a.requestFocus();
    await t.pump(const Duration(seconds: 1));
    expect(b.hasPrimaryFocus, isTrue);
  });

  testWidgets(
    'retour : élément d\'origine disparu, la zone mémorisée reprend',
    (t) async {
      final a = FocusNode(), b = FocusNode(), c = FocusNode();
      addTearDown(() {
        a.dispose();
        b.dispose();
        c.dispose();
      });
      final owner = Object();
      FocusReturn.register(owner, (route) {
        c.requestFocus();
        return true;
      });
      addTearDown(() => FocusReturn.unregister(owner));
      await _pump(t, a, b, c);
      b.requestFocus();
      await t.pump();
      final nav = t.state<NavigatorState>(find.byType(Navigator));
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('F')),
        ),
      );
      await t.pumpAndSettle();
      // L'élément d'origine n'est plus utilisable (reconstruit, remplacé).
      b.canRequestFocus = false;
      await t.pump(const Duration(milliseconds: 50));
      nav.pop();
      await t.pump(const Duration(seconds: 1));
      expect(c.hasPrimaryFocus, isTrue);
    },
  );
}
