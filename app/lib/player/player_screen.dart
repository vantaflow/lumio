import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/features/cast/cast_button.dart';
import 'package:lumio/features/cast/player_cast.dart';
import 'package:lumio/features/settings/settings_providers.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/data/progress_repository.dart';
import 'package:lumio/data/sync_providers.dart';
import 'package:lumio/player/next_episode_overlay.dart';
import 'package:lumio/player/play_router.dart' show LocalFileSource;
import 'package:lumio/player/playback_events.dart';
import 'package:lumio/player/playback_events_provider.dart';
import 'package:lumio/player/player_controller.dart';
import 'package:lumio/player/subtitle_style.dart';
import 'package:lumio/player/tracks_controller.dart';
import 'package:lumio/player/tracks_panel.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/torrent/ip_warning_dialog.dart';
import 'package:lumio/torrent/network_watcher.dart';
import 'package:lumio/torrent/torrent_engine.dart' show TorrentStatus;
import 'package:lumio/torrent/torrent_overlay.dart';
import 'package:lumio/torrent/torrent_playback.dart';
import 'package:lumio/torrent/torrent_providers.dart';
import 'package:lumio/ui/common/state_view.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart' hide Video;
import 'package:lumio_core/lumio_core.dart' as core show Video;
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
    this.profileId = defaultProfileId,
    this.videoId,
    this.meta,
    this.resolveNext,
    this.resolveNextRanked,
    this.fallbacks = const [],
    this.local,
    this.subtitles = const [],
    this.allowPrivateForAddon,
    this.videoBuilder,
    this.tracksBackend,
    this.castDiscover,
    this.castSessionFactory,
    this.castEnabled,
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

  /// Profil dont la progression est enregistrée.
  final String profileId;

  /// Identifiant de l'épisode lu (`tt1:1:2`) ; par défaut [metaId] (film).
  final String? videoId;

  /// Fiche du titre, pour trouver l'épisode suivant.
  final Meta? meta;

  /// Résout le flux de l'épisode suivant (fournie par l'appelant) ; `null`
  /// en retour : « Épisode suivant indisponible ».
  final Future<StreamItem?> Function(core.Video next)? resolveNext;

  /// Variante de [resolveNext] qui rend tous les flux classés : les suivants
  /// servent de secours si le premier échoue avant la première image.
  final Future<List<StreamItem>> Function(core.Video next)? resolveNextRanked;

  /// Sources de secours de [item] (lecture automatique) : essayées dans
  /// l'ordre si [item] échoue avant la première image.
  final List<StreamItem> fallbacks;

  /// [item] est un fichier d'un dossier local accordé : lu en `file://` par
  /// le chemin interne de [routePlayback], seulement pour [item] lui-même.
  final LocalFileSource? local;

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

  /// Découverte des appareils de diffusion (tests) ; par défaut SSDP.
  @visibleForTesting
  final Stream<CastDevice> Function()? castDiscover;

  /// Fabrique de session de cast (tests).
  @visibleForTesting
  final CastSession Function(CastDevice, CastSource, String)?
  castSessionFactory;

  /// Force l'affichage du bouton Cast (tests) ; par défaut selon la plateforme.
  @visibleForTesting
  final bool? castEnabled;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with WidgetsBindingObserver {
  late final PlayerController _ctl;
  final _root = FocusNode(debugLabel: 'player-root');
  final _playNode = FocusNode(debugLabel: 'player-play');
  final _tracksNode = FocusNode(debugLabel: 'player-tracks');
  TracksController? _tracks;
  bool _panel = false;
  Timer? _hide;
  bool _controls = true;
  late String? _videoId = widget.videoId ?? widget.metaId;
  late String _title = widget.item.title;
  ProgressRecorder? _recorder;
  Duration? _credits;
  bool _creditsRead = false;
  bool _offerDone = false;
  bool _showNext = false;
  bool _switching = false;
  bool _disposed = false;

  /// Bus d'événements de lecture (lu dans initState : `ref` est inutilisable
  /// dans dispose) ; [_announced] = un `start` a été émis sans `stop`.
  late final PlaybackEvents _events;
  bool _announced = false;

  /// Lecture de torrent en cours (créée au premier flux torrent) et dernier
  /// statut pour la superposition sources/débit.
  TorrentPlayback? _torrent;
  bool _torrentActive = false;
  int _torrentToken = 0;
  StreamItem? _current;
  final _torrentStatus = ValueNotifier<TorrentStatus?>(null);
  NetworkWatcher? _watcher;
  late final PlayerCast _cast;

  core.Video? get _next {
    final m = widget.meta;
    final id = _videoId;
    if (m == null || id == null || widget.resolveNext == null) return null;
    return nextEpisode(m, id);
  }

  ProgressRecorder? _newRecorder() {
    final metaId = widget.metaId;
    final id = _videoId;
    if (metaId == null || id == null) return null;
    final nextId = _next?.id;
    final certification = widget.meta?.certification;
    // Lu ici : `ref` n'est plus utilisable quand dispose() écrit la sortie.
    final repo = ref.read(progressRepositoryProvider);
    return ProgressRecorder(
      onError: () => _tellL((l) => l.progressNotSaved),
      save: (pos, dur) => repo.save(
        widget.profileId,
        metaId,
        id,
        pos,
        dur,
        nextVideoId: nextId,
        certification: certification,
      ),
    );
  }

  /// Ouvre [item] à la position de reprise enregistrée (au-delà de 2 %,
  /// jusqu'à 90 %), sinon depuis le début.
  Future<void> _openFrom(
    StreamItem item, {
    List<StreamItem> alternatives = const [],
  }) async {
    var start = Duration.zero;
    final id = _videoId;
    if (widget.metaId != null && id != null) {
      try {
        final e = await ref
            .read(progressRepositoryProvider)
            .get(widget.profileId, id);
        if (e != null) {
          start = ProgressRules.resumeAt(e.position, e.duration) ?? start;
        }
      } on Object {
        // Progression illisible : lecture depuis le début.
      }
    }
    if (_disposed) return;
    if (start > Duration.zero) _tellL((l) => l.resumeAt(formatClock(start)));
    if (alternatives.isEmpty) {
      await _openOne(item, start);
      return;
    }
    // Chaque source passe par le même chemin d'ouverture, donc par toutes
    // les gardes (adresse privée, VPN, avertissement IP une seule fois).
    final played = await _ctl.playWithFallback(
      [item, ...alternatives],
      opener: (s) => _openOne(s, start),
      onAbandon: (_) => _abandonSource(),
    );
    if (_disposed || played == null) return;
    if (!identical(played, item) && mounted) {
      setState(() => _title = played.title);
      _tell(context.l10n.playingFallback(played.title));
    }
  }

  /// Abandonne la source en cours (trop longue à démarrer) : ses retours
  /// tardifs sont ignorés (jeton) et le torrent est libéré.
  Future<void> _abandonSource() async {
    _torrentToken++;
    _torrentActive = false;
    _watcher?.stop();
    _watcher = null;
    try {
      await _torrent?.release().timeout(const Duration(seconds: 10));
    } on Object {
      // Libération trop longue ou en échec : on passe à la suite.
    }
  }

  /// Ouvre une seule source : torrent préparé par le moteur, lien direct par
  /// le contrôleur.
  Future<void> _openOne(StreamItem item, Duration start) async {
    _current = item;
    if (item.isTorrent) {
      await _openTorrent(item, start);
      return;
    }
    _torrentToken++;
    _torrentActive = false;
    _watcher?.stop();
    unawaited(_torrent?.release());
    await _ctl.open(
      item,
      allowPrivate:
          widget.allowPrivateForAddon?.call(item.addonId) ??
          widget.allowPrivate,
      local: identical(item, widget.item) ? widget.local : null,
      start: start,
    );
  }

  /// Torrent : démarre le moteur, attend une source, puis ouvre l'URL locale
  /// du moteur par le chemin interne `trustedLocal` (jamais une URL d'addon).
  Future<void> _openTorrent(StreamItem item, Duration start) async {
    final torrent = _torrent ??= ref.read(torrentPlaybackFactoryProvider)();
    final token = ++_torrentToken;
    _torrentActive = true; // lu au prochain build (peut venir d'initState)
    _torrentStatus.value = null;
    _ctl.showOpening();
    // Confidentialité : avertissement IP (une fois), VPN exigé ou rappel.
    final privacy = ref.read(torrentPrivacyProvider);
    try {
      if (!await privacy.ipWarningAccepted()) {
        if (_disposed || !mounted || token != _torrentToken) return;
        final accepted = await showIpWarningDialog(context);
        if (_disposed || token != _torrentToken) return;
        if (!accepted) {
          _failTorrent(token, (l) => l.torrentIpWarningDeclined);
          return;
        }
        try {
          await privacy.acceptIpWarning();
        } on Object {
          // Non mémorisé : la question sera reposée au prochain torrent.
        }
        if (_disposed || token != _torrentToken) return;
      }
      final decision = await privacy.evaluate();
      if (_disposed || token != _torrentToken) return;
      if (decision is GuardStop) {
        _failTorrent(token, (l) => l.torrentVpnRequired);
        return;
      }
      if (decision is GuardWarnNoVpn) _tellL((l) => l.torrentNoVpnReminder);
    } on Object {
      // Réglages illisibles : on ne démarre pas (échec fermé).
      _failTorrent(token, (l) => l.torrentFailed);
      return;
    }
    _watchNetwork(torrent, token, privacy);
    final Uri url;
    try {
      url = await torrent.prepare(
        item,
        onStatus: (s) {
          if (!_disposed && token == _torrentToken) _torrentStatus.value = s;
        },
      );
    } on TorrentCancelledException {
      return;
    } on NoPeersException {
      _failTorrent(token, (l) => l.torrentNoPeers, fallbackable: true);
      return;
    } on InsufficientStorageException {
      _failTorrent(token, (l) => l.torrentInsufficientStorage);
      return;
    } on NoStreamableFileException {
      _failTorrent(token, (l) => l.torrentNoFile, fallbackable: true);
      return;
    } on VpnRequiredException {
      _failTorrent(token, (l) => l.torrentVpnRequired);
      return;
    } on Object {
      _failTorrent(token, (l) => l.torrentFailed, fallbackable: true);
      return;
    }
    if (_disposed || token != _torrentToken) return;
    await _ctl.open(
      StreamItem(
        addonId: item.addonId,
        title: item.title,
        url: url,
        language: item.language,
        sizeBytes: item.sizeBytes,
      ),
      trustedLocal: true,
      start: start,
    );
  }

  /// Surveille les interfaces pendant le torrent : si le VPN exigé tombe, le
  /// torrent est arrêté (données supprimées) et un message est affiché.
  void _watchNetwork(
    TorrentPlayback torrent,
    int token,
    TorrentPrivacy privacy,
  ) {
    _watcher?.stop();
    _watcher = null;
    unawaited(
      privacy.guard().then((g) {
        if (!g.enforcing || _disposed || token != _torrentToken) return;
        _watcher = NetworkWatcher(
          privacy: privacy,
          onStop: (_) {
            if (_disposed || token != _torrentToken) return;
            _torrentToken++;
            _torrentActive = false;
            unawaited(torrent.release());
            unawaited(_cast.stop(resume: false)); // plus rien à relayer
            try {
              unawaited(_ctl.player.stop().catchError((Object _) {}));
            } on Object {
              // Lecteur indisponible : le message d'erreur suffit.
            }
            if (mounted) _ctl.fail(context.l10n.torrentVpnLost);
          },
        )..start();
      }),
    );
  }

  void _failTorrent(
    int token,
    String Function(AppLocalizations l) message, {
    bool fallbackable = false,
  }) {
    if (_disposed || !mounted || token != _torrentToken) return;
    _watcher?.stop();
    _ctl.fail(message(context.l10n), fallbackable: fallbackable);
  }

  bool get _castShown => widget.castEnabled ?? castPlatformSupported;

  /// Bouton Cast : choix de l'appareil puis transfert de la lecture.
  Future<void> _openCast() async {
    _hide?.cancel();
    if (_ctl.castSource == null) {
      _tellL((l) => l.castUnsupported);
      return;
    }
    final device = await showCastPicker(context, discover: widget.castDiscover);
    if (device == null || !mounted || _disposed) {
      _armHide();
      return;
    }
    final r = await _cast.start(device, _title);
    if (!mounted || _disposed) return;
    switch (r) {
      case CastStart.started:
        break;
      case CastStart.unsupported:
        _tellL((l) => l.castUnsupported);
      case CastStart.noNetwork:
        _tellL((l) => l.castNetworkError);
      case CastStart.failed:
        _tellL((l) => l.castFailed);
    }
  }

  /// « Réessayer » : un torrent repart de la préparation, un lien direct
  /// rouvre à la dernière position.
  Future<void> _retry() async {
    final item = _current;
    if (item != null && item.isTorrent) {
      await _openTorrent(item, _ctl.state.position);
    } else {
      await _ctl.retry();
    }
  }

  /// Lit les chapitres une fois la durée connue (pas avant : le filtre des
  /// génériques d'ouverture en dépend).
  Future<void> _loadCredits() async {
    if (_next == null) return;
    try {
      _credits = await _ctl.creditsStart();
    } on Object {
      _credits = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _ctl =
        widget.controller ??
        PlayerController(proxy: () => ref.read(localProxyProvider.future));
    _ctl.stateListenable.addListener(_onState);
    _events = ref.read(playbackEventsProvider);
    WidgetsBinding.instance.addObserver(this);
    _cast = PlayerCast(
      source: () => _ctl.castSource,
      position: () => _ctl.state.position,
      pauseLocal: () => _ctl.player.pause(),
      resumeLocal: (at) async {
        if (_disposed) return;
        await _ctl.player.seek(at);
        await _ctl.player.play();
        _showControls(focusPlay: true);
      },
      onLost: () => _tellL((l) => l.castLost),
      createSession: widget.castSessionFactory,
    )..addListener(() => mounted ? setState(() {}) : null);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _recorder = _newRecorder();
    unawaited(_openFrom(widget.item, alternatives: widget.fallbacks));
    unawaited(_initTracks());
    _armHide();
  }

  /// Mise en arrière-plan : le cast continue (pause de l'application = pas
  /// de pause de la télévision). Fermeture de l'application (`detached`) : le
  /// cast et son serveur sont arrêtés.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(_cast.stop(resume: false));
    }
  }

  void _tellL(String Function(AppLocalizations l) message) {
    if (!mounted) return;
    _tell(message(context.l10n));
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
        drift.onSaveError = (_) => _tellL((l) => l.settingsNotSaved);
        store = drift;
      }
      style = await styleStore.load();
    } on Object {
      _tellL((l) => l.settingsUnavailable);
    }
    // Langues par défaut des réglages (best-effort : sans elles, le moteur
    // garde ses pistes par défaut).
    String? defaultAudio;
    String? defaultSubs;
    try {
      defaultAudio = await ref.read(defaultAudioLangProvider.future);
      defaultSubs = await ref.read(defaultSubtitleLangProvider.future);
    } on Object {
      // Pas de langue par défaut.
    }
    if (!mounted) return;
    final l10n = context.l10n;
    final fetcher = IoHttpFetcher();
    final c = TracksController(
      backend:
          widget.tracksBackend?.call(_ctl) ??
          MediaKitTracksBackend(_ctl.player, l10n: l10n),
      l10n: l10n,
      defaultAudioLang: defaultAudio,
      defaultSubtitleLang: defaultSubs,
      store: store,
      profileId: ref.read(currentProfileIdProvider),
      metaId: widget.metaId ?? '',
      addonSubtitles: widget.subtitles,
      style: style,
      onStyleChanged: (s) => unawaited(
        styleStore.save(s).catchError((Object _) {
          _tellL((l) => l.settingsNotSaved);
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
      _tellL((l) => l.subtitleSettingsNotApplied);
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
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _announce(PlaybackAction.stop);
    final st = _ctl.state;
    // Cast en cours : la position utile est celle de l'appareil, pas celle du
    // lecteur local (en pause depuis le début du cast).
    final castPos = _cast.active ? _cast.lastPosition : null;
    _recorder?.flush(castPos ?? st.position, st.duration, force: true);
    _hide?.cancel();
    _cast.dispose(); // ferme le serveur de cast et arrête l'appareil
    _ctl.stateListenable.removeListener(_onState);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _root.dispose();
    _playNode.dispose();
    _tracksNode.dispose();
    _tracks?.dispose();
    // Arrêt du torrent et suppression de ses données à la sortie.
    _watcher?.stop();
    unawaited(_torrent?.release());
    _torrentStatus.dispose();
    if (widget.controller == null) unawaited(_ctl.dispose());
    super.dispose();
  }

  /// Signale le cycle de lecture aux écouteurs (suivi…). Rien sans identifiant
  /// de titre ; `stop` seulement après un `start`.
  void _announce(PlaybackAction a, {double? progress}) {
    if (widget.metaId == null) return;
    if (a == PlaybackAction.stop) {
      if (!_announced) return;
      _announced = false;
    } else {
      _announced = true;
    }
    final st = _ctl.state;
    final pct =
        progress ??
        (st.duration > Duration.zero
            ? st.position.inMilliseconds * 100 / st.duration.inMilliseconds
            : 0.0);
    _events.emit(
      PlaybackEvent(
        action: a,
        profileId: widget.profileId,
        metaId: widget.metaId,
        videoId: _videoId,
        progress: pct.clamp(0, 100).toDouble(),
      ),
    );
  }

  PlayerPhase? _lastPhase;
  void _onState() {
    final st = _ctl.state;
    final p = st.phase;
    if (p == PlayerPhase.playing) {
      _recorder?.tick(st.position, st.duration);
      if (!_creditsRead && st.duration > Duration.zero) {
        _creditsRead = true;
        unawaited(_loadCredits());
      }
      _maybeOfferNext(st);
    }
    // Retour en arrière avant le point de déclenchement : l'invite s'efface
    // (elle pourra revenir).
    if (_showNext &&
        !_switching &&
        p != PlayerPhase.ended &&
        !shouldOfferNext(st.position, st.duration, creditsStart: _credits)) {
      _showNext = false;
      _offerDone = false;
      setState(() {});
    }
    if (p == _lastPhase) return;
    final before = _lastPhase;
    _lastPhase = p;
    if (p == PlayerPhase.playing &&
        !(before == PlayerPhase.buffering && _announced)) {
      _announce(PlaybackAction.start);
    } else if ((p == PlayerPhase.paused || p == PlayerPhase.failed) &&
        _announced) {
      _announce(PlaybackAction.pause);
    } else if (p == PlayerPhase.ended) {
      _announce(PlaybackAction.stop);
    }
    if (p == PlayerPhase.paused || p == PlayerPhase.ended) {
      _recorder?.flush(st.position, st.duration);
      // Envoi rapide de la progression aux autres appareils (nul sans backend).
      if (p == PlayerPhase.paused && mounted) {
        ref.read(syncServiceProvider)?.syncSoon();
      }
    }
    if (p == PlayerPhase.ended && !_switching) _offerNext();
    if (p == PlayerPhase.failed || p == PlayerPhase.paused) {
      _showControls();
    } else {
      _armHide();
    }
  }

  /// Fin de déplacement : enregistre la position visée (la position du
  /// moteur n'est pas encore à jour).
  void _flushAfterSeek(Duration target) {
    final st = _ctl.state;
    var t = target < Duration.zero ? Duration.zero : target;
    if (st.duration > Duration.zero && t > st.duration) t = st.duration;
    _recorder?.flush(t, st.duration);
  }

  void _maybeOfferNext(PlayerState st) {
    if (_offerDone || _showNext || _next == null) return;
    if (shouldOfferNext(st.position, st.duration, creditsStart: _credits)) {
      _offerNext();
    }
  }

  void _offerNext() {
    if (_next == null || _showNext || _offerDone) return;
    _offerDone = true;
    _hide?.cancel();
    setState(() => _showNext = true);
  }

  void _cancelNext() {
    setState(() => _showNext = false);
    _root.requestFocus();
  }

  /// « Lire maintenant » (ou fin du décompte) marque l'épisode courant comme
  /// vu (écrit à sa durée) : l'utilisateur passe à la suite. Le suivant n'est
  /// ajouté à « Continuer » que s'il n'a aucune progression ; un suivant déjà
  /// vu n'est jamais réinitialisé. Résout et ouvre le
  /// suivant ; sans flux, message et lecture en cours conservée.
  Future<void> _playNext() async {
    final next = _next;
    final resolve = widget.resolveNext;
    if (next == null || resolve == null || _switching) return;
    _switching = true;
    setState(() => _showNext = false);
    StreamItem? item;
    var alternatives = const <StreamItem>[];
    try {
      final ranked = widget.resolveNextRanked;
      if (ranked != null) {
        final list = await ranked(next);
        if (list.isNotEmpty) {
          item = list.first;
          alternatives = list.skip(1).take(2).toList();
        }
      } else {
        item = await resolve(next);
      }
    } on Object {
      item = null;
    }
    if (_disposed) return;
    if (item == null) {
      _switching = false;
      _tellL((l) => l.nextEpisodeUnavailable);
      _root.requestFocus();
      return;
    }
    // L'utilisateur passe à la suite : l'épisode est enregistré comme vu et
    // le suivant entre dans « Continuer ».
    final st = _ctl.state;
    _announce(PlaybackAction.stop, progress: 100);
    _recorder?.flush(st.duration, st.duration, force: true);
    setState(() {
      _videoId = next.id;
      _title = item!.title;
      _offerDone = false;
      _credits = null;
      _creditsRead = false;
      _recorder = _newRecorder();
    });
    _switching = false;
    _root.requestFocus();
    await _openFrom(item, alternatives: alternatives);
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
    if (_panel || _showNext || _cast.active) return KeyEventResult.ignored;
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
        _flushAfterSeek(_ctl.state.position - seekStep);
        _showControls();
      case PlayerKeyAction.seekForward:
        unawaited(_ctl.seekBy(seekStep));
        _flushAfterSeek(_ctl.state.position + seekStep);
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
    // Les messages d'erreur suivent la langue courante.
    if (widget.controller == null) _ctl.l10n = context.l10n;
    _tracks?.l10n = context.l10n;
    final colors =
        Theme.of(context).extension<LumioColors>() ?? LumioColors.dark;
    final fade = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : LumioMotion.panel;
    // Retour système : ferme d'abord le panneau ou la carte « Épisode
    // suivant » au lieu de quitter la lecture.
    return BackGuard(
      isOpen: _panel || _showNext,
      onClose: () => _panel ? _closePanel() : _cancelNext(),
      child: Scaffold(
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
                        label: context.l10n.buffering,
                        child: CircularProgressIndicator(color: colors.accent),
                      ),
                    ),
                  if (st.notice != null && !failed)
                    Align(
                      alignment: const Alignment(0, 0.35),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          st.notice!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  if (_cast.active)
                    CastBar(
                      title: _title,
                      deviceName: _cast.device!.friendlyName,
                      paused: _cast.paused,
                      onPlayPause: () => unawaited(_cast.togglePause()),
                      onSeekBack: () => unawaited(_cast.seekBy(-seekStep)),
                      onSeekForward: () => unawaited(_cast.seekBy(seekStep)),
                      onStop: () => unawaited(_cast.stop()),
                    )
                  else if (failed)
                    _FailureView(
                      message: st.error ?? context.l10n.failGeneric,
                      onRetry: _retry,
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
                            title: _title,
                            state: st,
                            playNode: _playNode,
                            tracksNode: _tracksNode,
                            onTracks: _tracks == null ? null : _openPanel,
                            onCast: _castShown
                                ? () => unawaited(_openCast())
                                : null,
                            onPlayPause: () {
                              unawaited(_ctl.playPause());
                              _armHide();
                            },
                            onSeekBy: (d) {
                              unawaited(_ctl.seekBy(d));
                              _flushAfterSeek(_ctl.state.position + d);
                              _armHide();
                            },
                            onSeekTo: (t) {
                              unawaited(_ctl.seekTo(t));
                              _flushAfterSeek(t);
                              _armHide();
                            },
                            onTouch: () => _showControls(),
                          ),
                        ),
                      ),
                    ),
                  if (_torrentActive && !failed)
                    PositionedDirectional(
                      top: LumioSpacing.lg,
                      end: LumioSpacing.lg,
                      child: ValueListenableBuilder<TorrentStatus?>(
                        valueListenable: _torrentStatus,
                        builder: (context, ts, child) {
                          final show =
                              _controls ||
                              st.phase == PlayerPhase.opening ||
                              st.phase == PlayerPhase.buffering ||
                              ts?.error != null;
                          return show ? child! : const SizedBox.shrink();
                        },
                        child: TorrentOverlay(status: _torrentStatus),
                      ),
                    ),
                  if (_showNext && !failed && _next != null)
                    NextEpisodeOverlay(
                      key: ValueKey(_videoId),
                      paused: st.phase == PlayerPhase.paused,
                      episodeTitle: _next!.title,
                      onPlayNow: () => unawaited(_playNext()),
                      onCancel: _cancelNext,
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
                  child: Text(context.l10n.chooseOtherSource),
                ),
                TextButton(onPressed: onBack, child: Text(context.l10n.back)),
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
    required this.onCast,
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
  final VoidCallback? onCast;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeekBy;
  final ValueChanged<Duration> onSeekTo;
  final VoidCallback onTouch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<LumioColors>() ?? LumioColors.dark;
    final big = MediaQuery.sizeOf(context).width >= 1280;
    // Téléphone : écart réduit pour que cinq boutons tiennent sur la ligne.
    final gap = MediaQuery.sizeOf(context).width < 600
        ? LumioSpacing.sm
        : LumioSpacing.lg;
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
                    label: context.l10n.seekBack10,
                    size: big ? 88 : 56,
                    onPressed: () => onSeekBy(-seekStep),
                  ),
                  SizedBox(width: gap),
                  _RoundButton(
                    focusNode: playNode,
                    icon: state.isPlaying ? Icons.pause : Icons.play_arrow,
                    label: state.isPlaying
                        ? context.l10n.pause
                        : context.l10n.play,
                    size: big ? 128 : 72,
                    primary: true,
                    onPressed: onPlayPause,
                  ),
                  SizedBox(width: gap),
                  _RoundButton(
                    icon: Icons.forward_10,
                    label: context.l10n.seekForward10,
                    size: big ? 88 : 56,
                    onPressed: () => onSeekBy(seekStep),
                  ),
                  if (onTracks != null) ...[
                    SizedBox(width: gap),
                    _RoundButton(
                      focusNode: tracksNode,
                      icon: Icons.subtitles,
                      label: context.l10n.tracksAndSubtitles,
                      size: big ? 88 : 56,
                      onPressed: onTracks!,
                    ),
                  ],
                  if (onCast != null) ...[
                    SizedBox(width: gap),
                    _RoundButton(
                      icon: Icons.cast,
                      label: context.l10n.castTooltip,
                      size: big ? 88 : 56,
                      onPressed: onCast!,
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
            label: context.l10n.seekBar,
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
                      height: math.max(
                        handle + 2 * lumioFocusWidth,
                        lumioTouchMin,
                      ),
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
                              duration: MediaQuery.of(context).disableAnimations
                                  ? Duration.zero
                                  : LumioMotion.focus,
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
