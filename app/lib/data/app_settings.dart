import 'package:lumio/data/db.dart';

/// Réglages de l'application (table `settings`, clé/valeur) : langue de
/// l'interface, cache et débit des torrents, langue de sous-titres par défaut
/// (par profil).
class AppSettingsStore {
  AppSettingsStore(this._db);

  final AppDatabase _db;

  static const localeKey = 'ui_locale';
  static const torrentCacheKey = 'torrent_cache_gb';
  static const uploadKey = 'upload_kbps';
  static const onboardingDoneKey = 'onboarding_done';
  static const onboardingSkippedKey = 'onboarding_skipped';
  static const sourcesReminderDismissedKey = 'sources_reminder_dismissed';
  static String subtitleLangKey(String profileId) => 'subtitle_lang:$profileId';

  Future<String?> read(String key) async {
    final row = await (_db.select(
      _db.settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> write(String key, String value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  Future<void> delete(String key) =>
      (_db.delete(_db.settings)..where((t) => t.key.equals(key))).go();

  Future<int?> readInt(String key) async => int.tryParse(await read(key) ?? '');
}

/// Réglages des torrents, consommés par le moteur (tâche 25).
class TorrentSettings {
  const TorrentSettings({this.cacheGb = 2, this.uploadKbps = 0});

  /// Taille maximale du cache de lecture, en Go.
  final int cacheGb;

  /// Débit montant maximal en Ko/s ; 0 = illimité.
  final int uploadKbps;

  static const cacheChoicesGb = [1, 2, 3, 5];
  static const uploadChoicesKbps = [0, 256, 512, 1024, 2048];

  TorrentSettings copyWith({int? cacheGb, int? uploadKbps}) => TorrentSettings(
    cacheGb: cacheGb ?? this.cacheGb,
    uploadKbps: uploadKbps ?? this.uploadKbps,
  );
}
