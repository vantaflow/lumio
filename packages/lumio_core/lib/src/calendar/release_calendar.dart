import '../addons/meta.dart';

/// Entrée du calendrier : un épisode à venir d'une série, ou la série seule
/// quand aucune date de sortie n'est connue.
class CalendarEntry {
  const CalendarEntry({required this.series, this.video, this.date});

  final Meta series;

  /// Épisode à venir ; `null` pour une entrée « date inconnue ».
  final Video? video;

  /// Date de sortie en UTC ; `null` pour une entrée « date inconnue ».
  final DateTime? date;

  bool get unknown => date == null;
}

/// Prochaines sorties des [series] dans les [days] jours après [now].
///
/// Les épisodes dont la date de sortie est postérieure à [now] et au plus
/// [days] jours plus tard sont triés par date (puis nom de série, saison,
/// épisode). Une série sans aucun épisode futur daté (ni dans la fenêtre ni
/// au-delà) donne une entrée « date inconnue », placée à la fin dans l'ordre
/// d'entrée ; une série dont les sorties datées tombent seulement après la
/// fenêtre n'apparaît pas.
List<CalendarEntry> upcoming(List<Meta> series, DateTime now, {int days = 30}) {
  final from = now.toUtc();
  final until = from.add(Duration(days: days));
  final dated = <CalendarEntry>[];
  final unknown = <CalendarEntry>[];
  for (final s in series) {
    var hasFuture = false;
    for (final v in s.videos) {
      final d = v.released;
      if (d == null || !d.isAfter(from)) continue;
      hasFuture = true;
      if (d.isAfter(until)) continue;
      dated.add(CalendarEntry(series: s, video: v, date: d));
    }
    if (!hasFuture) unknown.add(CalendarEntry(series: s));
  }
  dated.sort((a, b) {
    final c = a.date!.compareTo(b.date!);
    if (c != 0) return c;
    final n = a.series.name.compareTo(b.series.name);
    if (n != 0) return n;
    final s = (a.video!.season ?? 0).compareTo(b.video!.season ?? 0);
    if (s != 0) return s;
    return (a.video!.episode ?? 0).compareTo(b.video!.episode ?? 0);
  });
  return [...dated, ...unknown];
}
