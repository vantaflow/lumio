import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:lumio/data/app_settings.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio_core/lumio_core.dart';

/// Identifiant du service Trakt dans la file et les réglages.
const traktId = 'trakt';

/// Services de suivi, dans l'ordre d'affichage.
const trackerIds = [traktId];

/// Jetons (SecretStore) et réglages du suivi, par profil.
class TrackingRepository {
  TrackingRepository(this._secrets, this._settings);

  final SecretStore _secrets;
  final AppSettingsStore _settings;

  static String tokenKey(String trackerId, String profileId) =>
      '$trackerId.token.$profileId';
  static String kidKey(String profileId) => 'tracking_kid_allowed:$profileId';
  static String reauthKey(String trackerId, String profileId) =>
      'tracking_reauth:$trackerId:$profileId';

  Future<TrackerToken?> token(String trackerId, String profileId) async {
    final raw = await _secrets.read(tokenKey(trackerId, profileId));
    if (raw == null) return null;
    try {
      return TrackerToken.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null; // entrée illisible : comme déconnecté
    }
  }

  Future<void> saveToken(
    String trackerId,
    String profileId,
    TrackerToken t,
  ) async {
    await _secrets.write(
      tokenKey(trackerId, profileId),
      jsonEncode(t.toJson()),
    );
    await setReauth(trackerId, profileId, false);
  }

  Future<void> clearToken(String trackerId, String profileId) =>
      _secrets.delete(tokenKey(trackerId, profileId));

  /// Un parent a autorisé le suivi pour ce profil enfant.
  Future<bool> kidAllowed(String profileId) async =>
      await _settings.read(kidKey(profileId)) == '1';

  Future<void> setKidAllowed(String profileId, bool on) => on
      ? _settings.write(kidKey(profileId), '1')
      : _settings.delete(kidKey(profileId));

  /// Le service a refusé le jeton : reconnexion à proposer dans les réglages.
  Future<bool> reauthRequired(String trackerId, String profileId) async =>
      await _settings.read(reauthKey(trackerId, profileId)) == '1';

  Future<void> setReauth(String trackerId, String profileId, bool on) => on
      ? _settings.write(reauthKey(trackerId, profileId), '1')
      : _settings.delete(reauthKey(trackerId, profileId));
}

/// File d'attente dans SQLite.
class DriftScrobbleStore implements ScrobbleStore {
  DriftScrobbleStore(this._db);

  final AppDatabase _db;

  @override
  Future<List<QueuedScrobble>> all() async {
    final rows = await (_db.select(
      _db.scrobbleQueueTable,
    )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
    final out = <QueuedScrobble>[];
    for (final r in rows) {
      try {
        out.add(
          QueuedScrobble(
            id: r.id,
            profileId: r.profileId,
            trackerId: r.trackerId,
            event: ScrobbleEvent.fromJson(
              jsonDecode(r.eventJson) as Map<String, dynamic>,
            ),
            attempts: r.attempts,
            nextAttemptAt: DateTime.fromMillisecondsSinceEpoch(
              r.nextAttemptAt,
              isUtc: true,
            ),
          ),
        );
      } on Object {
        // Ligne illisible : supprimée plutôt que bloquer la file.
        await remove(r.id);
      }
    }
    return out;
  }

  @override
  Future<int> add(
    String profileId,
    String trackerId,
    ScrobbleEvent event,
    DateTime nextAttemptAt,
  ) => _db
      .into(_db.scrobbleQueueTable)
      .insert(
        ScrobbleQueueTableCompanion.insert(
          profileId: profileId,
          trackerId: trackerId,
          eventJson: jsonEncode(event.toJson()),
          nextAttemptAt: Value(nextAttemptAt.millisecondsSinceEpoch),
        ),
      );

  @override
  Future<void> remove(int id) =>
      (_db.delete(_db.scrobbleQueueTable)..where((t) => t.id.equals(id))).go();

  @override
  Future<void> markFailed(int id, int attempts, DateTime nextAttemptAt) =>
      (_db.update(_db.scrobbleQueueTable)..where((t) => t.id.equals(id))).write(
        ScrobbleQueueTableCompanion(
          attempts: Value(attempts),
          nextAttemptAt: Value(nextAttemptAt.millisecondsSinceEpoch),
        ),
      );
}
