import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/library_repository.dart';
import 'package:lumio/features/home/continue_playback.dart';
import 'package:lumio/features/home/home_layout.dart';
import 'package:lumio/providers.dart';
import 'package:lumio_core/lumio_core.dart';

/// Cache des catalogues, partagé et conservé : l'accueil rouvert avec un
/// cache chaud n'attend pas le réseau (ENF-1).
final catalogCacheProvider = Provider<TtlCache>((ref) => TtlCache());

typedef AggregatorFactory =
    CatalogAggregator Function({required bool allowPrivate});

/// Un agrégateur par niveau de confiance réseau (adresses privées permises ou
/// non), partageant le même cache.
final aggregatorFactoryProvider = Provider<AggregatorFactory>((ref) {
  final cache = ref.watch(catalogCacheProvider);
  final made = <bool, CatalogAggregator>{};
  return ({required bool allowPrivate}) => made.putIfAbsent(
    allowPrivate,
    () => CatalogAggregator(
      defaultAddonClient(allowPrivate: allowPrivate),
      cache,
    ),
  );
});

final continuePlaybackProvider = Provider<ContinuePlayback>(
  (ref) => const StubContinuePlayback(),
);

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => InMemoryLibraryRepository(),
);

final libraryProvider = StreamProvider<List<MetaPreview>>(
  (ref) => ref
      .watch(libraryRepositoryProvider)
      .watch(ref.watch(currentProfileIdProvider)),
);

final homeLayoutStoreProvider = Provider<HomeLayoutStore>(
  (ref) => HomeLayoutStore(ref.watch(appDatabaseProvider)),
);

/// Disposition de l'accueil du profil actif.
final homeLayoutProvider =
    AsyncNotifierProvider<HomeLayoutController, HomeLayout>(
      HomeLayoutController.new,
    );

class HomeLayoutController extends AsyncNotifier<HomeLayout> {
  @override
  Future<HomeLayout> build() => ref
      .read(homeLayoutStoreProvider)
      .load(ref.watch(currentProfileIdProvider));

  Future<void> _set(HomeLayout layout) async {
    state = AsyncData(layout);
    try {
      await ref
          .read(homeLayoutStoreProvider)
          .save(ref.read(currentProfileIdProvider), layout);
    } on Object catch (e) {
      // La disposition reste appliquée pour la session ; l'échec est signalé
      // seulement dans le journal (aucune donnée sensible ici).
      debugPrint(
        'Disposition de l\'accueil non enregistrée (${e.runtimeType})',
      );
    }
  }

  Future<void> setHidden(String id, bool hidden) {
    final cur = state.value ?? const HomeLayout();
    return _set(
      cur.copyWith(
        hidden: hidden ? {...cur.hidden, id} : ({...cur.hidden}..remove(id)),
      ),
    );
  }

  /// Déplace [id] d'un cran dans [arranged] (ordre complet courant).
  Future<void> move(String id, int delta, List<String> arranged) {
    final i = arranged.indexOf(id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= arranged.length) return Future.value();
    final order = [...arranged];
    order.insert(j, order.removeAt(i));
    return _set((state.value ?? const HomeLayout()).copyWith(order: order));
  }
}

/// Rangée de catalogue attendue (connue avant l'arrivée des données).
@immutable
class RowSpec {
  const RowSpec({
    required this.id,
    required this.title,
    required this.manifest,
    required this.catalog,
    required this.allowPrivate,
  });

  final String id;
  final String title;
  final AddonManifest manifest;
  final CatalogDecl catalog;
  final bool allowPrivate;

  String get addonName => manifest.name;
}

class HomeRowsState {
  const HomeRowsState({
    this.specs = const [],
    this.rows = const {},
    this.privateAddons = const {},
  });

  final List<RowSpec> specs;

  /// Rangées déjà arrivées (par identifiant de rangée).
  final Map<String, CatalogRow> rows;

  /// Addons approuvés pour le réseau privé (leurs affiches aussi).
  final Set<String> privateAddons;

  bool get complete => specs.every((s) => rows.containsKey(s.id));
}

/// Vrai si l'adresse désigne l'appareil ou le réseau local : l'addon n'a pu
/// être installé qu'avec l'approbation explicite `allowPrivate`.
bool isPrivateAddress(Uri u) {
  try {
    UrlGuard.check(u);
    return false;
  } on UnsafeUrlException catch (e) {
    return e.code == UnsafeUrlReason.privateAddress;
  }
}

/// Charge les catalogues des addons actifs ; chaque rangée arrive seule et
/// seule la rangée concernée se reconstruit (via `select` par identifiant).
final homeRowsProvider = NotifierProvider<HomeRowsController, HomeRowsState>(
  HomeRowsController.new,
);

class HomeRowsController extends Notifier<HomeRowsState> {
  final List<StreamSubscription<CatalogRow>> _subs = [];

  @override
  HomeRowsState build() {
    ref.onDispose(_cancel);
    _cancel();
    final addons = ref.watch(addonsProvider).value;
    if (addons == null) return const HomeRowsState();
    final usable = [
      for (final a in addons)
        if (a.enabled && !a.broken) a.manifest!,
    ];
    final specs = <RowSpec>[];
    final privateAddons = <String>{};
    for (final m in usable) {
      final priv = isPrivateAddress(m.transportUrl);
      if (priv) privateAddons.add(m.id);
      for (final c in m.catalogs) {
        if (c.extra.any((e) => e.isRequired)) continue;
        specs.add(
          RowSpec(
            id: catalogRowId(m.id, c.type, c.id),
            title: c.name,
            manifest: m,
            catalog: c,
            allowPrivate: priv,
          ),
        );
      }
    }
    _load(usable);
    return HomeRowsState(specs: specs, privateAddons: privateAddons);
  }

  void _load(List<AddonManifest> manifests) {
    final factory = ref.read(aggregatorFactoryProvider);
    for (final priv in [false, true]) {
      final group = [
        for (final m in manifests)
          if (isPrivateAddress(m.transportUrl) == priv) m,
      ];
      if (group.isEmpty) continue;
      _subs.add(
        factory(allowPrivate: priv).rows(group).listen(_onRow, onError: (_) {}),
      );
    }
  }

  void _onRow(CatalogRow row) {
    final id = catalogRowId(row.addonId, row.type, row.catalogId);
    state = HomeRowsState(
      specs: state.specs,
      rows: {...state.rows, id: row},
      privateAddons: state.privateAddons,
    );
  }

  void _cancel() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  /// Relance une rangée en erreur : elle repasse en squelette.
  void retry(String rowId) {
    final spec = state.specs.where((s) => s.id == rowId).firstOrNull;
    if (spec == null) return;
    state = HomeRowsState(
      specs: state.specs,
      rows: {...state.rows}..remove(rowId),
      privateAddons: state.privateAddons,
    );
    final single = AddonManifest(
      id: spec.manifest.id,
      version: spec.manifest.version,
      name: spec.manifest.name,
      types: spec.manifest.types,
      resources: spec.manifest.resources,
      catalogs: [spec.catalog],
      transportUrl: spec.manifest.transportUrl,
      description: spec.manifest.description,
      logo: spec.manifest.logo,
      idPrefixes: spec.manifest.idPrefixes,
    );
    _subs.add(
      ref
          .read(aggregatorFactoryProvider)(allowPrivate: spec.allowPrivate)
          .rows([single])
          .listen(_onRow, onError: (_) {}),
    );
  }
}

/// Éléments visibles par le profil actif (filtre d'âge : certification
/// inconnue masquée pour un profil enfant).
List<MetaPreview> visibleItems(List<MetaPreview> items, Profile? profile) {
  if (profile == null || !profile.isKid) return items;
  final limit = AgeLimit.values[profile.ageLimit];
  return [
    for (final m in items)
      if (ratingAllows(m.certification, limit)) m,
  ];
}

enum HomePhase { loading, error, noAddons, filtered, ready }

/// Vue d'ensemble de l'accueil ; comparée par valeur pour que l'écran ne se
/// reconstruise pas à chaque rangée qui arrive.
@immutable
class HomeSummary {
  const HomeSummary(this.phase, this.catalogIds);

  final HomePhase phase;
  final List<String> catalogIds;

  @override
  bool operator ==(Object other) =>
      other is HomeSummary &&
      other.phase == phase &&
      listEquals(other.catalogIds, catalogIds);

  @override
  int get hashCode => Object.hash(phase, Object.hashAll(catalogIds));
}

final homeSummaryProvider = Provider<HomeSummary>((ref) {
  final addons = ref.watch(addonsProvider);
  if (!addons.hasValue) {
    return HomeSummary(
      addons.hasError ? HomePhase.error : HomePhase.loading,
      const [],
    );
  }
  final specs = ref.watch(homeRowsProvider.select((s) => s.specs));
  final ids = [for (final s in specs) s.id];
  if (specs.isEmpty) return HomeSummary(HomePhase.noAddons, ids);

  final profile = ref.watch(currentProfileProvider);
  if (profile != null && profile.isKid) {
    final rows = ref.watch(homeRowsProvider);
    final cont = ref.watch(continueWatchingProvider).value ?? const [];
    final lib = ref.watch(libraryProvider).value ?? const [];
    if (rows.complete && cont.isEmpty && lib.isEmpty) {
      final raw = rows.rows.values.fold<int>(0, (n, r) => n + r.items.length);
      final shown = rows.rows.values.fold<int>(
        0,
        (n, r) => n + visibleItems(r.items, profile).length,
      );
      if (raw > 0 && shown == 0) return HomeSummary(HomePhase.filtered, ids);
    }
  }
  return HomeSummary(HomePhase.ready, ids);
});
