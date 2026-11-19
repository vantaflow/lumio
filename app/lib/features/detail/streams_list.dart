import 'package:flutter/material.dart';
import 'package:lumio/l10n/app_localizations_fr.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/features/addons/health_pill.dart';
import 'package:lumio/ui/common/state_view.dart';
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/icons/lumio_icons.dart';
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

String sizeLabel(int bytes, [AppLocalizations? l]) {
  l ??= AppLocalizationsFr();
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;
  if (bytes >= gb) {
    final v = (bytes / gb).toStringAsFixed(1);
    return l.sizeGb(l.localeName == 'fr' ? v.replaceAll('.', ',') : v);
  }
  return l.sizeMb((bytes / mb).round());
}

/// Icône aimant (flux torrent) de la maquette TV40 : contour ambre.
class MagnetIcon extends StatelessWidget {
  const MagnetIcon({super.key, this.size = 32, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.torrentLabel,
    child: LumioIconView(
      LumioIcon.torrents,
      size: size,
      color: color ?? context.lumio.accent,
    ),
  );
}

final _noHealth = HealthTracker();

/// Liste des flux groupée par addon (maquettes TV06, TV40, P11, P12) : titre
/// de section, puis par addon un en-tête « ADDON · nom · Santé : … » et une
/// ligne par flux (qualité, langue, taille, aimant ou lien, sources). Le flux
/// préféré du profil a le badge de qualité ambre.
class StreamsList extends StatelessWidget {
  const StreamsList({
    super.key,
    required this.groups,
    required this.addonNames,
    required this.loading,
    required this.prefs,
    required this.preferred,
    required this.onSelect,
    this.health = const {},
    this.tracker,
    this.showCount = false,
    this.headerTop = 24,
  });

  final List<StreamGroup> groups;

  /// Mesures de fiabilité par identifiant de stockage d'addon.
  final Map<String, AddonHealth> health;

  /// Suivi de fiabilité qui pondère le classement (aucun = tous inconnus).
  final HealthTracker? tracker;

  /// Nom affiché par identifiant de stockage d'addon.
  final Map<String, String> addonNames;
  final bool loading;
  final StreamPrefs prefs;
  final StreamItem? preferred;
  final void Function(StreamItem item) onSelect;

  /// Titre « Flux disponibles · N » (fiche film) au lieu de « Sources ».
  final bool showCount;

  /// Marge au-dessus d'un en-tête d'addon (24 fiche film, 16 fiche série).
  final double headerTop;

  @override
  Widget build(BuildContext context) {
    final lumio = context.lumio;
    final l = context.l10n;
    final empty = groups.every((g) => g.items.isEmpty);
    Widget heading(String text, double top, double bottom) => Padding(
      padding: EdgeInsets.only(top: top, bottom: bottom),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: lumio.text, height: 1.2),
        ),
      ),
    );
    final headTop = showCount ? 28.0 : 0.0;
    if (empty && loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading(l.sourcesTitle, headTop, 4),
          const SizedBox(height: 160, child: StateView.loading()),
        ],
      );
    }
    if (empty && groups.every((g) => g.error == null)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading(l.sourcesTitle, headTop, 16),
          // P11 : carte de 200, icône d'alerte et message centrés.
          Container(
            height: 200,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: lumio.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LumioIconView(
                  LumioIcon.alert,
                  size: 44,
                  color: lumio.textMuted,
                ),
                const SizedBox(height: 14),
                Text(
                  l.noStreams,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 30,
                    color: const Color(0xFFC9D0DA),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    // Chaque signature n'apparaît qu'une fois : dans le groupe de son
    // doublon le mieux noté ; les autres sont masqués et comptés.
    final tracked = tracker ?? _noHealth;
    final best = <String, StreamItem>{};
    final copies = <String, Set<String>>{};
    for (final g in groups) {
      for (final s in g.items) {
        final k = s.signature;
        (copies[k] ??= {}).add(g.addonId);
        final cur = best[k];
        if (cur == null ||
            StreamRanker.score(s, prefs, tracked) >
                StreamRanker.score(cur, prefs, tracked)) {
          best[k] = s;
        }
      }
    }
    final visible = {
      for (final g in groups)
        g: [
          for (final s in g.items)
            if (identical(best[s.signature], s)) s,
        ],
    };
    final total = visible.values.fold<int>(0, (n, v) => n + v.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          showCount && total > 0 ? l.streamsAvailable(total) : l.sourcesTitle,
          headTop,
          0,
        ),
        for (final g in groups) ...[
          _GroupHeader(
            name: addonNames[g.addonId] ?? l.addonFallback,
            failed: g.error != null,
            count: visible[g]!.length,
            health: health[g.addonId],
            top: headerTop,
          ),
          for (final (i, s) in StreamRanker.sort(
            visible[g]!,
            prefs,
            tracked,
          ).indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
              child: _StreamRow(
                item: s,
                recommended: identical(s, preferred),
                others: (copies[s.signature] ?? const <String>{}).difference({
                  g.addonId,
                }).length,
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

/// En-tête d'un addon (maquettes TV06 `.ad`, P12) : « ADDON · nom · Santé :
/// bonne » en turquoise ; un addon qui n'a pas répondu ajoute l'alerte « Ne
/// répond pas » et la pastille de santé détaillée.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.name,
    required this.failed,
    required this.count,
    required this.health,
    required this.top,
  });

  final String name;
  final bool failed;
  final int count;
  final AddonHealth? health;
  final double top;

  @override
  Widget build(BuildContext context) {
    final lumio = context.lumio;
    final l = context.l10n;
    final teal = TextStyle(
      fontFamily: 'Manrope',
      fontSize: 26,
      fontWeight: FontWeight.w700,
      fontVariations: const [FontVariation.weight(700)],
      color: lumio.secondary,
    );
    final known = health != null && health!.level != HealthLevel.unknown;
    final healthLine = !known || failed
        ? null
        : switch (health!.level) {
            HealthLevel.reliable => l.healthLineGood,
            HealthLevel.slow => l.healthLineSlow,
            _ => l.healthLineBad,
          };
    final muted = TextStyle(
      fontFamily: 'Manrope',
      fontSize: 26,
      fontWeight: FontWeight.w400,
      color: lumio.textMuted,
    );
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 10),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          Text('${l.streamGroupAddon} · ', style: teal),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: teal),
          if (healthLine != null) Text(' · $healthLine', style: teal),
          const SizedBox(width: 16),
          if (failed) ...[
            LumioIconView(LumioIcon.alert, size: 26, color: lumio.error),
            const SizedBox(width: 8),
            Text(l.noResponse, style: muted),
          ] else
            Text(l.streamCount(count), style: muted),
          if (failed && known) ...[
            const SizedBox(width: 16),
            HealthPill(health: health!, showDetail: true),
          ],
        ],
      ),
    );
  }
}

class _StreamRow extends StatefulWidget {
  const _StreamRow({
    required this.item,
    required this.recommended,
    required this.onSelect,
    this.others = 0,
  });

  /// Même source proposée par d'autres addons (masquée).
  final int others;
  final StreamItem item;
  final bool recommended;
  final VoidCallback onSelect;

  @override
  State<_StreamRow> createState() => _StreamRowState();
}

class _StreamRowState extends State<_StreamRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final lumio = context.lumio;
    final l = context.l10n;
    final item = widget.item;
    final seeders = item.seeders;
    final quality = qualityLabel(item.quality);
    final bits = [
      quality,
      if (item.language != null) item.language!.toUpperCase(),
      if (item.sizeBytes != null) sizeLabel(item.sizeBytes!, l),
    ].where((e) => e.isNotEmpty).join(' · ');
    final kind = item.isTorrent ? l.kindTorrent : l.kindDirect;
    final seedColor = (seeders ?? 0) >= healthySeeders
        ? lumio.success
        : lumio.accent;
    TextStyle text(Color color, [FontWeight w = FontWeight.w400]) => TextStyle(
      fontFamily: 'Manrope',
      fontSize: 26,
      fontWeight: w,
      fontVariations: [FontVariation.weight(w.value.toDouble())],
      color: color,
    );
    return FocusableCard(
      scale: 1.02,
      borderRadius: BorderRadius.circular(18),
      onSelect: widget.onSelect,
      onFocusChange: (f) => setState(() => _focused = f),
      semanticLabel:
          '${item.title}, $bits, $kind'
          '${seeders != null ? ', ${l.seedersSemantic(seeders)}' : ''}'
          '${widget.recommended ? ', ${l.recommendedSemantic}' : ''}',
      child: Container(
        height: 92,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          color: _focused ? lumio.surfaceFocus : lumio.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            if (quality.isNotEmpty) ...[
              Container(
                key: widget.recommended
                    ? const ValueKey('stream-recommended')
                    : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: widget.recommended ? lumio.accent : lumio.surfaceFocus,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  quality,
                  style: text(
                    widget.recommended ? lumio.onAccent : lumio.text,
                    FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 20),
            ],
            Expanded(
              child: Text(
                item.language != null
                    ? '${item.language!.toUpperCase()}  ${item.title}'
                    : item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text(lumio.text),
              ),
            ),
            if (widget.others > 0) ...[
              const SizedBox(width: 20),
              Text(
                l.otherAddonsCount(widget.others),
                style: text(lumio.textMuted).copyWith(fontSize: 24),
              ),
            ],
            if (item.sizeBytes != null) ...[
              const SizedBox(width: 20),
              Text(sizeLabel(item.sizeBytes!, l), style: text(lumio.textMuted)),
            ],
            const SizedBox(width: 20),
            item.isTorrent
                ? const MagnetIcon()
                : LumioIconView(
                    LumioIcon.link,
                    color: lumio.secondary,
                    size: 32,
                  ),
            const SizedBox(width: 20),
            SizedBox(
              width: item.isTorrent && seeders != null ? null : 170,
              child: Text(
                item.isTorrent && seeders != null
                    ? l.seedersCount(seeders)
                    : (item.isTorrent
                          ? l.streamBadgeTorrent
                          : l.streamBadgeDirect),
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: item.isTorrent && seeders != null
                    ? text(seedColor, FontWeight.w700)
                    : text(lumio.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
