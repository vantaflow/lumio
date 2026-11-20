import 'dart:convert' show utf8;

import 'package:crypto/crypto.dart' show sha256;

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
    this.trackers = const [],
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

  /// Trackers issus de `sources` (`tracker:<url>`) ; `dht:` ignoré.
  final List<String> trackers;

  /// Vrai quand le flux n'a pas de lien direct et passe par un torrent.
  bool get isTorrent => url == null;

  /// Identité stable pour dédoublonner : infoHash+fileIdx, ou URL (requête
  /// conservée sans les clés volatiles : jeton, expiration, signature) + taille.
  String get signature {
    final u = url;
    if (u == null) return '${infoHash ?? ''}:${fileIdx ?? ''}';
    final port = u.hasPort ? ':${u.port}' : '';
    final clean = '${u.scheme}://${u.host}$port${u.path}';
    final pairs = <String>[
      for (final e in u.queryParametersAll.entries)
        if (!_volatileKeys.contains(e.key.toLowerCase()))
          for (final v in e.value) '${e.key}=$v',
    ]..sort();
    final q = pairs.isEmpty ? '' : '?${pairs.join('&')}';
    return '$clean$q|${sizeBytes ?? ''}';
  }

  /// Identité non sensible du flux, à mémoriser pour le reprendre : torrent
  /// `t:<infoHash>:<fileIdx>`, lien direct `u:<SHA-256 de [signature]>`. Ne
  /// contient jamais l'URL (qui peut porter la clé d'un addon).
  String get identityKey => isTorrent
      ? 't:${infoHash ?? ''}:${fileIdx ?? ''}'
      : 'u:${sha256.convert(utf8.encode(signature))}';

  static const _volatileKeys = {
    'token',
    'apikey',
    'api_key',
    'key',
    'expires',
    'exp',
    'sig',
    'signature',
    't',
    'ts',
  };
}

/// Résultat d'un addon : flux normalisés, ou [error] si l'addon a échoué.
class StreamGroup {
  const StreamGroup({required this.addonId, this.items = const [], this.error});

  final String addonId;
  final List<StreamItem> items;
  final Object? error;
}
