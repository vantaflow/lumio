import 'dart:math' as math;

import '../health/health_tracker.dart';
import '../subtitles/subtitle_service.dart';
import 'stream_item.dart';

/// Préférence de flux d'un profil : qualité maximale, langues par ordre de
/// préférence et choix du lien direct avant le torrent.
class StreamPrefs {
  const StreamPrefs({
    this.maxQuality = Quality.hd1080,
    this.languages = const ['fr'],
    this.preferDirect = true,
  });

  /// Plafond de qualité : au-dessus, un flux passe après les autres.
  final Quality maxQuality;

  /// Codes de langue (ISO 639-1), du plus au moins préféré.
  final List<String> languages;

  /// Favorise un lien direct (un torrent a besoin de sources pour démarrer).
  final bool preferDirect;

  StreamPrefs copyWith({
    Quality? maxQuality,
    List<String>? languages,
    bool? preferDirect,
  }) => StreamPrefs(
    maxQuality: maxQuality ?? this.maxQuality,
    languages: languages ?? this.languages,
    preferDirect: preferDirect ?? this.preferDirect,
  );

  Map<String, Object?> toJson() => {
    'maxQuality': maxQuality.name,
    'languages': languages,
    'preferDirect': preferDirect,
  };

  /// Lecture tolérante : valeur absente ou invalide = valeur par défaut.
  factory StreamPrefs.fromJson(Map<String, Object?> j) {
    final q = Quality.values.where((e) => e.name == j['maxQuality']);
    final l = j['languages'];
    final d = j['preferDirect'];
    return StreamPrefs(
      maxQuality: q.isEmpty || q.first == Quality.unknown
          ? Quality.hd1080
          : q.first,
      languages: l is List
          ? [
              for (final e in l)
                if (e is String && e.trim().isNotEmpty) normalizeLang(e),
            ]
          : const ['fr'],
      preferDirect: d is bool ? d : true,
    );
  }
}

/// Classement des flux d'un titre : score, dédoublonnage, fiabilité des addons.
class StreamRanker {
  const StreamRanker._();

  static const _languageBonus = 40.0;
  static const _qualityStep = 30.0;
  static const _directBonus = 15.0;

  /// Socle qui garde tout score positif (un flux au-dessus du plafond perd
  /// jusqu'à 90 points) : le facteur de fiabilité ne peut pas le remonter.
  static const _base = 100.0;

  /// Score d'un flux : langue préférée +40 (un peu moins pour les suivantes),
  /// qualité jusqu'au plafond +30 par cran (au-dessus : −30 par cran), lien
  /// direct +15 si [StreamPrefs.preferDirect], plus le log des sources ;
  /// le tout multiplié par la fiabilité de l'addon (défaillant ×0,3, lent
  /// ×0,8, inconnu ou fiable ×1).
  static double score(StreamItem s, StreamPrefs p, HealthTracker h) {
    var v = _base + _language(s, p);
    final q = s.quality;
    if (q != Quality.unknown) {
      v += q.index <= p.maxQuality.index
          ? _qualityStep * q.index
          : -_qualityStep * (q.index - p.maxQuality.index);
    }
    if (p.preferDirect && !s.isTorrent) v += _directBonus;
    final seeders = s.seeders;
    if (seeders != null && seeders > 0) v += math.log(1 + seeders);
    return v * _reliability(h, s.addonId);
  }

  static double _language(StreamItem s, StreamPrefs p) {
    final l = s.language;
    if (l == null || p.languages.isEmpty) return 0;
    // `multi` convient à toute langue préférée.
    final i = l == 'multi' ? 0 : p.languages.indexOf(normalizeLang(l));
    if (i < 0) return 0;
    return math.max(_languageBonus / 2, _languageBonus - 2.0 * i);
  }

  static double _reliability(HealthTracker h, String addonId) =>
      switch (h.stats(addonId).level) {
        HealthLevel.failing => 0.3,
        HealthLevel.slow => 0.8,
        HealthLevel.unknown || HealthLevel.reliable => 1.0,
      };

  /// Trie du meilleur au moins bon, sans retirer de doublon (ordre d'origine
  /// à égalité).
  static List<StreamItem> sort(
    List<StreamItem> items,
    StreamPrefs p,
    HealthTracker h,
  ) {
    final scored = [
      for (var i = 0; i < items.length; i++)
        (i: i, item: items[i], score: score(items[i], p, h)),
    ];
    scored.sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : a.i.compareTo(b.i);
    });
    return [for (final e in scored) e.item];
  }

  /// Dédoublonne par [StreamItem.signature] (le doublon le mieux noté est
  /// gardé) puis trie du meilleur au moins bon.
  static List<StreamItem> rank(
    List<StreamItem> items,
    StreamPrefs p,
    HealthTracker h,
  ) {
    final best = <String, ({int i, StreamItem item, double score})>{};
    for (var i = 0; i < items.length; i++) {
      final s = items[i];
      final sc = score(s, p, h);
      final key = s.signature;
      final cur = best[key];
      if (cur == null || sc > cur.score) {
        best[key] = (i: cur?.i ?? i, item: s, score: sc);
      }
    }
    final kept = best.values.toList()
      ..sort((a, b) {
        final c = b.score.compareTo(a.score);
        return c != 0 ? c : a.i.compareTo(b.i);
      });
    return [for (final e in kept) e.item];
  }

  /// Meilleur flux, `null` s'il n'y en a aucun.
  static StreamItem? preferred(
    Iterable<StreamItem> items,
    StreamPrefs p,
    HealthTracker h,
  ) {
    final ranked = rank(items.toList(), p, h);
    return ranked.isEmpty ? null : ranked.first;
  }
}
