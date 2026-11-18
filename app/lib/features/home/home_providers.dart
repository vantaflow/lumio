import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/library_repository.dart';
import 'package:lumio/data/progress_repository.dart';
import 'package:lumio/features/addons/health_providers.dart';
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
      withHealth(ref, defaultAddonClient(allowPrivate: allowPrivate)),
      cache,
    ),
  );
});

final continuePlaybackProvider = Provider<ContinuePlayback>(
  (ref) => DefaultContinuePlayback(ref),
);

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(ref.watch(appDatabaseProvider)),
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

  Future<void> setHidden(String id, bool hidden) async {
    // Attend la disposition chargée : jamais d'écrasement par les défauts.
    final cur = state.value ?? await future;
    return _set(
      cur.copyWith(
        hidden: hidden ? {...cur.hidden, id} : ({...cur.hidden}..remove(id)),
      ),
    );
  }

  /// Déplace [id] d'un cran dans [arranged] (ordre complet courant).
  Future<void> move(String id, int delta, List<String> arranged) async {
    final i = arranged.indexOf(id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= arranged.length) return;
    final cur = state.value ?? await future;
    final order = [...arranged];
    order.insert(j, order.removeAt(i));
    return _set(cur.copyWith(order: order));
  }
}

/// Rangée de catalogue attendue (connue avant l'arrivée des données).
@immutable
class RowSpec {
  const RowSpec({
    required this.id,
    required this.addonId,
    required this.title,
    required this.manifest,
    required this.catalog,
    required this.allowPrivate,
  });

  final String id;

  /// Identifiant de stockage de l'addon (unique), pas celui du manifeste.
  final String addonId;
  final String title;
  final AddonManifest manifest;
  final CatalogDecl catalog;

  /// Vrai si l'agrégateur qui produit la rangée accepte le réseau privé ;
  /// vaut aussi pour les affiches de la rangée.
  final bool allowPrivate;

  String get addonName => manifest.name;
}

class HomeRowsState {
  const HomeRowsState({this.specs = const [], this.rows = const {}});

  final List<RowSpec> specs;

  /// Rangées déjà arrivées (par identifiant de rangée).
  final Map<String, CatalogRow> rows;

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
  final Map<String, StreamSubscription<CatalogRow>> _retries = {};

  @override
  HomeRowsState build() {
    ref.onDispose(_cancel);
    _cancel();
    final addons = ref.watch(addonsProvider).value;
    if (addons == null) return const HomeRowsState();
    final usable = [
      for (final a in addons)
        if (a.enabled && !a.broken) a,
    ];
    final specs = <RowSpec>[];
    for (final a in usable) {
      final m = a.manifest!;
      final priv = isPrivateAddress(m.transportUrl);
      for (final c in m.catalogs) {
        if (c.extra.any((e) => e.isRequired)) continue;
        specs.add(
          RowSpec(
            id: catalogRowId(a.id, c.type, c.id),
            addonId: a.id,
            title: c.name,
            manifest: m,
            catalog: c,
            allowPrivate: priv,
          ),
        );
      }
    }
    _load(usable);
    return HomeRowsState(specs: specs);
  }

  /// Un flux par addon : la rangée est rattachée à l'identifiant de stockage
  /// (deux addons peuvent déclarer le même identifiant de manifeste).
  void _load(List<InstalledAddon> addons) {
    final factory = ref.read(aggregatorFactoryProvider);
    for (final a in addons) {
      final m = a.manifest!;
      _subs.add(
        factory(
          allowPrivate: isPrivateAddress(m.transportUrl),
        ).rows([m]).listen((r) => _onRow(a.id, r), onError: (_) {}),
      );
    }
  }

  void _onRow(String addonId, CatalogRow row) {
    final id = catalogRowId(addonId, row.type, row.catalogId);
    state = HomeRowsState(specs: state.specs, rows: {...state.rows, id: row});
  }

  void _cancel() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    for (final s in _retries.values) {
      s.cancel();
    }
    _retries.clear();
  }

  /// Relance une rangée en erreur : elle repasse en squelette.
  void retry(String rowId) {
    final spec = state.specs.where((s) => s.id == rowId).firstOrNull;
    if (spec == null) return;
    _retries.remove(rowId)?.cancel();
    state = HomeRowsState(
      specs: state.specs,
      rows: {...state.rows}..remove(rowId),
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
    _retries[rowId] = ref
        .read(aggregatorFactoryProvider)(allowPrivate: spec.allowPrivate)
        .rows([single])
        .listen((r) => _onRow(spec.addonId, r), onError: (_) {});
  }
}

/// Limite d'âge d'un profil enfant ; valeur corrompue = la plus stricte.
AgeLimit _limitOf(Profile p) =>
    p.ageLimit >= 0 && p.ageLimit < AgeLimit.values.length
    ? AgeLimit.values[p.ageLimit]
    : AgeLimit.all;

/// Vrai si [profile] peut voir un contenu de [certification] (profil enfant :
/// certification inconnue refusée).
bool profileAllows(Profile? profile, String? certification) =>
    profile == null ||
    !profile.isKid ||
    ratingAllows(certification, _limitOf(profile));

/// Règle unique des profils enfants pour une fiche : refusé si une
/// certification connue ([certs], valeurs nulles ignorées) n'est pas permise,
/// ou si aucune n'est connue.
bool contentAllowed(Profile? profile, Iterable<String?> certs) {
  if (profile == null || !profile.isKid) return true;
  final known = [for (final c in certs) ?c];
  return known.isNotEmpty && known.every((c) => profileAllows(profile, c));
}

/// Éléments visibles par le profil actif (filtre d'âge : certification
/// inconnue masquée pour un profil enfant).
List<MetaPreview> visibleItems(List<MetaPreview> items, Profile? profile) {
  if (profile == null || !profile.isKid) return items;
  final limit = _limitOf(profile);
  return [
    for (final m in items)
      if (ratingAllows(m.certification, limit)) m,
  ];
}

/// Même règle pour « Continuer » (certification mémorisée avec la progression).
List<ProgressEntry> visibleProgress(
  List<ProgressEntry> entries,
  Profile? profile,
) {
  if (profile == null || !profile.isKid) return entries;
  final limit = _limitOf(profile);
  return [
    for (final e in entries)
      if (ratingAllows(e.certification, limit)) e,
  ];
}

enum HomePhase { loading, error, noAddons, filtered, noCatalog, ready }

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
  final rows = ref.watch(homeRowsProvider);
  if (rows.complete && rows.rows.values.every((r) => !r.failed)) {
    final cont = visibleProgress(
      ref.watch(continueWatchingProvider).value ?? const [],
      profile,
    );
    final lib = visibleItems(
      ref.watch(libraryProvider).value ?? const [],
      profile,
    );
    if (cont.isEmpty && lib.isEmpty) {
      final raw = rows.rows.values.fold<int>(0, (n, r) => n + r.items.length);
      final shown = rows.rows.values.fold<int>(
        0,
        (n, r) => n + visibleItems(r.items, profile).length,
      );
      if (raw == 0) return HomeSummary(HomePhase.noCatalog, ids);
      if (shown == 0) return HomeSummary(HomePhase.filtered, ids);
    }
  }
  return HomeSummary(HomePhase.ready, ids);
});
