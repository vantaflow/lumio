/// Qualité vidéo déduite du nom ou de la description d'un flux.
enum Quality { unknown, sd, hd720, hd1080, uhd2160 }

/// Flux normalisé : lien direct (http/https) et/ou torrent (infoHash).
class StreamItem {
  const StreamItem({
    required this.addonId,
    required this.title,
    this.url,
    this.infoHash,
    this.fileIdx,
    this.quality = Quality.unknown,
    this.language,
    this.sizeBytes,
    this.seeders,
    this.requestHeaders = const {},
    this.notWebReady = false,
  });

  final String addonId;
  final String title;
  final Uri? url;

  /// InfoHash en minuscules (40 caractères hexadécimaux).
  final String? infoHash;
  final int? fileIdx;
  final Quality quality;

  /// Code ISO 639-1 (`fr`, `en`…) ou `multi` ; `null` si inconnu.
  final String? language;
  final int? sizeBytes;
  final int? seeders;
  final Map<String, String> requestHeaders;
  final bool notWebReady;

  /// Vrai quand le flux n'a pas de lien direct et passe par un torrent.
  bool get isTorrent => url == null;

  /// Identité stable pour dédoublonner : infoHash+fileIdx, ou URL sans requête
  /// + taille.
  String get signature {
    final u = url;
    if (u == null) return '${infoHash ?? ''}:${fileIdx ?? ''}';
    final port = u.hasPort ? ':${u.port}' : '';
    final clean = '${u.scheme}://${u.host}$port${u.path}';
    return '$clean|${sizeBytes ?? ''}';
  }
}

/// Résultat d'un addon : flux normalisés, ou [error] si l'addon a échoué.
class StreamGroup {
  const StreamGroup({required this.addonId, this.items = const [], this.error});

  final String addonId;
  final List<StreamItem> items;
  final Object? error;
}
