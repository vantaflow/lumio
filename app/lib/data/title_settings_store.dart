import 'dart:convert';

import 'package:lumio/data/db.dart';
import 'package:lumio_core/lumio_core.dart';

/// Réglages par titre persistés dans SQLite. L'interface du cœur est
/// synchrone : [load] précharge un profil en mémoire, [save] écrit aussitôt en
/// mémoire puis en base ([flush] attend les écritures en cours).
class DriftTitleSettingsStore implements TitleSettingsStore {
  DriftTitleSettingsStore(this._db);

  final AppDatabase _db;
  final _cache = <String, TitleSettings>{};
  final _pending = <Future<void>>[];

  String _k(String profileId, String metaId) =>
      '$profileId\u0000${titleSettingsKey(metaId)}';

  Future<void> load(String profileId) async {
    final rows = await (_db.select(
      _db.titleSettingsTable,
    )..where((t) => t.profileId.equals(profileId))).get();
    for (final r in rows) {
      try {
        final j = jsonDecode(r.json);
        if (j is Map<String, Object?>) {
          _cache['$profileId\u0000${r.metaId}'] = TitleSettings.fromJson(j);
        }
      } on FormatException {
        // Ligne illisible : ignorée, les réglages repartent des défauts.
      }
    }
  }

  @override
  TitleSettings forTitle(String profileId, String metaId) =>
      _cache[_k(profileId, metaId)] ?? const TitleSettings();

  @override
  void save(String profileId, String metaId, TitleSettings s) {
    _cache[_k(profileId, metaId)] = s;
    final f = _db
        .into(_db.titleSettingsTable)
        .insertOnConflictUpdate(
          TitleSettingsTableCompanion.insert(
            profileId: profileId,
            metaId: titleSettingsKey(metaId),
            json: jsonEncode(s.toJson()),
          ),
        );
    _pending.add(f.then((_) {}, onError: (Object _) {}));
  }

  Future<void> flush() async {
    final all = List.of(_pending);
    _pending.clear();
    await Future.wait(all);
  }
}
