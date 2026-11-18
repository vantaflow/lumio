import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/player/subtitle_style.dart';
import 'package:lumio/player/tracks_controller.dart';
import 'package:lumio/ui/theme.dart';

/// Panneau latéral droit du lecteur (620 de large) : pistes audio, sous-titres
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

  static const width = 620.0;

  @override
  State<TracksPanel> createState() => _TracksPanelState();
}

class _TracksPanelState extends State<TracksPanel> {
  StreamSubscription<String>? _errSub;

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
    final audio = c.backend.audioTracks;
    final subs = c.backend.subtitleTracks;
    final selAudio = c.backend.selectedAudioId;
    final selSub = c.backend.selectedSubtitleId;
    final heading = theme.textTheme.titleMedium?.copyWith(color: colors.accent);
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
          label: context.l10n.tracksAndSubtitles,
          child: Material(
            color: colors.surface,
            borderRadius: const BorderRadiusDirectional.horizontal(
              start: Radius.circular(32),
            ),
            child: SizedBox(
              width: TracksPanel.width,
              child: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(LumioSpacing.lg),
                  children: [
                    Text(
                      context.l10n.tracksAndSubtitles,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: LumioSpacing.md),
                    Text(context.l10n.audio, style: heading),
                    if (audio.isEmpty) _Hint(context.l10n.noAudioTrack),
                    for (final t in audio)
                      _Option(
                        key: ValueKey('audio-${t.id}'),
                        autofocus: t == audio.first,
                        label: t.label,
                        selected: t.id == selAudio,
                        onPressed: () => c.selectAudio(t),
                      ),
                    const SizedBox(height: LumioSpacing.md),
                    Text(context.l10n.subtitles, style: heading),
                    _Option(
                      key: const ValueKey('sub-off'),
                      autofocus: audio.isEmpty,
                      label: context.l10n.subtitlesOff,
                      selected: selSub == null && c.addonSelectedId == null,
                      onPressed: () => c.selectSubtitle(null),
                    ),
                    for (final t in subs)
                      _Option(
                        key: ValueKey('sub-${t.id}'),
                        label: t.label,
                        selected: t.id == selSub && c.addonSelectedId == null,
                        onPressed: () => c.selectSubtitle(t),
                      ),
                    for (final s in c.addonSubtitles)
                      _Option(
                        key: ValueKey('addon-${s.id}'),
                        label: context.l10n.addonSubtitle(s.lang),
                        selected: c.addonSelectedId == s.id,
                        onPressed: () => c.selectAddonSubtitle(s),
                      ),
                    const SizedBox(height: LumioSpacing.md),
                    Text(context.l10n.subtitleDelay, style: heading),
                    Row(
                      children: [
                        _Step(
                          key: const ValueKey('delay-minus'),
                          label: context.l10n.subtitleAdvance,
                          icon: Icons.remove,
                          onPressed: () => c.changeDelay(-subtitleDelayStepMs),
                        ),
                        Expanded(
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              formatDelay(c.delayMs),
                              key: const ValueKey('delay-value'),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: colors.text,
                              ),
                            ),
                          ),
                        ),
                        _Step(
                          key: const ValueKey('delay-plus'),
                          label: context.l10n.subtitleRetard,
                          icon: Icons.add,
                          onPressed: () => c.changeDelay(subtitleDelayStepMs),
                        ),
                      ],
                    ),
                    const SizedBox(height: LumioSpacing.md),
                    Text(context.l10n.subtitleSize, style: heading),
                    Wrap(
                      spacing: LumioSpacing.sm,
                      children: [
                        for (final s in SubtitleSize.values)
                          _Option(
                            key: ValueKey('size-${s.name}'),
                            label: s.label,
                            selected: c.style.size == s,
                            compact: true,
                            onPressed: () => c.setSize(s),
                          ),
                      ],
                    ),
                    const SizedBox(height: LumioSpacing.md),
                    _Option(
                      key: const ValueKey('bg-toggle'),
                      label: context.l10n.opaqueBackground,
                      selected: c.style.opaqueBackground,
                      toggle: true,
                      onPressed: c.toggleBackground,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

class _Option extends StatefulWidget {
  const _Option({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.compact = false,
    this.toggle = false,
    this.autofocus = false,
    super.key,
  });

  final bool autofocus;
  final String label;
  final bool selected;
  final bool compact;
  final bool toggle;
  final VoidCallback onPressed;

  @override
  State<_Option> createState() => _OptionState();
}

class _OptionState extends State<_Option> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<LumioColors>() ?? LumioColors.dark;
    final icon = widget.toggle
        ? (widget.selected ? Icons.toggle_on : Icons.toggle_off)
        : (widget.selected ? Icons.check_circle : Icons.circle_outlined);
    return Semantics(
      button: true,
      selected: widget.selected,
      toggled: widget.toggle ? widget.selected : null,
      label: widget.label,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            autofocus: widget.autofocus,
            onTap: widget.onPressed,
            onFocusChange: (v) => setState(() => _focused = v),
            child: Container(
              constraints: BoxConstraints(
                minHeight: lumioTouchMin,
                minWidth: widget.compact ? 72 : 0,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: LumioSpacing.md,
                vertical: LumioSpacing.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: _focused ? colors.surfaceFocus : colors.surfaceRaised,
                border: Border.all(
                  color: _focused ? colors.focusRing : Colors.transparent,
                  width: lumioFocusWidth,
                ),
              ),
              child: Row(
                mainAxisSize: widget.compact
                    ? MainAxisSize.min
                    : MainAxisSize.max,
                children: [
                  Icon(
                    icon,
                    color: widget.selected ? colors.accent : colors.textMuted,
                  ),
                  const SizedBox(width: LumioSpacing.sm),
                  Flexible(
                    child: Text(
                      widget.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatefulWidget {
  const _Step({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  State<_Step> createState() => _StepState();
}

class _StepState extends State<_Step> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<LumioColors>() ?? LumioColors.dark;
    return Semantics(
      button: true,
      label: widget.label,
      child: ExcludeSemantics(
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.onPressed,
          onFocusChange: (v) => setState(() => _focused = v),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _focused ? colors.surfaceFocus : colors.surfaceRaised,
              border: Border.all(
                color: _focused ? colors.focusRing : Colors.transparent,
                width: lumioFocusWidth,
              ),
            ),
            child: Icon(widget.icon, color: colors.text),
          ),
        ),
      ),
    );
  }
}
