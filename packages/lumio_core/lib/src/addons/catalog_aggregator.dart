import 'dart:async';
import 'dart:collection';

import '../cache/ttl_cache.dart';
import 'addon_client.dart';
import 'manifest.dart';
import 'meta_preview.dart';

/// Une rangée de l'accueil : un catalogue d'un addon, ou son erreur.
class CatalogRow {
  const CatalogRow({
    required this.addonId,
    required this.catalogId,
    required this.type,
    required this.title,
    this.items = const [],
    this.error,
  });

  final String addonId;
  final String catalogId;
  final String type;
  final String title;
  final List<MetaPreview> items;

  /// En général une [AddonException] dont le message (français) est affiché.
  final Object? error;

  bool get failed => error != null;
}

/// Charge les catalogues de plusieurs addons en parallèle, avec isolation des
/// pannes : une erreur ou un addon lent ne bloque jamais les autres rangées.
class CatalogAggregator {
  CatalogAggregator(this._client, this._cache, {this.maxConcurrent = 4});

  final AddonClient _client;
  final TtlCache _cache;
  final int maxConcurrent;

  final Queue<Completer<void>> _waiting = Queue();
  var _running = 0;

  /// Nombre maximal de pages mémorisées par catalogue (les plus récentes).
  static const maxPagesPerCatalog = 50;

  // Par catalogue : skip -> éléments livrés (skip 0 = rangée d'accueil),
  // avec la même durée de vie que le cache.
  final Map<String, _Delivered> _delivered = {};

  /// Émet une rangée par catalogue (hors catalogues à extra obligatoire,
  /// comme la recherche), dans l'ordre d'arrivée.
  Stream<CatalogRow> rows(List<AddonManifest> addons) {
    final out = StreamController<CatalogRow>();
    var cancelled = false;
    out.onCancel = () => cancelled = true;

    Future<void> one(AddonManifest a, CatalogDecl c) async {
      if (cancelled) return;
      CatalogRow row;
      try {
        final items = await _fetch(
          a,
          c,
          const {},
          isCancelled: () => cancelled,
        );
        if (cancelled) return; // ne pas toucher à l'état d'une rangée annulée
        _deliveredFor(a, c, reset: true).pages[0] = items;
        row = CatalogRow(
          addonId: a.id,
          catalogId: c.id,
          type: c.type,
          title: c.name,
          items: items,
        );
      } catch (e) {
        row = CatalogRow(
          addonId: a.id,
          catalogId: c.id,
          type: c.type,
          title: c.name,
          error: _asAddonException(e),
        );
      }
      if (!cancelled && !out.isClosed) out.add(row);
    }

    final jobs = <Future<void>>[
      for (final a in addons)
        for (final c in a.catalogs)
          if (!c.extra.any((e) => e.isRequired)) one(a, c),
    ];
    Future.wait(jobs).whenComplete(() {
      if (!out.isClosed) out.close();
    });
    return out.stream;
  }

  /// Page suivante d'un catalogue, sans les identifiants déjà renvoyés pour ce
  /// catalogue. Lève [AddonException] si l'addon échoue.
  Future<List<MetaPreview>> page(
    AddonManifest a,
    CatalogDecl c, {
    required int skip,
  }) async {
    final delivered = _deliveredFor(a, c).pages;
    final known = delivered[skip];
    if (known != null) return known; // même page : même résultat
    final items = await _fetch(a, c, {if (skip > 0) 'skip': '$skip'});
    final again = delivered[skip];
    if (again != null) return again;
    // Dédoublonne seulement contre les pages de skip inférieur déjà livrées.
    final seen = <String>{
      for (final e in delivered.entries)
        if (e.key < skip) ...e.value.map((m) => m.id),
    };
    final page = List<MetaPreview>.unmodifiable([
      for (final m in items)
        if (seen.add(m.id)) m,
    ]);
    delivered[skip] = page;
    // Ne garde que les pages les plus récentes (la rangée d'accueil, skip 0,
    // sert de référence de dédoublonnage : elle reste).
    while (delivered.length > maxPagesPerCatalog) {
      delivered.remove(delivered.keys.firstWhere((k) => k != 0));
    }
    return page;
  }

  _Delivered _deliveredFor(
    AddonManifest a,
    CatalogDecl c, {
    bool reset = false,
  }) {
    final key = '${a.transportUrl}|${c.type}|${c.id}';
    final now = _cache.now();
    var d = _delivered[key];
    if (reset || d == null || !now.isBefore(d.expires)) {
      d = _delivered[key] = _Delivered(now.add(_cache.ttl));
    }
    return d;
  }

  Future<List<MetaPreview>> _fetch(
    AddonManifest a,
    CatalogDecl c,
    Map<String, String> extra, {
    bool Function()? isCancelled,
  }) async {
    final key = _key(a, c, extra);
    final hit = _cache.get<List<MetaPreview>>(key);
    if (hit != null) return hit;
    await _acquire();
    try {
      if (isCancelled?.call() ?? false) return const [];
      final items = await _client.catalog(a, c.type, c.id, extra: extra);
      final frozen = List<MetaPreview>.unmodifiable(items);
      _cache.put(key, frozen);
      return frozen;
    } finally {
      _release();
    }
  }

  static String _key(
    AddonManifest a,
    CatalogDecl c,
    Map<String, String> extra,
  ) {
    final sorted = extra.entries.toList()
      ..sort((x, y) => x.key.compareTo(y.key));
    final e = sorted.map((e) => '${e.key}=${e.value}').join('&');
    return '${a.transportUrl}|${c.type}|${c.id}|$e';
  }

  Future<void> _acquire() {
    if (_running < maxConcurrent) {
      _running++;
      return Future.value();
    }
    final c = Completer<void>();
    _waiting.add(c);
    return c.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete(); // la place est transmise
    } else {
      _running--;
    }
  }

  static AddonException _asAddonException(Object e) => e is AddonException
      ? e
      : AddonException('Erreur inattendue lors du chargement', cause: e);
}

class _Delivered {
  _Delivered(this.expires);
  final DateTime expires;
  final Map<int, List<MetaPreview>> pages = {};
}
