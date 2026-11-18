import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

void main() {
  const pass = 'correct horse battery staple';
  const plain = '[{"url":"https://a.example/k3y/manifest.json","logo":null}]';

  test('PBKDF2-HMAC-SHA256 : vecteurs RFC 7914', () async {
    String hex(List<int> b) =>
        b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    expect(
      hex(
        await SecretBox.pbkdf2(utf8.encode('passwd'), utf8.encode('salt'), 1),
      ),
      '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc',
    );
    expect(
      hex(
        await SecretBox.pbkdf2(
          utf8.encode('Password'),
          utf8.encode('NaCl'),
          80000,
        ),
      ),
      '4ddcd8f60b98be21830cee5ef22701f9641a4418d04c0414aeff08876b34ab56',
    );
    // Cohérence avec une implémentation de référence (package crypto).
    final hmac = Hmac(sha256, utf8.encode('p'));
    expect(
      await SecretBox.pbkdf2(utf8.encode('p'), [1, 2, 3], 1),
      hmac.convert([1, 2, 3, 0, 0, 0, 1]).bytes,
    );
  });

  test('aller-retour, format v1 à quatre parties', () async {
    final sealed = await SecretBox.seal(plain, pass);
    final parts = sealed.split('.');
    expect(parts.length, 4);
    expect(parts[0], 'v1');
    expect(base64Url.decode(base64Url.normalize(parts[1])).length, 16);
    expect(base64Url.decode(base64Url.normalize(parts[2])).length, 12);
    expect(sealed.contains(plain), isFalse);
    expect(sealed.contains('a.example'), isFalse);
    expect(await SecretBox.open(sealed, pass), plain);
  });

  test('texte accentué et vide', () async {
    expect(
      await SecretBox.open(await SecretBox.seal('é à 日本', pass), pass),
      'é à 日本',
    );
    expect(await SecretBox.open(await SecretBox.seal('', pass), pass), '');
  });

  test('mauvaise phrase secrète : WrongPassphraseException', () async {
    final sealed = await SecretBox.seal(plain, pass);
    await expectLater(
      SecretBox.open(sealed, 'correct horse battery stapl3'),
      throwsA(isA<WrongPassphraseException>()),
    );
    await expectLater(
      SecretBox.open(sealed, ''),
      throwsA(isA<WrongPassphraseException>()),
    );
  });

  test('deux seal du même texte diffèrent (sel et nonce aléatoires)', () async {
    final a = await SecretBox.seal(plain, pass);
    final b = await SecretBox.seal(plain, pass);
    expect(a, isNot(b));
    expect(a.split('.')[1], isNot(b.split('.')[1]));
    expect(a.split('.')[2], isNot(b.split('.')[2]));
  });

  test(
    'tout caractère modifié fait échouer l\'ouverture',
    () async {
      final sealed = await SecretBox.seal('abc', pass);
      const alphabet =
          'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
      // Les 4 parties : la version, le sel, le nonce, le texte chiffré + tag.
      // Un seul échantillon par position suffit ; les quatre derniers bits
      // « inutilisés » d'un base64 non canonique sont aussi refusés.
      final futures = <Future<void>>[];
      for (var i = 0; i < sealed.length; i++) {
        if (sealed[i] == '.') continue;
        final repl = alphabet[(alphabet.indexOf(sealed[i]) + 1) % 64];
        final bad = sealed.replaceRange(i, i + 1, repl);
        futures.add(
          expectLater(
            SecretBox.open(bad, pass),
            throwsA(isA<WrongPassphraseException>()),
            reason: 'position $i',
          ),
        );
      }
      await Future.wait(futures);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'entrées malformées : WrongPassphraseException, jamais autre chose',
    () async {
      final sealed = await SecretBox.seal('abc', pass);
      final p = sealed.split('.');
      for (final bad in [
        '',
        'v1',
        'v1.a.b',
        'v2.${p[1]}.${p[2]}.${p[3]}',
        '$sealed.x',
        'v1.${p[1]}.${p[2]}.',
        'v1.@@@.${p[2]}.${p[3]}',
        'v1.${p[1]}.${p[2]}.${p[3]}=',
        'v1.${p[1]}.AA.${p[3]}',
      ]) {
        await expectLater(
          SecretBox.open(bad, pass),
          throwsA(isA<WrongPassphraseException>()),
          reason: bad,
        );
      }
    },
  );

  test('AAD : un blob d\'un autre type ne s\'ouvre pas sous addons', () async {
    final other = await SecretBox.seal(plain, pass, aad: 'settings');
    await expectLater(
      SecretBox.open(other, pass),
      throwsA(isA<WrongPassphraseException>()),
    );
    expect(await SecretBox.open(other, pass, aad: 'settings'), plain);
    // Et inversement.
    final mine = await SecretBox.seal(plain, pass);
    await expectLater(
      SecretBox.open(mine, pass, aad: 'settings'),
      throwsA(isA<WrongPassphraseException>()),
    );
  });
}
