import 'dart:async';

import '../addons/addon_client.dart';
import '../addons/manifest.dart';
import 'subtitle_item.dart';

/// Interroge en parallèle les addons compatibles (ressource `subtitles`).
/// Un addon en échec est ignoré ; le résultat est dédoublonné par URL.
class SubtitleService {
  SubtitleService(this._client, {this.onLog});

  final AddonClient _client;

  /// Journal facultatif ; les messages ne contiennent jamais d'URL en clair.
  final void Function(String message)? onLog;

  Future<List<SubtitleItem>> load(
    List<AddonManifest> addons,
    String type,
    String id,
  ) async {
    final targets = addons
        .where((a) => a.supports('subtitles', type, id))
        .toList();
    final results = await Future.wait(
      targets.map((a) async {
        try {
          final raws = await _client.rawSubtitles(a, type, id);
          return [for (final r in raws) ?_normalize(r, a.id)];
        } catch (_) {
          onLog?.call('Sous-titres : addon ${a.id} en échec, ignoré.');
          return const <SubtitleItem>[];
        }
      }),
    );
    final seen = <String>{};
    return [
      for (final list in results)
        for (final s in list)
          if (seen.add(s.url.toString())) s,
    ];
  }

  /// Tri stable : langues préférées d'abord (dans l'ordre donné), puis les
  /// autres par langue alphabétique.
  List<SubtitleItem> sortByPreference(
    List<SubtitleItem> items,
    List<String> langs,
  ) {
    final prefs = [for (final l in langs) normalizeLang(l)];
    int rank(SubtitleItem s) {
      final i = prefs.indexOf(normalizeLang(s.lang));
      return i < 0 ? prefs.length : i;
    }

    final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
    indexed.sort((a, b) {
      final ra = rank(a.$2);
      final rb = rank(b.$2);
      if (ra != rb) return ra.compareTo(rb);
      if (ra == prefs.length) {
        final c = a.$2.lang.compareTo(b.$2.lang);
        if (c != 0) return c;
      }
      return a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }

  static SubtitleItem? _normalize(Map<String, dynamic> r, String addonId) {
    final rawUrl = r['url'];
    if (rawUrl is! String) return null;
    final url = Uri.tryParse(rawUrl.trim());
    if (url == null ||
        !(url.scheme == 'http' || url.scheme == 'https') ||
        url.host.isEmpty) {
      return null;
    }
    final lang = r['lang'];
    final id = r['id'];
    return SubtitleItem(
      id: id == null ? url.toString() : id.toString(),
      url: url,
      lang: lang is String && lang.trim().isNotEmpty
          ? normalizeLang(lang)
          : 'und',
      addonId: addonId,
    );
  }
}

const _langs = <String, List<String>>{
  'fr': ['fra', 'fre', 'french', 'français', 'francais'],
  'en': ['eng', 'english'],
  'ar': ['ara', 'arabic', 'arabe'],
  'es': ['spa', 'spanish', 'español', 'espanol'],
  'de': ['deu', 'ger', 'german', 'deutsch'],
  'it': ['ita', 'italian', 'italiano'],
  'pt': ['por', 'portuguese', 'português', 'portugues'],
  'nl': ['nld', 'dut', 'dutch'],
  'ru': ['rus', 'russian'],
  'tr': ['tur', 'turkish'],
  'ja': ['jpn', 'japanese'],
  'ko': ['kor', 'korean'],
  'zh': ['zho', 'chi', 'chinese'],
  'pl': ['pol', 'polish'],
  'he': ['heb', 'hebrew'],
  'fa': ['fas', 'per', 'persian'],
  'hi': ['hin', 'hindi'],
  'sv': ['swe', 'swedish'],
  'el': ['ell', 'gre', 'greek'],
  'ro': ['ron', 'rum', 'romanian'],
};

final Map<String, String> _langIndex = {
  for (final e in _langs.entries) ...{
    e.key: e.key,
    for (final v in e.value) v: e.key,
  },
};

/// Normalise un code langue en ISO 639-1 quand il est connu (`fre`, `fra`,
/// `French`, `fr-FR` donnent `fr`) ; sinon renvoie la valeur d'origine.
String normalizeLang(String raw) {
  final k = raw.trim().toLowerCase();
  final direct = _langIndex[k];
  if (direct != null) return direct;
  final base = k.split(RegExp('[-_]')).first;
  return _langIndex[base] ?? raw.trim();
}
