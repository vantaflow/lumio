import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:lumio/data/db.dart';
import 'package:lumio_core/lumio_core.dart';

/// « Ma liste » : titres mis de côté, par profil (SQLite).
class LibraryRepository {
  LibraryRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  /// Ajoute [item] en tête de liste ; sans effet s'il y est déjà.
  Future<void> add(String profileId, MetaPreview item) async {
    final stamp = _now().millisecondsSinceEpoch;
    await _db
        .into(_db.libraryItems)
        .insert(
          LibraryItemsCompanion.insert(
            profileId: Value(profileId),
            itemId: item.id,
            type: item.type,
            metaJson: Value(jsonEncode(_toJson(item))),
            addedAt: Value(stamp),
            certification: Value(item.certification),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> remove(String profileId, String metaId) =>
      (_db.delete(_db.libraryItems)..where(
            (t) => t.profileId.equals(profileId) & t.itemId.equals(metaId),
          ))
          .go();

  Future<bool> contains(String profileId, String metaId) async {
    final row =
        await (_db.select(_db.libraryItems)..where(
              (t) => t.profileId.equals(profileId) & t.itemId.equals(metaId),
            ))
            .getSingleOrNull();
    return row != null;
  }

  /// Liste du profil, du plus récent au plus ancien. Une ligne illisible est
  /// ignorée (jamais d'erreur sur l'accueil).
  Stream<List<MetaPreview>> watch(String profileId) {
    final q = _db.select(_db.libraryItems)
      ..where((t) => t.profileId.equals(profileId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.addedAt),
        (t) => OrderingTerm.desc(t.itemId),
      ]);
    return q.watch().map((rows) => [for (final r in rows) ?_fromRow(r)]);
  }

  static Map<String, Object?> _toJson(MetaPreview m) => {
    'id': m.id,
    'type': m.type,
    'name': m.name,
    'poster': m.poster?.toString(),
    'releaseInfo': m.releaseInfo,
    'certification': m.certification,
    'sourceAddonId': m.sourceAddonId,
    'sourceKind': m.sourceKind,
  };

  static MetaPreview? _fromRow(LibraryItem r) {
    try {
      final j = jsonDecode(r.metaJson);
      if (j is! Map) return null;
      final poster = j['poster'];
      final uri = poster is String ? Uri.tryParse(poster) : null;
      return MetaPreview(
        id: r.itemId,
        type: r.type,
        name: j['name'] is String ? j['name'] as String : r.itemId,
        poster: uri != null && (uri.scheme == 'http' || uri.scheme == 'https')
            ? uri
            : null,
        releaseInfo: j['releaseInfo'] as String?,
        // La colonne fait foi (filtre enfant) ; le JSON sert de repli.
        certification: r.certification ?? j['certification'] as String?,
        sourceAddonId: j['sourceAddonId'] is String
            ? j['sourceAddonId'] as String
            : '',
        sourceKind: j['sourceKind'] is String
            ? j['sourceKind'] as String
            : 'addon',
      );
    } on Object catch (e) {
      debugPrint('Ma liste : ligne illisible (${e.runtimeType})');
      return null;
    }
  }
}
