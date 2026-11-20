import 'package:drift/drift.dart';

part 'db.g.dart';

/// Profils d'utilisateur (le profil « default » est créé par les tâches
/// ultérieures ; la table existe dès la version 1 du schéma).
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();

  /// Limite d'âge (index de `AgeLimit`, v4) ; 4 = adulte, sans filtre.
  IntColumn get ageLimit => integer().withDefault(const Constant(4))();

  /// Profil enfant (v4) : ni réglages ni changement de profil sans le PIN.
  BoolColumn get isKid => boolean().withDefault(const Constant(false))();

  /// Profil verrouillé (v4) : le PIN parent est demandé pour l'ouvrir.
  BoolColumn get locked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Addons installés. L'URL n'est jamais stockée ici : [secretKey] référence
/// l'entrée du `SecretStore`, et [urlHash] (SHA-256 de l'URL normalisée)
/// ne sert qu'à détecter les doublons.
class Addons extends Table {
  TextColumn get id => text()();
  TextColumn get profileScope =>
      text().withDefault(const Constant('default'))();
  IntColumn get position => integer()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get manifestJson => text()();
  TextColumn get secretKey => text()();
  TextColumn get urlHash => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {profileScope, urlHash},
  ];
}

/// Éléments de la bibliothèque (Ma liste).
class LibraryItems extends Table {
  TextColumn get profileId => text().withDefault(const Constant('default'))();
  TextColumn get itemId => text()();
  TextColumn get type => text()();
  TextColumn get metaJson => text().withDefault(const Constant('{}'))();
  IntColumn get addedAt => integer().withDefault(const Constant(0))();

  /// Certification d'âge du titre (v6), pour le filtre des profils enfants ;
  /// nulle si inconnue.
  TextColumn get certification => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {profileId, itemId};
}

/// Progression de lecture.
class Progress extends Table {
  TextColumn get profileId => text().withDefault(const Constant('default'))();
  TextColumn get itemId => text()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  /// Titre ou série d'appartenance de [itemId] (v3) ; vide pour les lignes
  /// antérieures.
  TextColumn get metaId => text().withDefault(const Constant(''))();

  /// Marqué comme vu (≥ 90 %, v3).
  BoolColumn get watched => boolean().withDefault(const Constant(false))();

  /// Certification d'âge du titre (v5), pour le filtre des profils enfants ;
  /// nulle si inconnue.
  TextColumn get certification => text().nullable()();

  /// Titre affiché dans « Continuer » (v12) : mémorisé au moment de la lecture
  /// pour ne jamais afficher un identifiant brut ; nul pour les anciennes
  /// lignes (repli sur une requête meta).
  TextColumn get title => text().nullable()();

  /// Adresse de l'affiche (v12).
  TextColumn get poster => text().nullable()();

  /// Type du titre : `movie`, `series`… (v12).
  TextColumn get mediaType => text().nullable()();

  /// Saison et épisode de [itemId] pour une série (v12).
  IntColumn get season => integer().nullable()();
  IntColumn get episode => integer().nullable()();

  /// Identifiant de stockage (opaque, interne) de l'addon dont venait le flux
  /// regardé (v13) ; nul pour les anciennes lignes.
  TextColumn get streamAddonId => text().nullable()();

  /// Identité NON sensible du flux regardé (v13) : `t:<infoHash>:<fileIdx>`
  /// ou `u:<SHA-256 de l'URL normalisée>`. Jamais l'URL (clé d'addon).
  TextColumn get streamKey => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {profileId, itemId};
}

/// Réglages clé/valeur.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Réglages de lecture par titre (clé : série, voir `titleSettingsKey`).
@DataClassName('TitleSettingsRow')
class TitleSettingsTable extends Table {
  @override
  String get tableName => 'title_settings';

  TextColumn get profileId => text()();
  TextColumn get metaId => text()();
  TextColumn get json => text()();

  @override
  Set<Column<Object>> get primaryKey => {profileId, metaId};
}

/// Dossiers locaux accordés par l'utilisateur (v9). Propres à l'appareil :
/// propres à l'appareil.
class LocalFolders extends Table {
  TextColumn get path => text()();
  IntColumn get addedAt => integer().withDefault(const Constant(0))();

  /// Dernière analyse réussie (ms) ; 0 si jamais.
  IntColumn get lastScanAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {path};
}

/// Vidéos trouvées dans les dossiers locaux (v9). [id] = `local:<sha1 du
/// chemin>` ; [titleOverride] est la correction manuelle, conservée aux
/// réanalyses.
class LocalItems extends Table {
  TextColumn get id => text()();
  TextColumn get folderPath => text()();
  TextColumn get path => text()();
  TextColumn get fileName => text()();
  TextColumn get title => text()();
  TextColumn get titleOverride => text().nullable()();
  IntColumn get year => integer().nullable()();
  IntColumn get season => integer().nullable()();
  IntColumn get episode => integer().nullable()();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  IntColumn get modifiedAt => integer().withDefault(const Constant(0))();
  IntColumn get addedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// File d'attente du suivi (Trakt…, v10) : événements de lecture à renvoyer.
/// Propre à l'appareil.
@DataClassName('ScrobbleRow')
class ScrobbleQueueTable extends Table {
  @override
  String get tableName => 'scrobble_queue';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get profileId => text()();
  TextColumn get trackerId => text()();

  /// `ScrobbleEvent.toJson` (identifiant IMDb et avancement, sans secret).
  TextColumn get eventJson => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Prochain essai (ms depuis l'epoch).
  IntColumn get nextAttemptAt => integer().withDefault(const Constant(0))();
}

@DriftDatabase(
  tables: [
    Profiles,
    Addons,
    LibraryItems,
    Progress,
    Settings,
    TitleSettingsTable,
    LocalFolders,
    LocalItems,
    ScrobbleQueueTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(titleSettingsTable);
      if (from < 3) {
        await m.addColumn(progress, progress.metaId);
        await m.addColumn(progress, progress.watched);
        // Lignes antérieures : vu à 90 % ou plus.
        await customStatement(
          'UPDATE progress SET watched = 1 '
          'WHERE duration_ms > 0 AND position_ms * 10 >= duration_ms * 9',
        );
      }
      if (from < 4) {
        await m.addColumn(profiles, profiles.ageLimit);
        await m.addColumn(profiles, profiles.isKid);
        await m.addColumn(profiles, profiles.locked);
      }
      if (from < 5) await m.addColumn(progress, progress.certification);
      if (from < 6) {
        final has = await customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' "
          "AND name = 'library_items'",
        ).get();
        if (has.isEmpty) {
          await m.createTable(libraryItems);
        } else {
          await m.addColumn(libraryItems, libraryItems.certification);
        }
      }
      // v7 : l'ancienne file de synchronisation est abandonnée (supprimée en
      // v11) ; ici seules les tables d'origine éventuellement absentes d'une
      // base très ancienne sont créées.
      if (from < 7) {
        // Tables d'origine éventuellement absentes d'une base très ancienne.
        for (final TableInfo<Table, dynamic> t in [
          profiles,
          settings,
          progress,
          libraryItems,
          addons,
        ]) {
          final has = await customSelect(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
            variables: [Variable.withString(t.actualTableName)],
          ).get();
          if (has.isEmpty) await m.createTable(t);
        }
      }
      // v9 : dossiers locaux et leurs vidéos.
      if (from < 9) {
        await m.createTable(localFolders);
        await m.createTable(localItems);
      }
      // v10 : file d'attente du suivi (Trakt).
      if (from < 10) await m.createTable(scrobbleQueueTable);
      // v11 : plus de synchronisation ni de Simkl. Les déclencheurs et les
      // tables de la file d'envoi disparaissent ; les données de l'utilisateur
      // (profils, ma liste, progression, addons) ne sont pas touchées.
      if (from < 11) await _dropSyncAndSimkl();
      // v12 : titre, affiche, type, saison et épisode mémorisés dans la
      // progression (une base déjà à jour n'est pas retouchée).
      if (from < 12) {
        final cols = {
          for (final r in await customSelect(
            'PRAGMA table_info(progress)',
          ).get())
            r.read<String>('name'),
        };
        if (cols.isEmpty) {
          // Base très ancienne sans table `progress` : créée au modèle courant.
          await m.createTable(progress);
        } else {
          if (!cols.contains('title')) {
            await m.addColumn(progress, progress.title);
          }
          if (!cols.contains('poster')) {
            await m.addColumn(progress, progress.poster);
          }
          if (!cols.contains('media_type')) {
            await m.addColumn(progress, progress.mediaType);
          }
          if (!cols.contains('season')) {
            await m.addColumn(progress, progress.season);
          }
          if (!cols.contains('episode')) {
            await m.addColumn(progress, progress.episode);
          }
        }
      }
      // v13 : identité du flux regardé, pour que « Reprendre » relance le même.
      if (from < 13) {
        final cols = {
          for (final r in await customSelect(
            'PRAGMA table_info(progress)',
          ).get())
            r.read<String>('name'),
        };
        if (cols.isNotEmpty) {
          if (!cols.contains('stream_addon_id')) {
            await m.addColumn(progress, progress.streamAddonId);
          }
          if (!cols.contains('stream_key')) {
            await m.addColumn(progress, progress.streamKey);
          }
        }
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Supprime les restes de la synchronisation (déclencheurs `sync_*`, tables
  /// `sync_outbox` et `sync_meta`) et ceux de Simkl (file de suivi, réglages).
  Future<void> _dropSyncAndSimkl() async {
    final triggers = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'trigger' "
      "AND name LIKE 'sync\\_%' ESCAPE '\\'",
    ).get();
    for (final t in triggers) {
      final name = t.read<String>('name').replaceAll('"', '');
      await customStatement('DROP TRIGGER IF EXISTS "$name"');
    }
    await customStatement('DROP TABLE IF EXISTS sync_outbox');
    await customStatement('DROP TABLE IF EXISTS sync_meta');
    await customStatement(
      "DELETE FROM scrobble_queue WHERE tracker_id = 'simkl'",
    );
    await customStatement(
      "DELETE FROM settings WHERE key LIKE 'tracking\\_reauth:simkl:%' ESCAPE '\\'",
    );
  }
}
