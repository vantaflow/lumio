import 'package:flutter/material.dart';
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/theme.dart';

/// Style d'un [TvButton] (maquettes TV : docs/design/maquettes).
enum TvButtonKind {
  /// Ambre plein, texte foncé (action principale).
  primary,

  /// Gris soutenu (#2A3340), texte clair.
  secondary,

  /// Pastille de navigation : transparente, texte atténué.
  nav,

  /// Pastille de navigation de l'écran courant (ambre, maquette TV05).
  navSelected,

  /// Bouton texte (maquettes `.bt`) : transparent, texte #C9D0DA.
  ghost,
}

/// Bouton en pastille des écrans TV : mesures des maquettes (hauteur 88 par
/// défaut, texte 30-32), anneau de focus #FFE08A de 4 dp et léger
/// agrandissement via [FocusableCard].
class TvButton extends StatelessWidget {
  const TvButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = TvButtonKind.primary,
    this.height = 88,
    this.horizontalPadding = 48,
    this.fontSize = 32,
    this.autofocus = false,
    this.focusNode,
    this.icon,
    this.destructive = false,
    this.scale = 1.04,
    this.expand = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final TvButtonKind kind;
  final double height;
  final double horizontalPadding;
  final double fontSize;
  final bool autofocus;
  final FocusNode? focusNode;
  final Widget? icon;
  final bool destructive;
  final double scale;

  /// Occupe toute la largeur disponible (listes de boutons).
  final bool expand;

  /// Étiquette d'accessibilité si elle diffère du texte (ex. « − »).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    final (bg, fg, weight) = switch (kind) {
      TvButtonKind.primary => (c.accent, c.onAccent, FontWeight.w700),
      TvButtonKind.secondary => (c.surfaceFocus, c.text, FontWeight.w700),
      TvButtonKind.nav => (Colors.transparent, c.textMuted, FontWeight.w600),
      TvButtonKind.navSelected => (c.accent, c.onAccent, FontWeight.w700),
      TvButtonKind.ghost => (
        Colors.transparent,
        const Color(0xFFC9D0DA),
        FontWeight.w600,
      ),
    };
    final radius = BorderRadius.circular(height / 2);
    return FocusableCard(
      autofocus: autofocus,
      focusNode: focusNode,
      scale: scale,
      borderRadius: radius,
      semanticLabel: semanticLabel ?? label,
      enabled: onPressed != null,
      onSelect: onPressed ?? () {},
      child: Container(
        height: height,
        width: expand ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        decoration: BoxDecoration(color: bg, borderRadius: radius),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 12)],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: fontSize,
                  fontWeight: weight,
                  fontVariations: [
                    FontVariation.weight(weight.value.toDouble()),
                  ],
                  color: destructive ? c.error : fg,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pastille de navigation du haut (maquettes TV05/TV13) : 28 sp, 14 x 28.
class TvNavPill extends StatelessWidget {
  const TvNavPill({
    super.key,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.focusNode,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool selected;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => TvButton(
    label: label,
    onPressed: onPressed,
    focusNode: focusNode,
    autofocus: autofocus,
    kind: selected ? TvButtonKind.navSelected : TvButtonKind.nav,
    height: 60,
    horizontalPadding: 28,
    fontSize: 28,
    scale: 1.06,
  );
}
