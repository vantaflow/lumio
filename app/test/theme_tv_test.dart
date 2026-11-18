import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/ui/focus/tv_detection.dart';
import 'package:lumio/ui/theme.dart';

double _ratio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('contraste des jetons (>= 4,5:1)', () {
    for (final (name, c) in [
      ('sombre', LumioColors.dark),
      ('clair', LumioColors.light),
    ]) {
      test(name, () {
        final onBg = {
          'bg': c.bg,
          'bgAlt': c.bgAlt,
          'surface': c.surface,
          'surfaceRaised': c.surfaceRaised,
          'surfaceFocus': c.surfaceFocus,
        };
        for (final e in onBg.entries) {
          expect(
            _ratio(c.text, e.value),
            greaterThanOrEqualTo(4.5),
            reason: 'text sur ${e.key}',
          );
          expect(
            _ratio(c.textMuted, e.value),
            greaterThanOrEqualTo(4.5),
            reason: 'textMuted sur ${e.key}',
          );
        }
        for (final fg in {
          'accent': c.accent,
          'secondary': c.secondary,
          'error': c.error,
          'warning': c.warning,
          'success': c.success,
        }.entries) {
          expect(
            _ratio(fg.value, c.bg),
            greaterThanOrEqualTo(4.5),
            reason: '${fg.key} sur bg',
          );
          expect(
            _ratio(fg.value, c.surface),
            greaterThanOrEqualTo(4.5),
            reason: '${fg.key} sur surface',
          );
        }
        expect(_ratio(c.onAccent, c.accent), greaterThanOrEqualTo(4.5));
        // Anneau de focus : contraste d'objet graphique (>= 3:1).
        expect(_ratio(c.focusRing, c.bg), greaterThanOrEqualTo(3));
        expect(_ratio(c.focusRing, c.surface), greaterThanOrEqualTo(3));
      });
    }
  });

  group('échelle de texte', () {
    test('TV : tous les styles >= 24 sp', () {
      final t = LumioTheme.dark(tv: true).textTheme;
      for (final s in [
        t.displayLarge,
        t.headlineLarge,
        t.headlineMedium,
        t.headlineSmall,
        t.titleLarge,
        t.titleMedium,
        t.titleSmall,
        t.bodyLarge,
        t.bodyMedium,
        t.bodySmall,
        t.labelLarge,
        t.labelMedium,
        t.labelSmall,
      ]) {
        expect(s!.fontSize, greaterThanOrEqualTo(24));
      }
      expect(t.bodyLarge!.fontSize, 30);
      expect(t.displayLarge!.fontSize, 72);
    });

    test('téléphone : échelle 16/12', () {
      final t = LumioTheme.dark().textTheme;
      expect(t.bodyLarge!.fontSize, 16);
      expect(t.bodySmall!.fontSize, 12);
    });

    testWidgets('LumioThemeScope : TV seulement si TV et largeur >= 960', (
      t,
    ) async {
      double? size;
      Widget app({required bool tv, required Size screen}) {
        t.view.physicalSize = screen;
        t.view.devicePixelRatio = 1;
        return MaterialApp(
          home: LumioThemeScope(
            tv: tv,
            child: Builder(
              builder: (c) {
                size = Theme.of(c).textTheme.bodyLarge!.fontSize;
                return const SizedBox();
              },
            ),
          ),
        );
      }

      addTearDown(t.view.reset);
      await t.pumpWidget(app(tv: true, screen: const Size(1920, 1080)));
      expect(size, 30);
      await t.pumpWidget(app(tv: true, screen: const Size(800, 600)));
      expect(size, 16);
      await t.pumpWidget(app(tv: false, screen: const Size(1920, 1080)));
      expect(size, 16);
    });

    testWidgets('« réduire les animations » : transitions et ondulations '
        'coupées pour toute l\'appli', (t) async {
      late ThemeData theme;
      await t.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: LumioThemeScope(
              tv: false,
              child: Builder(
                builder: (c) {
                  theme = Theme.of(c);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      expect(theme.splashFactory, NoSplash.splashFactory);
      final b = theme.pageTransitionsTheme.builders[TargetPlatform.android]!;
      expect(b.runtimeType.toString(), '_NoTransitionsBuilder');
    });
  });

  group('polices embarquées', () {
    test('pubspec, fichiers et licences OFL présents', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('family: Bricolage Grotesque'));
      expect(pubspec, contains('family: Manrope'));
      for (final f in [
        'BricolageGrotesque-Variable.ttf',
        'Manrope-Variable.ttf',
        'BricolageGrotesque-OFL.txt',
        'Manrope-OFL.txt',
      ]) {
        expect(File('assets/fonts/$f').existsSync(), isTrue, reason: f);
      }
      expect(
        File('assets/fonts/Manrope-OFL.txt').readAsStringSync(),
        contains('SIL OPEN FONT LICENSE'),
      );
    });

    test('le thème utilise les deux familles', () {
      final t = LumioTheme.dark().textTheme;
      expect(t.displayLarge!.fontFamily, 'Bricolage Grotesque');
      expect(t.bodyLarge!.fontFamily, 'Manrope');
    });
  });

  group('détection Android TV', () {
    test('leanback présent -> TV', () async {
      expect(
        await detectAndroidTv(
          isAndroid: true,
          features: () async => [
            'android.hardware.touchscreen',
            leanbackFeature,
          ],
        ),
        isTrue,
      );
    });

    test('tablette tactile sans leanback -> pas une TV', () async {
      expect(
        await detectAndroidTv(
          isAndroid: true,
          features: () async => ['android.hardware.touchscreen'],
        ),
        isFalse,
      );
    });

    test('hors Android -> faux, sans lire les fonctionnalités', () async {
      var read = false;
      expect(
        await detectAndroidTv(
          isAndroid: false,
          features: () async {
            read = true;
            return [leanbackFeature];
          },
        ),
        isFalse,
      );
      expect(read, isFalse);
    });

    test('échec de lecture -> faux et journalisé', () async {
      final logs = <String?>[];
      final old = debugPrint;
      debugPrint = (m, {wrapWidth}) => logs.add(m);
      addTearDown(() => debugPrint = old);
      expect(
        await detectAndroidTv(
          isAndroid: true,
          features: () async => throw StateError('plugin absent'),
        ),
        isFalse,
      );
      expect(logs.single, contains('StateError'));
    });

    test('lecture bloquée -> délai dépassé, faux et journalisé', () async {
      final logs = <String?>[];
      final old = debugPrint;
      debugPrint = (m, {wrapWidth}) => logs.add(m);
      addTearDown(() => debugPrint = old);
      expect(
        await detectAndroidTv(
          isAndroid: true,
          timeout: const Duration(milliseconds: 50),
          features: () => Completer<List<String>>().future,
        ),
        isFalse,
      );
      expect(logs.single, contains('TimeoutException'));
    });
  });
}
