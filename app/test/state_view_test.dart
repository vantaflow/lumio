import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/ui/common/state_view.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('erreur : message et bouton Réessayer appelle onRetry', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _wrap(StateView.error(message: 'X', onRetry: () => calls++)),
    );
    expect(find.text('X'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    expect(calls, 1);
  });

  testWidgets('vide : message seul, sans action', (tester) async {
    await tester.pumpWidget(_wrap(const StateView.empty(message: 'Rien ici')));
    expect(find.text('Rien ici'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('vide : action optionnelle', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _wrap(
        StateView.empty(
          message: 'Rien ici',
          actionLabel: 'Ajouter',
          onAction: () => calls++,
        ),
      ),
    );
    await tester.tap(find.text('Ajouter'));
    expect(calls, 1);
  });

  testWidgets('chargement : indicateur de progression', (tester) async {
    await tester.pumpWidget(_wrap(const StateView.loading()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
