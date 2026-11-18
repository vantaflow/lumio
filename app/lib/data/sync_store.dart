import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lumio/data/addon_sync.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/sync_schema.dart';
import 'package:lumio_core/lumio_core.dart';

/// Nombre maximal de profils (voir `ProfileRepository`).
const _maxProfiles = 6;
const _maxNameLength = 40;

/// Base locale (SQLite) vue par le moteur de synchronisation.
///
/// Les addons passent par [AddonSync] (blob chiffré, installation par le chemin
/// normal) : sans lui ils ne sont ni envoyés ni appliqués.
///
/// Défense en profondeur : tout ce qui arrive du serveur est revalidé ici
/// (liste blanche de réglages, bornes, types) avant d'écrire, et le contenu
/// d'un PIN n'est jamais lu ni écrit.
class DriftLocalSyncStore implements LocalSyncStore {
  DriftLocalSyncStore(this._db, {DateTime Function()? now, AddonSync? addons})
    : _now = now ?? DateTime.now,
      _addons = addons;

  final AppDatabase _db;
  final AddonSync? _addons;
  final DateTime Function() _now;

  static const _lastVersionKey = 'last_version';

  Future<String?> _meta(String key) async {
    final r = await _db
        .customSelect(
          'SELECT value FROM sync_meta WHERE key = ?',
          variables: [Variable.withString(key)],
        )
        .getSingleOrNull();
    return r?.read<String>('value');
  }

  Future<void> _setMeta(String key, String value) => _db.customStatement(
    'INSERT OR REPLACE INTO sync_meta (key, value) VALUES (?, ?)',
    [key, value],
  );

  @override
  Future<int> lastVersion() async =>
      int.tryParse(await _meta(_lastVersionKey) ?? '') ?? 0;

  @override
  Future<void> setLastVersion(int version) =>
      _setMeta(_lastVersionKey, '$version');

  /// Remet tout le contenu synchronisable dans la file (à la connexion).
  Future<void> markAllDirty() async {
    for (final s in syncBackfillStatements) {
      await _db.customStatement(s);
    }
  }

  /// Oublie l'état de synchronisation (déconnexion, changement de compte) :
  /// la file est vidée et le curseur remis à zéro. Les données locales restent.
  Future<void> reset() async {
    await _db.customStatement('DELETE FROM sync_outbox');
    await _db.customStatement('DELETE FROM sync_meta');
  }

  Future<int> pendingCount() async =>
      (await _db
              .customSelect('SELECT COUNT(*) AS n FROM sync_outbox')
              .getSingle())
          .read<int>('n');

  // --- Envoi -------------------------------------------------------------

  @override
  Future<List<PendingChange>> pending(int limit) async {
    final rows = await _db
        .customSelect(
          "SELECT seq, kind, key FROM sync_outbox WHERE kind <> 'addons' "
          'ORDER BY seq LIMIT ?',
          variables: [Variable.withInt(limit)],
        )
        .get();
    final out = <PendingChange>[];
    for (final r in rows) {
      final kind = r.read<String>('kind');
      final key = r.read<String>('key');
      final item = await _snapshot(kind, key);
      out.add(PendingChange(item, r.read<int>('seq')));
    }
    // Les addons : seulement si une phrase secrète permet de les chiffrer et
    // que le blob distant a été lu ; sinon la marque reste en attente.
    final addons = _addons;
    if (addons != null && out.length < limit) {
      final row = await _db
          .customSelect(
            "SELECT seq FROM sync_outbox WHERE kind = 'addons' AND key = 'all'",
          )
          .getSingleOrNull();
      if (row != null) {
        final seq = row.read<int>('seq');
        final item = await addons.snapshot(seq);
        if (item != null) out.add(PendingChange(item, seq));
      }
    }
    return out;
  }

  Future<SyncItem> _snapshot(String kind, String key) async {
    SyncItem gone() => SyncItem(kind: kind, key: key, deleted: true);
    switch (kind) {
      case SyncKind.library:
        final k = _split(key);
        if (k == null) return gone();
        final row =
            await (_db.select(_db.libraryItems)..where(
                  (t) => t.profileId.equals(k.$1) & t.itemId.equals(k.$2),
                ))
                .getSingleOrNull();
        if (row == null) return gone();
        Object? meta;
        try {
          meta = jsonDecode(row.metaJson);
        } on FormatException {
          meta = null;
        }
        return SyncItem(
          kind: kind,
          key: key,
          payload: {
            'type': row.type,
            'meta': meta is Map ? meta : <String, Object?>{},
            'addedAt': row.addedAt,
            'certification': row.certification,
          },
        );
      case SyncKind.progress:
        final k = _split(key);
        if (k == null) return gone();
        final row =
            await (_db.select(_db.progress)..where(
                  (t) => t.profileId.equals(k.$1) & t.itemId.equals(k.$2),
                ))
                .getSingleOrNull();
        if (row == null) return gone();
        return SyncItem(
          kind: kind,
          key: key,
          payload: {
            'metaId': row.metaId,
            'positionMs': row.positionMs,
            'durationMs': row.durationMs,
            'watched': row.watched,
            'updatedAt': row.updatedAt,
            'certification': row.certification,
          },
        );
      case SyncKind.profiles:
        final row = await (_db.select(
          _db.profiles,
        )..where((t) => t.id.equals(key))).getSingleOrNull();
        if (row == null) return gone();
        // Nom, statut enfant, limite d'âge : jamais de PIN ni de verrou.
        return SyncItem(
          kind: kind,
          key: key,
          payload: {
            'name': row.name,
            'isKid': row.isKid,
            'ageLimit': row.ageLimit,
          },
        );
      case SyncKind.settings:
        if (!isSyncableSettingKey(key)) return gone();
        final row = await (_db.select(
          _db.settings,
        )..where((t) => t.key.equals(key))).getSingleOrNull();
        if (row == null) return gone();
        return SyncItem(kind: kind, key: key, payload: {'value': row.value});
      default:
        return gone();
    }
  }

  @override
  Future<void> acknowledge(List<PendingChange> sent) async {
    if (sent.isEmpty) return;
    await _db.transaction(() async {
      for (final c in sent) {
        await _db.customStatement('DELETE FROM sync_outbox WHERE seq = ?', [
          c.seq,
        ]);
      }
    });
    for (final c in sent) {
      if (c.item.kind == SyncKind.addons) {
        await _addons?.acknowledged(c.seq, deleted: c.item.deleted);
      }
    }
  }

  // --- Réception ---------------------------------------------------------

  static const _order = {
    SyncKind.profiles: 0,
    SyncKind.library: 1,
    SyncKind.progress: 2,
    SyncKind.settings: 3,
    SyncKind.addons: 4,
  };

  @override
  Future<void> apply(List<SyncItem> remote) async {
    final items = [
      for (final i in remote)
        if (_order.containsKey(i.kind)) i,
    ]..sort((a, b) => _order[a.kind]!.compareTo(_order[b.kind]!));
    if (items.isEmpty) return;
    await _db.transaction(() async {
      final pending = {
        for (final r
            in await _db
                .customSelect('SELECT kind, key FROM sync_outbox')
                .get())
          '${r.read<String>('kind')}\u0000${r.read<String>('key')}',
      };
      await _setMeta('applying', '1');
      try {
        for (final i in items) {
          if (i.kind == SyncKind.addons) {
            // Mis de côté, déchiffré plus tard (AddonSync.process) : même en
            // cas de changement local en attente, la mise de côté est sans risque.
            await _addons?.recordRemote(i);
            continue;
          }
          if (pending.contains('${i.kind}\u0000${i.key}')) continue;
          await _applyOne(i);
        }
      } finally {
        await _setMeta('applying', '0');
      }
    });
  }

  Future<void> _applyOne(SyncItem i) async {
    switch (i.kind) {
      case SyncKind.library:
        return _applyLibrary(i);
      case SyncKind.progress:
        return _applyProgress(i);
      case SyncKind.profiles:
        return _applyProfile(i);
      case SyncKind.settings:
        return _applySetting(i);
    }
  }

  Future<void> _applyLibrary(SyncItem i) async {
    final k = _split(i.key);
    if (k == null) return;
    if (i.deleted) {
      await (_db.delete(
        _db.libraryItems,
      )..where((t) => t.profileId.equals(k.$1) & t.itemId.equals(k.$2))).go();
      return;
    }
    final p = i.payload;
    final type = p?['type'];
    final meta = p?['meta'];
    if (p == null || type is! String || type.isEmpty || type.length > 64) {
      return;
    }
    final addedAt = p['addedAt'];
    final cert = p['certification'];
    await _db
        .into(_db.libraryItems)
        .insertOnConflictUpdate(
          LibraryItemsCompanion.insert(
            profileId: Value(k.$1),
            itemId: k.$2,
            type: type,
            metaJson: Value(
              jsonEncode(meta is Map ? meta : <String, Object?>{}),
            ),
            addedAt: Value(addedAt is num ? addedAt.toInt() : 0),
            certification: Value(cert is String ? cert : null),
          ),
        );
  }

  Future<void> _applyProgress(SyncItem i) async {
    final k = _split(i.key);
    if (k == null) return;
    if (i.deleted) {
      await (_db.delete(
        _db.progress,
      )..where((t) => t.profileId.equals(k.$1) & t.itemId.equals(k.$2))).go();
      return;
    }
    final p = i.payload;
    if (p == null) return;
    int nat(Object? v) => v is num && v >= 0 ? v.toInt() : 0;
    final updatedAt = p['updatedAt'];
    if (updatedAt is! num) return;
    final cert = p['certification'];
    final metaId = p['metaId'];
    await _db
        .into(_db.progress)
        .insertOnConflictUpdate(
          ProgressCompanion.insert(
            profileId: Value(k.$1),
            itemId: k.$2,
            metaId: Value(metaId is String ? metaId : ''),
            positionMs: Value(nat(p['positionMs'])),
            durationMs: Value(nat(p['durationMs'])),
            watched: Value(p['watched'] == true),
            updatedAt: Value(updatedAt.toInt()),
            certification: Value(cert is String ? cert : null),
          ),
        );
  }

  Future<void> _applySetting(SyncItem i) async {
    // Liste blanche : un serveur compromis ne peut pas écrire un PIN.
    if (!isSyncableSettingKey(i.key)) return;
    if (i.deleted) {
      await (_db.delete(_db.settings)..where((t) => t.key.equals(i.key))).go();
      return;
    }
    final v = i.payload?['value'];
    if (v is! String || v.length > 4096) return;
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(SettingsCompanion.insert(key: i.key, value: v));
  }

  Future<void> _applyProfile(SyncItem i) async {
    final id = i.key;
    if (id.isEmpty || id.length > 64) return;
    if (i.deleted) {
      final all = await _db.select(_db.profiles).get();
      // Le dernier profil local est conservé.
      if (all.length <= 1 || !all.any((p) => p.id == id)) return;
      await (_db.delete(
        _db.progress,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.libraryItems,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.titleSettingsTable,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(_db.profiles)..where((t) => t.id.equals(id))).go();
      return;
    }
    final p = i.payload;
    if (p == null) return;
    final rawName = p['name'];
    if (rawName is! String) return;
    var name = rawName.trim();
    if (name.isEmpty) return;
    if (name.length > _maxNameLength) name = name.substring(0, _maxNameLength);
    final isKid = p['isKid'] == true;
    final rawAge = p['ageLimit'];
    final adult = AgeLimit.adult.index;
    var age = rawAge is num ? rawAge.toInt().clamp(0, adult) : adult;
    // Un profil enfant n'a jamais la limite « adulte » (voir ProfileRepository).
    if (isKid && age == adult) age = AgeLimit.age12.index;
    final existing = await (_db.select(
      _db.profiles,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      if ((await _db.select(_db.profiles).get()).length >= _maxProfiles) return;
      await _db
          .into(_db.profiles)
          .insert(
            ProfilesCompanion.insert(
              id: id,
              name: name,
              createdAt: Value(_now().millisecondsSinceEpoch),
              ageLimit: Value(age),
              isKid: Value(isKid),
            ),
          );
    } else {
      await (_db.update(_db.profiles)..where((t) => t.id.equals(id))).write(
        ProfilesCompanion(
          name: Value(name),
          ageLimit: Value(age),
          isKid: Value(isKid),
        ),
      );
    }
  }

  /// Sépare `profil|titre` au premier `|` (un identifiant de profil n'en
  /// contient jamais ; celui d'un titre peut).
  static (String, String)? _split(String key) {
    final i = key.indexOf('|');
    if (i <= 0 || i == key.length - 1) return null;
    return (key.substring(0, i), key.substring(i + 1));
  }
}
