import 'dart:convert';
import 'dart:io';

import 'package:lumio_core/lumio_core.dart';
import 'package:lumio_core/testing.dart';
import 'package:test/test.dart';

final _url = Uri.parse('https://addon.example/manifest.json');

AddonManifest _parse(String file) => AddonManifest.fromJson(
  jsonDecode(File('test/fixtures/manifests/$file').readAsStringSync()),
  _url,
);

void main() {
  test('valid_minimal', () {
    final m = _parse('valid_minimal.json');
    expect(m.id, isNotEmpty);
    expect(m.resources, isNotEmpty);
  });

  test('valid_full : ressources mixtes, extra, logo', () {
    final m = _parse('valid_full.json');
    expect(m.id, 'dev.test.full');
    expect(m.logo, Uri.parse('https://example.com/logo.png'));
    expect(m.resources.map((r) => r.name), ['catalog', 'meta', 'stream']);
    expect(m.catalogs.first.extra.map((e) => e.name), ['search', 'genre']);
    expect(m.catalogs.first.extra.last.options, ['Action', 'Drame']);
    expect(m.baseUrl, Uri.parse('https://addon.example'));
    expect(m.warnings, isEmpty);
  });

  test('supports : types, idPrefixes par ressource', () {
    final m = _parse('valid_full.json');
    expect(m.supports('catalog', 'movie', 'x'), isTrue);
    expect(m.supports('meta', 'movie', 'tt1'), isTrue);
    expect(m.supports('meta', 'tv', 'tt1'), isFalse); // types de la ressource
    expect(m.supports('stream', 'movie', 'dev:42'), isTrue);
    expect(m.supports('stream', 'movie', 'zz1'), isFalse);
    expect(m.supports('subtitles', 'movie', 'tt1'), isFalse);
  });

  test('unknown_types : types conservés', () {
    final m = _parse('unknown_types.json');
    expect(m.types, containsAll(['hologram', 'podcast']));
    expect(m.catalogs.map((c) => c.type), contains('hologram'));
  });

  test('null_field : null = absent', () {
    final m = _parse('null_field.json');
    expect(m.description, isNull);
    expect(m.logo, isNull);
    expect(m.catalogs.single.name, 'top');
  });

  test('unicode_arabic : texte intact', () {
    final raw =
        jsonDecode(
              File(
                'test/fixtures/manifests/unicode_arabic.json',
              ).readAsStringSync(),
            )
            as Map;
    final m = AddonManifest.fromJson(raw, _url);
    expect(m.name, raw['name']);
    expect(m.name, matches(RegExp(r'[؀-ۿ]')));
  });

  test('version_not_semver : valide avec avertissement', () {
    final m = _parse('version_not_semver.json');
    expect(m.version, 'v2-beta');
    expect(m.warnings, isNotEmpty);
  });

  test('catalog_missing_type : entrée ignorée et signalée', () {
    final m = _parse('catalog_missing_type.json');
    expect(m.catalogs.map((c) => c.id), ['top']);
    expect(m.warnings, isNotEmpty);
  });

  test('missing_id : message précis', () {
    expect(
      () => _parse('missing_id.json'),
      throwsA(
        isA<ManifestException>().having(
          (e) => e.message,
          'message',
          'Manifeste invalide : champ id manquant',
        ),
      ),
    );
  });

  for (final f in [
    'resources_object.json',
    'empty_object.json',
    'array_root.json',
  ]) {
    test('$f invalide', () {
      expect(() => _parse(f), throwsA(isA<ManifestException>()));
    });
  }

  test('truncated et html : AddonClient lève ManifestException', () async {
    final server = await FakeAddonServer.start();
    addTearDown(server.close);
    for (final f in ['truncated.json', 'html_instead_of_json.json']) {
      server.route(
        '/manifest.json',
        FakeResponse.raw(File('test/fixtures/manifests/$f').readAsBytesSync()),
      );
      final client = AddonClient(
        IoHttpFetcher(),
        allowPrivate: true,
        retries: 0,
      );
      await expectLater(
        client.fetchManifest(server.baseUrl.replace(path: '/manifest.json')),
        throwsA(isA<ManifestException>()),
        reason: f,
      );
    }
  });

  test('6 Mo : ManifestException de taille, sans parser', () async {
    final server = await FakeAddonServer.start();
    addTearDown(server.close);
    server.route('/manifest.json', FakeResponse.raw(buildOversizedManifest()));
    final client = AddonClient(IoHttpFetcher(), allowPrivate: true);
    await expectLater(
      client.fetchManifest(server.baseUrl.replace(path: '/manifest.json')),
      throwsA(
        isA<ManifestException>().having(
          (e) => e.message,
          'message',
          contains('trop volumineuse'),
        ),
      ),
    );
  });

  test('manifeste valide via le réseau', () async {
    final server = await FakeAddonServer.start();
    addTearDown(server.close);
    server.route(
      '/manifest.json',
      FakeResponse.raw(
        File('test/fixtures/manifests/valid_full.json').readAsBytesSync(),
        contentType: 'application/json',
      ),
    );
    final client = AddonClient(IoHttpFetcher(), allowPrivate: true);
    final m = await client.fetchManifest(
      server.baseUrl.replace(path: '/manifest.json'),
    );
    expect(m.name, 'Complet');
  });
}
