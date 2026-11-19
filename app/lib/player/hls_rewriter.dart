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

final _attrRe = RegExp(r'([A-Z0-9-]+)=("[^"]*"|[^,]*)');

Map<String, String> _attrs(String line) {
  final i = line.indexOf(':');
  final out = <String, String>{};
  for (final m in _attrRe.allMatches(i < 0 ? line : line.substring(i + 1))) {
    var v = m.group(2)!;
    if (v.startsWith('"') && v.endsWith('"') && v.length >= 2) {
      v = v.substring(1, v.length - 1);
    }
    out[m.group(1)!] = v;
  }
  return out;
}

/// Allège une playlist maître qui propose beaucoup de variantes.
///
/// ffmpeg ouvre TOUTES les variantes au démarrage (une playlist et le premier
/// segment de chacune) : le maître HEVC d'exemple d'Apple en compte 28 et la
/// lecture ne démarrait jamais sur la box (délai dépassé). libmpv ne change
/// pas de qualité en cours de lecture : une seule variante suffit. On garde au
/// plus [maxVariants] variantes (par défaut la meilleure jusqu'à [maxHeight]
/// px ; avec 3 : aussi une intermédiaire proche de 720 p et la plus légère),
/// jamais de Dolby Vision
/// (non décodable), sans les playlists d'images clés, et on ne conserve que les
/// groupes audio, sous-titres et légendes qu'elles référencent. Une playlist
/// qui n'est pas un maître, ou qui a déjà peu de variantes, est rendue telle
/// quelle.
String pruneHlsMaster(
  String body, {
  int maxVariants = 1,
  int maxHeight = 1080,
}) {
  final lines = body.split('\n');
  final variants = <({int at, Map<String, String> a, int bw, int h})>[];
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].startsWith('#EXT-X-STREAM-INF:')) {
      final a = _attrs(lines[i]);
      final res = RegExp(r'\d+x(\d+)').firstMatch(a['RESOLUTION'] ?? '');
      variants.add((
        at: i,
        a: a,
        bw: int.tryParse(a['BANDWIDTH'] ?? '') ?? 0,
        h: res == null ? 0 : int.parse(res.group(1)!),
      ));
    }
  }
  if (variants.length <= maxVariants) return body;

  bool dolby(Map<String, String> a) => RegExp(
    r'dv(h1|he|av1)',
    caseSensitive: false,
  ).hasMatch(a['CODECS'] ?? '');
  var pool = variants.where((v) => !dolby(v.a)).toList();
  if (pool.isEmpty) pool = [...variants];
  final fit = pool.where((v) => v.h == 0 || v.h <= maxHeight).toList();
  if (fit.isNotEmpty) pool = fit;
  pool.sort((x, y) => y.bw.compareTo(x.bw));
  final keep = <({int at, Map<String, String> a, int bw, int h})>[pool.first];
  if (maxVariants >= 2) {
    final rest = pool.skip(1).toList();
    if (rest.isNotEmpty) {
      final lowest = rest.last;
      if (maxVariants >= 3 && rest.length > 1) {
        final mids = rest.take(rest.length - 1).toList()
          ..sort((x, y) => (x.h - 720).abs().compareTo((y.h - 720).abs()));
        keep.add(mids.first);
      }
      keep.add(lowest);
    }
  }
  final keptAt = {for (final v in keep) v.at};
  final groups = <String>{
    for (final v in keep) ...[
      for (final k in const ['AUDIO', 'SUBTITLES', 'CLOSED-CAPTIONS'])
        if (v.a[k] != null) '$k:${v.a[k]}',
    ],
  };

  final out = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (l.startsWith('#EXT-X-STREAM-INF:')) {
      final next = i + 1 < lines.length ? lines[i + 1] : '';
      if (keptAt.contains(i)) {
        out
          ..add(l)
          ..add(next);
      }
      i++; // la ligne d'adresse de la variante suit toujours son en-tête
      continue;
    }
    if (l.startsWith('#EXT-X-I-FRAME-STREAM-INF:')) continue;
    if (l.startsWith('#EXT-X-MEDIA:')) {
      final a = _attrs(l);
      if (!groups.contains('${a['TYPE']}:${a['GROUP-ID']}')) continue;
    }
    out.add(l);
  }
  return out.join('\n');
}
