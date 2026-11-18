import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/player/player_controller.dart';
import 'package:lumio/player/subtitle_style.dart';
import 'package:lumio/player/tracks_controller.dart';
import 'package:lumio/player/tracks_panel.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/common/state_view.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart' hide Video;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';

/// Résultat renvoyé à la fermeture de l'écran.
enum PlayerExit {
  /// Retour simple.
  back,

  /// « Choisir une autre source » après un échec : l'appelant rouvre la liste.
  pickAnother,
}

/// Actions déclenchées par le clavier ou la télécommande.
enum PlayerKeyAction {
  togglePlay,
  seekBack,
  seekForward,
  volumeUp,
  volumeDown,
  showControls,
  none,
}

const seekStep = Duration(seconds: 10);
const controlsHideDelay = Duration(seconds: 4);

/// Traduit une touche selon l'état de la superposition : commandes masquées,
/// gauche/droite = ∓10 s, haut/bas = volume, OK = afficher ; commandes
/// visibles, seule la lecture/pause globale est interceptée (le reste sert à
/// la navigation au D-pad entre les boutons).
PlayerKeyAction mapPlayerKey(
  LogicalKeyboardKey key, {
  required bool controlsVisible,
}) {
  if (key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.mediaPlayPause ||
      key == LogicalKeyboardKey.mediaPlay ||
      key == LogicalKeyboardKey.mediaPause) {
    return PlayerKeyAction.togglePlay;
  }
  if (key == LogicalKeyboardKey.mediaFastForward) {
    return PlayerKeyAction.seekForward;
  }
  if (key == LogicalKeyboardKey.mediaRewind) return PlayerKeyAction.seekBack;
  if (controlsVisible) return PlayerKeyAction.none;
  if (key == LogicalKeyboardKey.arrowLeft) return PlayerKeyAction.seekBack;
  if (key == LogicalKeyboardKey.arrowRight) return PlayerKeyAction.seekForward;
  if (key == LogicalKeyboardKey.arrowUp) return PlayerKeyAction.volumeUp;
  if (key == LogicalKeyboardKey.arrowDown) return PlayerKeyAction.volumeDown;
  if (key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.gameButtonA) {
    return PlayerKeyAction.showControls;
  }
  return PlayerKeyAction.none;
}

String formatClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '${d.inMinutes}:$s';
}

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({
    required this.item,
    this.allowPrivate = false,
    this.controller,
    this.metaId,
    this.subtitles = const [],
    this.allowPrivateForAddon,
    this.videoBuilder,
    this.tracksBackend,
    super.key,
  });

  final StreamItem item;

  /// Flux d'un addon autorisé sur le réseau privé par l'utilisateur.
  final bool allowPrivate;

  /// Contrôleur fourni (tests) ; sinon créé et libéré par l'écran.
  final PlayerController? controller;

  /// Identifiant du titre (`tt1` ou `tt1:1:2`) pour mémoriser pistes et
  /// décalage par série ; sans lui, rien n'est mémorisé.
  final String? metaId;

  /// Sous-titres proposés par les addons pour ce flux.
  final List<SubtitleItem> subtitles;

  /// Autorisation réseau privé par addon (celui du sous-titre) ; par défaut,
  /// seul l'addon du flux hérite de [allowPrivate].
  final bool Function(String addonId)? allowPrivateForAddon;

  /// Remplace la vidéo native (tests de widget).
  @visibleForTesting
  final Widget Function(PlayerController controller)? videoBuilder;

  /// Remplace le moteur de pistes media_kit (tests de widget).
  @visibleForTesting
  final TracksBackend Function(PlayerController controller)? tracksBackend;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final PlayerController _ctl;
  final _root = FocusNode(debugLabel: 'player-root');
  final _playNode = FocusNode(debugLabel: 'player-play');
  final _tracksNode = FocusNode(debugLabel: 'player-tracks');
  TracksController? _tracks;
  bool _panel = false;
  Timer? _hide;
  bool _controls = true;

  @override
  void initState() {
    super.initState();
    _ctl =
        widget.controller ??
        PlayerController(proxy: () => ref.read(localProxyProvider.future));
    _ctl.stateListenable.addListener(_onState);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    unawaited(_ctl.open(widget.item, allowPrivate: widget.allowPrivate));
    unawaited(_initTracks());
    _armHide();
  }

  void _tell(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Le sous-titre est téléchargé selon l'autorisation réseau privé de SON
  /// addon, pas de celui du flux.
  bool _allowPrivateFor(String addonId) =>
      widget.allowPrivateForAddon?.call(addonId) ??
      (addonId == widget.item.addonId && widget.allowPrivate);

  Future<void> _initTracks() async {
    TitleSettingsStore store = InMemoryTitleSettingsStore();
    var style = const SubtitleStyle();
    final styleStore = ref.read(subtitleStyleStoreProvider);
    try {
      if (widget.metaId != null) {
        final drift = await ref.read(titleSettingsStoreProvider.future);
        drift.onSaveError = (_) => _tell('Réglages non enregistrés');
        store = drift;
      }
      style = await styleStore.load();
    } on Object {
      _tell('Réglages mémorisés indisponibles');
    }
    if (!mounted) return;
    final fetcher = IoHttpFetcher();
    final c = TracksController(
      backend:
          widget.tracksBackend?.call(_ctl) ??
          MediaKitTracksBackend(_ctl.player),
      store: store,
      profileId: defaultProfileId,
      metaId: widget.metaId ?? '',
      addonSubtitles: widget.subtitles,
      style: style,
      onStyleChanged: (s) => unawaited(
        styleStore.save(s).catchError((Object _) {
          _tell('Réglages non enregistrés');
        }),
      ),
      download: (item) => downloadSubtitle(
        fetcher,
        item.url,
        allowPrivate: _allowPrivateFor(item.addonId),
      ),
      tempStore: SubtitleTempStore(getTemporaryDirectory),
    );
    try {
      await c.init();
    } on Object {
      _tell('Réglages de sous-titres non appliqués');
    }
    if (!mounted) {
      c.dispose();
      return;
    }
    setState(() => _tracks = c);
  }

  void _openPanel() {
    if (_tracks == null) return;
    _hide?.cancel();
    setState(() => _panel = true);
  }

  void _closePanel() {
    setState(() => _panel = false);
    _showControls();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tracksNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    _ctl.stateListenable.removeListener(_onState);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _root.dispose();
    _playNode.dispose();
    _tracksNode.dispose();
    _tracks?.dispose();
    if (widget.controller == null) unawaited(_ctl.dispose());
    super.dispose();
  }

  PlayerPhase? _lastPhase;
  void _onState() {
    final p = _ctl.state.phase;
    if (p == _lastPhase) return;
    _lastPhase = p;
    if (p == PlayerPhase.failed || p == PlayerPhase.paused) {
      _showControls();
    } else {
      _armHide();
    }
  }

  void _armHide() {
    _hide?.cancel();
    if (!_ctl.state.isPlaying && _ctl.state.phase != PlayerPhase.opening) {
      return;
    }
    _hide = Timer(controlsHideDelay, () {
      if (mounted && _ctl.state.isPlaying) _setControls(false);
    });
  }

  void _showControls({bool focusPlay = false}) {
    _setControls(true);
    if (focusPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playNode.requestFocus();
      });
    }
    _armHide();
  }

  void _setControls(bool v) {
    if (_controls == v) return;
    setState(() => _controls = v);
    if (!v) _root.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    // Panneau ouvert : il gère seul les touches (flèches = navigation).
    if (_panel) return KeyEventResult.ignored;
    final action = mapPlayerKey(event.logicalKey, controlsVisible: _controls);
    switch (action) {
      case PlayerKeyAction.none:
        if (_controls) _armHide();
        return KeyEventResult.ignored;
      case PlayerKeyAction.togglePlay:
        unawaited(_ctl.playPause());
        _showControls();
      case PlayerKeyAction.seekBack:
        unawaited(_ctl.seekBy(-seekStep));
        _showControls();
      case PlayerKeyAction.seekForward:
        unawaited(_ctl.seekBy(seekStep));
        _showControls();
      case PlayerKeyAction.volumeUp:
        unawaited(_ctl.setVolume(_ctl.state.volume + 10));
      case PlayerKeyAction.volumeDown:
        unawaited(_ctl.setVolume(_ctl.state.volume - 10));
      case PlayerKeyAction.showControls:
        _showControls(focusPlay: true);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<LumioColors>() ?? LumioColors.dark;
    final fade = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : LumioMotion.panel;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _root,
        autofocus: true,
        onKeyEvent: _onKey,
        child: ValueListenableBuilder<PlayerState>(
          valueListenable: _ctl.stateListenable,
          builder: (context, st, _) {
            final failed = st.phase == PlayerPhase.failed;
            return Stack(
              fit: StackFit.expand,
              children: [
                widget.videoBuilder?.call(_ctl) ??
                    Video(
                      controller: _ctl.video,
                      controls: NoVideoControls,
                      fill: Colors.black,
                    ),
                if (st.phase == PlayerPhase.buffering ||
                    st.phase == PlayerPhase.opening)
                  Center(
                    child: Semantics(
                      label: 'Mise en mémoire tampon',
                      child: CircularProgressIndicator(color: colors.accent),
                    ),
                  ),
                if (failed)
                  _FailureView(
                    message: st.error ?? 'La lecture a échoué.',
                    onRetry: _ctl.retry,
                    onOther: () =>
                        Navigator.of(context).pop(PlayerExit.pickAnother),
                    onBack: () => Navigator.of(context).pop(PlayerExit.back),
                  )
                else
                  AnimatedOpacity(
                    opacity: _controls ? 1 : 0,
                    duration: fade,
                    child: ExcludeFocus(
                      excluding: !_controls || _panel,
                      child: IgnorePointer(
                        ignoring: !_controls,
                        child: _Controls(
                          title: widget.item.title,
                          state: st,
                          playNode: _playNode,
                          tracksNode: _tracksNode,
                          onTracks: _tracks == null ? null : _openPanel,
                          onPlayPause: () {
                            unawaited(_ctl.playPause());
                            _armHide();
                          },
                          onSeekBy: (d) {
                            unawaited(_ctl.seekBy(d));
                            _armHide();
                          },
                          onSeekTo: (t) {
                            unawaited(_ctl.seekTo(t));
                            _armHide();
                          },
                          onTouch: () => _showControls(),
                        ),
                      ),
                    ),
                  ),
                if (_panel && _tracks != null && !failed)
                  PositionedDirectional(
                    top: 0,
                    bottom: 0,
                    end: 0,
                    child: TracksPanel(
                      controller: _tracks!,
                      onClose: _closePanel,
                    ),
                  ),
                if (!_controls && !failed && !_panel)
                  // Toucher l'écran réaffiche les commandes (téléphone/bureau).
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _showControls(focusPlay: true),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({
    required this.message,
    required this.onRetry,
    required this.onOther,
    required this.onBack,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onOther;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // « Réessayer » reçoit le focus en premier (ordre de traversée).
            StateView.error(message: message, onRetry: onRetry),
            const SizedBox(height: LumioSpacing.md),
            Wrap(
              spacing: LumioSpacing.md,
              children: [
                OutlinedButton(
                  onPressed: onOther,
                  child: const Text('Choisir une autre source'),
                ),
                TextButton(onPressed: onBack, child: const Text('Retour')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.title,
    required this.state,
    required this.playNode,
    required this.tracksNode,
    required this.onTracks,
    required this.onPlayPause,
    required this.onSeekBy,
    required this.onSeekTo,
    required this.onTouch,
  });

  final String title;
  final PlayerState state;
  final FocusNode playNode;
  final FocusNode tracksNode;
  final VoidCallback? onTracks;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeekBy;
  final ValueChanged<Duration> onSeekTo;
  final VoidCallback onTouch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<LumioColors>() ?? LumioColors.dark;
    final big = MediaQuery.sizeOf(context).width >= 1280;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.85),
          ],
          stops: const [0, 0.25, 0.6, 1],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: big ? 96 : LumioSpacing.lg,
            vertical: LumioSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colors.text,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoundButton(
                    icon: Icons.replay_10,
                    label: 'Reculer de 10 secondes',
                    size: big ? 88 : 56,
                    onPressed: () => onSeekBy(-seekStep),
                  ),
                  const SizedBox(width: LumioSpacing.lg),
                  _RoundButton(
                    focusNode: playNode,
                    icon: state.isPlaying ? Icons.pause : Icons.play_arrow,
                    label: state.isPlaying ? 'Pause' : 'Lecture',
                    size: big ? 128 : 72,
                    primary: true,
                    onPressed: onPlayPause,
                  ),
                  const SizedBox(width: LumioSpacing.lg),
                  _RoundButton(
                    icon: Icons.forward_10,
                    label: 'Avancer de 10 secondes',
                    size: big ? 88 : 56,
                    onPressed: () => onSeekBy(seekStep),
                  ),
                  if (onTracks != null) ...[
                    const SizedBox(width: LumioSpacing.lg),
                    _RoundButton(
                      focusNode: tracksNode,
                      icon: Icons.subtitles,
                      label: 'Pistes et sous-titres',
                      size: big ? 88 : 56,
                      onPressed: onTracks!,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: LumioSpacing.lg),
              _ProgressBar(
                state: state,
                big: big,
                onSeekBy: onSeekBy,
                onSeekTo: onSeekTo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatefulWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.size,
    required this.onPressed,
    this.primary = false,
    this.focusNode,
  });

  final IconData icon;
  final String label;
  final double size;
  final bool primary;
  final VoidCallback onPressed;
  final FocusNode? focusNode;

  @override
  State<_RoundButton> createState() => _RoundButtonState();
}

class _RoundButtonState extends State<_RoundButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<LumioColors>() ?? LumioColors.dark;
    final reduce = MediaQuery.of(context).disableAnimations;
    return Semantics(
      button: true,
      label: widget.label,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          focusNode: widget.focusNode,
          onShowFocusHighlight: (v) => setState(() => _focused = v),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed();
                return null;
              },
            ),
          },
          child: GestureDetector(
            onTap: widget.onPressed,
            child: AnimatedScale(
              scale: _focused ? 1.06 : 1,
              duration: reduce ? Duration.zero : LumioMotion.focus,
              child: AnimatedContainer(
                duration: reduce ? Duration.zero : LumioMotion.focus,
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.primary ? colors.accent : colors.surfaceFocus,
                  border: Border.all(
                    color: _focused ? colors.focusRing : Colors.transparent,
                    width: lumioFocusWidth,
                  ),
                ),
                child: Icon(
                  widget.icon,
                  size: widget.size * 0.5,
                  color: widget.primary ? colors.onAccent : colors.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatefulWidget {
  const _ProgressBar({
    required this.state,
    required this.big,
    required this.onSeekBy,
    required this.onSeekTo,
  });

  final PlayerState state;
  final bool big;
  final ValueChanged<Duration> onSeekBy;
  final ValueChanged<Duration> onSeekTo;

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  bool _focused = false;

  void _seekFromDx(double dx, double width) {
    final total = widget.state.duration;
    if (total <= Duration.zero || width <= 0) return;
    final f = (dx / width).clamp(0.0, 1.0);
    widget.onSeekTo(Duration(milliseconds: (total.inMilliseconds * f).round()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<LumioColors>() ?? LumioColors.dark;
    final st = widget.state;
    final total = st.duration.inMilliseconds;
    double frac(Duration d) =>
        total <= 0 ? 0 : (d.inMilliseconds / total).clamp(0.0, 1.0);
    final track = widget.big ? 12.0 : 8.0;
    final handle = widget.big ? 32.0 : 20.0;
    final text = theme.textTheme.titleMedium?.copyWith(color: colors.text);
    return Row(
      children: [
        Text(formatClock(st.position), style: text),
        const SizedBox(width: LumioSpacing.md),
        Expanded(
          child: Semantics(
            slider: true,
            label: 'Position de lecture',
            value: formatClock(st.position),
            child: Focus(
              onFocusChange: (v) => setState(() => _focused = v),
              onKeyEvent: (node, e) {
                if (e is KeyUpEvent) return KeyEventResult.ignored;
                if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  widget.onSeekBy(-seekStep);
                  return KeyEventResult.handled;
                }
                if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
                  widget.onSeekBy(seekStep);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => _seekFromDx(d.localPosition.dx, w),
                    onHorizontalDragUpdate: (d) =>
                        _seekFromDx(d.localPosition.dx, w),
                    child: SizedBox(
                      height: handle + 2 * lumioFocusWidth,
                      child: Stack(
                        alignment: AlignmentDirectional.centerStart,
                        clipBehavior: Clip.none,
                        children: [
                          _bar(w, track, colors.outline, 1),
                          _bar(w, track, colors.textMuted, frac(st.buffered)),
                          _bar(w, track, colors.accent, frac(st.position)),
                          PositionedDirectional(
                            start: (w - handle) * frac(st.position),
                            child: AnimatedContainer(
                              duration: LumioMotion.focus,
                              width: handle,
                              height: handle,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.accent,
                                border: Border.all(
                                  color: _focused
                                      ? colors.focusRing
                                      : Colors.transparent,
                                  width: lumioFocusWidth,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: LumioSpacing.md),
        Text(formatClock(st.duration), style: text),
      ],
    );
  }

  Widget _bar(double w, double h, Color color, double f) => Container(
    width: w * f,
    height: h,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(h / 2),
    ),
  );
}
