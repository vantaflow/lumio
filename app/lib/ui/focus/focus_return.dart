import 'package:flutter/widgets.dart';

/// Zones capables de rendre le focus à leur dernier élément mémorisé quand
/// leur route redevient la route courante (retour d'une fiche, de la recherche,
/// de Ma liste) et que l'élément d'origine n'existe plus.
///
/// Une zone s'inscrit avec [register] et se retire avec [unregister] ; chaque
/// rappel reçoit la route révélée et répond vrai s'il a rendu le focus.
class FocusReturn {
  FocusReturn._();

  static final Map<Object, bool Function(Route<dynamic> route)> _zones = {};

  static void register(Object owner, bool Function(Route<dynamic>) restore) =>
      _zones[owner] = restore;

  static void unregister(Object owner) => _zones.remove(owner);

  /// Demande aux zones inscrites de rendre le focus ; vrai si l'une l'a fait.
  static bool restore(Route<dynamic> route) {
    for (final zone in _zones.values.toList()) {
      if (zone(route)) return true;
    }
    return false;
  }
}
