/// Cause d'une [AddonException].
enum AddonErrorCode {
  duplicate,
  privateAddress,
  invalidAddress,
  addressRefused,
  timeout,
  unreachable,
  tlsFailed,
  notFound,
  serverError,
  refused,
  tooLarge,
  invalidJson,
  redirect,
  manifestInvalid,
  unexpected,
  other,
}

/// Erreur de lecture ou de récupération d'un addon (message lisible en
/// français, sans URL ni jeton).
class AddonException implements Exception {
  const AddonException(
    this.message, {
    this.cause,
    this.code = AddonErrorCode.other,
    this.status,
  });
  final String message;
  final Object? cause;

  /// Cause machine, pour traduire le message côté interface (le texte
  /// français de [message] reste destiné aux journaux).
  final AddonErrorCode code;

  /// Statut HTTP pour [AddonErrorCode.serverError] / [AddonErrorCode.refused].
  final int? status;

  @override
  String toString() => message;
}

/// Manifeste absent, injoignable ou invalide.
class ManifestException extends AddonException {
  const ManifestException(
    super.message, {
    super.cause,
    super.code = AddonErrorCode.manifestInvalid,
    super.status,
  });
}

class AddonResource {
  const AddonResource(this.name, {this.types, this.idPrefixes});
  final String name;
  final List<String>? types;
  final List<String>? idPrefixes;
}

class ExtraDecl {
  const ExtraDecl(this.name, {this.isRequired = false, this.options});
  final String name;
  final bool isRequired;
  final List<String>? options;
}

class CatalogDecl {
  const CatalogDecl({
    required this.type,
    required this.id,
    required this.name,
    this.extra = const [],
  });
  final String type;
  final String id;
  final String name;
  final List<ExtraDecl> extra;
}

class AddonManifest {
  const AddonManifest({
    required this.id,
    required this.version,
    required this.name,
    required this.types,
    required this.resources,
    required this.catalogs,
    required this.transportUrl,
    this.description,
    this.logo,
    this.idPrefixes,
    this.warnings = const [],
  });

  final String id;
  final String version;
  final String name;
  final String? description;
  final Uri? logo;
  final List<String> types;
  final List<AddonResource> resources;
  final List<CatalogDecl> catalogs;
  final List<String>? idPrefixes;
  final Uri transportUrl;

  /// Anomalies tolérées (version non semver, catalogue ignoré…).
  final List<String> warnings;

  /// Racine des ressources : l'URL du manifeste sans `manifest.json`, sans
  /// barre finale, requête ni fragment.
  Uri get baseUrl {
    var path = transportUrl.path;
    if (path.endsWith('manifest.json')) {
      path = path.substring(0, path.length - 'manifest.json'.length);
    }
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return Uri(
      scheme: transportUrl.scheme,
      userInfo: transportUrl.userInfo,
      host: transportUrl.host,
      port: transportUrl.hasPort ? transportUrl.port : null,
      path: path,
    );
  }

  /// Vrai si l'addon déclare [resource] pour [type] et l'identifiant [id].
  bool supports(String resource, String type, String id) {
    for (final r in resources) {
      if (r.name != resource) continue;
      final types = r.types ?? this.types;
      if (!types.contains(type)) continue;
      // Pour un catalogue, `id` est un id de catalogue : pas de préfixe.
      final prefixes = resource == 'catalog'
          ? null
          : r.idPrefixes ?? idPrefixes;
      if (prefixes == null || prefixes.any(id.startsWith)) return true;
    }
    return false;
  }

  /// Valide et construit un manifeste depuis du JSON décodé.
  ///
  /// Lève [ManifestException] (« Manifeste invalide : … »).
  factory AddonManifest.fromJson(Object? json, Uri transportUrl) {
    if (json is! Map) {
      throw const ManifestException(
        'Manifeste invalide : un objet JSON est attendu',
      );
    }
    final warnings = <String>[];
    final id = _requiredString(json, 'id');
    final version = _requiredString(json, 'version');
    final name = _requiredString(json, 'name');

    if (!_semver.hasMatch(version)) {
      warnings.add('version non semver : $version');
    }

    final types = _requiredStringList(json, 'types');
    final rawResources = json['resources'];
    if (rawResources == null) _missing('resources');
    if (rawResources is! List) {
      throw const ManifestException(
        'Manifeste invalide : champ resources doit être une liste',
      );
    }
    final resources = <AddonResource>[];
    for (final r in rawResources) {
      if (r is String && r.isNotEmpty) {
        resources.add(AddonResource(r));
      } else if (r is Map && r['name'] is String) {
        resources.add(
          AddonResource(
            r['name'] as String,
            types: _optStringList(r['types']),
            idPrefixes: _optStringList(r['idPrefixes']),
          ),
        );
      } else {
        throw const ManifestException(
          'Manifeste invalide : entrée de resources illisible',
        );
      }
    }

    final catalogs = <CatalogDecl>[];
    final rawCatalogs = json['catalogs'];
    if (rawCatalogs != null && rawCatalogs is! List) {
      throw const ManifestException(
        'Manifeste invalide : champ catalogs doit être une liste',
      );
    }
    for (final c in (rawCatalogs as List?) ?? const []) {
      if (c is! Map) {
        warnings.add('catalogue ignoré : entrée illisible');
        continue;
      }
      final type = c['type'];
      final cid = c['id'];
      if (type is! String || type.isEmpty || cid is! String || cid.isEmpty) {
        warnings.add('catalogue ignoré : type ou id manquant');
        continue;
      }
      final cname = c['name'];
      catalogs.add(
        CatalogDecl(
          type: type,
          id: cid,
          name: cname is String && cname.isNotEmpty ? cname : cid,
          extra: _extras(c['extra']),
        ),
      );
    }

    final description = json['description'];
    final logo = json['logo'];
    Uri? logoUri;
    if (logo is String) {
      final u = Uri.tryParse(logo);
      if (u != null && (u.scheme == 'http' || u.scheme == 'https')) {
        logoUri = u;
      }
    }

    return AddonManifest(
      id: id,
      version: version,
      name: name,
      description: description is String && description.isNotEmpty
          ? description
          : null,
      logo: logoUri,
      types: types,
      resources: resources,
      catalogs: catalogs,
      idPrefixes: _optStringList(json['idPrefixes']),
      transportUrl: transportUrl,
      warnings: warnings,
    );
  }

  static final _semver = RegExp(r'^\d+\.\d+\.\d+([-+][0-9A-Za-z.\-+]*)?$');

  static Never _missing(String field) =>
      throw ManifestException('Manifeste invalide : champ $field manquant');

  static String _requiredString(Map json, String field) {
    final v = json[field];
    if (v == null) _missing(field);
    if (v is! String || v.trim().isEmpty) {
      throw ManifestException(
        'Manifeste invalide : champ $field doit être un texte non vide',
      );
    }
    return v;
  }

  static List<String> _requiredStringList(Map json, String field) {
    final v = json[field];
    if (v == null) _missing(field);
    if (v is! List || v.any((e) => e is! String)) {
      throw ManifestException(
        'Manifeste invalide : champ $field doit être une liste de textes',
      );
    }
    return List<String>.from(v);
  }

  static List<String>? _optStringList(Object? v) =>
      v is List ? v.whereType<String>().toList() : null;

  static List<ExtraDecl> _extras(Object? v) {
    if (v is! List) return const [];
    return [
      for (final e in v)
        if (e is Map && e['name'] is String)
          ExtraDecl(
            e['name'] as String,
            isRequired: e['isRequired'] == true,
            options: _optStringList(e['options']),
          ),
    ];
  }
}
