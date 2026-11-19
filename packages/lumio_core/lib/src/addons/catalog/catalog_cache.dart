import 'dart:convert';
import 'dart:io';

/// Valeur en cache : texte JSON et date d'enregistrement.
class CachedCatalogEntry {
  const CachedCatalogEntry(this.data, this.at);
  final String data;
  final DateTime at;
}

/// Stockage local du catalogue (clé → JSON daté).
abstract class CatalogCacheStore {
  Future<CachedCatalogEntry?> read(String key);
  Future<void> write(String key, String data, DateTime at);
}

/// Cache mémoire (tests).
class MemoryCatalogCacheStore implements CatalogCacheStore {
  final Map<String, CachedCatalogEntry> entries = {};

  @override
  Future<CachedCatalogEntry?> read(String key) async => entries[key];

  @override
  Future<void> write(String key, String data, DateTime at) async =>
      entries[key] = CachedCatalogEntry(data, at);
}

/// Cache en fichiers (un JSON par clé) dans [dir].
class FileCatalogCacheStore implements CatalogCacheStore {
  FileCatalogCacheStore(this.dir);
  final Directory dir;

  File _file(String key) => File(
    '${dir.path}${Platform.pathSeparator}'
    '${base64Url.encode(utf8.encode(key)).replaceAll('=', '')}.json',
  );

  @override
  Future<CachedCatalogEntry?> read(String key) async {
    try {
      final f = _file(key);
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString());
      if (j is! Map || j['data'] is! String) return null;
      final at = DateTime.tryParse('${j['at']}');
      if (at == null) return null;
      return CachedCatalogEntry(j['data'] as String, at);
    } catch (_) {
      // Fichier corrompu : comme s'il n'existait pas.
      return null;
    }
  }

  @override
  Future<void> write(String key, String data, DateTime at) async {
    try {
      await dir.create(recursive: true);
      final f = _file(key);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(
        jsonEncode({'at': at.toUtc().toIso8601String(), 'data': data}),
        flush: true,
      );
      await tmp.rename(f.path);
    } catch (_) {
      // Le cache est facultatif : une écriture ratée n'est pas une erreur.
    }
  }
}
