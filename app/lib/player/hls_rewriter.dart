/// Réécriture des playlists HLS pour que chaque ressource repasse par le
/// proxy local (Dart pur, sans dépendance Flutter).
library;

final _uriAttr = RegExp(r'(?<![A-Za-z-])URI="([^"]*)"');

/// Cible sans effet (le proxy répond 404) qui remplace tout `URI=` interdit.
final blockedPlaylistTarget = Uri.parse('blocked:');

/// Réécrit [body] (playlist `.m3u8` située à [playlistUrl]) : chaque ligne de
/// ressource (segment, playlist de variante) et chaque attribut `URI="…"`
/// (`#EXT-X-KEY`, `#EXT-X-MAP`, `#EXT-X-MEDIA`…) est résolu contre
/// [playlistUrl] puis remplacé par `wrap(url)`.
///
/// Les ressources dont le schéma n'est pas http(s) (`file:`, `concat:`,
/// `rtmp:`, `data:`…) ne sont jamais transmises au lecteur : une ligne de
/// segment est supprimée, un attribut `URI=` pointe vers [blockedPlaylistTarget]
/// via le proxy (404).
///
/// Les lignes de commentaire sans `URI`, les lignes vides et les fins de ligne
/// (`\n` ou `\r\n`) sont conservés tels quels. Un `URI="data:…"` n'est pas
/// conservé : son schéma n'est pas http(s), il est donc bloqué comme les autres.
String rewriteM3u8(String body, Uri playlistUrl, Uri Function(Uri) wrap) {
  String? resolve(String ref) {
    final Uri target;
    try {
      target = playlistUrl.resolve(ref);
    } on FormatException {
      return null;
    }
    if (target.scheme != 'http' && target.scheme != 'https') return null;
    return wrap(target).toString();
  }

  final out = StringBuffer();
  var start = 0;
  while (start < body.length) {
    var end = body.indexOf('\n', start);
    final hasNewline = end != -1;
    if (!hasNewline) end = body.length;
    var line = body.substring(start, end);
    var cr = '';
    if (line.endsWith('\r')) {
      cr = '\r';
      line = line.substring(0, line.length - 1);
    }
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      out.write(line);
    } else if (trimmed.startsWith('#')) {
      out.write(
        line.replaceAllMapped(_uriAttr, (m) {
          final ref = m.group(1)!;
          if (ref.isEmpty) return m.group(0)!;
          final r = resolve(ref) ?? wrap(blockedPlaylistTarget).toString();
          return 'URI="$r"';
        }),
      );
    } else {
      final r = resolve(trimmed);
      if (r == null) {
        // Ligne de segment interdite : supprimée avec sa fin de ligne.
        start = end + 1;
        continue;
      }
      out.write(r);
    }
    out.write(cr);
    if (hasNewline) out.write('\n');
    start = end + 1;
  }
  return out.toString();
}
