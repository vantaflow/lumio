import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/ui/common/tv_screen.dart';
import 'package:lumio/ui/theme.dart';

void main() {
  testWidgets('en-tête : deux actions gardent leur largeur naturelle', (
    t,
  ) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: LumioTheme.dark(),
        home: TvScreen(
          title: 'Dossiers locaux',
          subtitle: 'Les vidéos stockées sur cet appareil',
          onBack: () {},
          actions: const [
            SizedBox(key: ValueKey('a1'), width: 72, height: 72),
            SizedBox(key: ValueKey('a2'), width: 440, height: 76),
          ],
          child: const SizedBox(),
        ),
      ),
    );
    // Avant : chaque action se partageait la place à parts égales (~306 px)
    // et la seconde était coupée.
    expect(t.getSize(find.byKey(const ValueKey('a2'))).width, 440);
    expect(t.getSize(find.byKey(const ValueKey('a1'))).width, 72);
  });
}
