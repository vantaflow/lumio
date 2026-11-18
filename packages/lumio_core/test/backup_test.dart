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
}
