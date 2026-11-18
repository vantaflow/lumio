import 'dart:async';

import 'addon_client.dart';
import 'manifest.dart';
import 'meta.dart';
import 'meta_preview.dart';

/// Charge et fusionne la fiche d'un média auprès des addons compatibles.
///
/// Stratégie : tous les addons compatibles sont interrogés en parallèle, avec
/// un budget global de [budget] (8 s) ; ceux qui n'ont pas répondu à temps ou
/// qui échouent sont ignorés. Les réponses sont fusionnées dans l'ordre des
/// manifestes : la première valeur non vide l'emporte, `videos` vient du
/// premier addon qui en fournit. Sans aucune réponse, la fiche est construite
/// depuis le [MetaPreview] du catalogue.
class MetaService {
  MetaService(this._client, {this.budget = const Duration(seconds: 8)});

  final AddonClient _client;
  final Duration budget;

  Future<Meta> load(List<AddonManifest> addons, MetaPreview p) async {
    final compatible = [
      for (final a in addons)
        if (a.supports('meta', p.type, p.id)) a,
    ];
    final results = List<Map<String, dynamic>?>.filled(compatible.length, null);
    final calls = [
      for (var i = 0; i < compatible.length; i++)
        _fetch(compatible[i], p).then((m) => results[i] = m),
    ];
    await Future.wait(calls).timeout(budget, onTimeout: () => const []);
    return _merge([for (final r in results) ?r], p);
  }

  Future<Map<String, dynamic>?> _fetch(AddonManifest a, MetaPreview p) async {
    try {
      return await _client.rawMeta(a, p.type, p.id);
    } catch (_) {
      return null; // un addon en échec ne casse jamais la fiche
    }
  }

  static Meta _merge(List<Map<String, dynamic>> raws, MetaPreview p) {
    String? text(String key) => _first(raws, (m) => metaText(m[key]));
    Uri? uri(String key) => _first(raws, (m) => _httpUri(m[key]));

    List<String> genres() =>
        _first(raws, (m) {
          final g = m['genres'] ?? m['genre'];
          if (g is! List) return null;
          final l = [
            for (final e in g)
              if (metaText(e) != null) metaText(e)!,
          ];
          return l.isEmpty ? null : l;
        }) ??
        const [];

    List<Video> videos() {
      for (final m in raws) {
        final v = m['videos'];
        if (v is! List) continue;
        final list = [for (final e in v) ?Video.tryParse(e)];
        if (list.isNotEmpty) return sortVideos(list);
      }
      return const [];
    }

    return Meta(
      id: p.id,
      type: p.type,
      name: text('name') ?? p.name,
      description: text('description'),
      releaseInfo: text('releaseInfo') ?? p.releaseInfo,
      certification: text('certification') ?? p.certification,
      poster: uri('poster') ?? p.poster,
      background: uri('background'),
      genres: genres(),
      videos: videos(),
    );
  }

  /// Saison, épisode, puis date de sortie ; la saison 0 (spéciaux) en dernier.
  /// Les entrées sans saison viennent après les saisons numérotées.
  static List<Video> sortVideos(List<Video> videos) {
    final indexed = [for (var i = 0; i < videos.length; i++) (i, videos[i])];
    int seasonRank(int? s) => s == null ? 1 : (s == 0 ? 2 : 0);
    indexed.sort((a, b) {
      final x = a.$2, y = b.$2;
      var c = seasonRank(x.season).compareTo(seasonRank(y.season));
      if (c != 0) return c;
      c = (x.season ?? 0).compareTo(y.season ?? 0);
      if (c != 0) return c;
      c = _nullsLast(x.episode, y.episode);
      if (c != 0) return c;
      c = _nullsLast(x.released, y.released);
      if (c != 0) return c;
      return a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }
}

int _nullsLast<T extends Comparable<Object>>(T? a, T? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

T? _first<T>(List<Map<String, dynamic>> raws, T? Function(Map m) pick) {
  for (final m in raws) {
    final v = pick(m);
    if (v != null) return v;
  }
  return null;
}

Uri? _httpUri(Object? v) {
  if (v is! String) return null;
  final u = Uri.tryParse(v);
  if (u == null || (u.scheme != 'http' && u.scheme != 'https')) return null;
  return u;
}
