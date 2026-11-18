import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

void main() {
  test('stremio:// devient https://', () {
    expect(
      parseInstallLink('stremio://exemple.org/a/manifest.json').toString(),
      'https://exemple.org/a/manifest.json',
    );
  });

  test('lumio://install?url= encodée', () {
    final u = parseInstallLink(
      'lumio://install?url=${Uri.encodeComponent('https://h.org/x/manifest.json')}',
    );
    expect(u.toString(), 'https://h.org/x/manifest.json');
  });

  test('lumio://install avec url stremio:// encodée', () {
    final u = parseInstallLink(
      'lumio://install?url=${Uri.encodeComponent('stremio://h.org/x/manifest.json')}',
    );
    expect(u.toString(), 'https://h.org/x/manifest.json');
  });

  test(
    'lumio : mauvais hôte, url absente, schéma interdit ou paramètre en trop',
    () {
      expect(
        parseInstallLink('lumio://autre?url=https://h.org/manifest.json'),
        isNull,
      );
      expect(parseInstallLink('lumio://install'), isNull);
      expect(
        parseInstallLink(
          'lumio://install?url=${Uri.encodeComponent('file:///etc/passwd')}',
        ),
        isNull,
      );
      expect(
        parseInstallLink(
          'lumio://install?url=${Uri.encodeComponent('lumio://install?url=x')}',
        ),
        isNull,
      );
      expect(
        parseInstallLink(
          'lumio://install?url=${Uri.encodeComponent('https://h.org/manifest.json')}&x=1',
        ),
        isNull,
      );
    },
  );

  test('http(s) brut', () {
    expect(
      parseInstallLink('HTTPS://Exemple.org:443/a/manifest.json').toString(),
      'https://exemple.org/a/manifest.json',
    );
    expect(
      parseInstallLink('http://192.168.1.5:7000/manifest.json').toString(),
      'http://192.168.1.5:7000/manifest.json',
    );
  });

  test('schémas dangereux refusés', () {
    for (final s in [
      'javascript:alert(1)',
      'file:///etc/passwd',
      'ftp://h.org/manifest.json',
      'data:text/plain,hi',
      '',
      '   ',
      'pas une url',
    ]) {
      expect(parseInstallLink(s), isNull, reason: s);
    }
  });

  test('texte avec URL entourée de mots', () {
    expect(
      parseInstallLink(
        'Voici mon addon : https://h.org/a/manifest.json, bon visionnage !',
      ).toString(),
      'https://h.org/a/manifest.json',
    );
    expect(
      parseInstallLink('regarde (stremio://h.org/b/manifest.json)').toString(),
      'https://h.org/b/manifest.json',
    );
  });

  test('URL sans manifest.json : normalisée', () {
    expect(
      parseInstallLink('https://h.org/a/').toString(),
      'https://h.org/a/manifest.json',
    );
  });

  test('taille maximale 2 048', () {
    final long = 'https://h.org/${'a' * 2100}/manifest.json';
    expect(parseInstallLink(long), isNull);
    final ok = 'https://h.org/${'a' * 1900}/manifest.json';
    expect(parseInstallLink(ok), isNotNull);
  });
}
