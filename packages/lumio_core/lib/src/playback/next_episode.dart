import 'package:lumio_core/src/addons/meta.dart';

/// Épisode qui suit [currentVideoId] dans [m] ; `null` si c'est le dernier ou
/// si l'épisode est inconnu. Les épisodes spéciaux (saison 0) sont ignorés,
/// sauf si l'épisode courant en est un.
Video? nextEpisode(Meta m, String currentVideoId) {
  final videos = m.videos;
  final i = videos.indexWhere((v) => v.id == currentVideoId);
  if (i < 0) return null;
  final fromSpecial = videos[i].season == 0;
  for (var j = i + 1; j < videos.length; j++) {
    final v = videos[j];
    if (v.season == 0 && !fromSpecial) continue;
    return v;
  }
  return null;
}
