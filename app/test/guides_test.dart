import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/features/settings/help_screen.dart';
import 'package:lumio/l10n/app_localizations.dart';
import 'package:lumio/ui/common/tv_guide.dart';
import 'package:lumio/ui/theme.dart';

Widget _app(Widget home, {Locale locale = const Locale('fr')}) => ProviderScope(
  child: MaterialApp(
    theme: LumioTheme.dark(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    home: home,
  ),
);

void main() {
  void tv(WidgetTester t) {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  testWidgets('page Aide : six guides, OK ouvre les étapes, Compris ferme', (
    t,
  ) async {
    tv(t);
    await t.pumpWidget(_app(const HelpScreen()));
    await t.pump();
    for (final id in [
      'addons',
      'setting',
      'portal',
      'trakt',
      'profiles',
      'subs',
    ]) {
      expect(find.byKey(ValueKey('help:$id')), findsOneWidget, reason: id);
    }
    await t.tap(find.byKey(const ValueKey('help:trakt')));
    await t.pumpAndSettle();
    expect(find.text('trakt.tv/activate', findRichText: true), findsNothing);
    expect(find.textContaining('trakt.tv/activate'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('guide-ok')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('guide-ok')), findsNothing);
  });

  testWidgets('guides en anglais', (t) async {
    tv(t);
    await t.pumpWidget(_app(const HelpScreen(), locale: const Locale('en')));
    await t.pump();
    expect(find.text('Help'), findsWidgets);
    expect(find.text('Set up an addon'), findsOneWidget);
  });

  testWidgets('encadré : titre, étapes numérotées et note', (t) async {
    tv(t);
    await t.pumpWidget(
      _app(
        const Scaffold(
          body: TvGuideBox(
            title: 'Sur votre téléphone',
            steps: ['A', 'B', 'C'],
            note: 'Note',
          ),
        ),
      ),
    );
    expect(find.text('Sur votre téléphone'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
  });
}
