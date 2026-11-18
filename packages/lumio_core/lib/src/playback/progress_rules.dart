/// Règles de progression de lecture : « vu » et reprise.
abstract final class ProgressRules {
  /// Part de la durée à partir de laquelle un titre est « vu ».
  static const watchedFraction = 0.9;

  /// Part minimale de la durée pour proposer une reprise.
  static const resumeMinFraction = 0.02;

  /// Vu à 90 % ou plus ; faux si la durée est inconnue.
  static bool isWatched(Duration pos, Duration dur) {
    if (dur <= Duration.zero) return false;
    return pos.inMicroseconds >= dur.inMicroseconds * watchedFraction;
  }

  /// Position de reprise ; `null` sous 2 % (on recommence) ou si le titre est
  /// vu (on repart du début).
  static Duration? resumeAt(Duration pos, Duration dur) {
    if (dur <= Duration.zero) return null;
    if (isWatched(pos, dur)) return null;
    if (pos.inMicroseconds < dur.inMicroseconds * resumeMinFraction) {
      return null;
    }
    return pos;
  }
}
