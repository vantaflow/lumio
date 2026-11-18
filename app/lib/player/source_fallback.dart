/// Issue d'une tentative d'ouverture d'une source.
enum AttemptOutcome {
  /// La première image est apparue : la lecture a commencé.
  played,

  /// Échec avant la première image, imputable à la source : on peut passer à
  /// la suivante.
  sourceFailed,

  /// Échec qui n'est pas imputable à la source (VPN exigé, avertissement
  /// refusé, stockage) : la suivante échouerait pareil, on s'arrête.
  stopped,
}

/// Nombre maximal de sources essayées pour une même lecture.
const maxFallbackAttempts = 3;

/// Essaie les sources de [candidates] dans l'ordre jusqu'à ce que l'une
/// démarre ([maxAttempts] au plus). Ne bascule JAMAIS après le début de la
/// lecture : [attempt] ne rend [AttemptOutcome.played] qu'une fois la
/// première image là, et la série s'arrête alors. Rend la source qui a joué,
/// `null` si aucune (ou si [cancelled] devient vrai).
Future<T?> runWithFallback<T>(
  List<T> candidates, {
  required Future<AttemptOutcome> Function(T item, int index, bool isLast)
  attempt,
  bool Function()? cancelled,
  int maxAttempts = maxFallbackAttempts,
}) async {
  final list = candidates.take(maxAttempts).toList();
  for (var i = 0; i < list.length; i++) {
    if (cancelled?.call() ?? false) return null;
    final outcome = await attempt(list[i], i, i == list.length - 1);
    if (cancelled?.call() ?? false) return null;
    switch (outcome) {
      case AttemptOutcome.played:
        return list[i];
      case AttemptOutcome.stopped:
        return null;
      case AttemptOutcome.sourceFailed:
        continue;
    }
  }
  return null;
}
