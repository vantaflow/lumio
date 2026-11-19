import 'package:flutter/material.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/ui/common/tv_dialogs.dart';
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/ui/theme.dart';

/// Étapes numérotées d'un guide (maquettes G01, G02, G04) : pastille ronde
/// et phrase courte, sans jargon.
class TvGuideSteps extends StatelessWidget {
  const TvGuideSteps({
    super.key,
    required this.steps,
    this.compact = false,
    this.gap,
  });

  final List<String> steps;

  /// Pastilles de 44 et texte de 27 (encadré d'un écran) au lieu de 60 / 30.
  final bool compact;
  final double? gap;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    final size = compact ? 44.0 : 60.0;
    final font = compact ? 27.0 : 30.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, s) in steps.indexed) ...[
          if (i > 0) SizedBox(height: gap ?? (compact ? 14 : 24)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surfaceFocus,
                  borderRadius: BorderRadius.circular(size / 2),
                ),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: compact ? 24 : 30,
                    fontWeight: FontWeight.w700,
                    fontVariations: const [FontVariation.weight(700)],
                    color: c.text,
                  ),
                ),
              ),
              SizedBox(width: compact ? 18 : 24),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: compact ? 4 : 8),
                  child: Text(
                    s,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: font,
                      height: 1.3,
                      color: c.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Encadré d'un écran : titre ambre puis étapes (maquettes G02 et G04).
class TvGuideBox extends StatelessWidget {
  const TvGuideBox({
    super.key,
    required this.title,
    required this.steps,
    this.note,
  });

  final String title;
  final List<String> steps;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.outline, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              fontVariations: const [FontVariation.weight(700)],
              color: c.accent,
            ),
          ),
          const SizedBox(height: 16),
          TvGuideSteps(steps: steps, compact: true),
          if (note != null) ...[
            const SizedBox(height: 16),
            Text(
              note!,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 24,
                height: 1.3,
                color: c.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Guide pas à pas en fenêtre (maquette G01) : titre, étapes, note facultative
/// et « Compris ».
Future<void> showTvGuide(
  BuildContext context, {
  required String title,
  required List<String> steps,
  String? note,
}) => showTvPanel<void>(
  context,
  builder: (ctx) => TvGuidePanel(
    title: title,
    steps: steps,
    note: note,
    onClose: () => Navigator.of(ctx).pop(),
  ),
);

/// Contenu de la fenêtre de guide.
class TvGuidePanel extends StatelessWidget {
  const TvGuidePanel({
    super.key,
    required this.title,
    required this.steps,
    required this.onClose,
    this.note,
  });

  final String title;
  final List<String> steps;
  final String? note;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return TvPanel(
      title: title,
      width: 960,
      titleSize: 48,
      fitActions: true,
      gap: 28,
      actionsGap: 24,
      onBack: onClose,
      actions: [
        TvButton(
          key: const ValueKey('guide-ok'),
          autofocus: true,
          label: l.guideGotIt,
          height: 76,
          fontSize: 28,
          horizontalPadding: 40,
          onPressed: onClose,
        ),
      ],
      children: [
        TvGuideSteps(steps: steps),
        if (note != null) ...[
          const SizedBox(height: 28),
          Text(
            note!,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 26,
              height: 1.35,
              color: context.lumio.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}
