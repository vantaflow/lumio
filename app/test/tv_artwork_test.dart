import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/features/home/tv_cards.dart';
import 'package:lumio/ui/theme.dart';

void main() {
  testWidgets('carte sans affiche : fond de surface et icône, titre lisible', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        theme: LumioTheme.dark(),
        home: Scaffold(
          body: Center(
            child: TvMediaCard(
              title: 'AAA on FOX',
              type: 'series',
              width: 230,
              height: 340,
              onSelect: () {},
            ),
          ),
        ),
      ),
    );
    final ph = find.byKey(const ValueKey('artwork-placeholder'));
    expect(ph, findsOneWidget);
    expect(t.getSize(ph), const Size(230, 340));
    final deco = t.widget<DecoratedBox>(ph).decoration as BoxDecoration;
    expect(deco.color, const Color(0xFF161B22));
    expect(find.text('AAA on FOX'), findsOneWidget);
  });
}
