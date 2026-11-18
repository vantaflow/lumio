import 'dart:convert';
import 'dart:io';

import 'package:lumio_core/testing.dart';
import 'package:test/test.dart';

void main() {
  final dir = Directory('test/fixtures/manifests');
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList();
  final readme = File('test/fixtures/manifests/README.md').readAsStringSync();

  test('corpus : au moins 11 fichiers committés (+ le cas 6 Mo généré)', () {
    expect(files.length, greaterThanOrEqualTo(11));
  });

  test('chaque fichier est documenté dans le README', () {
    for (final f in files) {
      final name = f.uri.pathSegments.last;
      expect(readme, contains('`$name`'), reason: name);
    }
    expect(readme, contains('too_large'));
    expect(readme, contains('6 Mo'));
  });

  test('fichiers « JSON valide » décodent, « malformés » non', () {
    for (final name in ['valid_minimal.json', 'valid_full.json']) {
      expect(() => jsonDecode(File('${dir.path}/$name').readAsStringSync()),
          returnsNormally);
    }
    for (final name in ['truncated.json', 'html_instead_of_json.json']) {
      expect(() => jsonDecode(File('${dir.path}/$name').readAsStringSync()),
          throwsFormatException,
          reason: name);
    }
  });

  test('cas 6 Mo généré à la volée dépasse 5 Mo', () {
    final bytes = buildOversizedManifest();
    expect(bytes.length, greaterThan(5 * 1024 * 1024));
    expect(bytes.length, lessThan(7 * 1024 * 1024));
    expect(() => jsonDecode(utf8.decode(bytes)), returnsNormally);
  });
}
