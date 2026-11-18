/// Limite d'âge d'un profil.
enum AgeLimit {
  all,
  age7,
  age12,
  age16,
  adult;

  /// Âge affiché (« 12+ »), nul pour [all] et [adult].
  int? get years => switch (this) {
    AgeLimit.age7 => 7,
    AgeLimit.age12 => 12,
    AgeLimit.age16 => 16,
    _ => null,
  };
}

final _frRating = RegExp(r'^(?:FR)?[-+ ]?(10|12|16|18)$');

/// Limite minimale requise pour une certification, ou null si inconnue.
AgeLimit? _required(String certification) {
  final c = certification.trim().toUpperCase();
  switch (c) {
    // Cinéma américain.
    case 'G':
    case 'TV-Y':
    case 'TV-G':
    case 'U':
    case 'TP':
    case 'FR-U':
    case 'FR-TP':
      return AgeLimit.all;
    case 'TV-Y7':
    case 'TV-Y7-FV':
    case 'PG':
      return AgeLimit.age7;
    case 'TV-PG':
      return AgeLimit.age12;
    case 'PG-13':
    case 'TV-14':
      return AgeLimit.age16;
    case 'R':
    case 'NC-17':
    case 'TV-MA':
      return AgeLimit.adult;
  }
  // France : -10 (refusé aux 7 ans), -12, -16, -18.
  final m = _frRating.firstMatch(c);
  if (m != null) {
    return switch (m.group(1)) {
      '10' || '12' => AgeLimit.age12,
      '16' => AgeLimit.age16,
      _ => AgeLimit.adult,
    };
  }
  return null;
}

/// Vrai si un contenu de [certification] peut être vu avec [limit].
/// Certification absente ou inconnue : refusée sauf pour [AgeLimit.adult].
bool ratingAllows(String? certification, AgeLimit limit) {
  if (limit == AgeLimit.adult) return true;
  if (certification == null) return false;
  final required = _required(certification);
  if (required == null) return false;
  return limit.index >= required.index;
}
