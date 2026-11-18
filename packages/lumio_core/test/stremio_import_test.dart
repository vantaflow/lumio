import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

void main() {
  group('parseStremioAddonCollection', () {
    test('trois addons dont un sans transportUrl : 2 adresses, 1 ignoré', () {
      final r = parseStremioAddonCollection({
        'result': {
          'addons': [
            {
              'transportUrl': 'https://a.example.com/tok/manifest.json',
              'manifest': {'id': 'a', 'name': 'Alpha'},
              'flags': <String, dynamic>{},
            },
            {
              'manifest': {'id': 'b', 'name': 'Bravo'},
            },
            {
              'transportUrl': 'http://192.168.1.20:7000/manifest.json',
              'manifest': {'id': 'c', 'name': 'Maison'},
            },
          ],
        },
      });
      expect(r.addonUrls, [
        Uri.parse('https://a.example.com/tok/manifest.json'),
        Uri.parse('http://192.168.1.20:7000/manifest.json'),
      ]);
      expect(r.skipped, ['Bravo']);
      expect(r.library, isEmpty);
    });

    test('tableau nu accepté ; addons natifs (official/protected) écartés', () {
      final r = parseStremioAddonCollection([
        {
          'transportUrl': 'https://v3-cinemeta.strem.io/manifest.json',
          'manifest': {'id': 'com.linvo.cinemeta', 'name': 'Cinemeta'},
          'flags': {'official': true, 'protected': true},
        },
        {
          'transportUrl': 'https://local.example/manifest.json',
          'manifest': {'id': 'local', 'name': 'Local'},
          'flags': {'protected': true},
        },
        {
          'transportUrl': 'https://x.example.com/manifest.json',
          'manifest': {'id': 'x', 'name': 'X'},
          'flags': {'official': false},
        },
      ]);
      expect(r.addonUrls, [Uri.parse('https://x.example.com/manifest.json')]);
      expect(r.skipped, ['Cinemeta', 'Local']);
    });

    test('adresses invalides, non http(s) ou en double ignorées', () {
      final r = parseStremioAddonCollection([
        {'transportUrl': 'ftp://a.example.com/manifest.json'},
        {'transportUrl': 'pas une url'},
        {'transportUrl': 42},
        'texte',
        {'transportUrl': 'https://a.example.com/manifest.json'},
        {'transportUrl': 'https://a.example.com/manifest.json'},
      ]);
      expect(r.addonUrls, hasLength(1));
      expect(r.skipped, hasLength(5));
    });

    test('un libellé ne contient jamais l\'adresse', () {
      final r = parseStremioAddonCollection([
        {'transportUrl': 'ftp://secret.example.com/tok-secret/manifest.json'},
      ]);
      expect(r.skipped.single, isNot(contains('secret')));
    });

    test('forme inconnue : refus lisible', () {
      expect(
        () => parseStremioAddonCollection('nope'),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        () => parseStremioAddonCollection({
          'result': {'x': 1},
        }),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });

  group('parseStremioLibrary', () {
    test('un élément removed est exclu, temp aussi', () {
      final r = parseStremioLibrary({
        'result': [
          {'_id': 'tt1', 'name': 'Élan', 'type': 'movie', 'removed': false},
          {'_id': 'tt2', 'name': 'Gone', 'type': 'movie', 'removed': true},
          {'_id': 'tt3', 'name': 'Tmp', 'type': 'series', 'temp': true},
          {
            '_id': 'tt4',
            'name': 'Série',
            'type': 'series',
            'poster': 'https://img.example.com/p.jpg',
            'state': {'timeWatched': 3},
          },
        ],
      });
      expect(r.library.map((m) => m.id), ['tt1', 'tt4']);
      expect(r.library[1].poster, Uri.parse('https://img.example.com/p.jpg'));
      expect(r.library[0].name, 'Élan');
      expect(r.skipped, ['Gone', 'Tmp']);
      expect(r.addonUrls, isEmpty);
    });

    test('tableau nu ; champs inconnus et poster dangereux écartés', () {
      final r = parseStremioLibrary([
        {
          '_id': 'tt9',
          'name': 'N',
          'type': 'movie',
          'poster': 'javascript:alert(1)',
          'secretField': 'x',
        },
        {'_id': '', 'name': 'sans id', 'type': 'movie'},
        {'name': 'sans id 2', 'type': 'movie'},
        {'_id': 'tt9', 'name': 'doublon', 'type': 'movie'},
      ]);
      expect(r.library, hasLength(1));
      expect(r.library.single.poster, isNull);
      expect(r.library.single.sourceKind, 'addon');
      expect(r.skipped, hasLength(3));
    });

    test('forme inconnue : refus lisible', () {
      expect(
        () => parseStremioLibrary(42),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });
}
