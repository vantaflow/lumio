import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/ui/theme.dart';

/// Avance de l'invite « Épisode suivant » sur la fin de l'épisode.
const nextEpisodeLead = Duration(seconds: 30);

/// Durée du décompte avant le lancement automatique.
const nextEpisodeCountdown = Duration(seconds: 10);

/// Part minimale de la durée avant laquelle on ne propose jamais la suite.
const nextEpisodeMinFraction = 0.6;

/// L'invite s'affiche à 30 s de la fin, ou au début du générique si le
/// chapitre est connu, mais jamais sans durée connue, sur une vidéo de 30 s
/// ou moins, à la position 0, ni avant 60 % de la durée.
bool shouldOfferNext(Duration pos, Duration dur, {Duration? creditsStart}) {
  if (dur <= nextEpisodeLead || pos <= Duration.zero) return false;
  final floor = dur * nextEpisodeMinFraction;
  var at = creditsStart ?? (dur - nextEpisodeLead);
  if (at < floor) at = floor;
  return pos >= at;
}

const _creditsWords = ['credits', 'crédits', 'générique', 'generique', 'outro'];
const _openingWords = [
  'opening',
  'ouverture',
  'début',
  'debut',
  'intro',
  'start',
  'recap',
  'récap',
];
const _endWords = ['end', 'fin', 'outro', 'closing'];

/// Début du chapitre de générique de fin dans la liste de chapitres mpv
/// (JSON `[{"title": "...", "time": 12.5}]`). Ignore les génériques
/// d'ouverture et tout chapitre commençant avant 50 % de [duration] ; préfère
/// un titre « de fin » / « end » / « outro ».
Duration? parseCreditsStart(String json, {required Duration duration}) {
  if (duration <= Duration.zero) return null;
  try {
    final data = jsonDecode(json);
    if (data is! List) return null;
    Duration? preferred;
    Duration? any;
    for (final c in data) {
      if (c is! Map) continue;
      final title = c['title'];
      final time = c['time'];
      if (title is! String || time is! num) continue;
      final t = title.toLowerCase();
      if (!_creditsWords.any(t.contains)) continue;
      if (_openingWords.any(t.contains)) continue;
      final at = Duration(milliseconds: (time * 1000).round());
      if (at < duration * 0.5) continue;
      if (_endWords.any(t.contains)) {
        if (preferred == null || at < preferred) preferred = at;
      } else if (any == null || at < any) {
        any = at;
      }
    }
    return preferred ?? any;
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
    this.paused = false,
    super.key,
  });

  final String episodeTitle;
  final VoidCallback onPlayNow;
  final VoidCallback onCancel;
  final Duration countdown;

  /// Lecture en pause : le décompte est suspendu.
  final bool paused;

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
      if (widget.paused) return;
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
    // Maquette P06 (TV) : carte de 560 à 48 du bord droit et à 200 du bas,
    // rayon 28, marge 32, titre 40, boutons de 76.
    final big = MediaQuery.sizeOf(context).width >= 1280;
    final tvButtons = [
      TvButton(
        focusNode: _playNode,
        autofocus: true,
        label: context.l10n.playNow,
        height: 76,
        fontSize: 28,
        horizontalPadding: 40,
        onPressed: () => _fire(widget.onPlayNow),
      ),
      TvButton(
        label: context.l10n.cancel,
        kind: TvButtonKind.secondary,
        height: 76,
        fontSize: 28,
        horizontalPadding: 40,
        onPressed: () => _fire(widget.onCancel),
      ),
    ];
    return Align(
      alignment: AlignmentDirectional.bottomEnd,
      child: Padding(
        padding: big
            ? const EdgeInsetsDirectional.only(end: 48, bottom: 200)
            : const EdgeInsets.all(LumioSpacing.xl),
        child: Semantics(
          container: true,
          liveRegion: true,
          label: context.l10n.nextEpisodeIn(_left, widget.episodeTitle),
          child: Container(
            constraints: BoxConstraints(maxWidth: big ? 560 : 480),
            padding: EdgeInsets.all(big ? 32 : LumioSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(big ? 28 : LumioRadius.lg),
              border: Border.all(color: colors.outline, width: big ? 2 : 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.nextEpisodeInShort(_left),
                  style: big
                      ? TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 28,
                          height: 1.4,
                          color: colors.textMuted,
                        )
                      : theme.textTheme.titleMedium?.copyWith(
                          color: colors.textMuted,
                        ),
                ),
                SizedBox(height: big ? 14 : LumioSpacing.sm),
                Text(
                  widget.episodeTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: big
                      ? TextStyle(
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 40,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          fontVariations: const [FontVariation.weight(700)],
                          color: colors.text,
                        )
                      : theme.textTheme.titleLarge?.copyWith(
                          color: colors.text,
                        ),
                ),
                SizedBox(height: big ? 22 : LumioSpacing.md),
                if (big)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      tvButtons[0],
                      const SizedBox(width: 16),
                      tvButtons[1],
                    ],
                  )
                else
                  Wrap(
                    spacing: LumioSpacing.md,
                    runSpacing: LumioSpacing.sm,
                    children: [
                      FilledButton(
                        focusNode: _playNode,
                        autofocus: true,
                        onPressed: () => _fire(widget.onPlayNow),
                        child: Text(context.l10n.playNow),
                      ),
                      OutlinedButton(
                        onPressed: () => _fire(widget.onCancel),
                        child: Text(context.l10n.cancel),
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
