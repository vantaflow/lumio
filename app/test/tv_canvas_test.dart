import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/features/home/home_screen.dart';
import 'package:lumio/ui/focus/tv_canvas.dart';

import 'support/app_harness.dart';

void main() {
  testWidgets('TvCanvas : écran 960x540 logiques (dpr 2) = canevas 1920x1080', (
    t,
  ) async {
    t.view.devicePixelRatio = 2;
    t.view.physicalSize = const Size(1920, 1080);
    addTearDown(t.view.reset);
    Size? seen;
    double? dpr;
    await t.pumpWidget(
      MaterialApp(
        home: TvCanvas(
          child: Builder(
            builder: (c) {
              seen = MediaQuery.sizeOf(c);
              dpr = MediaQuery.devicePixelRatioOf(c);
              return const Align(
                alignment: Alignment.topLeft,
                child: SizedBox(key: ValueKey('box'), width: 192, height: 108),
              );
            },
          ),
        ),
      ),
    );
    expect(seen, const Size(1920, 1080));
    expect(dpr, closeTo(1, 0.001));
    // 192 px de maquette occupent 96 px logiques réels.
    expect(t.getSize(find.byKey(const ValueKey('box'))).width, 192);
    expect(
      t.getRect(find.byKey(const ValueKey('box'))).width,
      closeTo(96, 0.01),
    );
  });

  testWidgets(
    'accueil TV : une seule ligne de navigation hors maquette exclue',
    (t) async {
      final h = AppHarness(t);
      await h.pump(const HomeScreen(tvLayout: true));
      for (final label in [
        'Accueil',
        'Films',
        'Séries',
        'Recherche',
        'Réglages',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      for (final gone in ['Gérer ma liste', 'Calendrier', 'Personnaliser']) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      // Les fonctions retirées de la barre restent derrière l'avatar.
      await t.tap(find.byKey(const ValueKey('home-avatar')));
      await h.settle();
      for (final label in ['Gérer ma liste', 'Calendrier', 'Personnaliser']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await h.close();
    },
  );
}
