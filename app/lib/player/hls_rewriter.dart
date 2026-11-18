/// Réécriture des playlists HLS pour que chaque ressource repasse par le
/// proxy local (Dart pur, sans dépendance Flutter).
library;

final _uriAttr = RegExp(r'URI="([^"]*)"');

/// Réécrit [body] (playlist `.m3u8` située à [playlistUrl]) : chaque ligne de
/// ressource (segment, playlist de variante) et chaque attribut `URI="…"`
/// (`#EXT-X-KEY`, `#EXT-X-MAP`, `#EXT-X-MEDIA`…) est résolu contre
/// [playlistUrl] puis remplacé par `wrap(url)`.
///
/// Les lignes de commentaire sans `URI`, les lignes vides, les `URI="data:…"`
/// et les fins de ligne (`\n` ou `\r\n`) sont conservés tels quels.
String rewriteM3u8(String body, Uri playlistUrl, Uri Function(Uri) wrap) {
  String resolve(String ref) {
    final Uri target;
    try {
      target = playlistUrl.resolve(ref);
    } on FormatException {
      return ref;
    }
    if (target.scheme != 'http' && target.scheme != 'https') return ref;
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
          if (ref.isEmpty || ref.toLowerCase().startsWith('data:')) {
            return m.group(0)!;
          }
          return 'URI="${resolve(ref)}"';
        }),
      );
    } else {
      out.write(resolve(trimmed));
    }
    out.write(cr);
    if (hasNewline) out.write('\n');
    start = end + 1;
  }
  return out.toString();
}
