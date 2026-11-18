import 'dart:convert';

import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

const _url = 'https://a.example.com/tok-secret/manifest.json';

BackupData _sample({bool withUrl = true}) => BackupData(
  createdAt: DateTime.utc(2026, 11, 18, 10),
  profiles: const [
    BackupProfile(id: 'default', name: 'Moi', isKid: false, ageLimit: 4),
    BackupProfile(id: 'p1', name: 'Léa', isKid: true, ageLimit: 2),
  ],
  library: const [
    BackupLibraryItem(
      profileId: 'default',
      itemId: 'tt1',
      type: 'movie',
      meta: {'id': 'tt1', 'name': 'Élan'},
      addedAt: 5,
      certification: 'PG',
    ),
  ],
  progress: const [
    BackupProgress(
      profileId: 'default',
      itemId: 'tt1',
      metaId: 'tt1',
      positionMs: 1000,
      durationMs: 9000,
      watched: false,
      updatedAt: 42,
      certification: null,
    ),
  ],
  settings: const {'ui_locale': 'fr', 'home_layout:default': '{"a":1}'},
  titleSettings: const [
    BackupTitleSettings(
      profileId: 'default',
      metaId: 'tt1',
      json: {'audioLang': 'fra'},
    ),
  ],
  addons: [
    BackupAddon(manifestId: 'a', name: 'Alpha', url: withUrl ? _url : null),
  ],
);

void main() {
  test('aller-retour sans secrets : aucune adresse dans le fichier', () {
    final json = Backup.export(_sample());
    final text = jsonEncode(json);
    expect(json['format'], 'lumio-backup');
    expect(json['version'], 1);
    expect(text, isNot(contains('tok-secret')));
    expect(text, isNot(contains('a.example.com')));
    final back = Backup.import(jsonDecode(text) as Map<String, dynamic>);
    expect(back.profiles.map((p) => p.name), ['Moi', 'Léa']);
    expect(back.profiles[1].isKid, isTrue);
    expect(back.library.single.meta['name'], 'Élan');
    expect(back.progress.single.updatedAt, 42);
    expect(back.settings['ui_locale'], 'fr');
    expect(back.titleSettings.single.json['audioLang'], 'fra');
    expect(back.addons.single.manifestId, 'a');
    expect(back.addons.single.url, isNull);
  });

  test('includeSecrets : les adresses sont présentes', () {
    final json = Backup.export(_sample(), includeSecrets: true);
    expect(jsonEncode(json), contains(_url));
    final back = Backup.import(json, allowAddonUrls: true);
    expect(back.addons.single.url, _url);
    // Un fichier en clair ne fait jamais confiance aux adresses.
    expect(Backup.import(json).addons.single.url, isNull);
  });

  test('jamais de PIN, de verrou ni de réglage hors liste blanche', () {
    final d = _sample();
    final dirty = BackupData(
      createdAt: d.createdAt,
      profiles: d.profiles,
      library: d.library,
      progress: d.progress,
      settings: {
        ...d.settings,
        'parent_pin_hash': 'x',
        'parent_recovery_hash': 'y',
        'parent_lockout': 'z',
        'active_profile': 'p1',
      },
      titleSettings: d.titleSettings,
      addons: d.addons,
    );
    final text = jsonEncode(Backup.export(dirty, includeSecrets: true));
    expect(text, isNot(contains('parent_')));
    expect(text, isNot(contains('active_profile')));
    expect(text, isNot(contains('locked')));
  });

  test('format inconnu, version future ou malformée : exception', () {
    BackupFormatError code(Map<String, dynamic> j) {
      try {
        Backup.import(j);
      } on BackupFormatException catch (e) {
        return e.error;
      }
      fail('aucune exception');
    }

    expect(
      code({'format': 'lumio-backup', 'version': 2}),
      BackupFormatError.unsupportedVersion,
    );
    expect(
      code({'format': 'autre', 'version': 1}),
      BackupFormatError.unknownFormat,
    );
    expect(code({'version': 1}), BackupFormatError.unknownFormat);
    expect(
      code({'format': 'lumio-backup', 'version': '1'}),
      BackupFormatError.malformed,
    );
    expect(
      code({'format': 'lumio-backup', 'version': 1, 'profiles': 'x'}),
      BackupFormatError.malformed,
    );
  });

  test('bornes : entrées invalides ignorées et comptées', () {
    final j = Backup.export(_sample());
    (j['profiles'] as List).add({'id': 'a|b', 'name': 'x'});
    (j['profiles'] as List).add({'id': 'ok', 'name': '   '});
    (j['library'] as List).add({
      'profileId': 'default',
      'itemId': '',
      'type': 'movie',
    });
    (j['progress'] as List).add({
      'profileId': 'default',
      'itemId': 'tt2',
      'updatedAt': 'hier',
    });
    (j['settings'] as Map)['parent_pin_hash'] = 'evil';
    final back = Backup.import(j);
    expect(back.profiles.length, 2);
    expect(back.library.length, 1);
    expect(back.progress.length, 1);
    expect(back.settings.containsKey('parent_pin_hash'), isFalse);
    expect(back.skipped, 5);
  });

  test('profil enfant sans limite valable : jamais adulte', () {
    final j = Backup.export(_sample());
    (j['profiles'] as List)[1] = {
      'id': 'p1',
      'name': 'Léa',
      'isKid': true,
      'ageLimit': 4,
    };
    expect(Backup.import(j).profiles[1].ageLimit, AgeLimit.age12.index);
  });

  test('trop d\'éléments ou fichier trop gros : refusé', () async {
    final j = Backup.export(_sample());
    j['profiles'] = [
      for (var i = 0; i < 7; i++) {'id': 'p$i', 'name': 'n'},
    ];
    expect(
      () => Backup.import(j),
      throwsA(
        isA<BackupFormatException>().having(
          (e) => e.error,
          'error',
          BackupFormatError.tooLarge,
        ),
      ),
    );
    expect(
      () => Backup.decode(List.filled(Backup.maxBytes + 1, 32)),
      throwsA(
        isA<BackupFormatException>().having(
          (e) => e.error,
          'error',
          BackupFormatError.tooLarge,
        ),
      ),
    );
    expect(
      () => Backup.decode(utf8.encode('pas du json')),
      throwsA(isA<BackupFormatException>()),
    );
    expect(
      () => Backup.decode(utf8.encode('[1]')),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('clair : encode/decode sans phrase', () async {
    final text = await Backup.encode(_sample());
    expect(text, isNot(contains('tok-secret')));
    expect(Backup.isEncrypted(text), isFalse);
    final back = await Backup.decode(utf8.encode(text));
    expect(back.profiles.length, 2);
  });

  test('includeSecrets exige une phrase d\'au moins 12 caractères', () async {
    expect(
      () => Backup.encode(_sample(), includeSecrets: true),
      throwsArgumentError,
    );
    expect(
      () => Backup.encode(_sample(), includeSecrets: true, passphrase: 'court'),
      throwsArgumentError,
    );
  });

  test(
    'chiffré : adresses jamais en clair, phrase exigée, bonne phrase ok',
    () async {
      const pass = 'une phrase assez longue';
      final text = await Backup.encode(
        _sample(),
        includeSecrets: true,
        passphrase: pass,
      );
      expect(text, isNot(contains('tok-secret')));
      expect(text, isNot(contains('a.example.com')));
      expect(text, isNot(contains('Léa')));
      expect(Backup.isEncrypted(text), isTrue);
      expect(
        () => Backup.decode(utf8.encode(text)),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.error,
            'error',
            BackupFormatError.passphraseRequired,
          ),
        ),
      );
      expect(
        () => Backup.decode(utf8.encode(text), passphrase: 'mauvaise phrase!!'),
        throwsA(isA<WrongPassphraseException>()),
      );
      final back = await Backup.decode(utf8.encode(text), passphrase: pass);
      expect(back.addons.single.url, _url);
      expect(back.profiles.length, 2);
    },
  );

  test(
    'un blob d\'addons de la synchro ne s\'ouvre pas comme sauvegarde',
    () async {
      const pass = 'une phrase assez longue';
      final blob = await SecretBox.seal('{"profiles":[]}', pass);
      final env = jsonEncode({
        'format': 'lumio-backup',
        'version': 1,
        'encrypted': true,
        'data': blob,
      });
      expect(
        () => Backup.decode(utf8.encode(env), passphrase: pass),
        throwsA(isA<WrongPassphraseException>()),
      );
    },
  );

  group('meta de la bibliothèque', () {
    BackupData withMeta(Map<String, dynamic> meta) => BackupData(
      createdAt: DateTime.utc(2026),
      library: [
        BackupLibraryItem(
          profileId: 'default',
          itemId: 'tt1',
          type: 'movie',
          meta: meta,
          addedAt: 1,
        ),
      ],
    );
    const meta = {
      'id': 'tt1',
      'type': 'movie',
      'name': 'Élan',
      'releaseInfo': '2020',
      'certification': 'PG',
      'sourceKind': 'addon',
      'poster': 'https://x/key123/p.jpg',
      'sourceAddonId': 'a',
      'evil': 'x',
    };

    test(
      'affiche et addon d\'origine absents du clair, présents chiffrés',
      () async {
        final clear = await Backup.encode(withMeta(meta));
        expect(clear, isNot(contains('key123')));
        expect(clear, isNot(contains('sourceAddonId')));
        expect(clear, isNot(contains('evil')));
        final back = await Backup.decode(utf8.encode(clear));
        expect(back.library.single.meta.keys.toSet(), {
          'id',
          'type',
          'name',
          'releaseInfo',
          'certification',
          'sourceKind',
        });
        const pass = 'une phrase assez longue';
        final enc = await Backup.encode(
          withMeta(meta),
          includeSecrets: true,
          passphrase: pass,
        );
        expect(enc, isNot(contains('key123')));
        final back2 = await Backup.decode(utf8.encode(enc), passphrase: pass);
        expect(back2.library.single.meta['poster'], 'https://x/key123/p.jpg');
        expect(back2.library.single.meta['sourceAddonId'], 'a');
        expect(back2.library.single.meta.containsKey('evil'), isFalse);
      },
    );

    test('import : clés inconnues écartées, affiche contrôlée', () {
      Map<String, dynamic> imp(Map<String, dynamic> m) => Backup.import(
        Backup.export(withMeta(m)),
        allowAddonUrls: true,
      ).library.single.meta;
      // Export nettoie déjà : on forge le JSON directement.
      Map<String, dynamic> forged(Map<String, dynamic> m) {
        final j = Backup.export(withMeta({'id': 'a'}));
        (j['library'] as List).single['meta'] = m;
        return Backup.import(j, allowAddonUrls: true).library.single.meta;
      }

      expect(imp(meta).containsKey('evil'), isFalse);
      expect(
        forged({
          'name': 'n',
          'x': 'y',
          'nested': {'a': 1},
        }),
        {'name': 'n'},
      );
      expect(forged({'poster': 'ftp://h/p.jpg'}), isEmpty);
      expect(forged({'poster': 'https://u:p@h/p.jpg'}), isEmpty);
      expect(forged({'poster': 'https:///p.jpg'}), isEmpty);
      expect(
        forged({'poster': 'https://h/p.jpg'})['poster'],
        'https://h/p.jpg',
      );
      // Fichier en clair : l'affiche n'est jamais reprise.
      final j = Backup.export(withMeta({'id': 'a'}));
      (j['library'] as List).single['meta'] = {'poster': 'https://h/p.jpg'};
      expect(Backup.import(j).library.single.meta, isEmpty);
    });

    test('méta profondément imbriquée : pas de plantage', () async {
      final deep = '${'[' * 100000}${']' * 100000}';
      final text =
          '{"format":"lumio-backup","version":1,"library":[{"profileId":"default",'
          '"itemId":"tt1","type":"movie","meta":{"name":"n","deep":$deep}}]}';
      final back = await Backup.decode(utf8.encode(text));
      expect(back.library.single.meta, {'name': 'n'});
      final bad =
          '{"format":"lumio-backup","version":1,"library":[{"meta":$deep}]}';
      final r = await Backup.decode(utf8.encode(bad));
      expect(r.library, isEmpty);
      expect(r.skipped, 1);
    });
  });

  test('progression datée du futur lointain : ramenée à maintenant', () {
    final now = DateTime.utc(2026, 11, 18);
    final j = Backup.export(_sample());
    final ms = now.millisecondsSinceEpoch;
    (j['progress'] as List).single['updatedAt'] = ms + 3 * 86400000;
    expect(Backup.import(j, now: now).progress.single.updatedAt, ms);
    (j['progress'] as List).single['updatedAt'] = ms + 3600000;
    expect(Backup.import(j, now: now).progress.single.updatedAt, ms + 3600000);
  });
}
