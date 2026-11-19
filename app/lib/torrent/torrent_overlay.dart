import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/torrent/torrent_engine.dart';
import 'package:lumio/ui/theme.dart';

/// Débit lisible ; `1,4 Mo/s`, `350 Ko/s` (selon la langue).
String formatTorrentRate(AppLocalizations l, int bytesPerSecond) {
  if (bytesPerSecond >= 1024 * 1024) {
    final v = bytesPerSecond / (1024 * 1024);
    // Séparateur décimal de la langue (« 1,4 Mo/s » en français).
    return l.torrentRateMb(NumberFormat('0.0', l.localeName).format(v));
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
    // Maquette P05 (TV) : cartes de 600, rayon 24, bord de 2, texte 28 gras.
    final big = MediaQuery.sizeOf(context).width >= 1280;
    final style = big
        ? TextStyle(
            fontFamily: 'Manrope',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            fontVariations: const [FontVariation.weight(700)],
            color: colors.text,
          )
        : Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.text);
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
                color: colors.surface.withValues(alpha: big ? 0.88 : 0.85),
                borderRadius: BorderRadius.circular(big ? 24 : LumioRadius.md),
                border: Border.all(
                  color: lost ? colors.warning : colors.outline,
                  width: big ? 2 : 1,
                ),
              ),
              child: Padding(
                padding: big
                    ? const EdgeInsets.symmetric(horizontal: 28, vertical: 20)
                    : const EdgeInsets.symmetric(
                        horizontal: LumioSpacing.md,
                        vertical: LumioSpacing.sm,
                      ),
                child: SizedBox(
                  width: big ? 544 : null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < lines.length; i++)
                        Padding(
                          padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
                          child: Text(
                            lines[i],
                            key: ValueKey(lines[i]),
                            style: lost && lines[i] == l.torrentConnectionLost
                                ? style?.copyWith(color: colors.warning)
                                : style,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
