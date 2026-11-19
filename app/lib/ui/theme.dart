import 'package:flutter/material.dart';

/// Jetons de design Lumio (source : docs/design/tokens.json).
///
/// Sombre d'abord ; le clair sert au téléphone et au bureau. Les tailles de
/// texte existent en deux échelles : téléphone/bureau et TV (canevas
/// 1920x1080, texte >= 24 sp), voir [LumioTheme.dark] paramètre `tv`.
class LumioColors extends ThemeExtension<LumioColors> {
  const LumioColors({
    required this.bg,
    required this.bgAlt,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceFocus,
    required this.outline,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.secondary,
    required this.focusRing,
    required this.success,
    required this.warning,
    required this.error,
  });

  final Color bg;
  final Color bgAlt;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceFocus;
  final Color outline;
  final Color text;
  final Color textMuted;
  final Color accent;
  final Color onAccent;
  final Color secondary;
  final Color focusRing;
  final Color success;
  final Color warning;
  final Color error;

  static const dark = LumioColors(
    bg: Color(0xFF0E1116),
    bgAlt: Color(0xFF12171E),
    surface: Color(0xFF161B22),
    surfaceRaised: Color(0xFF1F2630),
    surfaceFocus: Color(0xFF2A3340),
    outline: Color(0xFF3A4452),
    text: Color(0xFFF3F5F7),
    textMuted: Color(0xFFA9B2BF),
    accent: Color(0xFFFFB84D),
    onAccent: Color(0xFF1A1100),
    secondary: Color(0xFF4FD1C5),
    focusRing: Color(0xFFFFE08A),
    success: Color(0xFF5BD68A),
    warning: Color(0xFFFFB84D),
    error: Color(0xFFFF7A70),
  );

  static const light = LumioColors(
    bg: Color(0xFFF7F5F0),
    bgAlt: Color(0xFFEFECE4),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF1EEE7),
    surfaceFocus: Color(0xFFE4E0D5),
    outline: Color(0xFFB9B3A4),
    text: Color(0xFF14171C),
    textMuted: Color(0xFF4A5361),
    accent: Color(0xFFA85500),
    onAccent: Color(0xFFFFFFFF),
    secondary: Color(0xFF00796B),
    focusRing: Color(0xFF0B57D0),
    success: Color(0xFF1B7F44),
    warning: Color(0xFF8A5A00),
    error: Color(0xFFB3261E),
  );

  @override
  LumioColors copyWith() => this;

  @override
  LumioColors lerp(ThemeExtension<LumioColors>? other, double t) =>
      t < 0.5 || other is! LumioColors ? this : other;
}

/// Espacements (dp).
abstract final class LumioSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 40.0;
  static const xxl = 64.0;
}

/// Rayons (dp).
abstract final class LumioRadius {
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const pill = 999.0;
}

/// Anneau de focus : trait 4, écart 4, couleur `focusRing`.
const double lumioFocusWidth = 4;
const double lumioFocusOffset = 4;

/// Durées de mouvement ; toutes à zéro avec « réduire les animations ».
abstract final class LumioMotion {
  static const focus = Duration(milliseconds: 120);
  static const scaleCard = Duration(milliseconds: 160);
  static const panel = Duration(milliseconds: 220);
  static const screen = Duration(milliseconds: 280);
}

/// Hauteur supplémentaire due à l'échelle de texte TV : [titleLines] lignes de
/// titre et [captionLines] de légende, par rapport à l'échelle téléphone
/// (16 sp x 1,4 et 12 sp x 1,3).
double lumioTextGrowth(BuildContext context, int titleLines, int captionLines) {
  final t = Theme.of(context).textTheme;
  double line(TextStyle? s) => (s?.fontSize ?? 16) * (s?.height ?? 1.4);
  final grown =
      titleLines * line(t.titleMedium) + captionLines * line(t.bodySmall);
  final base = titleLines * 16 * 1.4 + captionLines * 12 * 1.3;
  return grown > base ? grown - base : 0;
}

/// Cibles tactiles minimales (dp).
const double lumioTouchMin = 48;

const _fontDisplay = 'Bricolage Grotesque';
const _fontBody = 'Manrope';

abstract final class LumioTheme {
  /// Largeur logique minimale pour appliquer l'échelle TV (avec `tv`).
  static const tvMinWidth = 960.0;

  static ThemeData dark({bool tv = false}) =>
      _build(LumioColors.dark, Brightness.dark, tv);
  static ThemeData light({bool tv = false}) =>
      _build(LumioColors.light, Brightness.light, tv);

  static ThemeData _build(LumioColors c, Brightness b, bool tv) {
    // Échelle de texte : (téléphone, TV) d'après docs/design/README.md.
    double sz(double phone, double tvSize) => tv ? tvSize : phone;
    final scheme = ColorScheme(
      brightness: b,
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.secondary,
      onSecondary: c.onAccent,
      error: c.error,
      onError: c.onAccent,
      surface: c.surface,
      onSurface: c.text,
      onSurfaceVariant: c.textMuted,
      outline: c.outline,
      outlineVariant: c.outline,
      surfaceContainerHighest: c.surfaceRaised,
      surfaceContainerHigh: c.surfaceRaised,
      surfaceContainer: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainerLowest: c.bg,
      inverseSurface: c.text,
      onInverseSurface: c.bg,
      inversePrimary: c.accent,
    );

    TextStyle display(double size, double h) => TextStyle(
      fontFamily: _fontDisplay,
      fontSize: size,
      fontWeight: FontWeight.w700,
      fontVariations: const [FontVariation.weight(700)],
      height: h,
      // Les maquettes HTML n'ont aucun interlettrage ; sans cela le thème
      // Material 3 en ajoute (+0,25 à +0,5) et le texte est plus large.
      letterSpacing: 0,
      color: c.text,
    );
    TextStyle body(double size, double h, [FontWeight w = FontWeight.w400]) =>
        TextStyle(
          fontFamily: _fontBody,
          fontSize: size,
          fontWeight: w,
          fontVariations: [FontVariation.weight(w.value.toDouble())],
          height: h,
          letterSpacing: 0,
          color: c.text,
        );

    // docs/design/README.md : display 72/32, h1 64/28, h2 44/20, title 34/18,
    // body 30/16, label 28/14, caption (minimum) 24/12.
    final display0 = sz(32, 72);
    final h1 = sz(28, 64);
    final h2 = sz(20, 44);
    final title = sz(18, 34);
    final bodySz = sz(16, 30);
    final label = sz(14, 28);
    final caption = sz(12, 24);
    final textTheme = TextTheme(
      displayLarge: display(display0, 1.15),
      displayMedium: display(display0, 1.15),
      displaySmall: display(display0, 1.15),
      headlineLarge: display(h1, 1.15),
      headlineMedium: display(h2, 1.2),
      headlineSmall: display(h2, 1.2),
      titleLarge: display(title, 1.25),
      titleMedium: body(bodySz, 1.4, FontWeight.w600),
      titleSmall: body(label, 1.3, FontWeight.w600),
      bodyLarge: body(bodySz, 1.4),
      bodyMedium: body(bodySz, 1.4),
      bodySmall: body(
        caption,
        1.3,
        FontWeight.w600,
      ).copyWith(color: c.textMuted),
      labelLarge: body(label, 1.3, FontWeight.w600),
      labelMedium: body(label, 1.3, FontWeight.w600),
      labelSmall: body(caption, 1.3, FontWeight.w600),
    );

    // Anneau de focus visible sur tout bouton, y compris à la télécommande.
    final focusSide = WidgetStateProperty.resolveWith<BorderSide?>(
      (s) => s.contains(WidgetState.focused)
          ? BorderSide(color: c.focusRing, width: lumioFocusWidth)
          : null,
    );
    // TV : boutons des maquettes (hauteur 76, marges 40, texte 28 gras).
    final minSize = tv
        ? const Size(88, 76)
        : const Size(lumioTouchMin, lumioTouchMin);
    final btnPad = WidgetStatePropertyAll<EdgeInsetsGeometry?>(
      tv ? const EdgeInsets.symmetric(horizontal: 40, vertical: 12) : null,
    );
    final btnText = WidgetStatePropertyAll<TextStyle?>(
      tv ? body(label, 1.2, FontWeight.w700) : null,
    );
    const pill = StadiumBorder();

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      textTheme: textTheme,
      focusColor: c.surfaceFocus,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: display(h2, 1.2),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LumioRadius.lg),
          side: BorderSide(color: c.outline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LumioRadius.xl),
        ),
        titleTextStyle: display(h2, 1.2),
        contentTextStyle: body(bodySz, 1.4),
        barrierColor: const Color(0xC206080C),
        insetPadding: tv
            ? const EdgeInsets.symmetric(horizontal: 96, vertical: 48)
            : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        actionsPadding: tv
            ? const EdgeInsets.fromLTRB(36, 8, 36, 32)
            : const EdgeInsets.fromLTRB(24, 0, 24, 16),
      ),
      dividerTheme: DividerThemeData(color: c.outline, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          padding: btnPad,
          textStyle: btnText,
          minimumSize: WidgetStatePropertyAll(minSize),
          shape: const WidgetStatePropertyAll(pill),
          backgroundColor: WidgetStatePropertyAll(c.accent),
          foregroundColor: WidgetStatePropertyAll(c.onAccent),
          side: focusSide,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          padding: btnPad,
          textStyle: btnText,
          minimumSize: WidgetStatePropertyAll(minSize),
          shape: const WidgetStatePropertyAll(pill),
          backgroundColor: WidgetStatePropertyAll(c.surfaceFocus),
          foregroundColor: WidgetStatePropertyAll(c.text),
          side: focusSide,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          padding: btnPad,
          textStyle: btnText,
          minimumSize: WidgetStatePropertyAll(minSize),
          shape: const WidgetStatePropertyAll(pill),
          backgroundColor: tv ? WidgetStatePropertyAll(c.surfaceFocus) : null,
          foregroundColor: WidgetStatePropertyAll(c.text),
          side: focusSide,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(minSize),
          foregroundColor: WidgetStatePropertyAll(c.text),
          side: focusSide,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onAccent : c.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.surfaceFocus,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.focused) ? c.focusRing : c.outline,
        ),
        trackOutlineWidth: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.focused) ? lumioFocusWidth : 1,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: body(bodySz, 1.4).copyWith(color: c.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LumioRadius.md),
          borderSide: BorderSide(color: c.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LumioRadius.md),
          borderSide: BorderSide(color: c.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LumioRadius.md),
          borderSide: BorderSide(color: c.focusRing, width: lumioFocusWidth),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LumioRadius.md),
          borderSide: BorderSide(color: c.error),
        ),
      ),
      listTileTheme: ListTileThemeData(
        selectedColor: c.accent,
        iconColor: c.textMuted,
        textColor: c.text,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceFocus,
        contentTextStyle: body(bodySz, 1.4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

extension LumioColorsContext on BuildContext {
  /// Jetons de couleur du thème courant.
  LumioColors get lumio =>
      Theme.of(this).extension<LumioColors>() ?? LumioColors.dark;
}

class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// Applique le thème adapté à l'écran : échelle TV (texte >= 24 sp) si
/// l'appareil est une TV et la largeur >= [LumioTheme.tvMinWidth] ; aucune
/// animation de transition ni d'ondulation avec « réduire les animations »
/// (`MediaQuery.disableAnimations`), pour toute l'application.
class LumioThemeScope extends StatelessWidget {
  const LumioThemeScope({super.key, required this.tv, required this.child});

  final bool tv;
  final Widget child;

  static final _phone = LumioTheme.dark();
  static final _tv = LumioTheme.dark(tv: true);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    var theme = tv && mq.size.width >= LumioTheme.tvMinWidth ? _tv : _phone;
    if (mq.disableAnimations) {
      theme = theme.copyWith(
        splashFactory: NoSplash.splashFactory,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _NoTransitionsBuilder(),
            TargetPlatform.iOS: _NoTransitionsBuilder(),
            TargetPlatform.macOS: _NoTransitionsBuilder(),
            TargetPlatform.windows: _NoTransitionsBuilder(),
            TargetPlatform.linux: _NoTransitionsBuilder(),
            TargetPlatform.fuchsia: _NoTransitionsBuilder(),
          },
        ),
      );
    }
    return Theme(data: theme, child: child);
  }
}

extension LumioTextStyleWeight on TextStyle {
  /// Change la graisse en tenant compte des polices variables (le thème fixe
  /// aussi l'axe `wght`, qu'un simple `fontWeight` ne modifie pas).
  TextStyle weighted(FontWeight w) => copyWith(
    fontWeight: w,
    fontVariations: [FontVariation.weight(w.value.toDouble())],
  );
}
