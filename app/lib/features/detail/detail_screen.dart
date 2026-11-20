import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/l10n/app_localizations_fr.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/features/addons/health_providers.dart';
import 'package:lumio/features/detail/playback_service.dart';
import 'package:lumio/features/detail/streams_list.dart';
import 'package:lumio/data/jellyfin_repository.dart' show jellyfinSourceKind;
import 'package:lumio/data/local_library.dart' show localSourceKind;
import 'package:lumio/features/jellyfin/jellyfin_screen.dart'
    show openJellyfinDetail;
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/features/local/local_screen.dart' show openLocalDetail;
import 'package:lumio/features/search/search_providers.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/common/state_view.dart';
import 'package:lumio/features/home/tv_cards.dart' show TvArtwork;
import 'package:lumio/ui/common/tv_dialogs.dart' show TvPanel, tvScrim;
import 'package:lumio/ui/common/tv_screen.dart' show tvMargin;
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/ui/focus/tv_row.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart' hide Video;
import 'package:lumio_core/lumio_core.dart' as core show Video;

/// Clé d'écran de la mémoire du focus.
const detailRouteKey = 'detail';

/// Ouvre la fiche de [item] (accueil, recherche, « Ma liste »).
Future<void> openDetail(BuildContext context, MetaPreview item) =>
    switch (item.sourceKind) {
      localSourceKind => openLocalDetail(context, item),
      jellyfinSourceKind => openJellyfinDetail(context, item),
      _ => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => DetailScreen(preview: item)),
      ),
    };

enum _Phase { loading, ready, refused, error }

/// Fiche d'un titre : affiche, synopsis, saisons et épisodes (vu / non vu),
/// liste des flux et « Ma liste » (stories 1.3, 1.4, 3.4).
class DetailScreen extends ConsumerStatefulWidget {
  const DetailScreen({super.key, required this.preview});

  final MetaPreview preview;

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  _Phase _phase = _Phase.loading;
  Meta? _meta;
  String? _videoId;
  int? _season;
  Set<String> _watched = const {};
  List<StreamGroup> _groups = const [];
  bool _loadingStreams = false;
  int _streamToken = 0;
  StreamSubscription<StreamGroup>? _streamSub;
  StreamSubscription<Set<String>>? _watchedSub;
  bool _disposed = false;

  PlaybackLauncher get _launcher => ref.read(playbackLauncherProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _disposed = true;
    _streamSub?.cancel();
    _watchedSub?.cancel();
    super.dispose();
  }

  bool _allowed(Meta? meta) => contentAllowed(
    ref.read(currentProfileProvider),
    [meta?.certification, widget.preview.certification],
  );

  Future<void> _load() async {
    setState(() => _phase = _Phase.loading);
    final pre = widget.preview.certification;
    if (pre != null && !_allowed(null)) {
      // Refus sans réseau : la certification du catalogue suffit.
      setState(() => _phase = _Phase.refused);
      return;
    }
    final Meta meta;
    try {
      meta = await _launcher.loadMeta(widget.preview);
    } on Object {
      if (_disposed) return;
      setState(() => _phase = _Phase.error);
      return;
    }
    if (_disposed) return;
    if (!_allowed(meta)) {
      setState(() => _phase = _Phase.refused);
      return;
    }
    final profileId = ref.read(currentProfileIdProvider);
    final repo = ref.read(progressRepositoryProvider);
    try {
      _watched = await repo.watchWatched(profileId, meta.id).first;
    } on Object {
      _watched = const {};
    }
    if (_disposed) return;
    _watchedSub = repo.watchWatched(profileId, meta.id).listen((w) {
      if (mounted) setState(() => _watched = w);
    }, onError: (_) {});
    final episodes = _episodes(meta);
    String? video;
    final isMovie =
        meta.type == 'movie' || (episodes.isEmpty && meta.type != 'series');
    if (!isMovie) {
      final first =
          episodes.where((v) => !_watched.contains(v.id)).firstOrNull ??
          episodes.firstOrNull;
      video = first?.id;
      _season = first == null ? null : (first.season ?? -1);
    } else {
      video = meta.id;
    }
    setState(() {
      _meta = meta;
      _videoId = video;
      _phase = _Phase.ready;
    });
    if (video != null) _loadStreams(video);
  }

  List<core.Video> _episodes(Meta m) => m.videos;

  void _loadStreams(String videoId) {
    final meta = _meta;
    if (meta == null) return;
    _streamSub?.cancel();
    final token = ++_streamToken;
    setState(() {
      _groups = const [];
      _loadingStreams = true;
    });
    _streamSub = _launcher
        .loadStreams(meta.type, videoId)
        .listen(
          (g) {
            if (token != _streamToken || !mounted) return;
            setState(() => _groups = [..._groups, g]);
          },
          onDone: () {
            if (token != _streamToken || !mounted) return;
            setState(() => _loadingStreams = false);
          },
          onError: (_) {
            if (token != _streamToken || !mounted) return;
            setState(() => _loadingStreams = false);
          },
        );
  }

  void _selectEpisode(core.Video v) {
    if (_videoId == v.id) return;
    setState(() => _videoId = v.id);
    _loadStreams(v.id);
  }

  Future<void> _play(
    StreamItem s, {
    List<StreamItem> fallbacks = const [],
  }) async {
    final meta = _meta;
    final id = _videoId;
    if (meta == null || id == null) return;
    await _launcher.play(
      context,
      meta: meta,
      videoId: id,
      stream: s,
      fallbacks: fallbacks,
    );
  }

  Future<void> _toggleList(bool inList) async {
    final repo = ref.read(libraryRepositoryProvider);
    final profileId = ref.read(currentProfileIdProvider);
    final p = widget.preview;
    final m = _meta;
    try {
      if (inList) {
        await repo.remove(profileId, p.id);
      } else {
        await repo.add(
          profileId,
          MetaPreview(
            id: p.id,
            type: p.type,
            name: m?.name ?? p.name,
            poster: m?.poster ?? p.poster,
            releaseInfo: m?.releaseInfo ?? p.releaseInfo,
            certification: m?.certification ?? p.certification,
            sourceAddonId: p.sourceAddonId,
            sourceKind: p.sourceKind,
          ),
        );
      }
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(context.l10n.listUpdateFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return TvScaffold(
      child: Scaffold(
        body: switch (_phase) {
          _Phase.loading => const SafeArea(child: StateView.loading()),
          // P24 : fiche indisponible, panneau sur le voile.
          _Phase.error => _unavailable(context),
          _Phase.refused => SafeArea(
            child: StateView.empty(message: context.l10n.notAllowedForProfile),
          ),
          _Phase.ready => _body(context, _meta!),
        },
      ),
    );
  }

  Widget _unavailable(BuildContext context) {
    final l = context.l10n;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: tvScrim),
        TvPanel(
          width: 800,
          contentPadding: EdgeInsets.zero,
          title: l.detailLoadError,
          onBack: () => Navigator.of(context).maybePop(),
          actions: [
            TvButton(
              kind: TvButtonKind.secondary,
              label: l.back,
              height: 76,
              horizontalPadding: 40,
              fontSize: 28,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            TvButton(
              autofocus: true,
              label: l.retry,
              height: 76,
              horizontalPadding: 40,
              fontSize: 28,
              onPressed: _load,
            ),
          ],
          children: [
            Text(
              l.detailUnavailableBody,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 30,
                height: 1.4,
                color: Color(0xFFC9D0DA),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _body(BuildContext context, Meta meta) {
    final prefs = ref.watch(streamPrefsProvider).value ?? const StreamPrefs();
    final addons = ref.watch(activeAddonsProvider);
    final names = {for (final a in addons) a.storageId: a.manifest.name};
    final order = [for (final a in addons) a.storageId];
    final groups = [..._groups]
      ..sort(
        (a, b) => order.indexOf(a.addonId).compareTo(order.indexOf(b.addonId)),
      );
    final tracker = ref.watch(healthTrackerProvider);
    final ranked = StreamRanker.rank(
      [for (final g in groups) ...g.items],
      prefs,
      tracker,
    );
    final preferred = ranked.isEmpty ? null : ranked.first;
    final fallbacks = ranked.skip(1).take(maxFallbacks).toList();
    final inList =
        ref.watch(libraryProvider).value?.any((m) => m.id == meta.id) ?? false;
    // L'affiche n'est autorisée en réseau privé que si c'est celle du
    // catalogue (addon source privé) ; une affiche fournie par la fusion de
    // fiches (addon inconnu) reste en réseau public.
    final allowPoster =
        meta.poster != null &&
        meta.poster == widget.preview.poster &&
        ref
            .watch(searchPrivateSourcesProvider)
            .contains(widget.preview.sourceAddonId);
    final isSeries =
        meta.type != 'movie' &&
        (meta.type == 'series' || meta.videos.isNotEmpty);

    final buttons = _Buttons(
      inList: inList,
      canPlay: preferred != null && _videoId != null,
      stacked: isSeries,
      onPlay: () {
        if (preferred != null) _play(preferred, fallbacks: fallbacks);
      },
      onToggleList: () => _toggleList(inList),
    );
    final sources = _Sources(
      meta: meta,
      season: _season,
      videoId: _videoId,
      watched: _watched,
      onSeason: (s) => setState(() => _season = s),
      onEpisode: _selectEpisode,
      streams: StreamsList(
        groups: groups,
        addonNames: names,
        health:
            ref.watch(healthSnapshotProvider).value ??
            const <String, AddonHealth>{},
        loading: _loadingStreams,
        prefs: prefs,
        preferred: preferred,
        tracker: tracker,
        onSelect: _play,
        showCount: !isSeries,
        headerTop: isSeries ? 16 : 24,
      ),
      noEpisodes: meta.videos.isEmpty && meta.type == 'series',
    );
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 1500;
        final pinned = isSeries && c.maxWidth >= 900;
        final info = _Info(
          meta: meta,
          allowPrivate: allowPoster,
          // Fiche série : boutons sous le synopsis (TV40), épinglés en bas de
          // la colonne (jamais coupés, quelle que soit la hauteur du texte) ;
          // fiche film : en tête de la colonne des flux (TV06).
          buttons: !pinned && (isSeries || c.maxWidth < 900) ? buttons : null,
          compact: pinned,
        );
        if (c.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: wide ? 680 : 480,
                decoration: BoxDecoration(
                  // Maquettes TV06/TV40 : dégradé 180° #1B2A33 -> #0E1116.
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [const Color(0xFF1B2A33), context.lumio.bg],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          wide ? tvMargin : LumioSpacing.xl,
                          wide ? (pinned ? 56 : 80) : LumioSpacing.md,
                          wide ? 60 : LumioSpacing.lg,
                          pinned ? 0 : LumioSpacing.xl,
                        ),
                        child: info,
                      ),
                    ),
                    if (pinned)
                      Padding(
                        // 12 dp de marge autour des boutons : l'anneau de
                        // focus (8 dp) et l'échelle restent dans l'écran.
                        padding: EdgeInsets.fromLTRB(
                          (wide ? tvMargin : LumioSpacing.xl) - 12,
                          0,
                          0,
                          36,
                        ),
                        child: buttons,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 40 : 12,
                    wide ? (isSeries ? 72 : 68) : 0,
                    wide ? tvMargin : 0,
                    48,
                  ),
                  children: [if (!isSeries) buttons, sources],
                ),
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: LumioSpacing.xl),
          children: [
            Padding(
              padding: const EdgeInsets.all(LumioSpacing.md),
              child: info,
            ),
            sources,
          ],
        );
      },
    );
  }
}

/// Boutons « Lecture auto · meilleure source » et « + Ma liste » (TV06 : en
/// ligne en haut des flux ; TV40 : l'un sous l'autre sous le synopsis).
class _Buttons extends StatelessWidget {
  const _Buttons({
    required this.inList,
    required this.canPlay,
    required this.stacked,
    required this.onPlay,
    required this.onToggleList,
  });

  final bool inList;
  final bool canPlay;
  final bool stacked;
  final VoidCallback onPlay;
  final VoidCallback onToggleList;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final play = TvButton(
      key: const ValueKey('detail-play'),
      autofocus: canPlay,
      onPressed: canPlay ? onPlay : null,
      height: 72,
      horizontalPadding: stacked ? 28 : 36,
      fontSize: stacked ? 28 : 30,
      label: l.autoPlayBest,
    );
    final list = TvButton(
      key: const ValueKey('detail-list'),
      autofocus: !canPlay,
      onPressed: onToggleList,
      kind: TvButtonKind.secondary,
      weight: stacked ? null : FontWeight.w600,
      height: 72,
      horizontalPadding: stacked ? 40 : 32,
      fontSize: stacked ? 28 : 30,
      label: inList ? l.removeFromList : l.addToListShort,
    );
    if (stacked) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [play, const SizedBox(height: 16), list],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Wrap(spacing: 20, runSpacing: 16, children: [play, list]),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({
    required this.meta,
    required this.allowPrivate,
    required this.buttons,
    this.compact = false,
  });

  final Meta meta;
  final bool allowPrivate;
  final Widget? buttons;

  /// Colonne dont les boutons sont épinglés en bas : affiche, titre et
  /// synopsis réduits pour tenir au-dessus d'eux à 1080p.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final lumio = context.lumio;
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 1500;
    final line = [
      if (meta.releaseInfo != null) meta.releaseInfo!,
      if (meta.certification != null) meta.certification!,
      ...meta.genres.take(3),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Affiche 300 x 450, rayon 24 ; dégradé de repli sans affiche.
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: compact ? 240 : 300,
            height: compact ? 360 : 450,
            child: TvArtwork(
              seed: meta.id,
              url: meta.poster,
              allowPrivate: allowPrivate,
              width: compact ? 240 : 300,
              scrim: false,
              resize: false,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Semantics(
          header: true,
          child: Text(
            meta.name,
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineLarge?.copyWith(
              color: lumio.text,
              fontSize: wide ? 56 : null,
              height: 1.2,
            ),
          ),
        ),
        if (line.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            line,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: lumio.textMuted,
              fontSize: wide ? 26 : null,
            ),
          ),
        ],
        if (meta.description != null) ...[
          const SizedBox(height: 20),
          Text(
            meta.description!,
            maxLines: compact ? 4 : 6,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFFC9D0DA),
              fontSize: wide ? 26 : null,
              height: 1.45,
            ),
          ),
        ],
        ?buttons,
      ],
    );
  }
}

class _Sources extends StatelessWidget {
  const _Sources({
    required this.meta,
    required this.season,
    required this.videoId,
    required this.watched,
    required this.onSeason,
    required this.onEpisode,
    required this.streams,
    required this.noEpisodes,
  });

  final Meta meta;
  final int? season;
  final String? videoId;
  final Set<String> watched;
  final ValueChanged<int> onSeason;
  final ValueChanged<core.Video> onEpisode;
  final Widget streams;
  final bool noEpisodes;

  static String seasonLabel(int s, [AppLocalizations? l]) {
    l ??= AppLocalizationsFr();
    return switch (s) {
      -1 => l.seasonEpisodes,
      0 => l.seasonSpecials,
      _ => l.seasonN(s),
    };
  }

  @override
  Widget build(BuildContext context) {
    final lumio = context.lumio;
    final seasons = <int>[];
    for (final v in meta.videos) {
      final s = v.season ?? -1;
      if (!seasons.contains(s)) seasons.add(s);
    }
    final episodes = [
      for (final v in meta.videos)
        if ((v.season ?? -1) == season) v,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (noEpisodes)
          Padding(
            padding: const EdgeInsets.all(LumioSpacing.lg),
            child: Text(context.l10n.noEpisodes),
          ),
        // Maquette TV40 : titres 34, puces de saison 56, cartes d'épisode
        // 280 x 112 (écart 20) ; 36 sous chaque bloc.
        if (seasons.length > 1 && meta.type != 'movie') ...[
          TvRow(
            title: context.l10n.seasonsTitle,
            restorationId: 'detail-seasons',
            routeKey: detailRouteKey,
            gap: 12,
            titleGap: 4,
            titleHeight: 1.2,
            height: 56 + 2 * 12,
            verticalPadding: 12,
            horizontalPadding: 0,
            items: [
              for (final s in seasons)
                TvButton(
                  kind: s == season
                      ? TvButtonKind.primary
                      : TvButtonKind.secondary,
                  height: 56,
                  horizontalPadding: 24,
                  fontSize: 26,
                  scale: 1.04,
                  label: seasonLabel(s, context.l10n),
                  onPressed: () => onSeason(s),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (episodes.isNotEmpty && meta.type != 'movie') ...[
          TvRow(
            title: season == null
                ? context.l10n.seasonEpisodes
                : seasonLabel(season!, context.l10n),
            restorationId: 'detail-episodes',
            routeKey: detailRouteKey,
            itemExtent: 280,
            gap: 20,
            titleGap: 4,
            titleHeight: 1.2,
            height: 112 + 2 * 12,
            verticalPadding: 12,
            horizontalPadding: 0,
            items: [
              for (final v in episodes)
                SizedBox(
                  key: ValueKey('episode:${v.id}'),
                  width: 280,
                  child: FocusableCard(
                    borderRadius: BorderRadius.circular(18),
                    onSelect: () => onEpisode(v),
                    semanticLabel:
                        '${_episodeCode(v, context.l10n)} ${v.title}'
                        ', ${watched.contains(v.id) ? context.l10n.watchedSemantic : context.l10n.unwatchedSemantic}',
                    child: Container(
                      height: 112,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: lumio.surface,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      // Épisode choisi : liseré ambre sans changer la mise en
                      // page.
                      foregroundDecoration: v.id == videoId
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: lumio.accent, width: 2),
                            )
                          : null,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _episodeCode(v, context.l10n),
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  color: lumio.accent,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  fontVariations: const [
                                    FontVariation.weight(700),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              if (watched.contains(v.id))
                                Icon(
                                  Icons.check_circle,
                                  size: 30,
                                  color: lumio.success,
                                  semanticLabel: context.l10n.watchedBadge,
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            v.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              fontVariations: [FontVariation.weight(600)],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (!noEpisodes) streams,
      ],
    );
  }

  /// « S1 · É1 » (maquette TV40) ; « É4 » sans saison.
  static String _episodeCode(core.Video v, AppLocalizations l) =>
      v.season != null && v.episode != null
      ? 'S${v.season} · ${l.episodeLetter}${v.episode}'
      : (v.episode != null ? '${l.episodeLetter}${v.episode}' : '');
}
