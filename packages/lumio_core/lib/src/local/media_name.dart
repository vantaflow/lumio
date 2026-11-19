/// Résultat de l'analyse du nom d'un fichier vidéo.
class ParsedName {
  const ParsedName(this.title, {this.year, this.season, this.episode});

  final String title;
  final int? year, season, episode;

  @override
  String toString() => 'ParsedName($title, $year, S$season E$episode)';
}

final _ext = RegExp(r'\.[A-Za-z0-9]{2,4}$');
final _brackets = RegExp(r'\[[^\]]*\]');
final _spaces = RegExp(r'\s+');
final _sxe = RegExp(
  r'(?<![A-Za-z0-9])S(\d{1,2})[ ._-]?E(\d{1,3})(?!\d)',
  caseSensitive: false,
);
final _nxm = RegExp(
  r'(?<![A-Za-z0-9])(\d{1,2})x(\d{2,3})(?![A-Za-z0-9])',
  caseSensitive: false,
);
final _parenYear = RegExp(r'\(((?:19|20)\d{2})\)');
final _bareYear = RegExp(r'(?<![A-Za-z0-9])((?:19|20)\d{2})(?![A-Za-z0-9])');
final _tag = RegExp(
  r'(?<![A-Za-z0-9])(?:480p|576p|720p|1080p|1080i|2160p|4k|uhd|x264|x265|'
  r'h\.?264|h\.?265|hevc|avc|hdr10?|hdr|web[- ]?dl|web[- ]?rip|blu[- ]?ray|'
  r'bdrip|brrip|dvdrip|hdtv|remux|multi|vostfr|vff|vfq|truefrench|french|'
  r'aac|ac3|dts|proper|repack)(?![A-Za-z0-9])',
  caseSensitive: false,
);

/// Analyse un nom de fichier vidéo : titre, année, saison et épisode.
///
/// Retire l'extension, les `[Groupe]`, les balises techniques (`1080p`,
/// `x265`, `MULTI`, `VOSTFR`…) ; reconnaît `S01E02`, `1x02`, `(2019)` et
/// `.2019.`. Si rien d'exploitable ne reste, le titre est le nom sans
/// extension.
ParsedName parseMediaName(String fileName) {
  final base = fileName.split(RegExp(r'[\\/]')).last;
  var stem = base;
  final e = _ext.firstMatch(stem);
  if (e != null && e.start > 0) stem = stem.substring(0, e.start);
  final fallback = _clean(stem);

  final noGroups = stem.replaceAll(_brackets, ' ');
  var s = noGroups.replaceAll(RegExp(r'[._]'), ' ');
  // Nom entièrement séparé par des tirets (« big-buck-bunny-2008 »).
  if (!RegExp(r'[ ._]').hasMatch(stem.trim()) && stem.contains('-')) {
    s = s.replaceAll('-', ' ');
  }

  int? season, episode, year;
  var cut = s.length;

  void consider(int at) {
    if (at < cut) cut = at;
  }

  final m = _sxe.firstMatch(s) ?? _nxm.firstMatch(s);
  if (m != null && s.substring(0, m.start).trim().isNotEmpty) {
    season = int.parse(m.group(1)!);
    episode = int.parse(m.group(2)!);
    consider(m.start);
  }
  final pm = _parenYear.allMatches(s).where((x) => x.start > 0).toList();
  if (pm.isNotEmpty) {
    year = int.parse(pm.last.group(1)!);
    consider(pm.first.start);
  } else {
    // Dernière année « nue » précédée d'un titre non vide.
    final bm = _bareYear
        .allMatches(s)
        .where((x) => s.substring(0, x.start).trim().isNotEmpty)
        .toList();
    if (bm.isNotEmpty) {
      year = int.parse(bm.last.group(1)!);
      consider(bm.last.start);
    }
  }
  final t = _tag.firstMatch(s);
  if (t != null && s.substring(0, t.start).trim().isNotEmpty) consider(t.start);

  final title = _clean(s.substring(0, cut));
  if (title.isEmpty) return ParsedName(fallback.isEmpty ? base : fallback);
  return ParsedName(title, year: year, season: season, episode: episode);
}

String _clean(String s) => s
    .replaceAll(RegExp(r'[._]'), ' ')
    .replaceAll(_spaces, ' ')
    .replaceAll(RegExp(r'^[\s\-–]+|[\s\-–]+$'), '');
