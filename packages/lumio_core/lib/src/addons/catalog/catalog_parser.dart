import 'dart:convert';

import 'catalog_models.dart';

/// Analyse tolérante (expressions régulières) des pages de stremio-addons.net
/// et de la collection officielle. Toute surprise de format lève
/// [CatalogParseException].
class AddonCatalogParser {
  const AddonCatalogParser._();

  static final _card = RegExp(
    r'<a\b[^>]*\bhref="/addons/([^"/?#]+)"[^>]*>(.*?)</a>',
    dotAll: true,
  );
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
    for (final c in _card.allMatches(html)) {
      final slug = c.group(1)!;
      final inner = c.group(2)!;
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
  static final _instanceStart = RegExp(r'\{"id":\d+,"uuid":"');
  static final _configurable = RegExp(r'"configurable":(true|false)');
  static final _required = RegExp(r'"configurationRequired":(true|false)');
  static final _stars = RegExp(r'"stars":(\d+)');

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
      final tail = flat.substring(start);
      final starts = [for (final s in _instanceStart.allMatches(tail)) s.start];
      for (var i = 0; i < starts.length; i++) {
        final chunk = tail.substring(
          starts[i],
          i + 1 < starts.length ? starts[i + 1] : tail.length,
        );
        final u = _manifestUrl.firstMatch(chunk)?.group(1);
        add(safeHttpUri(u), chunk);
      }
    }
    if (instances.isEmpty) {
      final urls = {for (final m in _manifestUrl.allMatches(flat)) m.group(1)!};
      // Une seule adresse : les réglages de la page lui appartiennent.
      final flags = urls.length == 1 ? flat : '';
      for (final u in urls) {
        add(safeHttpUri(u), flags);
      }
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
  static CatalogPage parseCollection(String json) {
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
      if (e is! Map || e['manifest'] is! Map) continue;
      final m = e['manifest'] as Map;
      final url = safeHttpUri(e['transportUrl']);
      final name = m['name'];
      if (url == null || name is! String || name.trim().isEmpty) continue;
      final hints = m['behaviorHints'];
      final adult = hints is Map && hints['adult'] == true;
      if (adult) continue;
      entries.add(
        CatalogEntry(
          slug: m['id'] is String ? m['id'] as String : url.host,
          name: name.trim(),
          description: (m['description'] as String?)?.trim(),
          logo: safeHttpUri(m['logo']),
          version: m['version']?.toString(),
          types: [for (final t in (m['types'] as List? ?? const [])) '$t'],
          resources: [
            for (final r in (m['resources'] as List? ?? const []))
              r is Map ? '${r['name']}' : '$r',
          ],
          instances: [
            CatalogInstance(
              manifestUrl: url,
              configurable: hints is Map && hints['configurable'] == true,
              configurationRequired:
                  hints is Map && hints['configurationRequired'] == true,
            ),
          ],
        ),
      );
    }
    if (entries.isEmpty && data.isNotEmpty) {
      throw const CatalogParseException('collection : aucune entrée lisible');
    }
    if (entries.isEmpty) {
      throw const CatalogParseException('collection vide');
    }
    return CatalogPage(entries: entries, total: entries.length);
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
