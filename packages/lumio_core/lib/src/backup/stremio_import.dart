import '../addons/meta_preview.dart';
import 'backup.dart';

/// Ce qu'on a pu lire d'un export JSON d'un autre client compatible.
///
/// [skipped] contient des libellés lisibles (nom ou rang), jamais d'adresse :
/// les adresses d'addons sont secrètes.
class StremioImportResult {
  const StremioImportResult({
    this.addonUrls = const [],
    this.library = const [],
    this.skipped = const [],
  });

  final List<Uri> addonUrls;
  final List<MetaPreview> library;
  final List<String> skipped;
}

const _maxEntries = 5000;
const _maxLabel = 80;

String _label(Object? name, int index) {
  if (name is String) {
    final t = name.trim();
    if (t.isNotEmpty) {
      return t.length > _maxLabel ? t.substring(0, _maxLabel) : t;
    }
  }
  return '#${index + 1}';
}

/// Liste d'éléments d'une réponse `{result: …}` ou d'un tableau nu.
List<Object?> _entries(Object json, {String? key}) {
  Object? v = json;
  if (v is Map && v.containsKey('result')) v = v['result'];
  if (key != null && v is Map && v.containsKey(key)) v = v[key];
  if (v is! List) {
    throw const BackupFormatException(BackupFormatError.malformed);
  }
  return v.length > _maxEntries ? v.sublist(0, _maxEntries) : v;
}

/// Lit une collection d'addons (`addonCollectionGet` : `{result:{addons:[…]}}`
/// ou tableau nu de `{transportUrl, manifest, flags}`). Les addons natifs
/// (`flags.official` ou `flags.protected`), sans adresse http(s) valide ou en
/// double sont ignorés.
StremioImportResult parseStremioAddonCollection(Object json) {
  final list = _entries(json, key: 'addons');
  final urls = <Uri>[];
  final seen = <String>{};
  final skipped = <String>[];
  for (final (i, e) in list.indexed) {
    if (e is! Map) {
      skipped.add(_label(null, i));
      continue;
    }
    final manifest = e['manifest'];
    final name = manifest is Map ? (manifest['name'] ?? manifest['id']) : null;
    final flags = e['flags'];
    if (flags is Map &&
        (flags['official'] == true || flags['protected'] == true)) {
      skipped.add(_label(name, i));
      continue;
    }
    final raw = e['transportUrl'];
    final uri = raw is String && raw.length <= 2048
        ? Uri.tryParse(raw.trim())
        : null;
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !seen.add(uri.toString())) {
      skipped.add(_label(name, i));
      continue;
    }
    urls.add(uri);
  }
  return StremioImportResult(addonUrls: urls, skipped: skipped);
}

/// Lit une bibliothèque (`datastoreGet` : `{result:[…]}` ou tableau nu
/// d'éléments `{_id, name, type, poster, removed, temp, state}`). Les éléments
/// retirés (`removed`) ou temporaires (`temp`) sont ignorés ; le reste passe
/// par la liste blanche de [Backup.cleanMeta].
StremioImportResult parseStremioLibrary(Object json) {
  final list = _entries(json);
  final out = <MetaPreview>[];
  final seen = <String>{};
  final skipped = <String>[];
  for (final (i, e) in list.indexed) {
    if (e is! Map) {
      skipped.add(_label(null, i));
      continue;
    }
    final id = e['_id'];
    final type = e['type'];
    if (e['removed'] == true ||
        e['temp'] == true ||
        id is! String ||
        id.isEmpty ||
        id.length > 200 ||
        type is! String ||
        type.isEmpty ||
        type.length > 64 ||
        !seen.add(id)) {
      skipped.add(_label(e['name'] ?? id, i));
      continue;
    }
    final year = e['year'] ?? e['releaseInfo'];
    final meta = Backup.cleanMeta({
      'id': id,
      'type': type,
      'name': e['name'],
      'poster': e['poster'],
      if (year is String || year is int) 'releaseInfo': year.toString(),
    }, withUrls: true);
    final poster = meta['poster'];
    out.add(
      MetaPreview(
        id: id,
        type: type,
        name: (meta['name'] as String?) ?? id,
        poster: poster is String ? Uri.tryParse(poster) : null,
        releaseInfo: meta['releaseInfo'] as String?,
        sourceAddonId: '',
      ),
    );
  }
  return StremioImportResult(library: out, skipped: skipped);
}
