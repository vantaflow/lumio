import 'dart:convert';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/backup_files.dart' show backupFileName;
import 'package:lumio/data/backup_service.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/profile_repository.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio/features/profiles/profile_picker_screen.dart'
    show kidProfileNeedsPin;
import 'package:lumio_core/lumio_core.dart';

import 'support/fake_addon_fetcher.dart';

const _pass = 'une phrase assez longue';
const _urlA = 'https://a.example.com/tok-secret-a/manifest.json';
const _lan = 'http://192.168.1.20:7000/lan-secret/manifest.json';

class _Dev {
  _Dev() {
    db = AppDatabase(NativeDatabase.memory());
    secrets = MemorySecretStore();
    fetcher = FakeAddonFetcher({
      _urlA: sampleManifest(id: 'a', name: 'Alpha'),
      _lan: sampleManifest(id: 'lan', name: 'Maison'),
    });
    addons = AddonRepository(
      db,
      secrets,
      clientFactory: ({required allowPrivate}) =>
          AddonClient(fetcher, allowPrivate: allowPrivate, retries: 0),
    );
    service = BackupService(db, addons);
    profiles = ProfileRepository(
      db,
      hashPin: (p) async => 'h$p',
      verifyPin: (p, s) async => s == 'h$p',
    );
  }

  late AppDatabase db;
  late MemorySecretStore secrets;
  late FakeAddonFetcher fetcher;
  late AddonRepository addons;
  late BackupService service;
  late ProfileRepository profiles;

  Future<void> seed() async {
    await profiles.ensureDefault();
    await profiles.create('Léa', isKid: true, limit: AgeLimit.age7);
    await db
        .into(db.libraryItems)
        .insert(
          LibraryItemsCompanion.insert(
            itemId: 'tt1',
            type: 'movie',
            metaJson: const Value('{"name":"Élan"}'),
            addedAt: const Value(5),
          ),
        );
    await db
        .into(db.progress)
        .insert(
          ProgressCompanion.insert(
            itemId: 'tt1',
            metaId: const Value('tt1'),
            positionMs: const Value(1000),
            durationMs: const Value(9000),
            updatedAt: const Value(100),
          ),
        );
    await db
        .into(db.settings)
        .insert(SettingsCompanion.insert(key: 'ui_locale', value: 'en'));
    await db
        .into(db.settings)
        .insert(SettingsCompanion.insert(key: 'parent_pin_hash', value: 'SEC'));
    await db
        .into(db.settings)
        .insert(
          SettingsCompanion.insert(key: 'parent_lockout', value: 'LOCKSEC'),
        );
    await db
        .into(db.titleSettingsTable)
        .insert(
          TitleSettingsTableCompanion.insert(
            profileId: 'default',
            metaId: 'tt1',
            json: '{"audioLang":"fra"}',
          ),
        );
    await addons.install(_urlA);
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test(
    'aller-retour sans secrets : ni PIN ni adresse dans le fichier',
    () async {
      final a = _Dev();
      await a.seed();
      final text = await a.service.export();
      expect(text, isNot(contains('tok-secret-a')));
      expect(text, isNot(contains('a.example.com')));
      expect(text, isNot(contains('SEC')));
      expect(text, isNot(contains('parent_')));
      expect(text, contains('"Alpha"'));

      final b = _Dev();
      final data = await Backup.decode(utf8.encode(text));
      final r = await b.service.import(data);
      expect(r.profilesAdded, 2);
      expect(r.libraryAdded, 1);
      expect(r.progressApplied, 1);
      expect(r.settingsAdded, 1);
      expect(r.titleSettingsAdded, 1);
      expect(r.addonsNameOnly, 1);
      expect(await b.addons.list(), isEmpty);
      expect((await b.profiles.list()).map((p) => p.name), ['Moi', 'Léa']);
      final settings = await b.db.select(b.db.settings).get();
      expect(settings.map((s) => s.key), ['ui_locale']);
      expect(await b.db.select(b.db.titleSettingsTable).get(), hasLength(1));
      await a.db.close();
      await b.db.close();
    },
  );

  test(
    'fusion : l\'existant est conservé, la progression récente gagne',
    () async {
      final b = _Dev();
      await b.profiles.ensureDefault();
      await b.db
          .into(b.db.libraryItems)
          .insert(
            LibraryItemsCompanion.insert(
              itemId: 'tt1',
              type: 'series',
              metaJson: const Value('{"name":"Local"}'),
            ),
          );
      await b.db
          .into(b.db.progress)
          .insert(
            ProgressCompanion.insert(
              itemId: 'tt1',
              positionMs: const Value(5),
              updatedAt: const Value(500),
            ),
          );
      await b.db
          .into(b.db.progress)
          .insert(
            ProgressCompanion.insert(
              itemId: 'tt2',
              positionMs: const Value(5),
              updatedAt: const Value(50),
            ),
          );
      await b.db
          .into(b.db.settings)
          .insert(SettingsCompanion.insert(key: 'ui_locale', value: 'fr'));
      final data = BackupData(
        createdAt: DateTime.utc(2026),
        profiles: const [
          BackupProfile(id: 'default', name: 'Autre', isKid: true, ageLimit: 0),
        ],
        library: const [
          BackupLibraryItem(
            profileId: 'default',
            itemId: 'tt1',
            type: 'movie',
            meta: {'name': 'Sauvegarde'},
            addedAt: 1,
          ),
          BackupLibraryItem(
            profileId: 'default',
            itemId: 'tt3',
            type: 'movie',
            meta: {},
            addedAt: 1,
          ),
          BackupLibraryItem(
            profileId: 'inconnu',
            itemId: 'tt9',
            type: 'movie',
            meta: {},
            addedAt: 1,
          ),
        ],
        progress: const [
          BackupProgress(
            profileId: 'default',
            itemId: 'tt1',
            metaId: 'tt1',
            positionMs: 1,
            durationMs: 2,
            watched: false,
            updatedAt: 400,
          ),
          BackupProgress(
            profileId: 'default',
            itemId: 'tt2',
            metaId: 'tt2',
            positionMs: 99,
            durationMs: 100,
            watched: true,
            updatedAt: 60,
          ),
        ],
        settings: const {'ui_locale': 'en'},
      );
      final r = await b.service.import(data);
      expect(r.profilesKept, 1);
      expect(r.profilesAdded, 0);
      expect(r.libraryAdded, 1);
      expect(r.progressApplied, 1);
      expect(r.settingsAdded, 0);
      final p = (await b.profiles.list()).single;
      expect(p.name, 'Moi');
      expect(p.isKid, isFalse);
      final lib = await b.db.select(b.db.libraryItems).get();
      expect(lib.map((e) => e.itemId).toSet(), {'tt1', 'tt3'});
      expect(lib.firstWhere((e) => e.itemId == 'tt1').type, 'series');
      final prog = {
        for (final e in await b.db.select(b.db.progress).get()) e.itemId: e,
      };
      expect(prog['tt1']!.positionMs, 5);
      expect(prog['tt2']!.positionMs, 99);
      expect(prog['tt2']!.watched, isTrue);
      await b.db.close();
    },
  );

  test(
    'profil enfant importé sans PIN parent : à passer par la création du PIN',
    () async {
      final a = _Dev();
      await a.seed();
      final data = await Backup.decode(utf8.encode(await a.service.export()));
      final b = _Dev();
      final r = await b.service.import(data);
      expect(r.kidProfilesAdded, 1);
      final kid = (await b.profiles.list()).firstWhere((p) => p.isKid);
      expect(kid.locked, isFalse);
      expect(await b.profiles.hasParentPin(), isFalse);
      expect(
        kidProfileNeedsPin(kid, hasPin: await b.profiles.hasParentPin()),
        isTrue,
      );
      await a.db.close();
      await b.db.close();
    },
  );

  test('six profils au maximum : le surplus est ignoré', () async {
    final b = _Dev();
    await b.profiles.ensureDefault();
    for (var i = 0; i < 4; i++) {
      await b.profiles.create('P$i');
    }
    final data = BackupData(
      createdAt: DateTime.utc(2026),
      profiles: const [
        BackupProfile(id: 'x1', name: 'X1', isKid: false, ageLimit: 4),
        BackupProfile(id: 'x2', name: 'X2', isKid: false, ageLimit: 4),
      ],
    );
    final r = await b.service.import(data);
    expect(r.profilesAdded, 1);
    expect(r.profilesSkipped, 1);
    expect(await b.profiles.list(), hasLength(6));
    await b.db.close();
  });

  test('fichier piégé : réglages hors liste blanche jamais écrits', () async {
    final b = _Dev();
    final data = BackupData(
      createdAt: DateTime.utc(2026),
      settings: const {
        'parent_pin_hash': 'evil',
        'active_profile': 'x',
        'ui_locale': 'en',
      },
    );
    final r = await b.service.import(data);
    expect(r.settingsAdded, 1);
    expect((await b.db.select(b.db.settings).get()).map((s) => s.key), [
      'ui_locale',
    ]);
    await b.db.close();
  });

  test(
    'chiffré : adresses absentes du fichier, installées à l\'import, locale en attente',
    () async {
      final a = _Dev();
      await a.seed();
      final lan = await a.addons.install(_lan, allowPrivate: true);
      expect(lan.id, 'lan');
      final text = await a.service.export(
        includeSecrets: true,
        passphrase: _pass,
      );
      expect(text, isNot(contains('tok-secret-a')));
      expect(text, isNot(contains('lan-secret')));
      expect(text, isNot(contains('Alpha')));
      expect(Backup.isEncrypted(text), isTrue);
      expect(() => a.service.export(includeSecrets: true), throwsArgumentError);

      final b = _Dev();
      await expectLater(
        Backup.decode(utf8.encode(text)),
        throwsA(isA<BackupFormatException>()),
      );
      final data = await Backup.decode(utf8.encode(text), passphrase: _pass);
      final r = await b.service.import(data);
      expect(r.addonsInstalled, 1);
      expect(r.pendingAddons.map((p) => p.name), ['Maison']);
      expect(r.pendingAddons.single.toString(), isNot(contains('lan-secret')));
      expect((await b.addons.list()).map((e) => e.id), ['a']);
      // Rien d'automatique pour l'adresse locale.
      expect(
        b.fetcher.requested.map((u) => u.host),
        isNot(contains('192.168.1.20')),
      );
      // L'adresse reste dans le SecretStore, jamais dans SQLite.
      final rows = await b.db.select(b.db.addons).get();
      expect(
        jsonEncode(rows.map((e) => e.manifestJson).toList()),
        isNot(contains('tok-secret')),
      );
      expect(
        b.secrets.snapshot.values.any((v) => v.contains('tok-secret-a')),
        isTrue,
      );

      await b.service.installConfirmed(r.pendingAddons.single);
      expect(
        (await b.addons.list()).map((e) => e.id),
        containsAll(['a', 'lan']),
      );

      // Deuxième import : déjà installé, rien de nouveau.
      final again = await b.service.import(data);
      expect(again.addonsInstalled, 0);
      expect(again.addonsAlready, 2);
      expect(again.pendingAddons, isEmpty);
      await a.db.close();
      await b.db.close();
    },
  );

  test(
    'nom de fichier avec secondes, hôte seul pour l\'adresse en attente',
    () {
      expect(
        backupFileName(DateTime(2026, 11, 18, 9, 5, 7)),
        'lumio-20261118-090507.lumio.json',
      );
      const a = PendingBackupAddon(name: 'M', url: _lan);
      expect(a.host, '192.168.1.20');
    },
  );

  test('export en clair : affiche absente de la bibliothèque', () async {
    final a = _Dev();
    await a.profiles.ensureDefault();
    await a.db
        .into(a.db.libraryItems)
        .insert(
          LibraryItemsCompanion.insert(
            itemId: 'tt1',
            type: 'movie',
            metaJson: const Value(
              '{"id":"tt1","name":"Élan","poster":"https://x/key123/p.jpg",'
              '"sourceAddonId":"a"}',
            ),
          ),
        );
    final clear = await a.service.export();
    expect(clear, isNot(contains('key123')));
    expect(clear, contains('Élan'));
    final enc = await a.service.export(includeSecrets: true, passphrase: _pass);
    expect(enc, isNot(contains('key123')));
    final data = await Backup.decode(utf8.encode(enc), passphrase: _pass);
    expect(data.library.single.meta['poster'], 'https://x/key123/p.jpg');
    await a.db.close();
  });
}
