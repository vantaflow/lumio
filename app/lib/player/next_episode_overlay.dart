import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lumio/ui/theme.dart';

/// Avance de l'invite « Épisode suivant » sur la fin de l'épisode.
const nextEpisodeLead = Duration(seconds: 30);

/// Durée du décompte avant le lancement automatique.
const nextEpisodeCountdown = Duration(seconds: 10);

/// L'invite s'affiche à 30 s de la fin, ou au début du générique si le
/// chapitre est connu. Jamais sans durée connue.
bool shouldOfferNext(Duration pos, Duration dur, {Duration? creditsStart}) {
  if (dur <= Duration.zero) return false;
  final at = creditsStart ?? (dur - nextEpisodeLead);
  return pos >= at;
}

/// Début du premier chapitre intitulé « Credits » ou « Générique » dans la
/// liste de chapitres mpv (JSON `[{"title": "...", "time": 12.5}]`).
Duration? parseCreditsStart(String json) {
  try {
    final data = jsonDecode(json);
    if (data is! List) return null;
    for (final c in data) {
      if (c is! Map) continue;
      final title = c['title'];
      final time = c['time'];
      if (title is! String || time is! num) continue;
      final t = title.toLowerCase();
      if (t.contains('credits') ||
          t.contains('crédits') ||
          t.contains('générique') ||
          t.contains('generique')) {
        return Duration(milliseconds: (time * 1000).round());
      }
    }
  } on Object {
    // Liste illisible : on retombe sur « 30 s avant la fin ».
  }
  return null;
}

/// Invite « Épisode suivant » : décompte de 10 s, puis lancement, sauf
/// annulation. Le focus arrive sur « Lire maintenant » (D-pad utilisable).
class NextEpisodeOverlay extends StatefulWidget {
  const NextEpisodeOverlay({
    required this.episodeTitle,
    required this.onPlayNow,
    required this.onCancel,
    this.countdown = nextEpisodeCountdown,
    super.key,
  });

  final String episodeTitle;
  final VoidCallback onPlayNow;
  final VoidCallback onCancel;
  final Duration countdown;

  @override
  State<NextEpisodeOverlay> createState() => _NextEpisodeOverlayState();
}

class _NextEpisodeOverlayState extends State<NextEpisodeOverlay> {
  late int _left;
  Timer? _timer;
  bool _done = false;
  final _playNode = FocusNode(debugLabel: 'next-episode-play');

  @override
  void initState() {
    super.initState();
    _left = widget.countdown.inSeconds;
    // L'écran du lecteur détient déjà le focus : on le prend explicitement.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playNode.requestFocus();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left <= 1) {
        _fire(widget.onPlayNow);
      } else {
        setState(() => _left--);
      }
    });
  }

  /// Une seule issue (lancement ou annulation), jamais deux.
  void _fire(VoidCallback cb) {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    cb();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _playNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<LumioColors>() ?? LumioColors.dark;
    return Align(
      alignment: AlignmentDirectional.bottomEnd,
      child: Padding(
        padding: const EdgeInsets.all(LumioSpacing.xl),
        child: Semantics(
          container: true,
          liveRegion: true,
          label:
              'Épisode suivant dans $_left secondes : ${widget.episodeTitle}',
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(LumioSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(LumioRadius.lg),
              border: Border.all(color: colors.outline),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Épisode suivant dans $_left s',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: LumioSpacing.sm),
                Text(
                  widget.episodeTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: LumioSpacing.md),
                Wrap(
                  spacing: LumioSpacing.md,
                  runSpacing: LumioSpacing.sm,
                  children: [
                    FilledButton(
                      focusNode: _playNode,
                      autofocus: true,
                      onPressed: () => _fire(widget.onPlayNow),
                      child: const Text('Lire maintenant'),
                    ),
                    OutlinedButton(
                      onPressed: () => _fire(widget.onCancel),
                      child: const Text('Annuler'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
