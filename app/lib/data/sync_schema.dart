import 'package:drift/drift.dart';

/// File d'envoi de la synchronisation (v7), alimentée par des déclencheurs
/// SQLite : toute écriture d'une ligne synchronisable, d'où qu'elle vienne,
/// inscrit (type, clé) dans `sync_outbox`. Le contenu n'est pas copié : il est
/// relu à l'envoi (une ligne absente = pierre tombale).
///
/// `sync_meta('applying') = '1'` coupe les déclencheurs pendant l'application
/// d'éléments reçus, pour ne pas les renvoyer au serveur.
///
/// Types : `library` et `progress` (clé `profil|titre`), `profiles` (id),
/// `settings` (clé de réglage, liste blanche seulement : jamais de PIN).
const syncTableStatements = <String>[
  'CREATE TABLE IF NOT EXISTS sync_meta ('
      'key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS sync_outbox ('
      'seq INTEGER PRIMARY KEY AUTOINCREMENT, '
      'kind TEXT NOT NULL, key TEXT NOT NULL, UNIQUE (kind, key))',
];

const _notApplying =
    "COALESCE((SELECT value FROM sync_meta WHERE key = 'applying'), '0') <> '1'";

/// Suppression puis insertion (et non `INSERT OR REPLACE`) : la clause de
/// conflit de l'instruction qui déclenche (ex. un upsert Drift) l'emporterait
/// sur celle du déclencheur et ferait échouer l'écriture d'origine.
String _enqueue(String kind, String keyExpr) =>
    "DELETE FROM sync_outbox WHERE kind = '$kind' AND key = $keyExpr; "
    "INSERT INTO sync_outbox (kind, key) VALUES ('$kind', $keyExpr);";

String _settingsGuard(String row) =>
    "($row.key = 'ui_locale' OR $row.key GLOB 'home_layout:*' "
    "OR $row.key GLOB 'stream_prefs:*' OR $row.key GLOB 'subtitle_lang:*')";

List<String> _triggers() {
  final out = <String>[];
  void rowTriggers(
    String table,
    String kind,
    String Function(String row) keyOf,
  ) {
    for (final (name, event, row) in [
      ('ai', 'INSERT', 'NEW'),
      ('au', 'UPDATE', 'NEW'),
      ('ad', 'DELETE', 'OLD'),
    ]) {
      out.add(
        'CREATE TRIGGER IF NOT EXISTS sync_${table}_$name AFTER $event ON $table '
        'WHEN $_notApplying '
        'BEGIN ${_enqueue(kind, keyOf(row))} END',
      );
    }
  }

  rowTriggers(
    'library_items',
    'library',
    (r) => "$r.profile_id || '|' || $r.item_id",
  );
  rowTriggers(
    'progress',
    'progress',
    (r) => "$r.profile_id || '|' || $r.item_id",
  );
  // Profils : le verrou local (`locked`) ne voyage pas, sa modification n'envoie rien.
  out.addAll([
    'CREATE TRIGGER IF NOT EXISTS sync_profiles_ai AFTER INSERT ON profiles '
        'WHEN $_notApplying BEGIN ${_enqueue('profiles', 'NEW.id')} END',
    'CREATE TRIGGER IF NOT EXISTS sync_profiles_au '
        'AFTER UPDATE OF name, age_limit, is_kid ON profiles '
        'WHEN $_notApplying AND (OLD.name IS NOT NEW.name '
        'OR OLD.age_limit IS NOT NEW.age_limit '
        'OR OLD.is_kid IS NOT NEW.is_kid) '
        'BEGIN ${_enqueue('profiles', 'NEW.id')} END',
    'CREATE TRIGGER IF NOT EXISTS sync_profiles_ad AFTER DELETE ON profiles '
        'WHEN $_notApplying BEGIN ${_enqueue('profiles', 'OLD.id')} END',
  ]);
  for (final (name, event, row) in [
    ('ai', 'INSERT', 'NEW'),
    ('au', 'UPDATE', 'NEW'),
    ('ad', 'DELETE', 'OLD'),
  ]) {
    out.add(
      'CREATE TRIGGER IF NOT EXISTS sync_settings_$name AFTER $event ON settings '
      'WHEN $_notApplying AND ${_settingsGuard(row)} '
      'BEGIN ${_enqueue('settings', '$row.key')} END',
    );
  }
  return out;
}

final syncTriggerStatements = _triggers();

/// Remet toutes les lignes synchronisables dans la file (migration vers la
/// v7, connexion à un compte) : le serveur départage ensuite.
final syncBackfillStatements = <String>[
  'INSERT OR REPLACE INTO sync_outbox (kind, key) '
      "SELECT 'library', profile_id || '|' || item_id FROM library_items",
  'INSERT OR REPLACE INTO sync_outbox (kind, key) '
      "SELECT 'progress', profile_id || '|' || item_id FROM progress",
  'INSERT OR REPLACE INTO sync_outbox (kind, key) '
      "SELECT 'profiles', id FROM profiles",
  "INSERT OR REPLACE INTO sync_outbox (kind, key) SELECT 'settings', key FROM settings "
      "WHERE ${_settingsGuard('settings')}",
];

/// Crée les tables et les déclencheurs de synchronisation (idempotent).
Future<void> installSyncSchema(
  GeneratedDatabase db, {
  bool backfill = false,
}) async {
  for (final s in [...syncTableStatements, ...syncTriggerStatements]) {
    await db.customStatement(s);
  }
  if (backfill) {
    for (final s in syncBackfillStatements) {
      await db.customStatement(s);
    }
  }
}
