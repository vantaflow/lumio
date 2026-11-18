import 'package:flutter/material.dart';
import 'package:lumio/data/stream_prefs.dart';
import 'package:lumio/ui/common/state_view.dart';
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

/// Seuil de sources à partir duquel un torrent est affiché en vert.
const healthySeeders = 50;

String qualityLabel(Quality q) => switch (q) {
  Quality.sd => 'SD',
  Quality.hd720 => '720p',
  Quality.hd1080 => '1080p',
  Quality.uhd2160 => '4K',
  Quality.unknown => '',
};

String sizeLabel(int bytes) {
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;
  if (bytes >= gb) {
    return '${(bytes / gb).toStringAsFixed(1).replaceAll('.', ',')} Go';
  }
  return '${(bytes / mb).round()} Mo';
}

/// Icône aimant (flux torrent) : un fer à cheval aux pôles marqués.
class MagnetIcon extends StatelessWidget {
  const MagnetIcon({super.key, this.size = 22, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Torrent',
    child: CustomPaint(
      size: Size.square(size),
      painter: _MagnetPainter(color ?? context.lumio.secondary),
    ),
  );
}

class _MagnetPainter extends CustomPainter {
  _MagnetPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.24
      ..strokeCap = StrokeCap.butt;
    final path = Path()
      ..moveTo(w * 0.2, w * 0.95)
      ..lineTo(w * 0.2, w * 0.45)
      ..arcToPoint(Offset(w * 0.8, w * 0.45), radius: Radius.circular(w * 0.3))
      ..lineTo(w * 0.8, w * 0.95);
    canvas.drawPath(path, stroke);
    final tip = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(w * 0.08, w * 0.76, w * 0.24, w * 0.12), tip);
    canvas.drawRect(Rect.fromLTWH(w * 0.68, w * 0.76, w * 0.24, w * 0.12), tip);
  }

  @override
  bool shouldRepaint(_MagnetPainter old) => old.color != color;
}

/// Liste des flux groupée par addon (story 1.4) : titre d'addon et santé,
/// puis une ligne par flux (qualité, langue, taille, sources ; aimant pour
/// un torrent). Le flux préféré du profil est signalé « Recommandé ».
class StreamsList extends StatelessWidget {
  const StreamsList({
    super.key,
    required this.groups,
    required this.addonNames,
    required this.loading,
    required this.prefs,
    required this.preferred,
    required this.onSelect,
  });

  final List<StreamGroup> groups;

  /// Nom affiché par identifiant de stockage d'addon.
  final Map<String, String> addonNames;
  final bool loading;
  final StreamPrefs prefs;
  final StreamItem? preferred;
  final void Function(StreamItem item) onSelect;

  @override
  Widget build(BuildContext context) {
    final lumio = context.lumio;
    final theme = Theme.of(context);
    final empty = groups.every((g) => g.items.isEmpty);
    if (empty && loading) {
      return const SizedBox(height: 160, child: StateView.loading());
    }
    if (empty && groups.every((g) => g.error == null)) {
      return const SizedBox(
        height: 220,
        child: StateView.empty(
          message: 'Aucun flux trouvé. Vérifiez vos addons.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final g in groups) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: LumioSpacing.md,
              bottom: LumioSpacing.sm,
            ),
            child: Row(
              children: [
                Text(
                  addonNames[g.addonId] ?? 'Addon',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: lumio.text,
                  ),
                ),
                const SizedBox(width: LumioSpacing.md),
                Icon(
                  g.error != null ? Icons.error_outline : Icons.check_circle,
                  size: 16,
                  color: g.error != null ? lumio.error : lumio.success,
                ),
                const SizedBox(width: 4),
                Text(
                  g.error != null ? 'Ne répond pas' : '${g.items.length} flux',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          for (final s in sortStreams(g.items, prefs))
            Padding(
              padding: const EdgeInsets.only(bottom: LumioSpacing.sm),
              child: _StreamRow(
                item: s,
                recommended: identical(s, preferred),
                onSelect: () => onSelect(s),
              ),
            ),
        ],
        if (loading)
          const Padding(
            padding: EdgeInsets.all(LumioSpacing.md),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}

class _StreamRow extends StatelessWidget {
  const _StreamRow({
    required this.item,
    required this.recommended,
    required this.onSelect,
  });

  final StreamItem item;
  final bool recommended;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final lumio = context.lumio;
    final theme = Theme.of(context);
    final seeders = item.seeders;
    final bits = [
      qualityLabel(item.quality),
      if (item.language != null) item.language!.toUpperCase(),
      if (item.sizeBytes != null) sizeLabel(item.sizeBytes!),
    ].where((e) => e.isNotEmpty).join(' · ');
    final kind = item.isTorrent ? 'torrent' : 'lien direct';
    return FocusableCard(
      scale: 1.02,
      onSelect: onSelect,
      semanticLabel:
          '${item.title}, $bits, $kind'
          '${seeders != null ? ', $seeders sources' : ''}'
          '${recommended ? ', recommandé' : ''}',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: LumioSpacing.md,
          vertical: LumioSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: recommended ? lumio.surfaceRaised : lumio.surface,
          borderRadius: BorderRadius.circular(LumioRadius.md),
          border: Border.all(color: recommended ? lumio.accent : lumio.outline),
        ),
        child: Row(
          children: [
            item.isTorrent
                ? const MagnetIcon()
                : Icon(Icons.link, color: lumio.secondary, size: 22),
            const SizedBox(width: LumioSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: lumio.text,
                    ),
                  ),
                  if (bits.isNotEmpty)
                    Text(bits, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (item.isTorrent && seeders != null) ...[
              Icon(
                Icons.arrow_upward,
                size: 16,
                color: seeders >= healthySeeders
                    ? lumio.success
                    : lumio.warning,
              ),
              Text(
                '$seeders',
                style: TextStyle(
                  color: seeders >= healthySeeders
                      ? lumio.success
                      : lumio.warning,
                ),
              ),
              const SizedBox(width: LumioSpacing.md),
            ],
            if (recommended)
              Text(
                'Recommandé',
                style: theme.textTheme.bodySmall?.copyWith(color: lumio.accent),
              ),
          ],
        ),
      ),
    );
  }
}
