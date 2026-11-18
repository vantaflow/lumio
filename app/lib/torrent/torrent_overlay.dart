import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/torrent/torrent_engine.dart';
import 'package:lumio/ui/theme.dart';

/// Débit lisible ; `1,4 Mo/s`, `350 Ko/s` (selon la langue).
String formatTorrentRate(AppLocalizations l, int bytesPerSecond) {
  if (bytesPerSecond >= 1024 * 1024) {
    final v = bytesPerSecond / (1024 * 1024);
    return l.torrentRateMb(v.toStringAsFixed(1));
  }
  return l.torrentRateKb((bytesPerSecond / 1024).round().toString());
}

/// Superposition du lecteur : sources, débit, téléchargé. `null` = connexion
/// en cours ; une erreur du moteur affiche « Connexion perdue… ».
class TorrentOverlay extends StatelessWidget {
  const TorrentOverlay({required this.status, super.key});

  final ValueListenable<TorrentStatus?> status;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<LumioColors>() ?? LumioColors.dark;
    final l = context.l10n;
    final style = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(color: colors.text);
    return ValueListenableBuilder<TorrentStatus?>(
      valueListenable: status,
      builder: (context, st, _) {
        final lost = st?.error != null;
        final lines = <String>[
          if (st == null)
            l.torrentConnecting
          else ...[
            if (lost) l.torrentConnectionLost,
            [
              l.torrentPeers(st.peers),
              formatTorrentRate(l, st.downloadRate),
              l.torrentBuffered((st.progress * 100).clamp(0, 100).round()),
            ].join(' · '),
          ],
        ];
        return Semantics(
          liveRegion: true,
          label: lines.join('. '),
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(LumioRadius.md),
                border: Border.all(
                  color: lost ? colors.warning : colors.outline,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LumioSpacing.md,
                  vertical: LumioSpacing.sm,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in lines)
                      Text(
                        line,
                        key: ValueKey(line),
                        style: lost && line == l.torrentConnectionLost
                            ? style?.copyWith(color: colors.warning)
                            : style,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
