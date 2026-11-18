/// Épisode (ou entrée de liste de lecture) d'une fiche.
class Video {
  const Video({
    required this.id,
    required this.title,
    this.season,
    this.episode,
    this.released,
  });

  /// Identifiant de flux, ex. `tt123:1:2` (forme conservée telle quelle).
  final String id;
  final String title;
  final int? season;
  final int? episode;

  /// Date de sortie en UTC ; `null` si absente ou illisible.
  final DateTime? released;

  /// Lit une entrée `videos` ; `null` si elle est inexploitable (sans id).
  static Video? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = metaText(json['id']);
    if (id == null) return null;
    final season = _int(json['season']);
    final episode = _int(json['episode'] ?? json['number']);
    final title =
        metaText(json['title']) ??
        metaText(json['name']) ??
        (episode != null ? 'Épisode $episode' : id);
    final r = json['released'];
    final released = r is String ? parseUtc(r) : null;
    return Video(
      id: id,
      title: title,
      season: season,
      episode: episode,
      released: released,
    );
  }
}

/// Fiche détaillée d'un média, fusionnée depuis plusieurs addons.
class Meta {
  const Meta({
    required this.id,
    required this.type,
    required this.name,
    this.description,
    this.releaseInfo,
    this.certification,
    this.poster,
    this.background,
    this.genres = const [],
    this.videos = const [],
  });

  final String id;
  final String type;
  final String name;
  final String? description;
  final String? releaseInfo;
  final String? certification;
  final Uri? poster;
  final Uri? background;
  final List<String> genres;
  final List<Video> videos;
}

/// Texte non vide (les nombres sont convertis) ; `null` sinon.
String? metaText(Object? v) {
  if (v is String) return v.trim().isEmpty ? null : v;
  if (v is num) return v.toString();
  return null;
}

/// Date en UTC ; sans fuseau explicite (`2020-05-01`), la valeur est lue comme
/// UTC et non comme heure locale. `null` si illisible.
DateTime? parseUtc(String s) {
  final t = s.trim();
  final hasZone = RegExp(
    r'(Z|[+-]\d{2}(:?\d{2})?)$',
    caseSensitive: false,
  ).hasMatch(t.contains('T') || t.contains(' ') ? t : '');
  return DateTime.tryParse(hasZone ? t : '${t}Z')?.toUtc();
}

int? _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}
