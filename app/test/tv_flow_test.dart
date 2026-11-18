import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/features/home/home_screen.dart';
import 'package:lumio/features/search/search_screen.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';

import 'support/app_harness.dart';

/// Un « événement » de télécommande : appui + relâchement.
Future<void> _press(AppHarness h, LogicalKeyboardKey key) async {
  await h.t.sendKeyEvent(key);
  await h.settle(4);
}

void main() {
  testWidgets('TV : accueil -> fiche -> lecture en 2 événements Select', (
    t,
  ) async {
    final h = AppHarness(t);
    await h.pump(const HomeScreen());
    var events = 0;
    // 1. Select sur la première carte (focus d'emblée) : ouvre la fiche.
    await _press(h, LogicalKeyboardKey.select);
    events++;
    expect(find.text('Un court métrage libre de droits.'), findsOneWidget);
    // 2. Select sur le premier flux / « Lecture auto » (focus d'emblée).
    await _press(h, LogicalKeyboardKey.select);
    events++;
    expect(h.players, hasLength(1));
    expect(h.players.single.item.url.toString(), contains('tt1.mp4'));
    expect(events, lessThanOrEqualTo(4));
    await h.close();
  });

  testWidgets('TV, application complète : accueil -> fiche -> lecture en '
      '2 événements Select', (t) async {
    final h = AppHarness(t);
    await h.pumpApp();
    await _press(h, LogicalKeyboardKey.select);
    expect(find.text('Un court métrage libre de droits.'), findsOneWidget);
    await _press(h, LogicalKeyboardKey.select);
    expect(h.players, hasLength(1));
    await h.close();
  });

  testWidgets('TV : flèche droite puis Select ouvre le deuxième titre en '
      '3 événements', (t) async {
    final h = AppHarness(t);
    await h.pump(const HomeScreen());
    await _press(h, LogicalKeyboardKey.arrowRight);
    await _press(h, LogicalKeyboardKey.select);
    await _press(h, LogicalKeyboardKey.select);
    expect(h.players, hasLength(1));
    expect(h.players.single.item.url.toString(), contains('tt2.mp4'));
    await h.close();
  });

  group('mises en page adaptatives', () {
    testWidgets('TV 1920x1080 : disposition TV, clavier à l\'écran', (t) async {
      final h = AppHarness(t);
      await h.pump(const SearchScreen());
      late BuildContext ctx;
      ctx = t.element(find.byType(SearchScreen));
      expect(isTvLayout(ctx), isTrue);
      expect(find.byKey(const ValueKey('key-a')), findsOneWidget);
      await h.close();
    });

    testWidgets('tablette 1280x800 tactile : pas une TV, texte téléphone', (
      t,
    ) async {
      final h = AppHarness(t, size: const Size(1280, 800), tv: false);
      await h.pump(const SearchScreen());
      final ctx = t.element(find.byType(SearchScreen));
      expect(isTvLayout(ctx), isFalse);
      // Champ de saisie éditable (clavier du système), pas lecture seule.
      expect(t.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
      expect(Theme.of(ctx).textTheme.bodyLarge!.fontSize, 16);
      await h.close();
    });

    testWidgets('téléphone 400x800 : colonne unique sans débordement', (
      t,
    ) async {
      final h = AppHarness(t, size: const Size(400, 800), tv: false);
      await h.pump(const SearchScreen());
      expect(find.byKey(const ValueKey('key-a')), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      await h.close();
      final h2 = AppHarness(t, size: const Size(400, 800), tv: false);
      await h2.pump(const HomeScreen());
      expect(find.text('Big Buck Bunny'), findsWidgets);
      await h2.close();
    });

    testWidgets('tablette 1280x800 : accueil sans débordement', (t) async {
      final h = AppHarness(t, size: const Size(1280, 800), tv: false);
      await h.pump(const HomeScreen());
      expect(find.text('Big Buck Bunny'), findsWidgets);
      await h.close();
    });
  });
}
