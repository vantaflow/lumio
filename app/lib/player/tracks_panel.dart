import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/ui/common/tv_screen.dart';
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/player/subtitle_groups.dart';
import 'package:lumio/player/subtitle_style.dart';
import 'package:lumio/player/tracks_controller.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart' show SubtitleItem;

/// Panneau du lecteur à droite (maquette P23, 780 de large) : pistes audio, sous-titres
/// (internes et d'addons), décalage, taille et fond. Entièrement utilisable au
/// D-pad ; l'ordre de focus suit l'ordre de lecture (audio, sous-titres,
/// décalage −/+, taille, fond). Retour ferme le panneau.
class TracksPanel extends StatefulWidget {
  const TracksPanel({
    required this.controller,
    required this.onClose,
    super.key,
  });

  final TracksController controller;
  final VoidCallback onClose;

  static const width = 780.0;

  @override
  State<TracksPanel> createState() => _TracksPanelState();
}

class _TracksPanelState extends State<TracksPanel> {
  StreamSubscription<String>? _errSub;
  bool _otherLangs = false;

  /// Piège le focus : les flèches et Tab restent dans le panneau.
  final _scope = FocusScopeNode(debugLabel: 'tracks-panel')
    ..traversalEdgeBehavior = TraversalEdgeBehavior.closedLoop
    ..directionalTraversalEdgeBehavior = TraversalEdgeBehavior.stop;

  TracksController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_rebuild);
    _errSub = c.errors.listen((m) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(m)));
    });
  }

  @override
  void dispose() {
    c.removeListener(_rebuild);
    _errSub?.cancel();
    _scope.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<LumioColors>() ?? LumioColors.dark;
    final l = context.l10n;
    final audio = c.backend.audioTracks;
    final subs = c.backend.subtitleTracks;
    final selAudio = c.backend.selectedAudioId;
    final selSub = c.backend.selectedSubtitleId;
    final size = MediaQuery.sizeOf(context);
    final big = size.width >= 1280;
    final sizes = SubtitleSize.values;
    final prefLangs = <String?>[
      c.settings.subtitleLang,
      c.defaultSubtitleLang,
      l.localeName,
    ];
    final selId = c.addonSelectedId;
    final grouped = groupSubtitles(
      c.addonSubtitles,
      preferred: prefLangs,
      locale: l.localeName,
      selectedId: selId,
    );
    final showOthers =
        _otherLangs ||
        (selId != null &&
            grouped.others.any((g) => g.shown.any((s) => s.id == selId)));
    Widget addonChip(SubtitleItem s) => _Chip(
      key: ValueKey('addon-${s.id}'),
      label: c.addonLabel(s),
      selected: c.addonSelectedId == s.id,
      onPressed: () => c.selectAddonSubtitle(s),
    );
    final sizeIndex = sizes.indexOf(c.style.size);
    return FocusScope(
      node: _scope,
      autofocus: true,
      onKeyEvent: (node, e) {
        if (e is KeyDownEvent &&
            (e.logicalKey == LogicalKeyboardKey.escape ||
                e.logicalKey == LogicalKeyboardKey.goBack)) {
          widget.onClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Semantics(
          container: true,
          label: l.tracksAndSubtitles,
          // Voile de la maquette P23 : rgba(6,8,12,.5), panneau à droite.
          child: ColoredBox(
            color: const Color(0x8006080C),
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  top: big ? 90 : 16,
                  end: big ? 96 : 16,
                  bottom: big ? 90 : 16,
                  start: big ? 0 : 16,
                ),
                child: Material(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(32),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    width: big ? TracksPanel.width : 560,
                    child: SingleChildScrollView(
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 44,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              l.tracksAndSubtitles,
                              style: TextStyle(
                                fontFamily: 'Bricolage Grotesque',
                                fontSize: 44,
                                height: 1.15,
                                fontWeight: FontWeight.w700,
                                fontVariations: const [
                                  FontVariation.weight(700),
                                ],
                                color: colors.text,
                              ),
                            ),
                          ),
                          TvSectionLabel(l.audio, top: 20),
                          const SizedBox(height: 14),
                          if (audio.isEmpty) _Hint(l.noAudioTrack),
                          _Chips([
                            for (final t in audio)
                              _Chip(
                                key: ValueKey('audio-${t.id}'),
                                autofocus: t == audio.first,
                                label: t.label,
                                selected: t.id == selAudio,
                                onPressed: () => c.selectAudio(t),
                              ),
                          ]),
                          const SizedBox(height: 28),
                          TvSectionLabel(l.subtitleAppearance, top: 0),
                          const SizedBox(height: 14),
                          _StepRow(
                            label: l.subtitleSize,
                            value: _sizeName(l, c.style.size),
                            valueKey: const ValueKey('size-value'),
                            minusKey: const ValueKey('size-minus'),
                            plusKey: const ValueKey('size-plus'),
                            minusLabel: l.subtitleSmaller,
                            plusLabel: l.subtitleLarger,
                            onMinus: sizeIndex > 0
                                ? () => c.setSize(sizes[sizeIndex - 1])
                                : null,
                            onPlus: sizeIndex < sizes.length - 1
                                ? () => c.setSize(sizes[sizeIndex + 1])
                                : null,
                          ),
                          const SizedBox(height: 12),
                          _StepRow(
                            label: l.subtitleDelay,
                            value: formatDelay(c.delayMs),
                            valueKey: const ValueKey('delay-value'),
                            minusKey: const ValueKey('delay-minus'),
                            plusKey: const ValueKey('delay-plus'),
                            minusLabel: l.subtitleAdvance,
                            plusLabel: l.subtitleRetard,
                            onMinus: () => c.changeDelay(-subtitleDelayStepMs),
                            onPlus: () => c.changeDelay(subtitleDelayStepMs),
                          ),
                          const SizedBox(height: 12),
                          _ToggleRow(
                            key: const ValueKey('bg-toggle'),
                            label: l.opaqueBackground,
                            on: c.style.opaqueBackground,
                            onPressed: c.toggleBackground,
                          ),
                          const SizedBox(height: 28),
                          TvSectionLabel(l.subtitles, top: 0),
                          const SizedBox(height: 14),
                          _Chips([
                            _Chip(
                              key: const ValueKey('sub-off'),
                              autofocus: audio.isEmpty,
                              label: l.subtitlesOff,
                              selected:
                                  selSub == null && c.addonSelectedId == null,
                              onPressed: () => c.selectSubtitle(null),
                            ),
                            for (final t in subs)
                              _Chip(
                                key: ValueKey('sub-${t.id}'),
                                label: t.label,
                                selected:
                                    t.id == selSub && c.addonSelectedId == null,
                                onPressed: () => c.selectSubtitle(t),
                              ),
                            for (final g in grouped.preferred)
                              for (final s in g.shown) addonChip(s),
                            if (grouped.others.isNotEmpty)
                              _Chip(
                                key: const ValueKey('sub-other-langs'),
                                label: showOthers
                                    ? l.subtitleHideOtherLanguages
                                    : l.subtitleOtherLanguages,
                                selected: false,
                                onPressed: () =>
                                    setState(() => _otherLangs = !showOthers),
                              ),
                          ]),
                          if (showOthers)
                            for (final g in grouped.others) ...[
                              const SizedBox(height: 16),
                              Text(
                                g.name,
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _Chips([for (final s in g.shown) addonChip(s)]),
                            ],
                          const SizedBox(height: 24),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TvButton(
                              key: const ValueKey('tracks-close'),
                              label: l.close,
                              kind: TvButtonKind.secondary,
                              height: 76,
                              fontSize: 28,
                              horizontalPadding: 40,
                              onPressed: widget.onClose,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Taille en mots (Petite, Normale, Grande, Très grande).
String _sizeName(AppLocalizations l, SubtitleSize s) => switch (s) {
  SubtitleSize.s => l.subtitleSizeSmall,
  SubtitleSize.m => l.subtitleSizeNormal,
  SubtitleSize.l => l.subtitleSizeLarge,
  SubtitleSize.xl => l.subtitleSizeXLarge,
};

/// Décalage lisible : « +0,3 s », « −1,2 s », « 0 s ».
String formatDelay(int ms) {
  if (ms == 0) return '0 s';
  final v = (ms.abs() / 1000).toStringAsFixed(1).replaceAll('.', ',');
  return '${ms < 0 ? '−' : '+'}$v s';
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<LumioColors>() ?? LumioColors.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LumioSpacing.sm),
      child: Text(text, style: TextStyle(color: colors.textMuted)),
    );
  }
}

/// Pastilles à la suite (maquette P23 : 12 dp d'écart).
class _Chips extends StatelessWidget {
  const _Chips(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.zero,
    child: Wrap(spacing: 12, runSpacing: 12, children: children),
  );
}

/// Pastille de choix (P23 `.chip`) : ambre si choisie, gris sinon.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.autofocus = false,
    super.key,
  });

  final String label;
  final bool selected;
  final bool autofocus;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: TvButton(
      label: label,
      kind: selected ? TvButtonKind.primary : TvButtonKind.secondary,
      height: 56,
      fontSize: 26,
      horizontalPadding: 24,
      autofocus: autofocus,
      onPressed: onPressed,
    ),
  );
}

/// Ligne « libellé  −  valeur  + » (P23) : 88 de haut, libellé de 360.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.value,
    required this.valueKey,
    required this.minusKey,
    required this.plusKey,
    required this.minusLabel,
    required this.plusLabel,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String value;
  final Key valueKey;
  final Key minusKey;
  final Key plusKey;
  final String minusLabel;
  final String plusLabel;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    TextStyle style(double size) => TextStyle(
      fontFamily: 'Manrope',
      fontSize: size,
      fontWeight: FontWeight.w700,
      fontVariations: const [FontVariation.weight(700)],
      color: context.lumio.text,
    );
    Widget step(
      Key k,
      String sign,
      String semantic,
      VoidCallback? f, [
      double w = 96,
    ]) => SizedBox(
      width: w,
      child: TvButton(
        key: k,
        label: sign,
        semanticLabel: semantic,
        kind: TvButtonKind.secondary,
        height: 72,
        fontSize: 28,
        horizontalPadding: 0,
        expand: true,
        onPressed: f,
      ),
    );
    // Petit écran (téléphone) : libellé au-dessus, commandes dessous.
    final compact = MediaQuery.sizeOf(context).width < 1280;
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: style(20)),
            const SizedBox(height: 8),
            Row(
              children: [
                step(minusKey, '−', minusLabel, onMinus),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      value,
                      key: valueKey,
                      textAlign: TextAlign.center,
                      style: style(24),
                    ),
                  ),
                ),
                step(plusKey, '+', plusLabel, onPlus),
              ],
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 88,
      child: Row(
        children: [
          // 360 + 96 + 200 + 96 + marges dépassent les 684 du panneau : comme
          // dans la maquette (flex), libellé, boutons et valeur rétrécissent.
          Expanded(child: Text(label, style: style(28))),
          const SizedBox(width: 20),
          step(minusKey, '−', minusLabel, onMinus, 80),
          const SizedBox(width: 20),
          SizedBox(
            width: 166,
            child: Semantics(
              liveRegion: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  key: valueKey,
                  textAlign: TextAlign.center,
                  style: style(34),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          step(plusKey, '+', plusLabel, onPlus, 80),
        ],
      ),
    );
  }
}

/// Ligne à interrupteur (P23 `.row` + `.tg` 84 x 46).
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.on,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool on;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    return Semantics(
      toggled: on,
      child: TvTile(
        minHeight: 88,
        horizontalPadding: 24,
        semanticLabel: label,
        onSelect: onPressed,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  fontVariations: const [FontVariation.weight(700)],
                  color: c.text,
                ),
              ),
            ),
            Container(
              width: 84,
              height: 46,
              decoration: BoxDecoration(
                color: on ? c.accent : c.outline,
                borderRadius: BorderRadius.circular(23),
              ),
              child: Align(
                alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c.text,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
