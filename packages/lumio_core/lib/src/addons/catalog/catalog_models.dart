/// Modèles du catalogue d'addons (source : stremio-addons.net, repli :
/// collection officielle). Aucun accès réseau ici.
library;

/// Page du site ou collection illisible : le format a changé (ou la réponse
/// n'est pas celle attendue). Déclenche le repli sur la collection officielle.
class CatalogParseException implements Exception {
  const CatalogParseException(this.reason);
  final String reason;

  @override
  String toString() => 'CatalogParseException: $reason';
}

/// Une URL http(s) avec hôte, sinon `null`.
Uri? safeHttpUri(Object? raw) {
  if (raw is! String || raw.isEmpty || raw.length > 2048) return null;
  final u = Uri.tryParse(raw.trim());
  if (u == null || (u.scheme != 'http' && u.scheme != 'https')) return null;
  if (u.host.isEmpty) return null;
  return u;
}

/// Instance d'un addon : une adresse de manifest (un même addon peut avoir
/// plusieurs hébergeurs).
class CatalogInstance {
  const CatalogInstance({
    required this.manifestUrl,
    this.configurable = false,
    this.configurationRequired = false,
    this.stars,
  });

  final Uri manifestUrl;
  final bool configurable;

  /// L'addon ne fonctionne pas sans réglage préalable (clé, langues…).
  final bool configurationRequired;
  final int? stars;

  /// Hôte affiché pour choisir entre plusieurs instances.
  String get domain => manifestUrl.host;

  /// Domaine et chemin court (sans `manifest.json`), pour distinguer deux
  /// instances du même hôte.
  String get label {
    var path = manifestUrl.path;
    if (path.endsWith('manifest.json')) {
      path = path.substring(0, path.length - 'manifest.json'.length);
    }
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path.length > 24) path = '${path.substring(0, 23)}…';
    return '$domain$path';
  }

  /// Page de configuration (convention du protocole : `…/configure` à la place
  /// de `…/manifest.json`), si l'addon est configurable.
  Uri? get configureUrl {
    if (!configurable && !configurationRequired) return null;
    final path = manifestUrl.path;
    if (!path.endsWith('/manifest.json')) return null;
    return Uri(
      scheme: manifestUrl.scheme,
      host: manifestUrl.host,
      port: manifestUrl.hasPort ? manifestUrl.port : null,
      path:
          '${path.substring(0, path.length - 'manifest.json'.length)}configure',
    );
  }

  Map<String, Object?> toJson() => {
    'url': manifestUrl.toString(),
    'configurable': configurable,
    'configurationRequired': configurationRequired,
    'stars': stars,
  };

  static CatalogInstance? fromJson(Object? j) {
    if (j is! Map) return null;
    final u = safeHttpUri(j['url']);
    if (u == null) return null;
    return CatalogInstance(
      manifestUrl: u,
      configurable: j['configurable'] == true,
      configurationRequired: j['configurationRequired'] == true,
      stars: j['stars'] is int ? j['stars'] as int : null,
    );
  }
}

/// Carte du catalogue (page de liste).
class CatalogEntry {
  const CatalogEntry({
    required this.slug,
    required this.name,
    this.description,
    this.logo,
    this.stars,
    this.version,
    this.types = const [],
    this.resources = const [],
    this.instances = const [],
  });

  final String slug;
  final String name;
  final String? description;
  final Uri? logo;

  /// Popularité (étoiles du site), si présente.
  final int? stars;
  final String? version;

  /// Types et ressources du manifest : connus seulement pour les entrées de la
  /// collection officielle (le site ne les met pas sur ses cartes).
  final List<String> types;
  final List<String> resources;

  /// Instances déjà connues (collection officielle) ; vide pour une carte du
  /// site : la fiche est alors téléchargée à la demande.
  final List<CatalogInstance> instances;

  Map<String, Object?> toJson() => {
    'slug': slug,
    'name': name,
    'description': description,
    'logo': logo?.toString(),
    'stars': stars,
    'version': version,
    'types': types,
    'resources': resources,
    'instances': [for (final i in instances) i.toJson()],
  };

  static CatalogEntry? fromJson(Object? j) {
    if (j is! Map || j['slug'] is! String || j['name'] is! String) return null;
    return CatalogEntry(
      slug: j['slug'] as String,
      name: j['name'] as String,
      description: j['description'] as String?,
      logo: safeHttpUri(j['logo']),
      stars: j['stars'] is int ? j['stars'] as int : null,
      version: j['version'] as String?,
      types: [for (final t in (j['types'] as List? ?? const [])) '$t'],
      resources: [for (final t in (j['resources'] as List? ?? const [])) '$t'],
      instances: [
        for (final i in (j['instances'] as List? ?? const []))
          ?CatalogInstance.fromJson(i),
      ],
    );
  }
}

/// Une page de résultats.
class CatalogPage {
  const CatalogPage({
    required this.entries,
    required this.total,
    this.page = 1,
    this.totalPages = 1,
  });

  final List<CatalogEntry> entries;
  final int total;
  final int page;
  final int totalPages;

  bool get hasMore => page < totalPages;

  Map<String, Object?> toJson() => {
    'entries': [for (final e in entries) e.toJson()],
    'total': total,
    'page': page,
    'totalPages': totalPages,
  };

  static CatalogPage fromJson(Map<String, Object?> j) => CatalogPage(
    entries: [
      for (final e in (j['entries'] as List? ?? const []))
        ?CatalogEntry.fromJson(e),
    ],
    total: j['total'] is int ? j['total'] as int : 0,
    page: j['page'] is int ? j['page'] as int : 1,
    totalPages: j['totalPages'] is int ? j['totalPages'] as int : 1,
  );
}

/// Fiche d'un addon : instances (adresses de manifest).
class CatalogDetail {
  const CatalogDetail({
    required this.slug,
    required this.name,
    required this.instances,
    this.description,
    this.logo,
  });

  final String slug;
  final String name;
  final String? description;
  final Uri? logo;
  final List<CatalogInstance> instances;

  /// Au moins une instance s'installe directement.
  bool get installable => instances.any((i) => !i.configurationRequired);

  Map<String, Object?> toJson() => {
    'slug': slug,
    'name': name,
    'description': description,
    'logo': logo?.toString(),
    'instances': [for (final i in instances) i.toJson()],
  };

  static CatalogDetail fromJson(Map<String, Object?> j) => CatalogDetail(
    slug: '${j['slug']}',
    name: '${j['name']}',
    description: j['description'] as String?,
    logo: safeHttpUri(j['logo']),
    instances: [
      for (final i in (j['instances'] as List? ?? const []))
        ?CatalogInstance.fromJson(i),
    ],
  );
}
