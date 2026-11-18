import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/l10n/error_messages.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/data/jellyfin_repository.dart'
    show JellyfinServer, isJellyfinId, jellyfinSourceKind, parseJellyfinId;
import 'package:lumio/data/local_library.dart' show isLocalId;
import 'package:lumio/data/progress_repository.dart';
import 'package:lumio/features/addons/addons_screen.dart';
import 'package:lumio/features/calendar/calendar_screen.dart';
import 'package:lumio/features/detail/detail_screen.dart';
import 'package:lumio/features/jellyfin/jellyfin_providers.dart';
import 'package:lumio/features/library/library_screen.dart';
import 'package:lumio/features/local/local_providers.dart';
import 'package:lumio/features/local/local_screen.dart';
import 'package:lumio/features/search/search_screen.dart';
import 'package:lumio/features/settings/settings_screen.dart';
import 'package:lumio/features/home/continue_playback.dart';
import 'package:lumio/features/home/home_layout.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/features/home/row_editor_screen.dart';
import 'package:lumio/features/onboarding/onboarding_flow.dart';
import 'package:lumio/features/profiles/pin_dialog.dart';
import 'package:lumio/features/profiles/profile_picker_screen.dart';
import 'package:lumio/features/update/update_banner.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/l10n/app_localizations_fr.dart';
import 'package:lumio/ui/common/guarded_image.dart';
import 'package:lumio/ui/common/state_view.dart';
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/focus/tv_row.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

const homeRouteKey = 'home';
const _posterWidth = 180.0;
const _posterHeight = 270.0;
const _continueWidth = 320.0;
const _continueHeight = 180.0;

String sourceLabel(String kind, [AppLocalizations? l]) {
  l ??= AppLocalizationsFr();
  return switch (kind) {
    'local' => l.sourceLocal,
    'jellyfin' => 'Jellyfin',
    _ => l.sourceAddon,
  };
}

/// Accueil : barre haute, « Continuer », « Ma liste », puis les catalogues des
/// addons actifs (story 3.1).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.onOpenItem});

  /// Ouverture d'une fiche (Task 18) ; sans elle, l'accueil ne fait rien.
  final void Function(MetaPreview item)? onOpenItem;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _topBarNode = FocusNode(debugLabel: 'Home.customize');
  final _topBarFocused = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    // Réanalyse des dossiers locaux au démarrage (limitée dans le temps ;
    // les échecs sont ignorés).
    unawaited(
      ref.read(localLibraryProvider).rescanAll().catchError((Object _) {}),
    );
  }

  @override
  void dispose() {
    _topBarNode.dispose();
    _topBarFocused.dispose();
    super.dispose();
  }

  Future<void> _openAddons() async {
    if (!await requireParent(context, ref)) return;
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AddonsScreen()));
  }

  void _open(MetaPreview item) {
    final custom = widget.onOpenItem;
    if (custom != null) {
      custom(item);
    } else {
      openDetail(context, item);
    }
  }

  Future<void> _openSearch() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SearchScreen(onOpenItem: _openFrom),
    ),
  );

  Future<void> _openLibrary() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LibraryScreen(onOpenItem: _openFrom),
    ),
  );

  Future<void> _openCalendar() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: calendarRouteKey),
      builder: (_) => CalendarScreen(onOpenItem: _openFrom),
    ),
  );

  /// Depuis un écran poussé : la fiche s'ouvre par-dessus cet écran.
  void _openFrom(MetaPreview item) => _open(item);

  Future<void> _openSettings() => openSettings(context, ref);

  Future<void> _openEditor() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const RowEditorScreen()));

  @override
  Widget build(BuildContext context) {
    // Retour : d'abord vers la barre haute, puis seulement quitter.
    return ListenableBuilder(
      listenable: _topBarFocused,
      builder: (context, _) => BackGuard(
        isOpen: !_topBarFocused.value,
        onClose: _topBarNode.requestFocus,
        child: TvScaffold(
          onBack: () {
            if (_topBarFocused.value) {
              Navigator.maybeOf(context)?.maybePop();
            } else {
              _topBarNode.requestFocus();
            }
          },
          child: Scaffold(
            body: Column(
              children: [
                const UpdateBanner(),
                Focus(
                  skipTraversal: true,
                  canRequestFocus: false,
                  onFocusChange: (f) => _topBarFocused.value = f,
                  child: _TopBar(
                    customizeNode: _topBarNode,
                    onCustomize: _openEditor,
                    onSearch: _openSearch,
                    onLibrary: _openLibrary,
                    onCalendar: _openCalendar,
                    onSettings: _openSettings,
                  ),
                ),
                SourcesReminderCard(onAdd: _openAddons),
                Expanded(
                  child: _HomeBody(
                    onOpenAddons: _openAddons,
                    onOpenItem: _open,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.customizeNode,
    required this.onCustomize,
    required this.onSearch,
    required this.onLibrary,
    required this.onCalendar,
    required this.onSettings,
  });

  final FocusNode customizeNode;
  final VoidCallback onCustomize;
  final VoidCallback onSearch;
  final VoidCallback onLibrary;
  final VoidCallback onCalendar;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final lumio = context.lumio;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: MediaQuery.sizeOf(context).width >= 720 ? 96 : LumioSpacing.md,
        end: LumioSpacing.xl,
        top: LumioSpacing.sm,
        bottom: LumioSpacing.sm,
      ),
      child: Row(
        children: [
          Semantics(
            header: true,
            child: Text(
              'Lumio',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: lumio.accent),
            ),
          ),
          // Wrap : les boutons passent à la ligne si le texte TV est large.
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: LumioSpacing.sm,
              runSpacing: LumioSpacing.xs,
              children: [
                TextButton.icon(
                  onPressed: onSearch,
                  icon: const Icon(Icons.search),
                  label: Text(context.l10n.homeSearch),
                ),
                TextButton.icon(
                  onPressed: onLibrary,
                  icon: const Icon(Icons.bookmark_border),
                  label: Text(context.l10n.homeManageList),
                ),
                TextButton.icon(
                  key: const ValueKey('home-calendar'),
                  onPressed: onCalendar,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(context.l10n.homeCalendar),
                ),
                TextButton.icon(
                  focusNode: customizeNode,
                  onPressed: onCustomize,
                  icon: const Icon(Icons.tune),
                  label: Text(context.l10n.homeCustomize),
                ),
                TextButton.icon(
                  key: const ValueKey('home-settings'),
                  onPressed: onSettings,
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(context.l10n.homeSettings),
                ),
                const ProfileButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.onOpenAddons, required this.onOpenItem});

  final VoidCallback onOpenAddons;
  final void Function(MetaPreview item)? onOpenItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(homeSummaryProvider);
    final layout = ref.watch(homeLayoutProvider);
    switch (summary.phase) {
      case HomePhase.error:
        return StateView.error(
          message: context.l10n.homeAddonsError,
          onRetry: () => ref.read(addonsProvider.notifier).reload(),
        );
      case HomePhase.noCatalog:
        return StateView.empty(message: context.l10n.homeNoCatalog);
      case HomePhase.noAddons:
        final help = StateView.empty(
          message: context.l10n.homeNoAddons,
          actionLabel: context.l10n.homeManageAddons,
          onAction: onOpenAddons,
        );
        // Les reprises restent accessibles même sans addon.
        return Column(
          children: [
            const _ContinueRow(),
            Expanded(child: help),
          ],
        );
      case HomePhase.filtered:
        return StateView.empty(message: context.l10n.homeFiltered);
      case HomePhase.loading:
        return const _SkeletonList();
      case HomePhase.ready:
        break;
    }
    if (!layout.hasValue) return const _SkeletonList();
    final natural = [
      continueRowId,
      libraryRowId,
      localRowId,
      ...summary.catalogIds,
      for (final r
          in ref.watch(jellyfinRowsProvider).value ?? const <JellyfinRowData>[])
        r.id,
    ];
    final ids = layout.requireValue.visible(natural);
    return ListView.builder(
      cacheExtent: 1500,
      padding: const EdgeInsets.only(bottom: LumioSpacing.xl),
      itemCount: ids.length,
      itemBuilder: (context, i) {
        final id = ids[i];
        return KeyedSubtree(
          key: ValueKey(id),
          child: switch (id) {
            continueRowId => const _ContinueRow(),
            libraryRowId => _LibraryRow(onOpenItem: onOpenItem),
            localRowId => _LocalRow(onOpenItem: onOpenItem),
            _ when id.startsWith('jf:') => _JellyfinRowView(
              rowId: id,
              onOpenItem: onOpenItem,
            ),
            _ => _CatalogRowView(rowId: id, onOpenItem: onOpenItem),
          },
        );
      },
    );
  }
}

// --- rangées ---

class _CatalogRowView extends ConsumerWidget {
  const _CatalogRowView({required this.rowId, required this.onOpenItem});

  final String rowId;
  final void Function(MetaPreview item)? onOpenItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Seule cette rangée se reconstruit quand ses données arrivent.
    final row = ref.watch(homeRowsProvider.select((s) => s.rows[rowId]));
    final spec = ref.watch(
      homeRowsProvider.select(
        (s) => s.specs.where((x) => x.id == rowId).firstOrNull,
      ),
    );
    if (spec == null) return const SizedBox.shrink();
    if (row == null) return _SkeletonRow(title: spec.title);
    if (row.failed) {
      return _ErrorRow(
        title: spec.title,
        message: row.error is AddonException
            ? l10nForError(context.l10n, row.error!)
            : context.l10n.homeRowFailed,
        onRetry: () => ref.read(homeRowsProvider.notifier).retry(rowId),
      );
    }
    final profile = ref.watch(currentProfileProvider);
    final items = visibleItems(row.items, profile);
    if (items.isEmpty) return const SizedBox.shrink();
    return _PosterRow(
      rowId: rowId,
      title: spec.title,
      items: items,
      onOpenItem: onOpenItem,
      allowPrivate: spec.allowPrivate,
    );
  }
}

/// Bibliothèque d'un serveur Jellyfin (badge « Jellyfin ») ; filtre d'âge :
/// classification inconnue masquée aux profils enfants.
class _JellyfinRowView extends ConsumerWidget {
  const _JellyfinRowView({required this.rowId, required this.onOpenItem});

  final String rowId;
  final void Function(MetaPreview item)? onOpenItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = ref
        .watch(jellyfinRowsProvider)
        .value
        ?.where((r) => r.id == rowId)
        .firstOrNull;
    if (row == null) return const SizedBox.shrink();
    if (row.error != null) {
      return _ErrorRow(
        title: row.title,
        message: l10nForError(context.l10n, row.error!),
        onRetry: () => ref.invalidate(jellyfinRowsProvider),
      );
    }
    final items = visibleItems(row.items, ref.watch(currentProfileProvider));
    if (items.isEmpty) return const SizedBox.shrink();
    return _PosterRow(
      rowId: rowId,
      title: row.title,
      items: items,
      onOpenItem: onOpenItem,
      allowPrivate: row.allowPrivate,
    );
  }
}

class _LibraryRow extends ConsumerWidget {
  const _LibraryRow({required this.onOpenItem});

  final void Function(MetaPreview item)? onOpenItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = visibleItems(
      ref.watch(libraryProvider).value ?? const [],
      ref.watch(currentProfileProvider),
    );
    if (items.isEmpty) return const SizedBox.shrink();
    return _PosterRow(
      rowId: libraryRowId,
      title: context.l10n.myList,
      items: items,
      onOpenItem: onOpenItem,
    );
  }
}

/// Vidéos des dossiers locaux (badge « Local », carte-titre sans affiche) ;
/// masquées aux profils enfants (aucune certification connue).
class _LocalRow extends ConsumerWidget {
  const _LocalRow({required this.onOpenItem});

  final void Function(MetaPreview item)? onOpenItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = visibleItems(
      ref.watch(localPreviewsProvider),
      ref.watch(currentProfileProvider),
    );
    if (items.isEmpty) return const SizedBox.shrink();
    return _PosterRow(
      rowId: localRowId,
      title: context.l10n.localFolders,
      items: items,
      onOpenItem: onOpenItem,
    );
  }
}

class _PosterRow extends ConsumerWidget {
  const _PosterRow({
    required this.rowId,
    required this.title,
    required this.items,
    required this.onOpenItem,
    this.allowPrivate = false,
  });

  final bool allowPrivate;
  final String rowId;
  final String title;
  final List<MetaPreview> items;
  final void Function(MetaPreview item)? onOpenItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TvRow(
      title: title,
      restorationId: rowId,
      routeKey: homeRouteKey,
      autofocusFirst: true,
      itemExtent: _posterWidth,
      height: _posterHeight + 80 + lumioTextGrowth(context, 2, 0),
      items: [
        for (final m in items)
          PosterCard(
            key: ValueKey('${m.sourceAddonId}|${m.id}'),
            item: m,
            allowPrivate: allowPrivate,
            onSelect: () => onOpenItem?.call(m),
          ),
      ],
    );
  }
}

class _ContinueRow extends ConsumerWidget {
  const _ContinueRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Une reprise locale dont le fichier n'est pas (ou plus) dans ce
    // appareil (progression synchronisée d'un autre) est masquée.
    final localIds = {
      for (final i in ref.watch(localItemsProvider).value ?? const []) i.id,
    };
    // Idem pour un serveur Jellyfin absent (ou retiré) de cet appareil.
    final serverIds = {
      for (final s
          in ref.watch(jellyfinServersProvider).value ??
              const <JellyfinServer>[])
        s.id,
    };
    final entries = [
      for (final e in visibleProgress(
        ref.watch(continueWatchingProvider).value ?? const [],
        ref.watch(currentProfileProvider),
      ))
        if ((!isLocalId(e.metaId) || localIds.contains(e.metaId)) &&
            (!isJellyfinId(e.metaId) ||
                serverIds.contains(parseJellyfinId(e.metaId)?.serverId)))
          e,
    ];
    if (entries.isEmpty) return const SizedBox.shrink();
    final playback = ref.watch(continuePlaybackProvider);
    return TvRow(
      title: context.l10n.continueWatching,
      restorationId: continueRowId,
      routeKey: homeRouteKey,
      autofocusFirst: true,
      itemExtent: _continueWidth,
      height: _continueHeight + 72 + lumioTextGrowth(context, 1, 1),
      items: [
        for (final e in entries)
          _ContinueCard(key: ValueKey(e.videoId), entry: e, playback: playback),
      ],
    );
  }
}

// --- cartes ---

/// Année (4 chiffres) tirée de `releaseInfo` (`2008`, `2008–2013`…), ou null.
String? _year(String? releaseInfo) =>
    RegExp(r'\b(19|20)\d{2}\b').firstMatch(releaseInfo ?? '')?.group(0);

/// Carte d'affiche : image gardée, titre, badge de source.
class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.item,
    required this.onSelect,
    this.allowPrivate = false,
  });

  final MetaPreview item;
  final bool allowPrivate;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final lumio = context.lumio;
    final source = sourceLabel(item.sourceKind, context.l10n);
    return SizedBox(
      width: _posterWidth,
      child: FocusableCard(
        onSelect: onSelect,
        semanticLabel: _year(item.releaseInfo) == null
            ? context.l10n.itemSemantic(item.name, source)
            : context.l10n.itemSemanticYear(
                item.name,
                _year(item.releaseInfo)!,
                source,
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _posterHeight,
              width: _posterWidth,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(LumioRadius.md),
                    child: _Poster(
                      title:
                          item.sourceKind == 'local' ||
                              item.sourceKind == jellyfinSourceKind
                          ? item.name
                          : null,
                      url: item.poster,
                      allowPrivate: allowPrivate,
                      width: _posterWidth,
                    ),
                  ),
                  PositionedDirectional(
                    start: LumioSpacing.sm,
                    top: LumioSpacing.sm,
                    child: SourceBadge(label: source),
                  ),
                ],
              ),
            ),
            const SizedBox(height: LumioSpacing.sm),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: lumio.text),
            ),
          ],
        ),
      ),
    );
  }
}

class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final lumio = context.lumio;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: lumio.bg.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(LumioRadius.sm),
        border: Border.all(color: lumio.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: lumio.text),
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({
    required this.url,
    required this.allowPrivate,
    required this.width,
    this.title,
  });

  /// Titre pour la carte générée quand il n'y a pas d'affiche (fichiers
  /// locaux) ; sinon une icône neutre.
  final String? title;
  final Uri? url;
  final bool allowPrivate;
  final double width;

  @override
  Widget build(BuildContext context) {
    final lumio = context.lumio;
    Widget placeholder() => title != null
        ? LocalTitleCard(title: title!)
        : ColoredBox(
            color: lumio.surfaceRaised,
            child: Center(
              child: Icon(
                Icons.movie_outlined,
                size: 48,
                color: lumio.textMuted,
              ),
            ),
          );
    final u = url;
    if (u == null) return placeholder();
    return Image(
      image: ResizeImage.resizeIfNeeded(
        (width * 2).round(),
        null,
        GuardedNetworkImage(u, allowPrivate: allowPrivate),
      ),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => placeholder(),
    );
  }
}

class _ContinueCard extends StatefulWidget {
  const _ContinueCard({super.key, required this.entry, required this.playback});

  final ProgressEntry entry;
  final ContinuePlayback playback;

  @override
  State<_ContinueCard> createState() => _ContinueCardState();
}

class _ContinueCardState extends State<_ContinueCard> {
  late Future<ContinueInfo> _info = _describe();

  Future<ContinueInfo> _describe() => widget.playback
      .describe(widget.entry)
      .catchError((Object _) => ContinueInfo(title: widget.entry.metaId));

  @override
  void didUpdateWidget(_ContinueCard old) {
    super.didUpdateWidget(old);
    if (old.entry.videoId != widget.entry.videoId ||
        old.playback != widget.playback) {
      _info = _describe();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lumio = context.lumio;
    final e = widget.entry;
    final progress = e.duration > Duration.zero
        ? (e.position.inMilliseconds / e.duration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;
    return SizedBox(
      width: _continueWidth,
      child: FutureBuilder<ContinueInfo>(
        future: _info,
        builder: (context, snap) {
          final info = snap.data ?? ContinueInfo(title: e.metaId);
          return FocusableCard(
            onSelect: () => widget.playback.play(context, e),
            semanticLabel: context.l10n.resumeSemantic(info.title),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: _continueHeight,
                  width: _continueWidth,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(LumioRadius.md),
                        child: _Poster(
                          url: info.poster,
                          allowPrivate: info.allowPrivate,
                          width: _continueWidth,
                        ),
                      ),
                      PositionedDirectional(
                        start: 0,
                        end: 0,
                        bottom: 0,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(LumioRadius.md),
                          ),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            color: lumio.accent,
                            backgroundColor: lumio.outline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: LumioSpacing.sm),
                Text(
                  info.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: lumio.text),
                ),
                if (info.subtitle != null)
                  Text(
                    info.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- squelettes et erreurs ---

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) => ListView(
    key: const ValueKey('home-skeleton'),
    physics: const NeverScrollableScrollPhysics(),
    children: const [_SkeletonRow(title: null), _SkeletonRow(title: null)],
  );
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    final lumio = context.lumio;
    return Semantics(
      label: context.l10n.loading,
      child: Column(
        key: const ValueKey('skeleton-row'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 96),
            child: title == null
                ? Container(
                    height: 22,
                    width: 180,
                    decoration: BoxDecoration(
                      color: lumio.surfaceRaised,
                      borderRadius: BorderRadius.circular(LumioRadius.sm),
                    ),
                  )
                : Text(
                    title!,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: lumio.text),
                  ),
          ),
          const SizedBox(height: LumioSpacing.sm),
          SizedBox(
            height: _posterHeight + 24,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 96, vertical: 12),
              itemCount: 8,
              itemBuilder: (_, _) => Padding(
                padding: const EdgeInsets.only(right: LumioSpacing.lg),
                child: Container(
                  width: _posterWidth,
                  height: _posterHeight,
                  decoration: BoxDecoration(
                    color: lumio.surface,
                    borderRadius: BorderRadius.circular(LumioRadius.md),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final lumio = context.lumio;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 96,
        vertical: LumioSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: lumio.text),
          ),
          const SizedBox(height: LumioSpacing.sm),
          Text(message, style: TextStyle(color: lumio.textMuted)),
          const SizedBox(height: LumioSpacing.sm),
          FilledButton(onPressed: onRetry, child: Text(context.l10n.retry)),
        ],
      ),
    );
  }
}
