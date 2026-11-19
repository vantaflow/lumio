import 'package:flutter/material.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/icons/lumio_icons.dart';
import 'package:lumio/ui/theme.dart';

/// Marge de sécurité TV des maquettes (docs/design/maquettes) : 96 dp de
/// chaque côté, en-tête de 152 dp ; évite le surbalayage des téléviseurs.
const double tvMargin = 96;
const double tvHeaderHeight = 152;

/// Marge latérale : 96 dp sur grand écran, 16 dp sur téléphone (< 720 dp).
double tvMarginOf(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 720 ? 16 : tvMargin;

/// Écran secondaire TV : en-tête (bouton Retour rond de 72, titre 56,
/// sous-titre 24, actions à droite) puis contenu dans les marges de sécurité.
class TvScreen extends StatelessWidget {
  const TvScreen({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.onBack,
    this.padding,
    this.showBack = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;
  final VoidCallback? onBack;
  final EdgeInsetsGeometry? padding;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.lumio;
    final m = tvMarginOf(context);
    return TvScaffold(
      onBack: onBack,
      child: Scaffold(
        body: Column(
          children: [
            SizedBox(
              height: tvHeaderHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: m),
                child: Row(
                  children: [
                    if (showBack) ...[
                      TvBackButton(onPressed: onBack),
                      const SizedBox(width: 28),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.headlineLarge?.copyWith(
                                fontSize: 56,
                                height: 1.1,
                              ),
                            ),
                          ),
                          if (subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodySmall?.copyWith(
                                  fontSize: 24,
                                  color: c.textMuted,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (final a in actions) ...[
                      const SizedBox(width: 24),
                      Flexible(child: a),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: padding ?? EdgeInsets.fromLTRB(m, 0, m, 48),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton Retour rond (72 dp) des en-têtes d'écran.
class TvBackButton extends StatelessWidget {
  const TvBackButton({super.key, this.onPressed, this.autofocus = false});

  final VoidCallback? onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    return FocusableCard(
      key: const ValueKey('tv-back'),
      autofocus: autofocus,
      scale: 1.06,
      borderRadius: BorderRadius.circular(36),
      semanticLabel: context.l10n.back,
      onSelect: onPressed ?? () => Navigator.of(context).maybePop(),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: c.surface),
        child: LumioIconView(LumioIcon.back, size: 36, color: c.text),
      ),
    );
  }
}

/// Étiquette de section turquoise en capitales (maquettes `.sec`).
class TvSectionLabel extends StatelessWidget {
  const TvSectionLabel(this.text, {super.key, this.top = 28});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top, bottom: 14),
    child: Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 26,
          fontWeight: FontWeight.w700,
          fontVariations: const [FontVariation.weight(700)],
          letterSpacing: 1,
          color: context.lumio.secondary,
        ),
      ),
    ),
  );
}

/// Ligne focalisable (maquettes `.row`) : fond #161B22, rayon 22, marge 32.
class TvTile extends StatelessWidget {
  const TvTile({
    super.key,
    required this.child,
    required this.onSelect,
    this.onLongPress,
    this.minHeight = 104,
    this.autofocus = false,
    this.focusNode,
    this.onFocusChange,
    this.semanticLabel,
    this.color,
    this.enabled = true,
    this.horizontalPadding = 32,
  });

  final double horizontalPadding;
  final Widget child;
  final VoidCallback? onSelect;
  final VoidCallback? onLongPress;
  final double minHeight;
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange;
  final String? semanticLabel;
  final Color? color;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    return FocusableCard(
      autofocus: autofocus,
      focusNode: focusNode,
      scale: 1.015,
      enabled: enabled && onSelect != null,
      borderRadius: BorderRadius.circular(22),
      semanticLabel: semanticLabel,
      onSelect: onSelect ?? () {},
      onLongPress: onLongPress,
      onFocusChange: onFocusChange,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: color ?? c.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: child,
      ),
    );
  }
}

/// Titre + description d'une ligne (30 gras + 24 atténué).
class TvTileText extends StatelessWidget {
  const TvTileText({
    super.key,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.maxLines = 1,
  });

  final String title;
  final String? subtitle;
  final Color? titleColor;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    final t = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: t.titleMedium?.copyWith(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            fontVariations: const [FontVariation.weight(700)],
            color: titleColor ?? c.text,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.bodySmall?.copyWith(fontSize: 24, color: c.textMuted),
          ),
      ],
    );
  }
}

/// Interrupteur des maquettes (84 x 46) : ambre allumé, #3A4452 éteint.
class TvSwitch extends StatelessWidget {
  const TvSwitch({super.key, required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    return AnimatedContainer(
      duration: LumioMotion.focus,
      width: 84,
      height: 46,
      decoration: BoxDecoration(
        color: value ? c.accent : c.outline,
        borderRadius: BorderRadius.circular(23),
      ),
      child: AnimatedAlign(
        duration: LumioMotion.focus,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(shape: BoxShape.circle, color: c.text),
        ),
      ),
    );
  }
}

/// Ligne à interrupteur : OK bascule.
class TvSwitchTile extends StatelessWidget {
  const TvSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.subtitleColor,
    this.subtitleKey,
    this.autofocus = false,
    this.onFocusChange,
    this.color,
    this.minHeight = 104,
  });

  final double minHeight;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final Key? subtitleKey;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    final t = Theme.of(context).textTheme;
    return Semantics(
      toggled: value,
      child: TvTile(
        autofocus: autofocus,
        minHeight: minHeight,
        color: color ?? c.surfaceFocus,
        onFocusChange: onFocusChange,
        semanticLabel: title,
        onSelect: onChanged == null ? null : () => onChanged!(!value),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: t.titleMedium?.copyWith(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      fontVariations: const [FontVariation.weight(700)],
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      key: subtitleKey,
                      style: t.bodySmall?.copyWith(
                        fontSize: 24,
                        color: subtitleColor ?? c.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            TvSwitch(value: value),
          ],
        ),
      ),
    );
  }
}

/// Bouton rond d'icône (72) des lignes d'actions (monter, descendre…).
class TvIconButton extends StatelessWidget {
  const TvIconButton({
    super.key,
    this.icon,
    this.lumioIcon,
    this.iconColor,
    this.background,
    required this.label,
    required this.onPressed,
    this.size = 72,
  });

  final IconData? icon;

  /// Icône SVG des maquettes (prioritaire sur [icon]).
  final LumioIcon? lumioIcon;
  final Color? iconColor;

  /// Fond du rond (par défaut #2A3340 ; #0E1116 dans les lignes).
  final Color? background;
  final String label;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    return Opacity(
      opacity: onPressed == null ? 0.35 : 1,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: FocusableCard(
          enabled: onPressed != null,
          scale: 1.06,
          borderRadius: BorderRadius.circular(size / 2),
          semanticLabel: label,
          onSelect: onPressed ?? () {},
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: background ?? c.surfaceFocus,
            ),
            child: lumioIcon != null
                ? LumioIconView(
                    lumioIcon!,
                    size: size * 0.45,
                    color: iconColor ?? c.text,
                  )
                : Icon(icon, size: size * 0.5, color: iconColor ?? c.text),
          ),
        ),
      ),
    );
  }
}
