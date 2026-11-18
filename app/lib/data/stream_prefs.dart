import 'dart:convert';

import 'package:lumio/data/db.dart';
import 'package:lumio_core/lumio_core.dart';

/// Préférence de flux d'un profil (en attendant le classement de la tâche 35) :
/// qualité maximale et langues, par ordre de préférence.
class StreamPrefs {
  const StreamPrefs({
    this.maxQuality = Quality.hd1080,
    this.languages = const ['fr'],
  });

  final Quality maxQuality;
  final List<String> languages;

  Map<String, Object?> toJson() => {
    'maxQuality': maxQuality.name,
    'languages': languages,
  };

  factory StreamPrefs.fromJson(Map<String, Object?> j) {
    final q = Quality.values.where((e) => e.name == j['maxQuality']);
    final l = j['languages'];
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
    );
  }
}

/// Préférences de flux persistées par profil (table `settings`).
class StreamPrefsStore {
  StreamPrefsStore(this._db);

  final AppDatabase _db;

  static String _key(String profileId) => 'stream_prefs:$profileId';

  Future<StreamPrefs> load(String profileId) async {
    final row = await (_db.select(
      _db.settings,
    )..where((t) => t.key.equals(_key(profileId)))).getSingleOrNull();
    if (row == null) return const StreamPrefs();
    try {
      final j = jsonDecode(row.value);
      if (j is Map<String, Object?>) return StreamPrefs.fromJson(j);
    } on FormatException {
      // Valeur illisible : préférences par défaut.
    }
    return const StreamPrefs();
  }

  Future<void> save(String profileId, StreamPrefs p) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: _key(profileId),
          value: jsonEncode(p.toJson()),
        ),
      );
}

/// Rang de langue : 0 = première langue préférée ; `multi` convient toujours ;
/// aucune correspondance = après toutes les langues préférées.
int _langRank(StreamItem s, StreamPrefs p) {
  final l = s.language;
  if (l == null) return p.languages.length;
  if (l == 'multi') return p.languages.isEmpty ? 0 : p.languages.length - 1;
  final i = p.languages.indexOf(normalizeLang(l));
  return i < 0 ? p.languages.length : i;
}

/// Rang de qualité : sous le plafond, la plus haute d'abord ; qualité
/// inconnue ensuite ; au-dessus du plafond en dernier (la moins haute d'abord).
int _qualityRank(StreamItem s, StreamPrefs p) {
  final q = s.quality;
  if (q == Quality.unknown) return 100;
  if (q.index <= p.maxQuality.index) return p.maxQuality.index - q.index;
  return 200 + (q.index - p.maxQuality.index);
}

/// Trie [items] du meilleur au moins bon : langue, qualité, lien direct avant
/// torrent à égalité, puis nombre de sources.
List<StreamItem> sortStreams(List<StreamItem> items, StreamPrefs p) {
  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
  indexed.sort((a, b) {
    final x = a.$2, y = b.$2;
    var c = _langRank(x, p).compareTo(_langRank(y, p));
    if (c != 0) return c;
    c = _qualityRank(x, p).compareTo(_qualityRank(y, p));
    if (c != 0) return c;
    c = (x.isTorrent ? 1 : 0).compareTo(y.isTorrent ? 1 : 0);
    if (c != 0) return c;
    c = (y.seeders ?? 0).compareTo(x.seeders ?? 0);
    if (c != 0) return c;
    return a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// Flux présélectionné (le meilleur), `null` s'il n'y en a aucun.
StreamItem? preferredStream(Iterable<StreamItem> items, StreamPrefs p) {
  final sorted = sortStreams(items.toList(), p);
  return sorted.isEmpty ? null : sorted.first;
}

/// Flux à présélectionner tant que la lecture des torrents est indisponible :
/// le meilleur lien direct, à défaut le meilleur torrent.
StreamItem? preferredPlayable(Iterable<StreamItem> items, StreamPrefs p) {
  final list = items.toList();
  return preferredStream(list.where((s) => !s.isTorrent), p) ??
      preferredStream(list, p);
}
