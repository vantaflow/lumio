/// Aperçu d'un média dans un catalogue.
class MetaPreview {
  const MetaPreview({
    required this.id,
    required this.type,
    required this.name,
    required this.sourceAddonId,
    this.poster,
    this.releaseInfo,
    this.certification,
    this.sourceKind = 'addon',
  });

  final String id;
  final String type;
  final String name;
  final Uri? poster;
  final String? releaseInfo;
  final String? certification;
  final String sourceAddonId;

  /// `addon`, `iptv`, `local` ou `jellyfin`.
  final String sourceKind;

  /// Lit une entrée de catalogue ; `null` si elle est inexploitable (sans id).
  static MetaPreview? tryParse(
    Object? json, {
    required String sourceAddonId,
    required String fallbackType,
    String sourceKind = 'addon',
  }) {
    if (json is! Map) return null;
    final id = _str(json['id']);
    if (id == null) return null;
    return MetaPreview(
      id: id,
      type: _str(json['type']) ?? fallbackType,
      name: _str(json['name']) ?? id,
      poster: _httpUri(json['poster']),
      releaseInfo: _str(json['releaseInfo']),
      certification: _str(json['certification']),
      sourceAddonId: sourceAddonId,
      sourceKind: sourceKind,
    );
  }
}

String? _str(Object? v) {
  if (v is String) return v.isEmpty ? null : v;
  if (v is num) return v.toString();
  return null;
}

Uri? _httpUri(Object? v) {
  if (v is! String) return null;
  final u = Uri.tryParse(v);
  if (u == null || (u.scheme != 'http' && u.scheme != 'https')) return null;
  return u;
}
