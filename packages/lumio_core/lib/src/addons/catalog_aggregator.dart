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
  final Map<String, Set<String>> _seen = {};

  /// Émet une rangée par catalogue (hors catalogues à extra obligatoire,
  /// comme la recherche), dans l'ordre d'arrivée.
  Stream<CatalogRow> rows(List<AddonManifest> addons) {
    final out = StreamController<CatalogRow>();
    var cancelled = false;
    out.onCancel = () => cancelled = true;

    Future<void> one(AddonManifest a, CatalogDecl c) async {
      CatalogRow row;
      try {
        final items = await _fetch(a, c, const {});
        _seenFor(a, c)
          ..clear()
          ..addAll(items.map((m) => m.id));
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
    final items = await _fetch(a, c, {if (skip > 0) 'skip': '$skip'});
    final seen = _seenFor(a, c);
    return [
      for (final m in items)
        if (seen.add(m.id)) m,
    ];
  }

  Set<String> _seenFor(AddonManifest a, CatalogDecl c) =>
      _seen.putIfAbsent('${a.transportUrl}|${c.type}|${c.id}', () => {});

  Future<List<MetaPreview>> _fetch(
    AddonManifest a,
    CatalogDecl c,
    Map<String, String> extra,
  ) async {
    final key = _key(a, c, extra);
    final hit = _cache.get<List<MetaPreview>>(key);
    if (hit != null) return hit;
    await _acquire();
    try {
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
