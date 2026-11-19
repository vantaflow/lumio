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

/// Pastille de santé d'un addon (maquettes TV10, P12) : point de couleur puis
/// verdict en gras ; couleur ET texte (jamais la couleur seule), libellé
/// d'accessibilité complet.
class HealthPill extends StatelessWidget {
  const HealthPill({
    super.key,
    required this.health,
    this.showDetail = false,
    this.fontSize = 26,
  });

  final AddonHealth health;

  /// Ajoute « Médiane … · … % de réussite » après le verdict.
  final bool showDetail;
  final double fontSize;

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
    final label = healthLevelLabel(level, l);
    final detail = level == HealthLevel.unknown
        ? null
        : healthDetailLabel(health, l);
    final style = TextStyle(
      fontFamily: 'Manrope',
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      fontVariations: const [FontVariation.weight(700)],
      color: const Color(0xFFC9D0DA),
    );
    return Semantics(
      container: true,
      label: detail == null ? label : l.healthSemantic(label, detail),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          if (showDetail && detail != null) ...[
            Text(' · ', style: style),
            Flexible(
              flex: 3,
              child: Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
