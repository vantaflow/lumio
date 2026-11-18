import 'dart:convert';

/// Manifeste syntaxiquement valide d'environ 6 Mo (au-delà du plafond de
/// 5 Mo), généré à la volée pour ne pas committer un gros fichier.
List<int> buildOversizedManifest() {
  final filler = 'a' * (6 * 1024 * 1024);
  return utf8.encode(jsonEncode({
    'id': 'dev.test.huge',
    'version': '1.0.0',
    'name': 'Huge',
    'resources': ['catalog'],
    'types': ['movie'],
    'catalogs': <Object>[],
    'description': filler,
  }));
}
