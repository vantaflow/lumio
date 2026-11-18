import 'package:flutter/material.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

/// Libellé du verdict (« Fiable », « Lent (> 3 s) », « Défaillant »).
String healthLevelLabel(HealthLevel level, AppLocalizations l) =>
    switch (level) {
      HealthLevel.reliable => l.healthReliable,
      HealthLevel.slow => l.healthSlow,
      HealthLevel.failing => l.healthFailing,
      HealthLevel.unknown => l.healthUnknown,
    };

/// Latence lisible : « 420 ms » ou « 1,4 s ».
String latencyLabel(Duration d, String languageCode) {
  final ms = d.inMilliseconds;
  if (ms < 1000) return '$ms ms';
  final s = (ms / 1000).toStringAsFixed(1);
  return '${languageCode == 'fr' ? s.replaceAll('.', ',') : s} s';
}

/// « Médiane 420 ms · 96 % de réussite ».
String healthDetailLabel(AddonHealth h, AppLocalizations l) => l.healthDetail(
  latencyLabel(h.median, l.localeName),
  (h.successRate * 100).round(),
);

/// Pastille de santé d'un addon : couleur ET texte (jamais la couleur seule),
/// libellé d'accessibilité complet.
class HealthPill extends StatelessWidget {
  const HealthPill({super.key, required this.health, this.showDetail = false});

  final AddonHealth health;

  /// Ajoute « Médiane … · … % de réussite » après le verdict.
  final bool showDetail;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.lumio;
    final level = health.level;
    final color = switch (level) {
      HealthLevel.reliable => c.success,
      HealthLevel.slow => c.warning,
      HealthLevel.failing => c.error,
      HealthLevel.unknown => c.textMuted,
    };
    final icon = switch (level) {
      HealthLevel.reliable => Icons.check_circle,
      HealthLevel.slow => Icons.hourglass_bottom,
      HealthLevel.failing => Icons.error,
      HealthLevel.unknown => Icons.help_outline,
    };
    final label = healthLevelLabel(level, l);
    final detail = level == HealthLevel.unknown
        ? null
        : healthDetailLabel(health, l);
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: detail == null ? label : l.healthSemantic(label, detail),
      excludeSemantics: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: LumioSpacing.sm,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LumioSpacing.sm,
                vertical: 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showDetail && detail != null)
            Text(detail, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
