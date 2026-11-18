import 'dart:convert';

import 'package:lumio/data/db.dart';
import 'package:lumio_core/lumio_core.dart';

/// Préférences de flux persistées par profil (table `settings`).
class StreamPrefsStore {
  StreamPrefsStore(this._db);

  final AppDatabase _db;

  static String _key(String profileId) => 'stream_prefs:$profileId';

  Future<StreamPrefs> load(String profileId) async {
    final row = await (_db.select(
      _db.settings,
    )..where((t) => t.key.equals(_key(profileId)))).getSingleOrNull();
    if (row == null) return const StreamPrefs();
    try {
      final j = jsonDecode(row.value);
      if (j is Map<String, Object?>) return StreamPrefs.fromJson(j);
    } on FormatException {
      // Valeur illisible : préférences par défaut.
    }
    return const StreamPrefs();
  }

  Future<void> save(String profileId, StreamPrefs p) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: _key(profileId),
          value: jsonEncode(p.toJson()),
        ),
      );
}
