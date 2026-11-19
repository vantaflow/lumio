import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lumio/ui/common/tv_scroll_clip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/features/addons/addon_labels.dart';
import 'package:lumio/features/addons/addon_logo.dart';
import 'package:lumio/features/addons/catalog_providers.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/data/addon_repository.dart' show InstalledAddon;
import 'package:lumio/providers.dart';
import 'package:lumio/ui/common/tv_dialogs.dart';
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Puces de catégories de la maquette TV16 ; [categories] vide = toutes.
class CatalogChip {
  const CatalogChip(this.id, this.categories);
  final String id;
  final List<String> categories;
}

const catalogChips = [
  CatalogChip('popular', []),
  CatalogChip('movies', [CatalogCategories.movies, CatalogCategories.tvShows]),
  CatalogChip('torrents', [CatalogCategories.torrents]),
  CatalogChip('debrid', [CatalogCategories.debrid]),
  CatalogChip('subtitles', [CatalogCategories.subtitles]),
  CatalogChip('anime', [CatalogCategories.anime]),
  CatalogChip('metadata', [CatalogCategories.metadata]),
  CatalogChip('tracking', [CatalogCategories.tracking]),
];

/// Catégories proposées par « Plus… ».
const _moreCategories = [
  CatalogCategories.httpStreams,
  CatalogCategories.usenet,
  CatalogCategories.asianDrama,
  CatalogCategories.bollywood,
  CatalogCategories.music,
  CatalogCategories.radios,
  CatalogCategories.liveTv,
  CatalogCategories.misc,
];

String chipLabel(String id, AppLocalizations l) => switch (id) {
  'popular' => l.catPopular,
  'movies' => l.catMoviesSeries,
  'torrents' => l.catTorrents,
  'debrid' => l.catDebrid,
  'subtitles' => l.catSubtitles,
  'anime' => l.catAnime,
  'metadata' => l.catMetadata,
  'tracking' => l.catTracking,
  _ => id,
};

String _moreLabel(String category, AppLocalizations l) => switch (category) {
  CatalogCategories.httpStreams => l.catHttpStreams,
  CatalogCategories.usenet => l.catUsenet,
  CatalogCategories.asianDrama => l.catAsianDrama,
  CatalogCategories.bollywood => l.catBollywood,
  CatalogCategories.music => l.catMusic,
  CatalogCategories.radios => l.catRadios,
  CatalogCategories.liveTv => l.catLiveTv,
  _ => l.catMisc,
};

/// Onglet « Catalogue » (maquette TV16) : puces de catégories, grille de
/// cartes, badge « Installé », note de bas de page.
class CatalogTab extends ConsumerStatefulWidget {
  const CatalogTab({super.key, required this.onUseLink, this.active = true});

  /// Confie l'adresse choisie au flux d'installation « Par lien ».
  final ValueChanged<String> onUseLink;
  final bool active;

  @override
  ConsumerState<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends ConsumerState<CatalogTab> {
  int _chip = 0;
  String? _more;
  final _entries = <CatalogEntry>[];
  CatalogResult<CatalogPage>? _last;
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _opening = false;
  Object? _error;
  int _gen = 0;
  bool _focusedOnce = false;

  List<String> get _categories =>
      _more != null ? [_more!] : catalogChips[_chip].categories;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool refresh = false}) async {
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _error = null;
      _entries.clear();
      _page = 1;
    });
    try {
      final r = await ref
          .read(addonCatalogServiceProvider)
          .list(CatalogQuery(categories: _categories), refresh: refresh);
      if (!mounted || gen != _gen) return;
      setState(() {
        _last = r;
        _entries.addAll(r.value.entries);
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _last == null) return;
    final gen = _gen;
    setState(() => _loadingMore = true);
    try {
      final r = await ref
          .read(addonCatalogServiceProvider)
          .list(CatalogQuery(categories: _categories, page: _page + 1));
      if (!mounted || gen != _gen) return;
      final known = {for (final e in _entries) e.slug};
      setState(() {
        _page++;
        _last = CatalogResult(
          CatalogPage(
            entries: _entries,
            total: r.value.total,
            page: _page,
            totalPages: r.value.totalPages,
          ),
          r.origin,
          r.fetchedAt,
        );
        _entries.addAll(r.value.entries.where((e) => known.add(e.slug)));
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || gen != _gen) return;
      setState(() => _loadingMore = false);
      showTvSnack(context, context.l10n.catalogLoadError, error: true);
    }
  }

  void _selectChip(int i) {
    if (i == _chip && _more == null) return;
    _chip = i;
    _more = null;
    unawaited(_load());
  }

  Future<void> _pickMore() async {
    final l = context.l10n;
    final picked = await showTvChoice<String>(
      context,
      title: l.catMoreTitle,
      options: [for (final c in _moreCategories) (c, _moreLabel(c, l))],
      current: _more,
    );
    if (picked == null || !mounted) return;
    _more = picked;
    unawaited(_load());
  }

  Future<void> _open(CatalogEntry e) async {
    if (_opening) return;
    final l = context.l10n;
    var instances = e.instances;
    if (instances.isEmpty) {
      setState(() => _opening = true);
      try {
        final r = await ref.read(addonCatalogServiceProvider).detail(e.slug);
        instances = r.value.instances;
      } catch (_) {
        if (mounted) showTvSnack(context, l.catalogDetailError, error: true);
        return;
      } finally {
        if (mounted) setState(() => _opening = false);
      }
    }
    if (!mounted || instances.isEmpty) return;
    CatalogInstance? pick;
    if (instances.length == 1) {
      pick = instances.first;
    } else {
      pick = await showTvChoice<CatalogInstance>(
        context,
        title: l.chooseInstanceTitle,
        options: [
          for (final i in instances)
            (
              i,
              i.configurationRequired
                  ? '${i.label} · ${l.instanceNeedsSetup}'
                  : i.label,
            ),
        ],
        current: null,
      );
    }
    if (pick == null || !mounted) return;
    if (pick.configurationRequired) {
      await _configureOnPhone(e.name, pick);
      return;
    }
    widget.onUseLink(pick.manifestUrl.toString());
  }

  Future<void> _configureOnPhone(String name, CatalogInstance i) {
    final l = context.l10n;
    final url = i.configureUrl ?? i.manifestUrl;
    return showTvPanel<void>(
      context,
      builder: (ctx) => TvPanel(
        title: l.configureOnPhoneTitle,
        width: 900,
        onBack: () => Navigator.of(ctx).pop(),
        actions: [
          TvButton(
            key: const ValueKey('configure-close'),
            autofocus: true,
            label: l.close,
            kind: TvButtonKind.secondary,
            height: 76,
            fontSize: 28,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                key: const ValueKey('configure-qr'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: QrImageView(
                  data: url.toString(),
                  size: 240,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(
                        ctx,
                      ).textTheme.titleLarge?.copyWith(fontSize: 34),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l.configureOnPhoneBody,
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        fontSize: 26,
                        height: 1.4,
                        color: ctx.lumio.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${url.host}${url.path}',
                      key: const ValueKey('configure-host'),
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        fontSize: 24,
                        color: ctx.lumio.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _cardMeta(CatalogEntry e, AppLocalizations l) {
    if (e.resources.isNotEmpty || e.types.isNotEmpty) {
      // Ressources réelles du manifest (collection officielle).
      final parts = [
        if (e.resources.contains('catalog')) l.resCatalog,
        if (e.resources.contains('meta')) l.resMeta,
        if (e.resources.contains('stream')) l.resStream,
        if (e.resources.contains('subtitles')) l.resSubtitles,
      ];
      return parts.isEmpty
          ? e.types.map((t) => contentTypeLabel(t, l)).join(' · ')
          : parts.join(' · ');
    }
    final s = e.stars;
    final v = e.version;
    if (s != null && v != null) return l.catalogCardMeta('$s', v);
    if (s != null) return l.catalogCardStars('$s');
    return v == null ? '' : 'v$v';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.lumio;
    final t = Theme.of(context).textTheme;
    final installed = <String>{
      for (final a
          in ref.watch(addonsProvider).value ?? const <InstalledAddon>[])
        a.name.trim().toLowerCase(),
    };
    final last = _last;
    final note = switch (last?.origin) {
      CatalogOrigin.staleCache => l.catalogOffline(_date(last!.fetchedAt)),
      CatalogOrigin.fallback => l.catalogFallbackNote,
      _ => null,
    };
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 52,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  children: [
                    for (final (i, ch) in catalogChips.indexed) ...[
                      if (i > 0) const SizedBox(width: 12),
                      _Chip(
                        key: ValueKey('chip:${ch.id}'),
                        label: chipLabel(ch.id, l),
                        selected: _more == null && _chip == i,
                        onSelect: () => _selectChip(i),
                      ),
                    ],
                    const SizedBox(width: 12),
                    _Chip(
                      key: const ValueKey('chip:more'),
                      label: _more == null ? l.catMore : _moreLabel(_more!, l),
                      selected: _more != null,
                      onSelect: _pickMore,
                    ),
                    const SizedBox(width: 12),
                    TvButton(
                      key: const ValueKey('catalog-refresh'),
                      label: l.catalogRefresh,
                      kind: TvButtonKind.ghost,
                      height: 52,
                      horizontalPadding: 24,
                      fontSize: 24,
                      scale: 1.06,
                      onPressed: _loading
                          ? null
                          : () => unawaited(_load(refresh: true)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(child: _body(l, c, t, installed)),
            if (note != null) ...[
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1500),
                child: Text(
                  note,
                  key: const ValueKey('catalog-note'),
                  style: t.bodySmall?.copyWith(
                    fontSize: 24,
                    height: 1.35,
                    color: c.accent,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 56),
          ],
        ),
        if (_opening)
          Positioned.fill(
            child: ColoredBox(
              color: tvScrim,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _body(
    AppLocalizations l,
    LumioColors c,
    TextTheme t,
    Set<String> installed,
  ) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Align(
        alignment: Alignment.topLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.catalogLoadError,
              key: const ValueKey('catalog-error'),
              style: t.bodyMedium?.copyWith(fontSize: 30, color: c.error),
            ),
            const SizedBox(height: 24),
            TvButton(
              key: const ValueKey('catalog-retry'),
              autofocus: true,
              label: l.retry,
              kind: TvButtonKind.secondary,
              height: 76,
              fontSize: 28,
              onPressed: () => unawaited(_load(refresh: true)),
            ),
          ],
        ),
      );
    }
    if (_entries.isEmpty) {
      return Text(
        l.catalogEmpty,
        key: const ValueKey('catalog-empty'),
        style: t.bodyMedium?.copyWith(fontSize: 30, color: c.textMuted),
      );
    }
    final hasMore = _last?.value.hasMore ?? false;
    // Découpe verticale (la grille ne doit pas déborder sur l'en-tête ni sur la
    // note), mais large sur les côtés pour laisser voir l'anneau de focus.
    return TvScrollClip(
      child: SingleChildScrollView(
      clipBehavior: Clip.none,
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: Wrap(
        spacing: 32,
        runSpacing: 32,
        children: [
          for (final (i, e) in _entries.indexed)
            _EntryCard(
              key: ValueKey('card:${e.slug}'),
              entry: e,
              meta: _cardMeta(e, l),
              installed: installed.contains(e.name.trim().toLowerCase()),
              autofocus: widget.active && !_focusedOnce && i == 0,
              onFocus: () => _focusedOnce = true,
              onSelect: () => unawaited(_open(e)),
            ),
          if (hasMore)
            _MoreCard(
              key: const ValueKey('catalog-more'),
              loading: _loadingMore,
              onSelect: () => unawaited(_loadMore()),
            ),
        ],
      ),
    ),
    );
  }

  String _date(DateTime d) {
    final x = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(x.day)}/${two(x.month)}/${x.year}';
  }
}

/// Puce de catégorie (maquette TV16 `.ch`) : 52 de haut, texte 24 ; la puce
/// courante est ambre.
class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) => TvButton(
    label: label,
    kind: selected ? TvButtonKind.primary : TvButtonKind.secondary,
    height: 52,
    horizontalPadding: 24,
    fontSize: 24,
    scale: 1.06,
    weight: selected ? FontWeight.w700 : FontWeight.w600,
    onPressed: onSelect,
  );
}

/// Carte d'addon (maquette TV16 `.cd`) : 400 x 250, logo 64, nom, capacités,
/// description, badge « Installé ».
class _EntryCard extends StatefulWidget {
  const _EntryCard({
    super.key,
    required this.entry,
    required this.meta,
    required this.installed,
    required this.autofocus,
    required this.onFocus,
    required this.onSelect,
  });

  final CatalogEntry entry;
  final String meta;
  final bool installed;
  final bool autofocus;
  final VoidCallback onFocus;
  final VoidCallback onSelect;

  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.lumio;
    final t = Theme.of(context).textTheme;
    final e = widget.entry;
    return FocusableCard(
      autofocus: widget.autofocus,
      scale: 1.04,
      borderRadius: BorderRadius.circular(24),
      semanticLabel: widget.installed
          ? '${e.name}, ${l.catalogInstalled}'
          : e.name,
      onFocusChange: (f) {
        if (f) widget.onFocus();
        setState(() => _focused = f);
      },
      onSelect: widget.onSelect,
      child: Container(
        width: 400,
        height: 250,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _focused ? c.surfaceFocus : c.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AddonLogo(logo: e.logo, name: e.name, size: 64),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            e.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.titleMedium?.copyWith(
                              fontSize: 30,
                              height: null,
                              fontWeight: FontWeight.w700,
                              fontVariations: const [FontVariation.weight(700)],
                            ),
                          ),
                          if (widget.meta.isNotEmpty)
                            Text(
                              widget.meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodySmall?.copyWith(
                                fontSize: 24,
                                height: 1.35,
                                color: c.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (e.description != null)
                  Expanded(
                    child: Text(
                      e.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(
                        fontSize: 24,
                        height: 1.35,
                        color: c.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
            if (widget.installed)
              Positioned(
                top: -4,
                right: -4,
                child: Text(
                  l.catalogInstalled,
                  key: ValueKey('installed:${e.slug}'),
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    fontVariations: const [FontVariation.weight(700)],
                    color: c.success,
                    height: 1.2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MoreCard extends StatelessWidget {
  const _MoreCard({super.key, required this.loading, required this.onSelect});
  final bool loading;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    return FocusableCard(
      scale: 1.04,
      borderRadius: BorderRadius.circular(24),
      semanticLabel: context.l10n.catalogLoadMore,
      onSelect: loading ? () {} : onSelect,
      child: Container(
        width: 400,
        height: 250,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: loading
            ? const CircularProgressIndicator()
            : Text(
                context.l10n.catalogLoadMore,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 30,
                  color: c.textMuted,
                ),
              ),
      ),
    );
  }
}
