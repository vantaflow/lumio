import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/features/home/tv_cards.dart';
import 'package:lumio/l10n/app_localizations.dart';
import 'package:lumio/ui/theme.dart';

Widget _host({Uri? poster, Uri? background}) => MaterialApp(
  theme: LumioTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('fr'),
  home: Scaffold(
    body: TvHero(
      eyebrow: 'REPRENDRE',
      title: 'Titre',
      poster: poster,
      background: background,
      onResume: () {},
    ),
  ),
);

void main() {
  const backdrop = ValueKey('hero-poster-backdrop');
  testWidgets('affiche seule : posée à taille d\'origine sur fond flouté', (
    t,
  ) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _host(poster: Uri.parse('https://img.example.com/p.jpg')),
    );
    expect(find.byKey(backdrop), findsOneWidget);
  });

  testWidgets('fond d\'addon présent : préféré à l\'affiche', (t) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _host(
        poster: Uri.parse('https://img.example.com/p.jpg'),
        background: Uri.parse('https://img.example.com/bg.jpg'),
      ),
    );
    expect(find.byKey(backdrop), findsNothing);
  });

  testWidgets('sans image : dégradé, pas de fond d\'affiche', (t) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host());
    expect(find.byKey(backdrop), findsNothing);
  });
}
