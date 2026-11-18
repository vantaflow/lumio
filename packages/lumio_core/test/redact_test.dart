import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

void main() {
  group('redactUrl', () {
    test('garde schéma et hôte, masque chemin et requête', () {
      expect(
        redactUrl('https://a.b/KEY123/manifest.json?x=1'),
        'https://a.b/***',
      );
    });

    test('conserve le port', () {
      expect(redactUrl('http://a.b:7000/SECRET'), 'http://a.b:7000/***');
    });

    test('masque les informations utilisateur', () {
      expect(redactUrl('https://user:pw@a.b/x'), 'https://a.b/***');
    });

    test('texte qui n\'est pas une URL', () {
      expect(redactUrl('pas une url'), '***');
    });

    test('chaîne vide', () {
      expect(redactUrl(''), '***');
    });
  });
}
