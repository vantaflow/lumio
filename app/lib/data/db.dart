import 'package:drift/drift.dart';

part 'db.g.dart';

/// Profils d'utilisateur (le profil « default » est créé par les tâches
/// ultérieures ; la table existe dès la version 1 du schéma).
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();

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

@DriftDatabase(
  tables: [
    Profiles,
    Addons,
    LibraryItems,
    Progress,
    Settings,
    TitleSettingsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(titleSettingsTable);
      if (from < 3) {
        await m.addColumn(progress, progress.metaId);
        await m.addColumn(progress, progress.watched);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
