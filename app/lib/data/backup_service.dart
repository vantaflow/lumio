import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/profile_repository.dart' show maxProfiles;
import 'package:lumio_core/lumio_core.dart';

/// Adresse locale d'un addon d'une sauvegarde : l'installation attend une
/// confirmation explicite (jamais autorisée automatiquement). L'adresse est
/// secrète : [toString] ne la montre pas.
class PendingBackupAddon {
  const PendingBackupAddon({required this.name, required this.url});

  final String name;
  final String url;

  /// Hôte seul (ni chemin ni paramètres : l'adresse est secrète).
  String get host => Uri.tryParse(url)?.host ?? '';

  @override
  String toString() => 'PendingBackupAddon($name, ${redactUrl(url)})';
}

/// Ce que l'import a fait.
class BackupImportReport {
  const BackupImportReport({
    this.profilesAdded = 0,
    this.profilesKept = 0,
    this.profilesSkipped = 0,
    this.kidProfilesAdded = 0,
    this.libraryAdded = 0,
    this.progressApplied = 0,
    this.settingsAdded = 0,
    this.titleSettingsAdded = 0,
    this.addonsInstalled = 0,
    this.addonsAlready = 0,
    this.addonsFailed = 0,
    this.addonsNameOnly = 0,
    this.skipped = 0,
    this.pendingAddons = const [],
  });

  final int profilesAdded;

  /// Profils déjà présents (identifiant connu) : laissés tels quels.
  final int profilesKept;

  /// Profils non ajoutés (six au maximum).
  final int profilesSkipped;
  final int kidProfilesAdded;
  final int libraryAdded;
  final int progressApplied;
  final int settingsAdded;
  final int titleSettingsAdded;
  final int addonsInstalled;
  final int addonsAlready;
  final int addonsFailed;

  /// Addons connus par leur nom seulement (fichier sans adresses) : à
  /// réinstaller à la main.
  final int addonsNameOnly;

  /// Entrées invalides ignorées.
  final int skipped;
  final List<PendingBackupAddon> pendingAddons;
}

/// Sauvegarde locale : lit la base pour l'export, écrit l'import par fusion
/// (rien n'est supprimé ni remplacé, sauf une progression plus récente).
class BackupService {
  BackupService(this._db, this._addons, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final AddonRepository _addons;
  final DateTime Function() _now;

  /// Contenu de la sauvegarde ; les adresses d'addons ne sont lues (dans le
  /// `SecretStore`) qu'avec [includeSecrets].
  Future<BackupData> collect({bool includeSecrets = false}) async {
    final profiles = await _db.select(_db.profiles).get();
    final library = await _db.select(_db.libraryItems).get();
    final progress = await _db.select(_db.progress).get();
    final settings = await _db.select(_db.settings).get();
    final titles = await _db.select(_db.titleSettingsTable).get();

    Map<String, dynamic> map(String raw) {
      try {
        final j = jsonDecode(raw);
        return j is Map ? Map<String, dynamic>.from(j) : <String, dynamic>{};
      } on FormatException {
        return <String, dynamic>{};
      }
    }

    final addons = <BackupAddon>[];
    for (final a in await _addons.list()) {
      final m = a.manifest;
      if (m == null) continue;
      String? url;
      if (includeSecrets) {
        try {
          url = (await _addons.urlOf(a.id)).toString();
        } on AddonException {
          url = null;
        }
      }
      addons.add(BackupAddon(manifestId: m.id, name: m.name, url: url));
    }

    return BackupData(
      createdAt: _now().toUtc(),
      profiles: [
        for (final p in profiles)
          BackupProfile(
            id: p.id,
            name: p.name,
            isKid: p.isKid,
            ageLimit: p.ageLimit,
          ),
      ],
      library: [
        for (final i in library)
          BackupLibraryItem(
            profileId: i.profileId,
            itemId: i.itemId,
            type: i.type,
            meta: map(i.metaJson),
            addedAt: i.addedAt,
            certification: i.certification,
          ),
      ],
      progress: [
        for (final p in progress)
          BackupProgress(
            profileId: p.profileId,
            itemId: p.itemId,
            metaId: p.metaId,
            positionMs: p.positionMs,
            durationMs: p.durationMs,
            watched: p.watched,
            updatedAt: p.updatedAt,
            certification: p.certification,
          ),
      ],
      settings: {
        for (final s in settings)
          if (isBackupSettingKey(s.key)) s.key: s.value,
      },
      titleSettings: [
        for (final t in titles)
          BackupTitleSettings(
            profileId: t.profileId,
            metaId: t.metaId,
            json: Map<String, Object?>.from(map(t.json)),
          ),
      ],
      addons: addons,
    );
  }

  /// Texte du fichier. Avec [includeSecrets] il est chiffré par [passphrase]
  /// (obligatoire) : aucune adresse n'est jamais écrite en clair.
  Future<String> export({
    bool includeSecrets = false,
    String? passphrase,
  }) async => Backup.encode(
    await collect(includeSecrets: includeSecrets),
    includeSecrets: includeSecrets,
    passphrase: passphrase,
  );

  /// Fusionne [data] dans la base. Les profils déjà présents ne sont pas
  /// modifiés (une sauvegarde ne peut pas lever les limites d'un profil
  /// enfant) ; bibliothèque, réglages et réglages par titre existants sont
  /// conservés ; la progression la plus récente l'emporte.
  Future<BackupImportReport> import(BackupData data) async {
    var profilesAdded = 0, profilesKept = 0, profilesSkipped = 0, kids = 0;
    var libraryAdded = 0, progressApplied = 0, settingsAdded = 0, titles = 0;

    await _db.transaction(() async {
      final known = {
        for (final p in await _db.select(_db.profiles).get()) p.id,
      };
      final base = _now().millisecondsSinceEpoch;
      for (final p in data.profiles) {
        if (known.contains(p.id)) {
          profilesKept++;
        } else if (known.length >= maxProfiles) {
          profilesSkipped++;
        } else {
          await _db
              .into(_db.profiles)
              .insert(
                ProfilesCompanion.insert(
                  id: p.id,
                  name: p.name,
                  createdAt: Value(base + profilesAdded),
                  ageLimit: Value(p.ageLimit),
                  isKid: Value(p.isKid),
                ),
              );
          known.add(p.id);
          profilesAdded++;
          if (p.isKid) kids++;
        }
      }

      String k(String a, String b) => '$a\u0000$b';

      final libKeys = {
        for (final r in await _db.select(_db.libraryItems).get())
          k(r.profileId, r.itemId),
      };
      for (final i in data.library) {
        if (!known.contains(i.profileId)) continue;
        if (!libKeys.add(k(i.profileId, i.itemId))) continue;
        await _db
            .into(_db.libraryItems)
            .insert(
              LibraryItemsCompanion.insert(
                profileId: Value(i.profileId),
                itemId: i.itemId,
                type: i.type,
                metaJson: Value(jsonEncode(i.meta)),
                addedAt: Value(i.addedAt),
                certification: Value(i.certification),
              ),
            );
        libraryAdded++;
      }

      final seen = {
        for (final r in await _db.select(_db.progress).get())
          k(r.profileId, r.itemId): r.updatedAt,
      };
      for (final p in data.progress) {
        if (!known.contains(p.profileId)) continue;
        final key = k(p.profileId, p.itemId);
        final current = seen[key];
        if (current != null && current >= p.updatedAt) continue;
        await _db
            .into(_db.progress)
            .insertOnConflictUpdate(
              ProgressCompanion.insert(
                profileId: Value(p.profileId),
                itemId: p.itemId,
                metaId: Value(p.metaId),
                positionMs: Value(p.positionMs),
                durationMs: Value(p.durationMs),
                watched: Value(p.watched),
                updatedAt: Value(p.updatedAt),
                certification: Value(p.certification),
              ),
            );
        seen[key] = p.updatedAt;
        progressApplied++;
      }

      final settingKeys = {
        for (final r in await _db.select(_db.settings).get()) r.key,
      };
      for (final e in data.settings.entries) {
        // Liste blanche revérifiée : jamais de PIN, de verrou ni de profil actif.
        if (!isBackupSettingKey(e.key) || !settingKeys.add(e.key)) continue;
        await _db
            .into(_db.settings)
            .insert(SettingsCompanion.insert(key: e.key, value: e.value));
        settingsAdded++;
      }

      final titleKeys = {
        for (final r in await _db.select(_db.titleSettingsTable).get())
          k(r.profileId, r.metaId),
      };
      for (final t in data.titleSettings) {
        if (!known.contains(t.profileId)) continue;
        if (!titleKeys.add(k(t.profileId, t.metaId))) continue;
        await _db
            .into(_db.titleSettingsTable)
            .insert(
              TitleSettingsTableCompanion.insert(
                profileId: t.profileId,
                metaId: t.metaId,
                json: jsonEncode(t.json),
              ),
            );
        titles++;
      }
    });

    // Addons : un par un, par le chemin d'installation normal (validation,
    // garde d'adresse, doublons). Hors transaction (réseau).
    var installed = 0, already = 0, failed = 0, nameOnly = 0;
    final pending = <PendingBackupAddon>[];
    for (final a in data.addons) {
      final url = a.url;
      if (url == null) {
        nameOnly++;
        continue;
      }
      try {
        if (await _addons.isInstalled(url)) {
          already++;
          continue;
        }
        await _addons.install(url);
        installed++;
      } on PrivateAddressException {
        pending.add(PendingBackupAddon(name: a.name, url: url));
      } on DuplicateAddonException {
        already++;
      } on Object {
        failed++;
      }
    }

    return BackupImportReport(
      profilesAdded: profilesAdded,
      profilesKept: profilesKept,
      profilesSkipped: profilesSkipped,
      kidProfilesAdded: kids,
      libraryAdded: libraryAdded,
      progressApplied: progressApplied,
      settingsAdded: settingsAdded,
      titleSettingsAdded: titles,
      addonsInstalled: installed,
      addonsAlready: already,
      addonsFailed: failed,
      addonsNameOnly: nameOnly,
      skipped: data.skipped,
      pendingAddons: pending,
    );
  }

  /// Installe un addon à adresse locale après confirmation de l'utilisateur.
  Future<void> installConfirmed(PendingBackupAddon a) =>
      _addons.install(a.url, allowPrivate: true);
}
