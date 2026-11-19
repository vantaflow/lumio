import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio_core/lumio_core.dart';

import 'support/fake_addon_fetcher.dart';

const _url = 'https://films.example.com/secret-token-123/manifest.json';

class _FlakySecrets extends MemorySecretStore {
  bool failWrite = false;
  bool failDelete = false;

  @override
  Future<void> write(String k, String v) async {
    if (failWrite) throw StateError('écriture impossible');
    return super.write(k, v);
  }

  @override
  Future<void> delete(String k) async {
    if (failDelete) throw StateError('suppression impossible');
    return super.delete(k);
  }
}

void main() {
  late AppDatabase db;
  late _FlakySecrets secrets;
  late FakeAddonFetcher fetcher;
  late AddonRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    secrets = _FlakySecrets();
    fetcher = FakeAddonFetcher({_url: sampleManifest()});
    repo = AddonRepository(
      db,
      secrets,
      clientFactory: ({required allowPrivate}) =>
          AddonClient(fetcher, allowPrivate: allowPrivate, retries: 0),
    );
  });
  tearDown(() => db.close());

  test(
    'même addon (hôte + id) avec d autres réglages : remplace, même rang',
    () async {
      const other = 'https://films.example.com/reglages-fr/manifest.json';
      const third = 'https://autre.example.org/manifest.json';
      fetcher.manifests[other] = sampleManifest();
      fetcher.manifests[third] = sampleManifest(id: 'x.autre', name: 'Autre');
      final first = await repo.install(_url);
      await repo.install(third);
      final m = await repo.preview(other);
      expect((await repo.findSameAddon(other, m))?.id, first.id);
      // Autre hôte, même id : pas le même addon.
      expect(await repo.findSameAddon(third, m), isNull);
      final added = await repo.installReplacing(other, first.id);
      final list = await repo.list();
      expect(list.map((a) => a.id), [added.id, 'x.autre']);
      expect((await repo.urlOf(added.id)).toString(), other);
      expect(list, hasLength(2));
    },
  );

  test(
    'install valide : listé avec nom et types, URL jamais dans SQLite',
    () async {
      final a = await repo.install(_url);
      expect(a.name, 'Films libres');

      final list = await repo.list();
      expect(list, hasLength(1));
      expect(list.single.name, 'Films libres');
      expect(list.single.manifest!.types, ['movie', 'series']);
      expect(list.single.enabled, isTrue);

      final rows = await db.customSelect('SELECT * FROM addons').get();
      expect(rows, hasLength(1));
      for (final v in rows.single.data.values) {
        expect('$v', isNot(contains('films.example.com')));
        expect('$v', isNot(contains('secret-token-123')));
      }
      expect(rows.single.data['secret_key'], 'addon_url:${a.id}');
      expect(jsonDecode(secrets.snapshot['addon_url:${a.id}']!)['url'], _url);
      expect((await repo.urlOf(a.id)).toString(), _url);
    },
  );

  test('URL invalide : exception, rien enregistré', () async {
    await expectLater(
      repo.install('pas une url'),
      throwsA(isA<AddonException>()),
    );
    await expectLater(
      repo.install('https://inconnu.example.com/manifest.json'),
      throwsA(isA<ManifestException>()),
    );
    expect(await repo.list(), isEmpty);
    expect(secrets.snapshot, isEmpty);
  });

  test(
    'doublon (variantes de la même URL) : DuplicateAddonException',
    () async {
      await repo.install(_url);
      for (final v in [
        _url,
        'https://FILMS.example.com/secret-token-123/',
        'https://films.example.com:443/secret-token-123',
        '  $_url#frag ',
      ]) {
        await expectLater(
          repo.install(v),
          throwsA(isA<DuplicateAddonException>()),
          reason: v,
        );
      }
      expect(await repo.list(), hasLength(1));
      expect(secrets.snapshot, hasLength(1));
    },
  );

  test(
    'même id de manifeste depuis une autre URL : deux installations',
    () async {
      const other = 'https://miroir.example.org/manifest.json';
      fetcher.manifests[other] = sampleManifest();
      final a = await repo.install(_url);
      final b = await repo.install(other);
      expect(a.id, isNot(b.id));
      expect((await repo.list()).map((e) => e.position), [0, 1]);
    },
  );

  test(
    'adresse privée : PrivateAddressException puis OK avec allowPrivate',
    () async {
      const lan = 'http://192.168.1.20:7000/manifest.json';
      fetcher.manifests[lan] = sampleManifest(id: 'lan', name: 'Maison');
      await expectLater(
        repo.install(lan),
        throwsA(isA<PrivateAddressException>()),
      );
      expect(fetcher.requested, isEmpty);
      expect(await repo.list(), isEmpty);

      final a = await repo.install(lan, allowPrivate: true);
      expect(a.name, 'Maison');
    },
  );

  test('preview ne stocke rien', () async {
    final m = await repo.preview(_url);
    expect(m.name, 'Films libres');
    expect(await repo.list(), isEmpty);
    expect(secrets.snapshot, isEmpty);
  });

  test('remove supprime la ligne et le secret', () async {
    final a = await repo.install(_url);
    await repo.remove(a.id);
    expect(await repo.list(), isEmpty);
    expect(secrets.snapshot, isEmpty);
    await expectLater(repo.urlOf(a.id), throwsA(isA<AddonException>()));
  });

  test('reorder et setEnabled sont persistés', () async {
    const u2 = 'https://b.example.com/manifest.json';
    const u3 = 'https://c.example.com/manifest.json';
    fetcher.manifests[u2] = sampleManifest(id: 'b', name: 'B');
    fetcher.manifests[u3] = sampleManifest(id: 'c', name: 'C');
    final a = await repo.install(_url);
    final b = await repo.install(u2);
    final c = await repo.install(u3);

    await repo.reorder([c.id, a.id]);
    expect((await repo.list()).map((e) => e.id), [c.id, a.id, b.id]);

    await repo.setEnabled(a.id, false);
    final l = await repo.list();
    expect(l.firstWhere((e) => e.id == a.id).enabled, isFalse);
    expect(l.firstWhere((e) => e.id == b.id).enabled, isTrue);
  });

  test('logo : jamais dans SQLite, restitué depuis le SecretStore', () async {
    const logo = 'https://films.example.com/secret-token-123/logo.png';
    fetcher.manifests[_url] = sampleManifest(logo: logo);
    final a = await repo.install(_url);
    expect(a.logo.toString(), logo);

    final rows = await db.customSelect('SELECT * FROM addons').get();
    for (final v in rows.single.data.values) {
      expect('$v', isNot(contains('secret-token-123')));
      expect('$v', isNot(contains('logo.png')));
    }
    final l = (await repo.list()).single;
    expect(l.logo.toString(), logo);
    expect(l.manifest!.logo.toString(), logo);
  });

  test('secret manquant : addon marqué broken, supprimable', () async {
    final a = await repo.install(_url);
    await secrets.delete('addon_url:${a.id}');
    final l = (await repo.list()).single;
    expect(l.broken, isTrue);
    expect(l.manifest, isNull);
    await repo.remove(a.id);
    expect(await repo.list(), isEmpty);
  });

  test('install : échec d\'écriture du secret, ni ligne ni secret', () async {
    secrets.failWrite = true;
    await expectLater(repo.install(_url), throwsStateError);
    expect(await repo.list(), isEmpty);
    expect(await db.customSelect('SELECT * FROM addons').get(), isEmpty);
    expect(secrets.snapshot, isEmpty);
  });

  test('remove : échec de suppression du secret, ligne conservée', () async {
    final a = await repo.install(_url);
    secrets.failDelete = true;
    await expectLater(repo.remove(a.id), throwsStateError);
    expect(await repo.list(), hasLength(1));
    secrets.failDelete = false;
    await repo.remove(a.id);
    expect(await repo.list(), isEmpty);
    expect(secrets.snapshot, isEmpty);
  });

  test('isInstalled détecte l\'URL normalisée', () async {
    expect(await repo.isInstalled(_url), isFalse);
    await repo.install(_url);
    expect(
      await repo.isInstalled('https://FILMS.example.com/secret-token-123/'),
      isTrue,
    );
  });
}
