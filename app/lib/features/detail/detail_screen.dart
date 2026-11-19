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
import 'package:lumio/ui/common/guarded_image.dart';
import 'package:lumio/ui/common/state_view.dart';
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
        body: SafeArea(
          child: switch (_phase) {
            _Phase.loading => const StateView.loading(),
            _Phase.error => StateView.error(
              message: context.l10n.detailLoadError,
              onRetry: _load,
            ),
            _Phase.refused => StateView.empty(
              message: context.l10n.notAllowedForProfile,
            ),
            _Phase.ready => _body(context, _meta!),
          },
        ),
      ),
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

    final info = _Info(
      meta: meta,
      allowPrivate: allowPoster,
      inList: inList,
      canPlay: preferred != null && _videoId != null,
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
      ),
      noEpisodes: meta.videos.isEmpty && meta.type == 'series',
    );
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: c.maxWidth >= 1500 ? 720 : 480,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    c.maxWidth >= 1500 ? tvMargin : LumioSpacing.xl,
                    c.maxWidth >= 1500 ? 56 : LumioSpacing.md,
                    LumioSpacing.lg,
                    LumioSpacing.xl,
                  ),
                  child: info,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    c.maxWidth >= 1500 ? 56 : 0,
                    c.maxWidth >= 1500 ? tvMargin : 0,
                    LumioSpacing.xl,
                  ),
                  children: [sources],
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

class _Info extends StatelessWidget {
  const _Info({
    required this.meta,
    required this.allowPrivate,
    required this.inList,
    required this.canPlay,
    required this.onPlay,
    required this.onToggleList,
  });

  final Meta meta;
  final bool allowPrivate;
  final bool inList;
  final bool canPlay;
  final VoidCallback onPlay;
  final VoidCallback onToggleList;

  @override
  Widget build(BuildContext context) {
    final lumio = context.lumio;
    final theme = Theme.of(context);
    final line = [
      if (meta.releaseInfo != null) meta.releaseInfo!,
      if (meta.certification != null) meta.certification!,
      ...meta.genres.take(3),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (meta.poster != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(LumioRadius.md),
            child: SizedBox(
              width: 260,
              height: 390,
              child: Image(
                image: GuardedNetworkImage(
                  meta.poster!,
                  allowPrivate: allowPrivate,
                ),
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => ColoredBox(color: lumio.surface),
              ),
            ),
          ),
        const SizedBox(height: LumioSpacing.md),
        Semantics(
          header: true,
          child: Text(
            meta.name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineLarge?.copyWith(
              color: lumio.text,
              fontSize: MediaQuery.sizeOf(context).width >= 1500 ? 56 : null,
            ),
          ),
        ),
        if (line.isNotEmpty) ...[
          const SizedBox(height: LumioSpacing.xs),
          Text(
            line,
            style: theme.textTheme.bodyMedium?.copyWith(color: lumio.textMuted),
          ),
        ],
        if (meta.description != null) ...[
          const SizedBox(height: LumioSpacing.md),
          Text(
            meta.description!,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: lumio.text,
              fontSize: MediaQuery.sizeOf(context).width >= 1500 ? 28 : null,
            ),
          ),
        ],
        const SizedBox(height: LumioSpacing.lg),
        // Ligne unique : le libellé ne passe plus sur deux lignes (D9).
        Wrap(
          spacing: LumioSpacing.lg,
          runSpacing: LumioSpacing.md,
          children: [
            TvButton(
              key: const ValueKey('detail-play'),
              autofocus: canPlay,
              onPressed: canPlay ? onPlay : null,
              icon: Icon(Icons.play_arrow, size: 36, color: lumio.onAccent),
              height: 80,
              horizontalPadding: 40,
              fontSize: 30,
              label: context.l10n.autoPlayBest,
            ),
            TvButton(
              key: const ValueKey('detail-list'),
              autofocus: !canPlay,
              onPressed: onToggleList,
              kind: TvButtonKind.secondary,
              height: 80,
              horizontalPadding: 36,
              fontSize: 30,
              icon: Icon(
                inList ? Icons.check : Icons.add,
                size: 34,
                color: lumio.text,
              ),
              label: inList
                  ? context.l10n.removeFromList
                  : context.l10n.addToList,
            ),
          ],
        ),
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
    final theme = Theme.of(context);
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
        if (seasons.length > 1 && meta.type != 'movie')
          TvRow(
            title: context.l10n.seasonsTitle,
            restorationId: 'detail-seasons',
            routeKey: detailRouteKey,
            itemExtent: 200,
            height: 64 + 2 * 14,
            verticalPadding: 14,
            horizontalPadding: 12,
            items: [
              for (final s in seasons)
                SizedBox(
                  width: 200,
                  child: TvButton(
                    kind: s == season
                        ? TvButtonKind.primary
                        : TvButtonKind.secondary,
                    height: 64,
                    horizontalPadding: 20,
                    fontSize: 26,
                    scale: 1.04,
                    label: seasonLabel(s, context.l10n),
                    onPressed: () => onSeason(s),
                  ),
                ),
            ],
          ),
        if (episodes.isNotEmpty && meta.type != 'movie')
          TvRow(
            title: season == null
                ? context.l10n.seasonEpisodes
                : seasonLabel(season!, context.l10n),
            restorationId: 'detail-episodes',
            routeKey: detailRouteKey,
            itemExtent: 340,
            height: 132 + 2 * 14,
            verticalPadding: 14,
            horizontalPadding: 12,
            items: [
              for (final v in episodes)
                SizedBox(
                  key: ValueKey('episode:${v.id}'),
                  width: 340,
                  child: FocusableCard(
                    onSelect: () => onEpisode(v),
                    semanticLabel:
                        '${_episodeCode(v, context.l10n)} ${v.title}'
                        ', ${watched.contains(v.id) ? context.l10n.watchedSemantic : context.l10n.unwatchedSemantic}',
                    child: Container(
                      height: 132,
                      padding: const EdgeInsets.all(LumioSpacing.md),
                      decoration: BoxDecoration(
                        color: lumio.surface,
                        borderRadius: BorderRadius.circular(LumioRadius.md),
                        border: Border.all(
                          color: v.id == videoId ? lumio.accent : lumio.outline,
                          width: v.id == videoId ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _episodeCode(v, context.l10n),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: lumio.accent,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
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
                          const SizedBox(height: LumioSpacing.xs),
                          Text(
                            v.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: lumio.text,
                              fontSize: 26,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        if (!noEpisodes)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: LumioSpacing.md),
                Semantics(
                  header: true,
                  child: Text(
                    context.l10n.sourcesTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: lumio.text,
                    ),
                  ),
                ),
                streams,
              ],
            ),
          ),
      ],
    );
  }

  static String _episodeCode(core.Video v, AppLocalizations l) =>
      v.season != null && v.episode != null
      ? 'S${v.season}E${v.episode}'
      : (v.episode != null ? '${l.episodeLetter}${v.episode}' : '');
}
