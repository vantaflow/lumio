import 'package:flutter/material.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/ui/common/tv_screen.dart';
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/theme.dart';

/// Voile des pop-ups (maquettes P09/P13 : rgba(6,8,12,.76)).
const Color tvScrim = Color(0xC206080C);

/// Panneau des pop-ups des maquettes : fond #161B22, rayon 32, marges 44 x 48,
/// titre 44. [width] vaut 760 par défaut ; le contenu défile s'il est long.
class TvPanel extends StatelessWidget {
  const TvPanel({
    super.key,
    required this.title,
    required this.children,
    this.width = 760,
    this.actions = const [],
    this.onBack,
  });

  final String title;
  final List<Widget> children;
  final List<Widget> actions;
  final double width;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    final t = Theme.of(context).textTheme;
    final h = MediaQuery.sizeOf(context).height;
    return TvScaffold(
      onBack: onBack,
      child: Center(
        child: Material(
          color: c.surface,
          elevation: 0,
          borderRadius: BorderRadius.circular(32),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: width,
              minWidth: width,
              maxHeight: h - 96,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 44),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: t.headlineMedium?.copyWith(
                        fontSize: 44,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Flexible(
                    child: SingleChildScrollView(
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      ),
                    ),
                  ),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: 16),
                          actions[i],
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Affiche [panel] sur le voile des maquettes.
Future<T?> showTvPanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: tvScrim,
  transitionDuration: const Duration(milliseconds: 120),
  pageBuilder: (ctx, _, _) => builder(ctx),
);

/// Sélecteur d'option (maquette P13) : une ligne par choix, le choix courant
/// est coché et reçoit le focus.
Future<T?> showTvChoice<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
  required T? current,
}) => showTvPanel<T>(
  context,
  builder: (ctx) => TvPanel(
    title: title,
    onBack: () => Navigator.of(ctx).pop(),
    children: [
      for (final (i, (value, label)) in options.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TvTile(
            key: ValueKey('choice:$label'),
            minHeight: 88,
            autofocus: value == current || (current == null && i == 0),
            color: ctx.lumio.surfaceRaised,
            semanticLabel: label,
            onSelect: () => Navigator.of(ctx).pop(value),
            child: Row(
              children: [
                Icon(
                  value == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 36,
                  color: value == current
                      ? ctx.lumio.accent
                      : ctx.lumio.textMuted,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  ),
);

/// Confirmation (maquette P09). Renvoie vrai si l'utilisateur confirme ;
/// le focus initial est sur « Annuler ».
Future<bool> showTvConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final ok = await showTvPanel<bool>(
    context,
    builder: (ctx) => TvPanel(
      title: title,
      width: 860,
      onBack: () => Navigator.of(ctx).pop(false),
      actions: [
        TvButton(
          autofocus: true,
          label: ctx.l10n.cancel,
          kind: TvButtonKind.secondary,
          height: 76,
          fontSize: 28,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        _ConfirmButton(
          label: confirmLabel,
          destructive: destructive,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
      children: [
        Text(
          body,
          style: Theme.of(
            ctx,
          ).textTheme.bodyLarge?.copyWith(fontSize: 30, color: ctx.lumio.text),
        ),
      ],
    ),
  );
  return ok ?? false;
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({
    required this.label,
    required this.destructive,
    required this.onPressed,
  });

  final String label;
  final bool destructive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    if (!destructive) {
      return TvButton(
        label: label,
        height: 76,
        fontSize: 28,
        onPressed: onPressed,
      );
    }
    // Maquette « .bd » : fond #FF7A70, texte #1A0A08.
    return FocusableCard(
      borderRadius: BorderRadius.circular(38),
      semanticLabel: label,
      onSelect: onPressed,
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.error,
          borderRadius: BorderRadius.circular(38),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            fontVariations: [FontVariation.weight(700)],
            color: Color(0xFF1A0A08),
          ),
        ),
      ),
    );
  }
}
