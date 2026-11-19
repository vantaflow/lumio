import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio/features/phone/phone_add.dart';
import 'package:lumio/features/phone/phone_providers.dart';
import 'package:lumio/features/phone/phone_server.dart';
import 'package:lumio/features/settings/settings_providers.dart';
import 'package:lumio/data/app_settings.dart';
import 'package:lumio/providers.dart';
import 'package:lumio_core/lumio_core.dart';

import 'support/fake_addon_fetcher.dart';
import 'support/fake_phone.dart';

const _a = 'https://alpha.example.com/tok-secret/manifest.json';
const _b = 'https://beta.example.com/tok-secret2/manifest.json';

/// Serveur réel + dépôt d'addons réel (base mémoire) : gestion depuis le
/// téléphone par les opérations existantes, sans jamais voir d'URL.
late ProviderContainer c;
late PhoneServer server;
late HttpClient http;
late String cookie;
late String csrf;
late String host;

final _backendProvider = Provider((ref) => AppPhoneBackend(ref));

Future<(String, String, int)> _raw(
  String method,
  String path,
  Object? body,
) async {
  final req = await http.openUrl(method, Uri.parse('http://$host$path'));
  req.headers.add('origin', 'http://$host');
  if (path != '/api/login') {
    req.headers.add('cookie', cookie);
    req.headers.add('x-csrf-token', csrf);
  }
  if (body != null) {
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(body));
  }
  final res = await req.close();
  final text = await utf8.decodeStream(res);
  return (text, res.headers['set-cookie']?.first ?? '', res.statusCode);
}

Future<List<Map<String, Object?>>> _list() async {
  final r = await _raw('GET', '/api/addons', null);
  return ((jsonDecode(r.$1) as Map)['addons']! as List)
      .cast<Map<String, Object?>>();
}

void main() {
  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    final repo = AddonRepository(
      db,
      MemorySecretStore(),
      clientFactory: ({required allowPrivate}) => AddonClient(
        FakeAddonFetcher({
          _a: sampleManifest(id: 'alpha', name: 'Alpha'),
          _b: sampleManifest(id: 'beta', name: 'Beta', types: ['movie']),
        }),
        allowPrivate: allowPrivate,
        retries: 0,
      ),
    );
    await repo.install(_a);
    await repo.install(_b);
    c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        addonRepositoryProvider.overrideWithValue(repo),
        appSettingsStoreProvider.overrideWithValue(AppSettingsStore(db)),
        lanAddressSourceProvider.overrideWithValue(const FakeLan('127.0.0.1')),
      ],
    );
    await c.read(addonsProvider.future);
    server = PhoneServer(
      backend: c.read(_backendProvider),
      adds: PhoneAddCoordinator(),
      lan: const FakeLan('127.0.0.1'),
      lang: 'fr',
      preferredPort: 0,
    );
    await server.start();
    http = HttpClient();
    host = server.state.value.address;
    final r = await _raw('POST', '/api/login', {
      'code': server.state.value.code,
    });
    cookie = r.$2.split(';').first;
    csrf = (jsonDecode(r.$1) as Map)['csrf']! as String;
  });

  tearDown(() async {
    http.close(force: true);
    await server.stop();
    server.dispose();
    c.dispose();
  });

  test('liste : noms, santé, aucune URL ni jeton', () async {
    final r = await _raw('GET', '/api/addons', null);
    expect(r.$1, isNot(contains('alpha.example.com')));
    expect(r.$1, isNot(contains('tok-secret')));
    expect(r.$1, isNot(contains('http')));
    final l = await _list();
    expect(l.map((a) => a['name']), ['Alpha', 'Beta']);
    expect(l.first['health'], 'unknown');
  });

  test('monter, désactiver, supprimer : le dépôt est modifié', () async {
    var l = await _list();
    final beta = l[1]['id']! as String;
    expect(
      (await _raw('POST', '/api/addons/$beta/move', {'delta': -1})).$3,
      200,
    );
    expect((await c.read(addonsProvider.future)).map((a) => a.id), [
      'beta',
      'alpha',
    ]);
    expect(
      (await _raw('POST', '/api/addons/$beta/enabled', {'enabled': false})).$3,
      200,
    );
    expect(
      (await c.read(addonRepositoryProvider).list()).first.enabled,
      isFalse,
    );
    l = await _list();
    expect(l.first['enabled'], isFalse);
    expect((await _raw('DELETE', '/api/addons/$beta', null)).$3, 200);
    expect((await c.read(addonRepositoryProvider).list()).map((a) => a.id), [
      'alpha',
    ]);
  });
}
