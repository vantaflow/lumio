import 'dart:convert';

import 'catalog_cache.dart';
import 'catalog_models.dart';
import 'catalog_source.dart';

/// D'où vient le résultat affiché.
enum CatalogOrigin {
  /// Téléchargé à l'instant.
  network,

  /// Cache de moins de 24 h.
  cache,

  /// Cache périmé (site injoignable ou format changé) : hors ligne.
  staleCache,

  /// Collection officielle (liste réduite).
  fallback,
}

class CatalogResult<T> {
  const CatalogResult(this.value, this.origin, this.fetchedAt);
  final T value;
  final CatalogOrigin origin;
  final DateTime fetchedAt;
}

/// Catalogue avec cache de 24 h, hors ligne et repli.
///
/// Ordre : cache frais → site → cache périmé → collection officielle → erreur
/// ([CatalogUnavailableException] ou [CatalogParseException] du dernier essai).
/// [refresh] ignore le cache frais (rafraîchissement manuel).
class AddonCatalogService {
  AddonCatalogService(
    this._source,
    this._store, {
    this.ttl = const Duration(hours: 24),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AddonCatalogSource _source;
  final CatalogCacheStore _store;
  final Duration ttl;
  final DateTime Function() _now;

  static const _collectionKey = 'collection';

  Future<CatalogResult<CatalogPage>> list(
    CatalogQuery q, {
    bool refresh = false,
  }) async {
    final cached = await _read(q.key, (j) => CatalogPage.fromJson(j));
    if (!refresh && cached != null && _fresh(cached.at)) {
      return CatalogResult(cached.value, CatalogOrigin.cache, cached.at);
    }
    Object? failure;
    try {
      final page = await _source.list(q);
      final at = _now();
      await _store.write(q.key, jsonEncode(page.toJson()), at);
      return CatalogResult(page, CatalogOrigin.network, at);
    } on CatalogParseException catch (e) {
      failure = e;
    } on CatalogUnavailableException catch (e) {
      failure = e;
    }
    if (cached != null) {
      return CatalogResult(cached.value, CatalogOrigin.staleCache, cached.at);
    }
    // Repli : première page seulement (la collection n'est pas paginée).
    if (q.page == 1) {
      final fb = await _collection(refresh: refresh);
      if (fb != null) {
        final entries = [
          for (final e in fb.value.entries)
            if (_matches(e, q.categories)) e,
        ];
        return CatalogResult(
          CatalogPage(entries: entries, total: entries.length),
          CatalogOrigin.fallback,
          fb.at,
        );
      }
    }
    throw failure;
  }

  Future<CatalogResult<CatalogDetail>> detail(
    String slug, {
    bool refresh = false,
  }) async {
    final key = 'detail|$slug';
    final cached = await _read(key, CatalogDetail.fromJson);
    if (!refresh && cached != null && _fresh(cached.at)) {
      return CatalogResult(cached.value, CatalogOrigin.cache, cached.at);
    }
    try {
      final d = await _source.detail(slug);
      final at = _now();
      await _store.write(key, jsonEncode(d.toJson()), at);
      return CatalogResult(d, CatalogOrigin.network, at);
    } on CatalogParseException {
      if (cached == null) rethrow;
    } on CatalogUnavailableException {
      if (cached == null) rethrow;
    }
    return CatalogResult(cached.value, CatalogOrigin.staleCache, cached.at);
  }

  bool _fresh(DateTime at) {
    final age = _now().difference(at);
    return !age.isNegative && age < ttl;
  }

  Future<({CatalogPage value, DateTime at})?> _collection({
    bool refresh = false,
  }) async {
    final cached = await _read(_collectionKey, (j) => CatalogPage.fromJson(j));
    if (!refresh && cached != null && _fresh(cached.at)) return cached;
    try {
      final page = await _source.collection();
      final at = _now();
      await _store.write(_collectionKey, jsonEncode(page.toJson()), at);
      return (value: page, at: at);
    } on CatalogParseException {
      return cached;
    } on CatalogUnavailableException {
      return cached;
    }
  }

  Future<({T value, DateTime at})?> _read<T>(
    String key,
    T Function(Map<String, Object?>) decode,
  ) async {
    final e = await _store.read(key);
    if (e == null) return null;
    try {
      final j = jsonDecode(e.data);
      if (j is! Map) return null;
      return (value: decode(j.cast<String, Object?>()), at: e.at);
    } catch (_) {
      return null;
    }
  }

  /// Filtre de la collection officielle (types et ressources du manifest) ;
  /// une catégorie sans équivalent n'exclut rien.
  static bool _matches(CatalogEntry e, List<String> categories) {
    if (categories.isEmpty) return true;
    var known = false;
    for (final c in categories) {
      switch (c) {
        case CatalogCategories.movies:
        case CatalogCategories.tvShows:
          known = true;
          if (e.types.contains('movie') || e.types.contains('series')) {
            return true;
          }
        case CatalogCategories.anime:
          known = true;
          if (e.types.contains('anime')) return true;
        case CatalogCategories.subtitles:
          known = true;
          if (e.resources.contains('subtitles')) return true;
        case CatalogCategories.metadata:
          known = true;
          if (e.resources.contains('meta') && !e.resources.contains('stream')) {
            return true;
          }
        default:
      }
    }
    return !known;
  }
}
