import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

class _StubFetcher implements HttpFetcher {
  _StubFetcher(this.respond);
  final Future<FetchResponse> Function() respond;

  @override
  Future<FetchResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) => respond();
}

FetchResponse _json(Object body, {int status = 200}) =>
    FetchResponse(status: status, body: utf8.encode(jsonEncode(body)));

final _url = Uri.parse('https://example.org/update.json');

UpdateChecker _checker(Future<FetchResponse> Function() r, String current) =>
    UpdateChecker(_StubFetcher(r), _url, current);

void main() {
  final sha = 'a' * 64;
  Map<String, Object> manifest(String v) => {
    'version': v,
    'apk': 'https://example.org/lumio.apk',
    'sha256': sha,
  };

  test('version distante plus récente : manifeste rendu', () async {
    final m = await _checker(
      () async => _json(manifest('1.2.0')),
      '1.1.9',
    ).check();
    expect(m, isNotNull);
    expect(m!.version, '1.2.0');
    expect(m.apkUrl, Uri.parse('https://example.org/lumio.apk'));
    expect(m.sha256, sha);
  });

  test('même version : null', () async {
    expect(
      await _checker(() async => _json(manifest('1.1.9')), '1.1.9').check(),
      isNull,
    );
  });

  test('version distante plus ancienne : null', () async {
    expect(
      await _checker(() async => _json(manifest('1.1.8')), '1.1.9').check(),
      isNull,
    );
  });

  test('comparaison numérique, pas lexicale (1.10.0 > 1.9.0)', () async {
    expect(
      await _checker(() async => _json(manifest('1.10.0')), '1.9.0').check(),
      isNotNull,
    );
  });

  test('suffixe de build ignoré (1.2.0+5 contre 1.2.0)', () async {
    expect(
      await _checker(() async => _json(manifest('1.2.0+5')), '1.2.0').check(),
      isNull,
    );
  });

  test('SocketException : null, pas d\'exception', () async {
    expect(
      await _checker(
        () async => throw const SocketException('hors ligne'),
        '1.0.0',
      ).check(),
      isNull,
    );
  });

  test('statut 500, JSON invalide, champs manquants : null', () async {
    expect(
      await _checker(() async => _json({}, status: 500), '1.0.0').check(),
      isNull,
    );
    expect(
      await _checker(
        () async => FetchResponse(status: 200, body: utf8.encode('{x')),
        '1.0.0',
      ).check(),
      isNull,
    );
    expect(
      await _checker(() async => _json({'version': '2.0.0'}), '1.0.0').check(),
      isNull,
    );
    expect(
      await _checker(() async => _json(manifest('abc')), '1.0.0').check(),
      isNull,
    );
  });

  test('URL d\'APK non http(s) : null', () async {
    final m = {...manifest('2.0.0'), 'apk': 'file:///etc/passwd'};
    expect(await _checker(() async => _json(m), '1.0.0').check(), isNull);
  });

  group('verifySha256', () {
    final bytes = utf8.encode('lumio');
    final hex = sha256.convert(bytes).toString();

    test('vrai sur les bons octets (casse indifférente)', () {
      expect(verifySha256(bytes, hex), isTrue);
      expect(verifySha256(bytes, hex.toUpperCase()), isTrue);
    });

    test('faux si un octet change', () {
      final bad = [...bytes]..[0] ^= 1;
      expect(verifySha256(bad, hex), isFalse);
    });
  });

  group('APK par architecture', () {
    Map<String, Object> multi() => {
      ...manifest('1.2.0'),
      'apks': {
        'arm64-v8a': {'apk': 'https://example.org/a64.apk', 'sha256': 'b' * 64},
        'armeabi-v7a': {
          'apk': 'https://example.org/a32.apk',
          'sha256': 'c' * 64,
        },
      },
    };

    Future<UpdateManifest?> run(List<String> abis) => UpdateChecker(
      _StubFetcher(() async => _json(multi())),
      _url,
      '1.0.0',
      supportedAbis: abis,
    ).check();

    test('choisit l\'APK de la première ABI connue', () async {
      final m = await run(['armeabi-v7a']);
      expect(m!.apkUrl, Uri.parse('https://example.org/a32.apk'));
      expect(m.sha256, 'c' * 64);
      final m64 = await run(['arm64-v8a', 'armeabi-v7a']);
      expect(m64!.apkUrl, Uri.parse('https://example.org/a64.apk'));
    });

    test(
      'ABI inconnue ou absente : repli sur apk/sha256 de la racine',
      () async {
        for (final abis in [
          <String>[],
          ['x86_64'],
        ]) {
          final m = await run(abis);
          expect(m!.apkUrl, Uri.parse('https://example.org/lumio.apk'));
          expect(m.sha256, sha);
        }
      },
    );

    test('entrée d\'ABI invalide : null', () async {
      final bad = multi();
      (bad['apks'] as Map)['armeabi-v7a'] = {
        'apk': 'https://example.org/a32.apk',
        'sha256': 'zz',
      };
      final m = await UpdateChecker(
        _StubFetcher(() async => _json(bad)),
        _url,
        '1.0.0',
        supportedAbis: ['armeabi-v7a'],
      ).check();
      expect(m, isNull);
    });
  });
}
