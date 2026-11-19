import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/l10n/error_messages.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/data/jellyfin_repository.dart'
    show JellyfinServer, isJellyfinId, jellyfinSourceKind, parseJellyfinId;
import 'package:lumio/data/local_library.dart' show isLocalId;
import 'package:lumio/data/progress_repository.dart';
import 'package:lumio/features/addons/addon_labels.dart';
import 'package:lumio/features/addons/addons_screen.dart';
import 'package:lumio/features/calendar/calendar_screen.dart';
import 'package:lumio/features/detail/detail_screen.dart';
import 'package:lumio/features/detail/playback_service.dart'
    show ActiveAddon, activeAddonsProvider, typeForVideo;
import 'package:lumio/features/jellyfin/jellyfin_providers.dart';
import 'package:lumio/features/library/library_screen.dart';
import 'package:lumio/features/local/local_providers.dart';
import 'package:lumio/features/local/local_screen.dart';
import 'package:lumio/features/search/search_screen.dart';
import 'package:lumio/features/settings/settings_screen.dart';
import 'package:lumio/features/home/continue_playback.dart';
import 'package:lumio/features/home/home_layout.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/features/home/tv_cards.dart';
import 'package:lumio/features/home/tv_home.dart';
import 'package:lumio/features/addons/add_addon_screen.dart';
import 'package:lumio/features/jellyfin/jellyfin_screen.dart'
    show JellyfinAddDialog;
import 'package:lumio/features/home/row_editor_screen.dart';
import 'package:lumio/features/onboarding/onboarding_flow.dart';
import 'package:lumio/features/profiles/pin_dialog.dart';
import 'package:lumio/features/profiles/profile_picker_screen.dart';
import 'package:lumio/features/update/update_banner.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/l10n/app_localizations_fr.dart';
import 'package:lumio/ui/common/guarded_image.dart';
import 'package:lumio/ui/common/state_view.dart';
import 'package:lumio/ui/common/tv_dialogs.dart';
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/ui/focus/row_traversal.dart';
import 'package:lumio/ui/focus/tv_row.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

const homeRouteKey = 'home';
const _posterWidth = 200.0;
const _posterHeight = 300.0;
const _continueWidth = 320.0;
const _rowPad = 28.0;
const _continueHeight = 180.0;

/// Menu d'un titre de « Ma liste » (appui long sur OK) : ouvrir la fiche ou le
/// retirer de la liste, comme depuis la fiche.
Future<void> showListItemMenu(
  BuildContext context,
  WidgetRef ref,
  MetaPreview item, {
  required VoidCallback onOpen,
}) async {
  final l = context.l10n;
  final choice = await showTvChoice<String>(
    context,
    title: item.name,
    current: null,
    options: [('open', l.openSheet), ('remove', l.removeFromList)],
  );
  if (choice == 'open') {
    onOpen();
  } else if (choice == 'remove') {
    try {
      await ref
          .read(libraryRepositoryProvider)
          .remove(ref.read(currentProfileIdProvider), item.id);
    } on Object {
      if (context.mounted) {
        showTvSnack(context, l.listUpdateFailed, error: true);
      }
    }
  }
}

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
  const HomeScreen({super.key, this.onOpenItem, this.tvLayout});

  /// Force la disposition TV (tests) ; sinon détectée par `isTvLayout`.
  final bool? tvLayout;

  /// Ouverture d'une fiche (Task 18) ; sans elle, l'accueil ne fait rien.
  final void Function(MetaPreview item)? onOpenItem;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _topBarNode = FocusNode(debugLabel: 'Home.customize');
  final _topBarFocused = ValueNotifier<bool>(false);
  final _scroll = ScrollController();
  bool _confirmingExit = false;

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
    _scroll.dispose();
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

  Future<void> _openSearch({String? type}) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SearchScreen(onOpenItem: _openFrom, initialType: type),
    ),
  );

  Future<void> _addLocalFolder() => addLocalFolderFlow(context, ref);

  Future<void> _addJellyfin() async {
    if (!await requireParent(context, ref)) return;
    if (!mounted) return;
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => const JellyfinAddDialog(),
    );
    if (added == true) ref.invalidate(jellyfinRowsProvider);
  }

  Future<void> _addAddon() async {
    if (!await requireParent(context, ref)) return;
    if (!mounted) return;
    await showAddAddonScreen(context);
  }

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

  /// Remonte la page puis donne le focus à « Accueil » (audit D2/D5).
  void _backToTop() {
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(0, duration: LumioMotion.screen, curve: Curves.easeOut);
    }
    _topBarNode.requestFocus();
  }

  /// Retour télécommande : contenu -> barre haute (page remontée) ; barre
  /// haute -> « Accueil » ; « Accueil » -> confirmation « Quitter Lumio ? ».
  Future<void> _handleBack() async {
    if (!_topBarFocused.value) {
      _backToTop();
      return;
    }
    if (!_topBarNode.hasFocus) {
      _topBarNode.requestFocus();
      return;
    }
    if (_confirmingExit) return;
    _confirmingExit = true;
    try {
      final quit = await showDialog<bool>(
        context: context,
        builder: (ctx) => const _QuitDialog(),
      );
      if (quit == true) await SystemNavigator.pop();
    } finally {
      _confirmingExit = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tv = isTvLayout(context, override: widget.tvLayout);
    return ListenableBuilder(
      listenable: _topBarFocused,
      builder: (context, _) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleBack();
        },
        child: TvScaffold(
          onBack: _handleBack,
          child: Scaffold(
            body: RowTraversalGroup(
              child: Column(
                children: [
                  const UpdateBanner(),
                  Focus(
                    skipTraversal: true,
                    canRequestFocus: false,
                    onFocusChange: (f) {
                      _topBarFocused.value = f;
                      if (f && _scroll.hasClients && _scroll.offset > 0) {
                        _scroll.animateTo(
                          0,
                          duration: LumioMotion.screen,
                          curve: Curves.easeOut,
                        );
                      }
                    },
                    child: tv
                        ? TvTopBar(
                            homeNode: _topBarNode,
                            onMovies: () => _openSearch(type: 'movie'),
                            onSeries: () => _openSearch(type: 'series'),
                            onSearch: _openSearch,
                            onSettings: _openSettings,
                            onLibrary: _openLibrary,
                            onCalendar: _openCalendar,
                            onCustomize: _openEditor,
                          )
                        : _TopBar(
                            customizeNode: _topBarNode,
                            onCustomize: _openEditor,
                            onSearch: _openSearch,
                            onLibrary: _openLibrary,
                            onCalendar: _openCalendar,
                            onSettings: _openSettings,
                          ),
                  ),
                  if (!tv) SourcesReminderCard(onAdd: _openAddons),
                  Expanded(
                    child: _HomeBody(
                      tv: tv,
                      scroll: _scroll,
                      onOpenAddons: _openAddons,
                      onAddAddon: _addAddon,
                      onAddLocal: _addLocalFolder,
                      onAddJellyfin: _addJellyfin,
                      onOpenItem: _open,
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
  const _HomeBody({
    required this.tv,
    required this.scroll,
    required this.onOpenAddons,
    required this.onAddAddon,
    required this.onAddLocal,
    required this.onAddJellyfin,
    required this.onOpenItem,
  });

  final bool tv;
  final ScrollController scroll;
  final VoidCallback onAddAddon;
  final VoidCallback onAddLocal;
  final VoidCallback onAddJellyfin;
  final VoidCallback onOpenAddons;
  final void Function(MetaPreview item)? onOpenItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(homeSummaryProvider);
    final layout = ref.watch(homeLayoutProvider);
    switch (summary.phase) {
      case HomePhase.error:
        return StateView.error(
          headerInset: 120,
          message: context.l10n.homeAddonsError,
          onRetry: () => ref.read(addonsProvider.notifier).reload(),
        );
      case HomePhase.noCatalog:
        return StateView.empty(
          headerInset: 120,
          message: context.l10n.homeNoCatalog,
          actionLabel: tv ? context.l10n.homeManageAddons : null,
          onAction: tv ? onOpenAddons : null,
        );
      case HomePhase.noAddons:
        final Widget help = tv
            ? SingleChildScrollView(
                child: TvEmptyHome(
                  onAddAddon: onAddAddon,
                  onAddLocal: onAddLocal,
                  onAddJellyfin: onAddJellyfin,
                ),
              )
            : StateView.empty(
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
        return StateView.empty(
          headerInset: 120,
          message: context.l10n.homeFiltered,
          actionLabel: tv ? context.l10n.tvSwitchProfile : null,
          onAction: tv ? () => switchProfileFlow(context, ref) : null,
        );
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
    // TV : la reprise la plus récente en héros (maquette TV05).
    final continues = tv ? _continueEntries(ref) : const <ProgressEntry>[];
    final hero = continues.isNotEmpty && ids.contains(continueRowId)
        ? continues.first
        : null;
    final lead = hero == null ? 0 : 1;
    return _HeroPresent(
      present: hero != null,
      child: ListView.builder(
        controller: scroll,
        cacheExtent: 1500,
        padding: const EdgeInsets.only(bottom: LumioSpacing.xl),
        itemCount: ids.length + lead,
        itemBuilder: (context, index) {
          if (hero != null && index == 0) {
            return _HomeHero(key: const ValueKey('home-hero'), entry: hero);
          }
          final i = index - lead;
          final id = ids[i];
          return KeyedSubtree(
            key: ValueKey(id),
            child: switch (id) {
              continueRowId => _ContinueRow(tvTop: hero != null ? 28 : 8),
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
      ),
    );
  }
}

/// Vrai quand le héros de l'accueil porte le focus initial : les rangées ne
/// le réclament alors pas.
class _HeroPresent extends InheritedWidget {
  const _HeroPresent({required this.present, required super.child});

  final bool present;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_HeroPresent>()?.present ??
      false;

  @override
  bool updateShouldNotify(_HeroPresent old) => present != old.present;
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
    if (row == null) {
      return _SkeletonRow(
        title: catalogRowTitle(spec.catalog.type, spec.title, context.l10n),
      );
    }
    if (row.failed) {
      return _ErrorRow(
        title: catalogRowTitle(spec.catalog.type, spec.title, context.l10n),
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
      title: catalogRowTitle(spec.catalog.type, spec.title, context.l10n),
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
      onLongSelect: (m) =>
          showListItemMenu(context, ref, m, onOpen: () => onOpenItem?.call(m)),
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
    this.onLongSelect,
    this.allowPrivate = false,
  });

  final bool allowPrivate;
  final String rowId;
  final String title;
  final List<MetaPreview> items;
  final void Function(MetaPreview item)? onOpenItem;

  /// Appui long sur une carte (menu « Retirer de ma liste » de la rangée
  /// Ma liste).
  final void Function(MetaPreview item)? onLongSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isTvLayout(context)) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TvRow(
          title: title,
          restorationId: rowId,
          routeKey: homeRouteKey,
          autofocusFirst: !_HeroPresent.of(context),
          itemExtent: tvCardWidth,
          gap: tvCardGap,
          titleGap: 20,
          titleHeight: 1.2,
          height: tvCardHeight + 24,
          items: [
            for (final m in items)
              TvMediaCard(
                key: ValueKey('${m.sourceAddonId}|${m.id}'),
                title: m.name,
                seed: m.id,
                poster: m.poster,
                allowPrivate: allowPrivate,
                badge:
                    m.sourceKind == 'local' ||
                        m.sourceKind == jellyfinSourceKind
                    ? sourceLabel(m.sourceKind, context.l10n)
                    : null,
                semanticLabel: _year(m.releaseInfo) == null
                    ? context.l10n.itemSemantic(
                        m.name,
                        sourceLabel(m.sourceKind, context.l10n),
                      )
                    : context.l10n.itemSemanticYear(
                        m.name,
                        _year(m.releaseInfo)!,
                        sourceLabel(m.sourceKind, context.l10n),
                      ),
                onSelect: () => onOpenItem?.call(m),
                onLongPress: onLongSelect == null
                    ? null
                    : () => onLongSelect!(m),
              ),
          ],
        ),
      );
    }
    return TvRow(
      title: title,
      restorationId: rowId,
      routeKey: homeRouteKey,
      autofocusFirst: !_HeroPresent.of(context),
      itemExtent: _posterWidth,
      verticalPadding: _rowPad,
      height: _posterHeight + 12 + 2 * 26 * 1.25 + 2 * _rowPad,
      items: [
        for (final m in items)
          PosterCard(
            key: ValueKey('${m.sourceAddonId}|${m.id}'),
            item: m,
            allowPrivate: allowPrivate,
            onSelect: () => onOpenItem?.call(m),
            onLongPress: onLongSelect == null ? null : () => onLongSelect!(m),
          ),
      ],
    );
  }
}

/// Entrées « Continuer » visibles pour le profil : une reprise locale dont le
/// fichier n'est pas (ou plus) dans cet appareil (progression venue d'une
/// sauvegarde) est masquée, idem pour un serveur Jellyfin absent.
List<ProgressEntry> _continueEntries(WidgetRef ref) {
  final localIds = {
    for (final i in ref.watch(localItemsProvider).value ?? const []) i.id,
  };
  final serverIds = {
    for (final s
        in ref.watch(jellyfinServersProvider).value ?? const <JellyfinServer>[])
      s.id,
  };
  return [
    for (final e in visibleProgress(
      ref.watch(continueWatchingProvider).value ?? const [],
      ref.watch(currentProfileProvider),
    ))
      if ((!isLocalId(e.metaId) || localIds.contains(e.metaId)) &&
          (!isJellyfinId(e.metaId) ||
              serverIds.contains(parseJellyfinId(e.metaId)?.serverId)))
        e,
  ];
}

class _ContinueRow extends ConsumerWidget {
  const _ContinueRow({this.tvTop = 12});

  /// Marge haute de la rangée TV (maquettes : 8 à 28 selon l'écran).
  final double tvTop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = _continueEntries(ref);
    if (entries.isEmpty) return const SizedBox.shrink();
    final playback = ref.watch(continuePlaybackProvider);
    // Un addon installé ou retiré peut fournir les titres manquants.
    final addons = ref.watch(activeAddonsProvider);
    if (isTvLayout(context)) {
      return Padding(
        padding: EdgeInsets.only(top: tvTop),
        child: TvRow(
          title: context.l10n.continueWatching,
          restorationId: continueRowId,
          routeKey: homeRouteKey,
          autofocusFirst: !_HeroPresent.of(context),
          itemExtent: tvCardWidth,
          gap: tvCardGap,
          titleGap: 20,
          titleHeight: 1.2,
          height: tvCardHeight + 24,
          items: [
            for (final e in entries)
              _ContinueCard(
                key: ValueKey(e.videoId),
                entry: e,
                playback: playback,
                addons: addons,
              ),
          ],
        ),
      );
    }
    return TvRow(
      title: context.l10n.continueWatching,
      restorationId: continueRowId,
      routeKey: homeRouteKey,
      autofocusFirst: !_HeroPresent.of(context),
      itemExtent: _continueWidth,
      verticalPadding: _rowPad,
      height: _continueHeight + 12 + 26 * 1.25 + 24 * 1.3 + 2 * _rowPad,
      items: [
        for (final e in entries)
          _ContinueCard(
            key: ValueKey(e.videoId),
            entry: e,
            playback: playback,
            addons: addons,
          ),
      ],
    );
  }
}

/// Héros de l'accueil TV (maquette TV05) : la reprise la plus récente.
class _HomeHero extends ConsumerStatefulWidget {
  const _HomeHero({super.key, required this.entry});

  final ProgressEntry entry;

  @override
  ConsumerState<_HomeHero> createState() => _HomeHeroState();
}

class _HomeHeroState extends ConsumerState<_HomeHero> {
  late Future<ContinueInfo> _info = _describe();
  bool? _inList;

  Future<ContinueInfo> _describe() {
    final unknown = context.l10n.unknownTitle;
    return ref
        .read(continuePlaybackProvider)
        .describe(widget.entry)
        .catchError(
          (Object _) => ContinueInfo(title: widget.entry.title ?? unknown),
        );
  }

  @override
  void didUpdateWidget(_HomeHero old) {
    super.didUpdateWidget(old);
    if (old.entry.videoId != widget.entry.videoId) {
      _info = _describe();
      _inList = null;
    }
  }

  /// « + Ma liste » n'existe que pour un titre de catalogue (pas de fichier
  /// local ni de serveur Jellyfin).
  bool get _listable =>
      !isLocalId(widget.entry.metaId) && !isJellyfinId(widget.entry.metaId);

  Future<void> _toggleList(ContinueInfo info, bool inList) async {
    final repo = ref.read(libraryRepositoryProvider);
    final profileId = ref.read(currentProfileIdProvider);
    final e = widget.entry;
    if (inList) {
      await repo.remove(profileId, e.metaId);
    } else {
      await repo.add(
        profileId,
        MetaPreview(
          id: e.metaId,
          type: typeForVideo(e.metaId, e.videoId),
          name: info.title,
          poster: info.poster,
          sourceAddonId: '',
          certification: e.certification,
        ),
      );
    }
    if (mounted) setState(() => _inList = !inList);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final e = widget.entry;
    ref.listen(activeAddonsProvider, (_, _) {
      if (mounted) setState(() => _info = _describe());
    });
    final playback = ref.watch(continuePlaybackProvider);
    final libs = ref.watch(libraryProvider).value;
    final inList = _inList ?? (libs?.any((m) => m.id == e.metaId) ?? false);
    return FutureBuilder<ContinueInfo>(
      future: _info,
      builder: (context, snap) {
        final info = snap.data ?? ContinueInfo(title: e.title ?? '');
        final left = e.duration - e.position;
        final parts = [
          l.heroResume.toUpperCase(),
          if (info.subtitle != null) info.subtitle!,
          if (left > Duration.zero)
            l.heroMinutesLeft(left.inMinutes.clamp(1, 99999)),
        ];
        return TvHero(
          eyebrow: parts.join(' · '),
          title: info.title,
          poster: info.poster,
          allowPrivate: info.allowPrivate,
          onResume: () => playback.play(context, e),
          listLabel: _listable
              ? (inList ? l.removeFromList : '+ ${l.myList}')
              : null,
          onList: _listable ? () => _toggleList(info, inList) : null,
        );
      },
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
    this.onLongPress,
    this.allowPrivate = false,
    this.width = _posterWidth,
    this.height = _posterHeight,
  });

  final MetaPreview item;
  final bool allowPrivate;
  final VoidCallback onSelect;

  /// Appui long sur OK (menu de la carte) ; absent : OK ouvre simplement.
  final VoidCallback? onLongPress;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final lumio = context.lumio;
    final source = sourceLabel(item.sourceKind, context.l10n);
    return SizedBox(
      width: width,
      child: FocusableCard(
        onSelect: onSelect,
        onLongPress: onLongPress,
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
              height: height,
              width: width,
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
                      width: width,
                    ),
                  ),
                  // Badge réel (Local / Jellyfin) ; un titre de catalogue n'a pas
                  // de source connue avant la recherche de flux (Direct /
                  // Torrent y sont affichés), donc plus de badge « addon ».
                  if (item.sourceKind == 'local' ||
                      item.sourceKind == jellyfinSourceKind)
                    PositionedDirectional(
                      start: 10,
                      top: 10,
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: lumio.text,
                fontSize: 26,
                height: 1.25,
              ),
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
  const _ContinueCard({
    super.key,
    required this.entry,
    required this.playback,
    required this.addons,
  });

  final ProgressEntry entry;
  final ContinuePlayback playback;

  /// Addons actifs : une nouvelle liste relance la description du titre.
  final List<ActiveAddon> addons;

  @override
  State<_ContinueCard> createState() => _ContinueCardState();
}

class _ContinueCardState extends State<_ContinueCard> {
  late Future<ContinueInfo> _info = _describe();

  Future<ContinueInfo> _describe() {
    final unknown = context.l10n.unknownTitle;
    return widget.playback
        .describe(widget.entry)
        .catchError(
          (Object _) => ContinueInfo(title: widget.entry.title ?? unknown),
        );
  }

  @override
  void didUpdateWidget(_ContinueCard old) {
    super.didUpdateWidget(old);
    if (old.entry.videoId != widget.entry.videoId ||
        old.playback != widget.playback ||
        !identical(old.addons, widget.addons)) {
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
          final info = snap.data ?? ContinueInfo(title: e.title ?? '');
          if (isTvLayout(context)) {
            return TvMediaCard(
              title: info.title,
              seed: e.metaId,
              poster: info.poster,
              allowPrivate: info.allowPrivate,
              badge: isLocalId(e.metaId)
                  ? sourceLabel('local', context.l10n)
                  : isJellyfinId(e.metaId)
                  ? sourceLabel(jellyfinSourceKind, context.l10n)
                  : null,
              progress: progress,
              semanticLabel: context.l10n.resumeSemantic(info.title),
              onSelect: () => widget.playback.play(context, e),
            );
          }
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
    if (isTvLayout(context)) {
      return Semantics(
        label: context.l10n.loading,
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            key: const ValueKey('skeleton-row'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title == null)
                Padding(
                  padding: const EdgeInsets.only(left: 96, bottom: 20, top: 4),
                  child: Container(
                    height: 34,
                    width: 360,
                    decoration: BoxDecoration(
                      color: lumio.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                )
              else
                TvRowTitle(title!),
              const TvSkeletonCards(),
            ],
          ),
        ),
      );
    }
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
    if (isTvLayout(context)) {
      return Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TvRowTitle(title),
            TvErrorBand(message: message, onRetry: onRetry),
          ],
        ),
      );
    }
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

/// Confirmation de sortie (Retour depuis « Accueil »).
class _QuitDialog extends StatefulWidget {
  const _QuitDialog();

  @override
  State<_QuitDialog> createState() => _QuitDialogState();
}

class _QuitDialogState extends State<_QuitDialog> {
  // Un Retour télécommande peut arriver deux fois (touche puis geste système) :
  // pendant 700 ms le Retour ne ferme pas la confirmation qu'il vient d'ouvrir.
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _armed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.lumio;
    final t = Theme.of(context).textTheme;
    return PopScope(
      canPop: _armed,
      child: Dialog(
        key: const ValueKey('quit-dialog'),
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: SizedBox(
            width: 720,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.quitTitle,
                  style: t.headlineMedium?.copyWith(fontSize: 44),
                ),
                const SizedBox(height: 16),
                Text(
                  l.quitBody,
                  style: t.bodyLarge?.copyWith(
                    color: c.textMuted,
                    fontSize: 30,
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    TvButton(
                      autofocus: true,
                      label: l.cancel,
                      kind: TvButtonKind.secondary,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(width: 24),
                    TvButton(
                      label: l.quitAction,
                      onPressed: () => Navigator.of(context).pop(true),
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
