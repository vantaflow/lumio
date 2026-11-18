import 'dart:convert';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/addon_sync.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio/data/sync_service.dart';
import 'package:lumio/data/sync_store.dart';
import 'package:lumio_core/lumio_core.dart';

import 'support/fake_addon_fetcher.dart';

const _pass = 'phrase secrete numero un';
const _urlA = 'https://a.example.com/tok-secret-a/manifest.json';
const _urlB = 'https://b.example.com/tok-secret-b/manifest.json';
const _urlC = 'https://c.example.com/tok-secret-c/manifest.json';
const _urlLan = 'http://192.168.1.5:7000/manifest.json';

/// Chiffrement factice (rapide) : le clair est lisible dans le « chiffré », ce
/// qui permet aux tests d'inspecter ce qui partirait, sans PBKDF2.
Future<String> _fakeSeal(String plain, String pass) async =>
    'v1.${base64Url.encode(utf8.encode(pass))}.${base64Url.encode(utf8.encode(plain))}';

Future<String> _fakeOpen(String sealed, String pass) async {
  final p = sealed.split('.');
  if (p.length != 3 || p[0] != 'v1') throw const WrongPassphraseException();
  if (utf8.decode(base64Url.decode(p[1])) != pass) {
    throw const WrongPassphraseException();
  }
  return utf8.decode(base64Url.decode(p[2]));
}

Future<String> _fakeFingerprint(String phrase, List<int> salt) async =>
    'fp.${base64Url.encode(salt)}.$phrase';

/// Le serveur : versions, éléments, requêtes tracées.
class FakeServer implements SyncHttp {
  final items = <String, Map<String, Object?>>{};
  int version = 0;
  final pushes = <Map<String, Object?>>[];

  Map<String, Object?>? get addonsItem => items['addons/all'];

  @override
  Future<SyncHttpResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    String? body,
  }) async {
    if (url.path == '/sync' && method == 'GET') {
      final since = int.parse(url.queryParameters['since']!);
      return SyncHttpResponse(
        200,
        jsonEncode({
          'items': [
            for (final i in items.values)
              if ((i['version']! as int) > since) i,
          ],
          'version': version,
          'more': false,
        }),
      );
    }
    if (url.path == '/sync' && method == 'POST') {
      version++;
      for (final i in (jsonDecode(body!) as Map)['items'] as List) {
        final m = Map<String, Object?>.from(i as Map);
        pushes.add(m);
        items['${m['kind']}/${m['key']}'] = {
          'kind': m['kind'],
          'key': m['key'],
          'payload': m['payload'],
          'deleted': m['deleted'] == true ? 1 : 0,
          'version': version,
        };
      }
      return SyncHttpResponse(200, jsonEncode({'version': version}));
    }
    return const SyncHttpResponse(404, '');
  }
}

class Device {
  Device(
    this.server,
    this.manifests, {
    SealFn? seal,
    OpenFn? open,
    bool realFingerprint = false,
  }) {
    db = AppDatabase(NativeDatabase.memory());
    secrets = MemorySecretStore();
    fetcher = FakeAddonFetcher(manifests);
    repo = AddonRepository(
      db,
      secrets,
      clientFactory: ({required allowPrivate}) =>
          AddonClient(fetcher, allowPrivate: allowPrivate, retries: 0),
    );
    opens = 0;
    sync = AddonSync(
      db,
      secrets,
      repo,
      seal: seal ?? _fakeSeal,
      fingerprint: realFingerprint ? null : _fakeFingerprint,
      open: (s, p) {
        opens++;
        return (open ?? _fakeOpen)(s, p);
      },
    );
    store = DriftLocalSyncStore(db, addons: sync);
    service = SyncService(
      api: SyncApiClient('https://sync.example.com', secrets, http: server),
      store: store,
      addons: sync,
    );
  }

  final FakeServer server;
  final Map<String, Map<String, Object?>> manifests;
  late AppDatabase db;
  late MemorySecretStore secrets;
  late FakeAddonFetcher fetcher;
  late AddonRepository repo;
  late AddonSync sync;
  late DriftLocalSyncStore store;
  late SyncService service;
  int opens = 0;

  Future<void> signIn() async {
    await secrets.write(SyncSecretKeys.session, 'S');
    await secrets.write(SyncSecretKeys.refresh, 'R');
    await secrets.write(SyncSecretKeys.email, 'a@example.com');
    await store.markAllDirty();
    await service.start();
    await service.syncNow();
  }

  Future<void> cycle() => service.syncNow();

  Future<List<String>> urls() async => [
    for (final a in await repo.list()) (await repo.urlOf(a.id)).toString(),
  ];

  Future<void> close() async {
    await service.dispose();
    await db.close();
  }
}

Map<String, Map<String, Object?>> _manifests() => {
  _urlA: sampleManifest(id: 'org.a', name: 'A'),
  _urlB: sampleManifest(id: 'org.b', name: 'B'),
  _urlC: sampleManifest(id: 'org.c', name: 'C'),
  _urlLan: sampleManifest(id: 'org.lan', name: 'Maison'),
};

Future<Map<String, Object?>> blobAt(
  Map<String, Object?> item,
  String p,
) async => Map<String, Object?>.from(
  jsonDecode(await _fakeOpen((item['payload']! as Map)['blob'] as String, p))
      as Map,
);
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late FakeServer server;
  late Device a;
  late Device b;

  setUp(() {
    server = FakeServer();
    a = Device(server, _manifests());
    b = Device(server, _manifests());
  });
  tearDown(() async {
    await a.close();
    await b.close();
  });

  Future<Map<String, Object?>> serverPlain(String pass) async {
    final blob = (server.addonsItem!['payload']! as Map)['blob'] as String;
    return Map<String, Object?>.from(
      jsonDecode(await _fakeOpen(blob, pass)) as Map,
    );
  }

  test('sans phrase secrète : aucun addon envoyé, état affiché', () async {
    await a.repo.install(_urlA);
    await a.signIn();
    await a.cycle();
    expect(server.addonsItem, isNull);
    expect(server.pushes.where((p) => p['kind'] == 'addons'), isEmpty);
    expect((await a.sync.state()).status, AddonSyncStatus.noPassphrase);
  });

  test('phrase trop courte refusée', () async {
    await expectLater(a.sync.setPassphrase('courte'), throwsArgumentError);
    expect(await a.sync.passphrase(), isNull);
  });

  test('envoi : seul un blob chiffré part, jamais une adresse', () async {
    await a.repo.install(_urlA);
    await a.repo.install(_urlB);
    await a.repo.setEnabled((await a.repo.list()).last.id, false);
    await a.signIn();
    await a.sync.setPassphrase(_pass);
    await a.cycle();
    final item = server.addonsItem!;
    final payload = item['payload']! as Map;
    expect(payload.keys, ['blob']);
    expect((payload['blob'] as String).startsWith('v1.'), isTrue);
    // Rien d'autre que le blob : le serveur ne voit aucune adresse ni nom.
    final wire = jsonEncode(
      server.pushes.where((p) => p['kind'] == 'addons').toList(),
    );
    expect(wire, isNot(contains('tok-secret')));
    expect(wire, isNot(contains('example.com')));
    final plain = jsonDecode(await _fakeOpen(payload['blob'] as String, _pass));
    expect((plain as Map)['gen'], 1);
    expect(plain['removed'], isEmpty);
    expect(plain['entries'], [
      {'url': _urlA, 'logo': null, 'enabled': true, 'position': 0},
      {'url': _urlB, 'logo': null, 'enabled': false, 'position': 1},
    ]);
    // La phrase n'est jamais envoyée, ni dans SQLite.
    expect(jsonEncode(server.pushes), isNot(contains(_pass)));
    final meta = await a.db.customSelect('SELECT * FROM sync_meta').get();
    expect(meta.map((r) => r.data.toString()).join(), isNot(contains(_pass)));
    expect(a.secrets.snapshot[AddonSyncSecretKeys.passphrase], _pass);
    expect((await a.sync.state()).status, AddonSyncStatus.ready);
  });

  test('nouvel appareil : saisie de la phrase, addons installés par le '
      'chemin normal, sans écraser le serveur', () async {
    await a.repo.install(_urlA);
    await a.repo.install(_urlB);
    await a.repo.setEnabled((await a.repo.list()).last.id, false);
    await a.signIn();
    await a.sync.setPassphrase(_pass);
    await a.cycle();
    final before = server.addonsItem!['version'];

    await b.signIn(); // B n'a aucun addon et pas encore de phrase
    expect(await b.urls(), isEmpty);
    expect(server.addonsItem!['version'], before);

    await b.sync.setPassphrase(_pass);
    await b.cycle();
    expect(await b.urls(), [_urlA, _urlB]);
    final list = await b.repo.list();
    expect(list.map((x) => x.enabled), [true, false]);
    // Passé par AddonRepository.install : le manifeste a été récupéré.
    expect(b.fetcher.requested.map((u) => u.toString()), [_urlA, _urlB]);
    // Et le serveur n'a pas été écrasé par une liste vide.
    expect((await serverPlain(_pass))['entries'], hasLength(2));
    expect((await b.sync.state()).status, AddonSyncStatus.ready);
  });

  test('phrase saisie avant le premier échange : rien n\'est envoyé tant que '
      'le serveur n\'a pas été lu', () async {
    await a.repo.install(_urlA);
    await a.signIn();
    await a.sync.setPassphrase(_pass);
    await a.cycle();
    final before = server.addonsItem!['version'];

    await b.repo.install(_urlC);
    await b.secrets.write(SyncSecretKeys.session, 'S');
    await b.secrets.write(SyncSecretKeys.refresh, 'R');
    // Phrase définie avant tout tirage : on attend, on n'envoie rien.
    await b.sync.setPassphrase(_pass);
    expect((await b.sync.state()).status, AddonSyncStatus.waiting);
    expect(await b.store.pending(10), isEmpty);
    expect(server.addonsItem!['version'], before);

    await b.service.start();
    await b.cycle();
    // Fusion : A et le C local de B.
    expect((await b.urls()).toSet(), {_urlA, _urlC});
    expect(
      ((await serverPlain(_pass))['entries'] as List).map((e) => e['url']),
      containsAll([_urlA, _urlC]),
    );
  });

  test(
    'mauvaise phrase : message, addons locaux intacts, rien d\'envoyé',
    () async {
      await a.repo.install(_urlA);
      await a.signIn();
      await a.sync.setPassphrase(_pass);
      await a.cycle();
      final before = server.addonsItem!['version'];

      await b.repo.install(_urlC); // addon local de B
      await b.signIn();
      await b.sync.setPassphrase('une autre phrase secrete');
      await b.cycle();
      await b.cycle();
      expect((await b.sync.state()).status, AddonSyncStatus.wrongPassphrase);
      expect(await b.urls(), [_urlC]);
      expect(server.addonsItem!['version'], before);
      // Une modification locale ne part pas non plus.
      await b.repo.install(_urlB);
      await b.cycle();
      expect(server.addonsItem!['version'], before);
      expect(await b.urls(), [_urlC, _urlB]);
    },
  );

  test('suppression ailleurs : seulement ce qui venait du blob', () async {
    await a.repo.install(_urlA);
    await a.repo.install(_urlB);
    await a.signIn();
    await a.sync.setPassphrase(_pass);
    await a.cycle();
    await b.signIn();
    await b.sync.setPassphrase(_pass);
    await b.cycle();
    expect(await b.urls(), [_urlA, _urlB]);
    // B a un addon à lui, jamais passé par le blob (aucune marque d'envoi).
    await b.db.customStatement(
      "INSERT OR REPLACE INTO sync_meta (key, value) VALUES ('applying', '1')",
    );
    await b.repo.install(_urlC);
    await b.db.customStatement(
      "INSERT OR REPLACE INTO sync_meta (key, value) VALUES ('applying', '0')",
    );
    // A supprime l'addon B, qui venait du blob.
    await a.repo.remove((await a.repo.list()).last.id);
    await a.cycle();
    await b.cycle();
    expect(await b.urls(), [_urlA, _urlC]);
    // L'addon local de B n'a pas été touché et revient dans le blob.
    await a.cycle();
    expect((await a.urls()).toSet(), {_urlA, _urlC});
  });

  test('adresse locale : en attente de confirmation, jamais autorisée '
      'automatiquement, conservée dans le blob', () async {
    await a.repo.install(_urlLan, allowPrivate: true);
    await a.signIn();
    await a.sync.setPassphrase(_pass);
    await a.cycle();

    await b.signIn();
    await b.sync.setPassphrase(_pass);
    await b.cycle();
    expect(await b.urls(), isEmpty);
    expect(b.fetcher.requested, isEmpty);
    final st = await b.sync.state();
    expect(st.pendingPrivate, hasLength(1));
    expect(st.pendingPrivate.single.label, 'http://192.168.1.5:7000/***');
    // B renvoie le blob (autre changement) sans perdre l'adresse locale.
    await b.repo.install(_urlA);
    await b.cycle();
    expect(
      ((await serverPlain(_pass))['entries'] as List).map((e) => e['url']),
      containsAll([_urlLan, _urlA]),
    );
    // Confirmation locale : installée par le chemin normal.
    expect(await b.sync.installPending(st.pendingPrivate.single.hash), isTrue);
    expect(await b.urls(), contains(_urlLan));
    expect((await b.sync.state()).pendingPrivate, isEmpty);
  });

  test('adresse locale ignorée : retirée du blob', () async {
    await a.repo.install(_urlLan, allowPrivate: true);
    await a.signIn();
    await a.sync.setPassphrase(_pass);
    await a.cycle();
    await b.signIn();
    await b.sync.setPassphrase(_pass);
    await b.cycle();
    await b.sync.dismissPending(
      (await b.sync.state()).pendingPrivate.single.hash,
    );
    await b.cycle();
    expect((await serverPlain(_pass))['entries'], isEmpty);
  });

  test('addon reçu injoignable : nouvel essai, rien de perdu', () async {
    await a.repo.install(_urlA);
    await a.signIn();
    await a.sync.setPassphrase(_pass);
    await a.cycle();
    final now = DateTime(2026, 1, 1);
    var clock = now;
    final c = Device(server, {});
    addTearDown(c.close);
    c.sync = AddonSync(
      c.db,
      c.secrets,
      c.repo,
      seal: _fakeSeal,
      open: _fakeOpen,
      fingerprint: _fakeFingerprint,
      now: () => clock,
    );
    c.store = DriftLocalSyncStore(c.db, addons: c.sync);
    c.service = SyncService(
      api: SyncApiClient('https://sync.example.com', c.secrets, http: server),
      store: c.store,
      addons: c.sync,
    );
    await c.signIn();
    await c.sync.setPassphrase(_pass);
    await c.cycle();
    expect(await c.urls(), isEmpty);
    expect((await c.sync.state()).failed, 1);
    // Le blob garde l'addon pour les autres appareils.
    expect(
      ((await serverPlain(_pass))['entries'] as List).single['url'],
      _urlA,
    );
    // Le serveur de l'addon revient : nouvel essai après le délai.
    c.manifests[_urlA] = sampleManifest(id: 'org.a', name: 'A');
    await c.cycle();
    expect(await c.urls(), isEmpty); // trop tôt
    clock = now.add(const Duration(minutes: 6));
    await c.cycle();
    expect(await c.urls(), [_urlA]);
    expect((await c.sync.state()).failed, 0);
  });

  test('phrase perdue : réinitialiser supprime le blob distant, le reste '
      'est intact, puis nouvelle phrase', () async {
    await a.repo.install(_urlA);
    await a.signIn();
    await a.db.customStatement(
      'INSERT INTO library_items (profile_id, item_id, type, meta_json, added_at) '
      "VALUES ('default', 'tt1', 'movie', '{}', 1)",
    );
    await a.sync.setPassphrase(_pass);
    await a.cycle();
    expect(
      server.items.keys,
      containsAll(['addons/all', 'library/default|tt1']),
    );

    await b.signIn();
    await b.sync.setPassphrase('phrase oubliee, essai errone');
    await b.cycle();
    expect((await b.sync.state()).status, AddonSyncStatus.wrongPassphrase);
    await b.sync.requestReset();
    expect((await b.sync.state()).status, AddonSyncStatus.resetting);
    await b.cycle();
    expect(server.addonsItem!['deleted'], 1);
    expect(server.addonsItem!['payload'], isNull);
    // Les autres données restent sur le serveur.
    expect(server.items['library/default|tt1']!['deleted'], 0);
    expect((await b.sync.state()).status, AddonSyncStatus.noPassphrase);
    expect(
      b.secrets.snapshot.containsKey(AddonSyncSecretKeys.passphrase),
      isFalse,
    );

    // Nouvelle phrase : les addons de cet appareil repartent.
    await b.repo.install(_urlB);
    await b.sync.setPassphrase('toute nouvelle phrase secrete');
    await b.cycle();
    expect(server.addonsItem!['deleted'], 0);
    expect(
      ((jsonDecode(
                await _fakeOpen(
                  (server.addonsItem!['payload']! as Map)['blob'] as String,
                  'toute nouvelle phrase secrete',
                ),
              ))['entries']
              as List)
          .map((e) => e['url']),
      [_urlB],
    );
  });

  test('changer la phrase : rechiffre et renvoie ; l\'ancienne phrase '
      'ne marche plus ailleurs', () async {
    await a.repo.install(_urlA);
    await a.signIn();
    await a.sync.setPassphrase(_pass);
    await a.cycle();
    await b.signIn();
    await b.sync.setPassphrase(_pass);
    await b.cycle();
    expect(await b.urls(), [_urlA]);

    await a.sync.changePassphrase('nouvelle phrase secrete 2');
    await a.cycle();
    expect(
      await a.secrets.read(AddonSyncSecretKeys.passphrase),
      'nouvelle phrase secrete 2',
    );
    // B ne peut plus ouvrir : message, addons intacts.
    await b.cycle();
    expect((await b.sync.state()).status, AddonSyncStatus.wrongPassphrase);
    expect(await b.urls(), [_urlA]);
    // B saisit la nouvelle phrase : de nouveau synchronisé.
    await b.sync.setPassphrase('nouvelle phrase secrete 2');
    await b.cycle();
    expect((await b.sync.state()).status, AddonSyncStatus.ready);
    // Changer sans phrase validée est refusé.
    final c = Device(server, _manifests());
    addTearDown(c.close);
    await expectLater(
      c.sync.changePassphrase('encore une phrase longue'),
      throwsStateError,
    );
  });

  test(
    'ordre et activation : appliqués sans toucher aux addons locaux',
    () async {
      await a.repo.install(_urlA);
      await a.repo.install(_urlB);
      await a.signIn();
      await a.sync.setPassphrase(_pass);
      await a.cycle();
      await b.signIn();
      await b.sync.setPassphrase(_pass);
      await b.cycle();
      await a.repo.reorder([(await a.repo.list()).last.id]);
      await a.repo.setEnabled((await a.repo.list()).first.id, false);
      await a.cycle();
      await b.cycle();
      expect(await b.urls(), [_urlB, _urlA]);
      expect((await b.repo.list()).map((x) => x.enabled), [false, true]);
    },
  );

  test('stable : pas de boucle d\'envoi entre deux appareils', () async {
    await a.repo.install(_urlA);
    await a.signIn();
    await a.sync.setPassphrase(_pass);
    await a.cycle();
    await b.signIn();
    await b.sync.setPassphrase(_pass);
    await b.cycle();
    await a.cycle();
    await b.cycle();
    final v = server.version;
    for (var i = 0; i < 3; i++) {
      await a.cycle();
      await b.cycle();
    }
    expect(server.version, v);
    // Son propre envoi n'est pas rouvert à chaque tirage.
    final opens = a.opens;
    await a.cycle();
    expect(a.opens, opens);
  });

  test('trop d\'addons pour 16 Ko : état affiché, rien d\'envoyé', () async {
    await a.signIn();
    await a.sync.setPassphrase(_pass);
    await a.cycle();
    for (var i = 0; i < 60; i++) {
      final url = 'https://h$i.example.com/${'x' * 250}$i/manifest.json';
      await a.db
          .into(a.db.addons)
          .insert(
            AddonsCompanion.insert(
              id: 'id$i',
              position: i,
              manifestJson: '{}',
              secretKey: 'addon_url:id$i',
              urlHash: AddonRepository.urlHashOf(url),
              enabled: const Value(true),
            ),
          );
      await a.secrets.write(
        'addon_url:id$i',
        jsonEncode({'url': url, 'logo': null}),
      );
    }
    await a.cycle();
    expect(server.addonsItem, isNull);
    expect((await a.sync.state()).status, AddonSyncStatus.tooLarge);
    // Retirer des addons rétablit l'envoi.
    for (var i = 20; i < 60; i++) {
      await a.repo.remove('id$i');
    }
    await a.cycle();
    expect(server.addonsItem, isNotNull);
    expect((await a.sync.state()).status, AddonSyncStatus.ready);
  });

  test(
    'déconnexion : phrase et addons en attente oubliés, addons gardés',
    () async {
      await a.repo.install(_urlA);
      await a.signIn();
      await a.sync.setPassphrase(_pass);
      await a.cycle();
      await a.service.signOut();
      expect(await a.sync.passphrase(), isNull);
      expect(await a.urls(), [_urlA]);
    },
  );

  test(
    'chiffrement réel (SecretBox) de bout en bout entre deux appareils',
    () async {
      final ra = Device(
        server,
        _manifests(),
        seal: SecretBox.seal,
        open: SecretBox.open,
      );
      final rb = Device(
        server,
        _manifests(),
        seal: SecretBox.seal,
        open: SecretBox.open,
      );
      addTearDown(ra.close);
      addTearDown(rb.close);
      await ra.repo.install(_urlA);
      await ra.signIn();
      await ra.sync.setPassphrase(_pass);
      await ra.cycle();
      final blob = (server.addonsItem!['payload']! as Map)['blob'] as String;
      expect(blob.startsWith('v1.'), isTrue);
      expect(blob, isNot(contains('example')));
      await rb.signIn();
      await rb.sync.setPassphrase(_pass);
      await rb.cycle();
      expect(await rb.urls(), [_urlA]);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'déclencheurs : un changement d\'addon met addons/all en file',
    () async {
      await a.db.customStatement('DELETE FROM sync_outbox');
      await a.repo.install(_urlA);
      var rows = await a.db
          .customSelect('SELECT kind, key FROM sync_outbox')
          .get();
      expect(
        rows.map((r) => '${r.read<String>('kind')}/${r.read<String>('key')}'),
        ['addons/all'],
      );
      await a.db.customStatement('DELETE FROM sync_outbox');
      await a.repo.setEnabled((await a.repo.list()).single.id, false);
      rows = await a.db.customSelect('SELECT kind FROM sync_outbox').get();
      expect(rows, hasLength(1));
      await a.db.customStatement('DELETE FROM sync_outbox');
      await a.repo.remove((await a.repo.list()).single.id);
      rows = await a.db.customSelect('SELECT kind FROM sync_outbox').get();
      expect(rows, hasLength(1));
    },
  );

  group('génération et suppressions explicites', () {
    test(
      'rejeu d\'un ancien blob : aucune suppression, aucune réinstallation',
      () async {
        await a.repo.install(_urlA);
        await a.repo.install(_urlB);
        await a.signIn();
        await a.sync.setPassphrase(_pass);
        await a.cycle();
        await b.signIn();
        await b.sync.setPassphrase(_pass);
        await b.cycle();
        await a.cycle(); // A a vu la publication de B
        final old = Map<String, Object?>.from(server.addonsItem!);
        final oldGen = (await blobAt(old, _pass))['gen'] as int;

        // A retire B : suppression explicite (gen 2), propagée à B.
        await a.repo.remove((await a.repo.list()).last.id);
        await a.cycle();
        final cur = await blobAt(server.addonsItem!, _pass);
        expect(cur['gen'], oldGen + 1);
        expect(cur['removed'], hasLength(1));
        await b.cycle();
        expect(await b.urls(), [_urlA]);

        // Le serveur rejoue l'ancien blob (gen 1, qui contient encore B).
        server.items['addons/all'] = {...old, 'version': ++server.version};
        await b.cycle();
        await a.cycle();
        expect(await b.urls(), [_urlA]);
        expect(await a.urls(), [_urlA]);
        expect(
          b.fetcher.requested.where((u) => u.toString() == _urlB).length,
          1,
        );
        // Et l'état à jour est republié (gen au-dessus de ce qui a été vu).
        expect(
          (await blobAt(server.addonsItem!, _pass))['entries'],
          hasLength(1),
        );
        expect(
          (await blobAt(server.addonsItem!, _pass))['gen'] as int,
          greaterThan(oldGen + 1),
        );
      },
    );

    test(
      'rejeu quand un addon local venait du blob : jamais supprimé',
      () async {
        await a.repo.install(_urlA);
        await a.repo.install(_urlB);
        await a.signIn();
        await a.sync.setPassphrase(_pass);
        await a.cycle();
        await b.signIn();
        await b.sync.setPassphrase(_pass);
        await b.cycle();
        // Un blob plus ancien sans B (appareil en retard) ne retire rien.
        final stale = jsonEncode({
          'v': 1,
          'gen': 0,
          'device': 'zz',
          'entries': [
            {'url': _urlA, 'logo': null, 'enabled': true, 'position': 0},
          ],
          'removed': [],
        });
        server.items['addons/all'] = {
          'kind': 'addons',
          'key': 'all',
          'payload': {'blob': await _fakeSeal(stale, _pass)},
          'deleted': 0,
          'version': ++server.version,
        };
        await b.cycle();
        expect(await b.urls(), [_urlA, _urlB]);
        await a.cycle();
        expect(await a.urls(), [_urlA, _urlB]);
      },
    );

    test(
      'appareil en retard (génération plus basse) : ignoré puis corrigé',
      () async {
        await a.repo.install(_urlA);
        await a.signIn();
        await a.sync.setPassphrase(_pass);
        await a.cycle();
        await a.repo.install(_urlB);
        await a.cycle();
        await a.repo.install(_urlC);
        await a.cycle(); // gen 3
        // Un appareil en retard pousse gen 2 sans B ni C.
        server.items['addons/all'] = {
          'kind': 'addons',
          'key': 'all',
          'payload': {
            'blob': await _fakeSeal(
              jsonEncode({
                'v': 1,
                'gen': 2,
                'device': 'late',
                'entries': [
                  {'url': _urlA, 'logo': null, 'enabled': true, 'position': 0},
                ],
                'removed': [],
              }),
              _pass,
            ),
          },
          'deleted': 0,
          'version': ++server.version,
        };
        await a.cycle();
        expect(await a.urls(), [_urlA, _urlB, _urlC]);
        final cur = await blobAt(server.addonsItem!, _pass);
        expect(cur['gen'] as int, greaterThan(3));
        expect(cur['entries'], hasLength(3));
      },
    );

    test('une suppression puis un nouvel ajout : l\'addon revient', () async {
      await a.repo.install(_urlA);
      await a.repo.install(_urlB);
      await a.signIn();
      await a.sync.setPassphrase(_pass);
      await a.cycle();
      await b.signIn();
      await b.sync.setPassphrase(_pass);
      await b.cycle();
      await a.repo.remove((await a.repo.list()).last.id);
      await a.cycle();
      await b.cycle();
      expect(await b.urls(), [_urlA]);
      await a.repo.install(_urlB);
      await a.cycle();
      expect((await blobAt(server.addonsItem!, _pass))['removed'], isEmpty);
      await b.cycle();
      expect(await b.urls(), [_urlA, _urlB]);
    });
  });

  test('réinitialisation par un autre appareil : l\'appareil en ligne ne '
      'renvoie rien et redemande la phrase, sans boucle', () async {
    await a.repo.install(_urlA);
    await a.signIn();
    await a.sync.setPassphrase(_pass);
    await a.cycle();
    await b.signIn();
    await b.sync.setPassphrase(_pass);
    await b.cycle();

    await b.sync.requestReset();
    await b.cycle();
    expect(server.addonsItem!['deleted'], 1);
    final version = server.version;

    // A, encore en ligne avec l'ancienne phrase, ne ressuscite pas le blob.
    await a.cycle();
    await a.cycle();
    expect((await a.sync.state()).status, AddonSyncStatus.phraseReset);
    expect(await a.sync.passphrase(), isNull);
    expect(server.addonsItem!['deleted'], 1);
    expect(server.version, version);
    expect(await a.urls(), [_urlA]);

    // B définit une nouvelle phrase ; A la saisit : plus de phrase erronée.
    const next = 'la toute nouvelle phrase';
    await b.repo.install(_urlB);
    await b.sync.setPassphrase(next);
    await b.cycle();
    expect(server.addonsItem!['deleted'], 0);
    await a.cycle();
    expect((await a.sync.state()).status, AddonSyncStatus.phraseReset);
    await a.sync.setPassphrase(next);
    await a.cycle();
    await b.cycle();
    expect((await a.sync.state()).status, AddonSyncStatus.ready);
    expect((await b.sync.state()).status, AddonSyncStatus.ready);
    expect((await a.urls()).toSet(), {_urlA, _urlB});
  });

  test('changement de phrase : un blob de l\'ancienne phrase reçu pendant le '
      'rechiffrement ne bloque pas l\'envoi', () async {
    await a.repo.install(_urlA);
    await a.signIn();
    await a.sync.setPassphrase(_pass);
    await a.cycle();
    await b.signIn();
    await b.sync.setPassphrase(_pass);
    await b.cycle();

    await a.sync.changePassphrase('nouvelle phrase secrete 2');
    // Avant l'envoi, B publie (ancienne phrase) et A le reçoit.
    await b.repo.install(_urlB);
    await b.cycle();
    final item = server.addonsItem!;
    await a.sync.recordRemote(
      SyncItem(
        kind: 'addons',
        key: 'all',
        payload: Map<String, dynamic>.from(item['payload']! as Map),
        version: 99,
      ),
    );
    final res = await a.sync.process();
    expect(res.needsPush, isTrue);
    expect(
      (await a.sync.state()).status,
      isNot(AddonSyncStatus.wrongPassphrase),
    );
    await a.cycle();
    expect(
      await blobAt(server.addonsItem!, 'nouvelle phrase secrete 2'),
      isNotEmpty,
    );
  });

  test('même phrase ressaisie après un faux « réinitialisé » : un ancien blob '
      'rejoué ne supprime ni ne réinstalle rien', () async {
    await a.repo.install(_urlA);
    await a.repo.install(_urlB);
    await a.signIn();
    await a.sync.setPassphrase(_pass);
    await a.cycle();
    // B est retiré (tombstone), puis réajouté.
    await a.repo.remove((await a.repo.list()).last.id);
    await a.cycle();
    final staleRemoval = Map<String, Object?>.from(server.addonsItem!);
    await a.repo.install(_urlB);
    await a.cycle();
    // Et C ajouté puis retiré : un ancien blob le contient encore.
    await a.repo.install(_urlC);
    await a.cycle();
    final staleWithC = Map<String, Object?>.from(server.addonsItem!);
    await a.repo.remove((await a.repo.list()).last.id);
    await a.cycle();
    expect(await a.urls(), [_urlA, _urlB]);

    // Un serveur sans phrase forge une pierre tombale…
    server.items['addons/all'] = {
      'kind': 'addons',
      'key': 'all',
      'payload': null,
      'deleted': 1,
      'version': ++server.version,
    };
    await a.cycle();
    expect((await a.sync.state()).status, AddonSyncStatus.phraseReset);
    // … l'utilisateur ressaisit la MÊME phrase…
    server.items['addons/all'] = {...staleRemoval, 'version': ++server.version};
    await a.sync.setPassphrase(_pass);
    await a.cycle();
    // … et le serveur rejoue d'anciens blobs : rien ne change.
    for (final stale in [staleRemoval, staleWithC]) {
      server.items['addons/all'] = {...stale, 'version': ++server.version};
      await a.cycle();
      expect(await a.urls(), [_urlA, _urlB]);
    }
    expect(
      a.fetcher.requested.where((u) => u.toString() == _urlC),
      hasLength(1),
    );
    // Même chose après un oubli complet de la phrase.
    await a.sync.forget();
    await a.sync.setPassphrase(_pass);
    server.items['addons/all'] = {...staleRemoval, 'version': ++server.version};
    await a.cycle();
    expect(await a.urls(), [_urlA, _urlB]);
  });

  test('forget(wipeFingerprint) efface empreinte et sel', () async {
    await a.repo.install(_urlA);
    await a.signIn();
    await a.sync.setPassphrase(_pass);
    expect(a.secrets.snapshot[AddonSyncSecretKeys.fingerprint], isNotNull);
    expect(a.secrets.snapshot[AddonSyncSecretKeys.fingerprintSalt], isNotNull);
    await a.sync.forget();
    expect(a.secrets.snapshot[AddonSyncSecretKeys.fingerprint], isNotNull);
    await a.sync.forget(wipeFingerprint: true);
    expect(a.secrets.snapshot[AddonSyncSecretKeys.fingerprint], isNull);
    expect(a.secrets.snapshot[AddonSyncSecretKeys.fingerprintSalt], isNull);
  });

  test(
    'génération hors limite (2^53) : blob illisible, rien appliqué',
    () async {
      await a.repo.install(_urlA);
      await a.signIn();
      await a.sync.setPassphrase(_pass);
      await a.cycle();
      server.items['addons/all'] = {
        'kind': 'addons',
        'key': 'all',
        'payload': {
          'blob': await _fakeSeal(
            jsonEncode({
              'v': 1,
              'gen': 9007199254740993,
              'device': 'x',
              'entries': [],
              'removed': [],
            }),
            _pass,
          ),
        },
        'deleted': 0,
        'version': ++server.version,
      };
      await b.signIn();
      await b.sync.setPassphrase(_pass);
      await b.cycle();
      expect(await b.urls(), isEmpty);
    },
  );
}
