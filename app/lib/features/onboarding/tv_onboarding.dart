import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:lumio/features/home/tv_home.dart' show LumioMark;
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/theme.dart';

/// Pastilles « Étape n sur N » des maquettes TV (la courante est un trait
/// ambre de 48 dp).
class TvStepDots extends StatelessWidget {
  const TvStepDots({
    super.key,
    required this.step,
    required this.total,
    required this.label,
  });

  final int step;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++) ...[
          Container(
            width: i == step ? 48 : 16,
            height: 16,
            decoration: BoxDecoration(
              color: i == step ? c.accent : c.outline,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 16),
        ],
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontSize: 26, color: c.textMuted),
        ),
      ],
    );
  }
}

/// Panneau gauche de la première étape (maquette Main) : logo, accroche, étape.
class TvOnboardingBrandPanel extends StatelessWidget {
  const TvOnboardingBrandPanel({
    super.key,
    required this.title,
    required this.body,
    required this.dots,
  });

  final String title;
  final String body;
  final Widget dots;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: 760,
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 96),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.5, -1),
          end: Alignment(0.4, 0.7),
          colors: [Color(0xFF1B2A33), Color(0xFF0E1116)],
          stops: [0, 0.7],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const LumioMark(size: 72),
              const SizedBox(width: 20),
              Text('Lumio', style: t.displayLarge?.copyWith(fontSize: 56)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colonne de 600 : « bibliothèque, vos » tient à 0,3 px près dans
              // la maquette, on laisse 4 px de tolérance de mesure.
              OverflowBox(
                maxWidth: 604,
                alignment: AlignmentDirectional.topStart,
                fit: OverflowBoxFit.deferToChild,
                child: Text(
                  title,
                  style: t.displayLarge?.copyWith(fontSize: 72, height: 1.05),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                body,
                style: t.bodyLarge?.copyWith(
                  fontSize: 30,
                  height: 1.4,
                  color: context.lumio.textMuted,
                ),
              ),
              // Maquette : le <p> garde sa marge basse par défaut (1 em = 30).
              const SizedBox(height: 30),
            ],
          ),
          dots,
        ],
      ),
    );
  }
}

/// Ligne de choix (langue) : 96 dp de haut, fond `surface`, focus = anneau +
/// fond relevé + échelle 1,04.
class TvChoiceRow extends StatefulWidget {
  const TvChoiceRow({
    super.key,
    required this.label,
    required this.onSelect,
    this.trailing,
    this.selected = false,
    this.autofocus = false,
  });

  final String label;
  final String? trailing;
  final bool selected;
  final bool autofocus;
  final VoidCallback onSelect;

  @override
  State<TvChoiceRow> createState() => _TvChoiceRowState();
}

class _TvChoiceRowState extends State<TvChoiceRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    final t = Theme.of(context).textTheme;
    return FocusableCard(
      autofocus: widget.autofocus,
      scale: 1.04,
      borderRadius: BorderRadius.circular(20),
      semanticLabel: widget.label,
      onSelect: widget.onSelect,
      onFocusChange: (f) => setState(() => _focused = f),
      child: Container(
        height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 36),
        decoration: BoxDecoration(
          color: _focused ? c.surfaceFocus : c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.selected && !_focused ? c.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: t.bodyLarge
                    ?.weighted(FontWeight.w600)
                    .copyWith(fontSize: 32),
              ),
            ),
            if (widget.trailing != null)
              Text(
                widget.trailing!,
                style: t.bodyLarge?.copyWith(fontSize: 26, color: c.textMuted),
              )
            else if (widget.selected)
              Icon(Icons.check, color: c.accent, size: 36),
          ],
        ),
      ),
    );
  }
}

/// Carte de source de l'étape finale (maquette TV03) : 520 x 300.
class TvSourceCard extends StatefulWidget {
  const TvSourceCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onSelect,
    this.autofocus = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool autofocus;
  final VoidCallback onSelect;

  @override
  State<TvSourceCard> createState() => _TvSourceCardState();
}

class _TvSourceCardState extends State<TvSourceCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    final t = Theme.of(context).textTheme;
    return FocusableCard(
      autofocus: widget.autofocus,
      scale: 1.04,
      borderRadius: BorderRadius.circular(28),
      semanticLabel: widget.title,
      onSelect: widget.onSelect,
      onFocusChange: (f) => setState(() => _focused = f),
      child: Container(
        width: 520,
        height: 300,
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: _focused ? c.surfaceFocus : c.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.surfaceFocus,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(widget.icon, color: widget.iconColor, size: 40),
            ),
            const SizedBox(height: 12),
            Text(
              widget.title,
              style: t.bodyLarge
                  ?.weighted(FontWeight.w700)
                  .copyWith(fontSize: 34),
            ),
            const SizedBox(height: 12),
            Text(
              widget.subtitle,
              style: t.bodyLarge?.copyWith(
                fontSize: 26,
                height: 1.35,
                color: c.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
