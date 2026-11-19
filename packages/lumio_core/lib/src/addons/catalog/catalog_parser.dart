import 'dart:convert';

import 'catalog_models.dart';

/// Analyse tolérante (expressions régulières) des pages de stremio-addons.net
/// et de la collection officielle. Toute surprise de format lève
/// [CatalogParseException].
class AddonCatalogParser {
  const AddonCatalogParser._();

  static final _card = RegExp(r'<a\b[^>]*\bhref="/addons/([^"/?#]+)"[^>]*>');
  static final _close = RegExp('</a>');
  static final _results = RegExp(r'(\d+)\s*<!--\s*-->\s*results');
  static final _pages = RegExp(r'\bof\s*<!--\s*-->\s*(\d+)');
  static final _img = RegExp(r'<img\b[^>]*\bsrc="([^"]*)"');
  static final _alt = RegExp(r'<img\b[^>]*\balt="([^"]*)"');
  static final _h3 = RegExp(r'<h3\b[^>]*>(.*?)</h3>', dotAll: true);
  static final _p = RegExp(r'<p\b[^>]*>(.*?)</p>', dotAll: true);
  static final _starCount = RegExp(
    r'lucide-star.*?<span[^>]*>\s*(\d+)\s*</span>',
    dotAll: true,
  );
  static final _version = RegExp(
    r'>\s*v\s*(?:<!--\s*-->)?\s*([0-9][^<\s]*)\s*<',
  );
  static final _tag = RegExp(r'<[^>]*>');

  /// Page de liste (`/addons?categories=…`).
  static CatalogPage parseList(String html, {int page = 1}) {
    html = _resolveStreamed(html);
    final m = _results.firstMatch(html);
    final entries = <CatalogEntry>[];
    final seen = <String>{};
    // Chaque carte va de sa balise ouvrante à `</a>` ou, à défaut, à la
    // carte suivante : une seule passe, jamais de rebalayage jusqu'à la fin.
    final opens = _card.allMatches(html).toList();
    final closes = [for (final m in _close.allMatches(html)) m.start];
    var ci = 0;
    for (var k = 0; k < opens.length; k++) {
      final c = opens[k];
      while (ci < closes.length && closes[ci] < c.end) {
        ci++;
      }
      var end = ci < closes.length ? closes[ci] : html.length;
      if (k + 1 < opens.length && opens[k + 1].start < end) {
        end = opens[k + 1].start;
      }
      final slug = c.group(1)!;
      final inner = html.substring(c.end, end);
      var name = _text(_h3.firstMatch(inner)?.group(1));
      // Contenu non encore diffusé : le texte alternatif du logo est le nom.
      if (name.isEmpty) {
        name = _decode(_alt.firstMatch(inner)?.group(1) ?? '').trim();
      }
      if (name.isEmpty || !seen.add(slug)) continue;
      final desc = _text(_p.firstMatch(inner)?.group(1));
      entries.add(
        CatalogEntry(
          slug: Uri.decodeComponent(slug),
          name: name,
          description: desc.isEmpty ? null : desc,
          logo: safeHttpUri(_decode(_img.firstMatch(inner)?.group(1) ?? '')),
          stars: int.tryParse(_starCount.firstMatch(inner)?.group(1) ?? ''),
          version: _version.firstMatch(inner)?.group(1),
        ),
      );
    }
    if (m == null && entries.isEmpty) {
      throw const CatalogParseException('page de liste non reconnue');
    }
    final total = int.tryParse(m?.group(1) ?? '') ?? entries.length;
    if (total > 0 && entries.isEmpty) {
      throw const CatalogParseException('résultats annoncés mais aucune carte');
    }
    return CatalogPage(
      entries: entries,
      total: total,
      page: page,
      totalPages: int.tryParse(_pages.firstMatch(html)?.group(1) ?? '') ?? 1,
    );
  }

  static final _placeholder = RegExp(r'<template id="P:(\d+)"></template>');
  static final _streamed = RegExp(
    r'<div hidden id="S:(\d+)">(.*?)</div>(?=<script|<div hidden id="S:|$)',
    dotAll: true,
  );

  /// Next.js diffuse certaines parties après coup : `<template id="P:n">`
  /// est remplacé par le contenu du bloc `<div hidden id="S:n">`.
  static String _resolveStreamed(String html) {
    if (!html.contains('<template id="P:')) return html;
    final blocks = {
      for (final m in _streamed.allMatches(html)) m.group(1)!: m.group(2)!,
    };
    var out = html;
    for (var pass = 0; pass < 3 && out.contains('<template id="P:'); pass++) {
      out = out.replaceAllMapped(
        _placeholder,
        (m) => blocks[m.group(1)] ?? m.group(0)!,
      );
    }
    return out;
  }

  static final _manifestUrl = RegExp(r'"manifestUrl":"([^"]+)"');
  static final _configurable = RegExp(r'"configurable":(true|false)');
  static final _required = RegExp(r'"configurationRequired":(true|false)');
  static final _stars = RegExp(r'"stars":(\d+)');

  /// Objets de premier niveau du tableau qui commence à [from] (juste après
  /// le `[`). S'arrête au `]` fermant, à un élément qui n'est pas un objet ou
  /// à des accolades déséquilibrées.
  static Iterable<String> _instanceObjects(String s, int from) sync* {
    var i = from;
    while (i < s.length) {
      final ch = s[i];
      if (ch == ',' || ch == ' ' || ch == '\n') {
        i++;
        continue;
      }
      if (ch != '{') return;
      final end = _objectEnd(s, i);
      if (end < 0) return;
      yield s.substring(i, end + 1);
      i = end + 1;
    }
  }

  /// Index de l'accolade fermante de l'objet ouvert en [open] (les chaînes
  /// et leurs échappements sont sautés), ou -1.
  static int _objectEnd(String s, int open) {
    var depth = 0;
    var inString = false;
    for (var i = open; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (inString) {
        if (c == 0x5C) {
          i++;
        } else if (c == 0x22) {
          inString = false;
        }
      } else if (c == 0x22) {
        inString = true;
      } else if (c == 0x7B) {
        depth++;
      } else if (c == 0x7D) {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  static String? _meta(String html, String property) {
    final m = RegExp(
      '<meta\\b[^>]*\\bproperty="$property"[^>]*\\bcontent="([^"]*)"',
    ).firstMatch(html);
    return m == null ? null : _decode(m.group(1)!);
  }

  /// Fiche d'un addon : instances (URL de manifest) et réglages.
  static CatalogDetail parseDetail(String html, String slug) {
    // La charge Next.js est une chaîne JSON échappée dans un script.
    final flat = html.replaceAll(r'\"', '"');
    final instances = <CatalogInstance>[];
    final seen = <String>{};
    void add(Uri? u, String chunk) {
      if (u == null || !seen.add(u.toString())) return;
      instances.add(
        CatalogInstance(
          manifestUrl: u,
          configurable: _configurable.firstMatch(chunk)?.group(1) == 'true',
          configurationRequired:
              _required.firstMatch(chunk)?.group(1) == 'true',
          stars: int.tryParse(_stars.firstMatch(chunk)?.group(1) ?? ''),
        ),
      );
    }

    final start = flat.indexOf('"instances":[');
    if (start >= 0) {
      // Chaque instance est un objet JSON du tableau, borné par ses
      // accolades (chaînes comprises) : les réglages ou adresses d'un bloc
      // voisin (« addons similaires »…) ne lui sont jamais attribués. Un
      // tableau présent mais illisible ne propose rien (pas de repli).
      for (final chunk in _instanceObjects(
        flat,
        start + '"instances":['.length,
      )) {
        add(safeHttpUri(_manifestUrl.firstMatch(chunk)?.group(1)), chunk);
      }
    } else {
      final urls = {for (final m in _manifestUrl.allMatches(flat)) m.group(1)!};
      // Une seule adresse : les réglages de la page lui appartiennent.
      // Plusieurs : ambigu, rien n'est proposé.
      if (urls.length == 1) add(safeHttpUri(urls.first), flat);
    }
    if (instances.isEmpty) {
      throw const CatalogParseException('fiche sans adresse de manifest');
    }
    final h1 = RegExp(r'<h1\b[^>]*>(.*?)</h1>', dotAll: true).firstMatch(html);
    final name = _meta(html, 'og:title') ?? _text(h1?.group(1));
    return CatalogDetail(
      slug: slug,
      name: name.isEmpty ? slug : name,
      description: _meta(html, 'og:description'),
      logo: safeHttpUri(_meta(html, 'og:image')),
      instances: instances,
    );
  }

  /// Collection officielle (`addonscollection.json`).
  ///
  /// [skipLocal] écarte les entrées dont l'adresse est locale (le « Local
  /// Files » de la collection officielle pointe vers 127.0.0.1).
  static CatalogPage parseCollection(String json, {bool skipLocal = false}) {
    final Object? data;
    try {
      data = jsonDecode(json);
    } on FormatException {
      throw const CatalogParseException('collection illisible');
    }
    if (data is! List) {
      throw const CatalogParseException('collection : liste attendue');
    }
    final entries = <CatalogEntry>[];
    for (final e in data) {
      // Lecture typée : un champ de mauvais type est ignoré ; une entrée
      // illisible est écartée sans gêner les autres.
      try {
        final entry = _collectionEntry(e);
        if (entry == null) continue;
        if (skipLocal && _isLocalHost(entry.instances.first.manifestUrl.host)) {
          continue;
        }
        entries.add(entry);
      } catch (_) {
        continue;
      }
    }
    if (entries.isEmpty && data.isNotEmpty) {
      throw const CatalogParseException('collection : aucune entrée lisible');
    }
    if (entries.isEmpty) {
      throw const CatalogParseException('collection vide');
    }
    return CatalogPage(entries: entries, total: entries.length);
  }

  static bool _isLocalHost(String h) =>
      h == 'localhost' || h == '::1' || h.startsWith('127.') || h == '0.0.0.0';

  static CatalogEntry? _collectionEntry(Object? e) {
    if (e is! Map) return null;
    final m = e['manifest'];
    if (m is! Map) return null;
    final url = safeHttpUri(e['transportUrl']);
    final name = m['name'];
    if (url == null || name is! String || name.trim().isEmpty) return null;
    final hints = m['behaviorHints'];
    if (hints is Map && hints['adult'] == true) return null;
    final description = m['description'];
    final types = m['types'];
    final resources = m['resources'];
    final id = m['id'];
    final version = m['version'];
    final desc = description is String ? description.trim() : '';
    return CatalogEntry(
      slug: id is String ? id : url.host,
      name: name.trim(),
      description: desc.isEmpty ? null : desc,
      logo: safeHttpUri(m['logo']),
      version: version is String || version is num ? '$version' : null,
      types: [
        if (types is List)
          for (final t in types) '$t',
      ],
      resources: [
        if (resources is List)
          for (final r in resources) r is Map ? '${r['name']}' : '$r',
      ],
      instances: [
        CatalogInstance(
          manifestUrl: url,
          configurable: hints is Map && hints['configurable'] == true,
          configurationRequired:
              hints is Map && hints['configurationRequired'] == true,
        ),
      ],
    );
  }

  static String _text(String? html) =>
      html == null ? '' : _decode(html.replaceAll(_tag, '')).trim();

  static String _decode(String s) => s
      .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
        return String.fromCharCode(int.parse(m.group(1)!, radix: 16));
      })
      .replaceAllMapped(
        RegExp(r'&#(\d+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!)),
      )
      .replaceAll('&quot;', '"')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&');
}
