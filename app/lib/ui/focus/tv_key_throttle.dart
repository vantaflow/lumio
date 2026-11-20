import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Cadence des flèches de la télécommande, centralisée pour toute l'interface.
///
/// Un appui court déplace le focus immédiatement (jamais retenu). Un appui
/// maintenu envoie des répétitions (KeyRepeat) à la cadence du système
/// (souvent 30 à 50 ms) : trop vite pour suivre l'œil, le focus « saute ».
/// Les répétitions ne déplacent donc le focus qu'au plus toutes les
/// [repeatInterval].
class TvKeyThrottle {
  TvKeyThrottle._();

  /// Intervalle minimal entre deux déplacements dus à un appui maintenu.
  static const repeatInterval = Duration(milliseconds: 140);

  /// Horloge remplaçable dans les tests.
  static Duration Function() clock = () => _epoch.elapsed;
  static final Stopwatch _epoch = Stopwatch()..start();

  static bool _hooked = false;
  static bool _currentIsRepeat = false;
  static Duration? _lastMove;

  /// Écoute le clavier matériel (appelée à la première utilisation) : le
  /// gestionnaire s'exécute avant l'arbre de focus et note si la touche en
  /// cours de traitement est une répétition.
  static void ensureHooked() {
    if (_hooked) return;
    _hooked = true;
    HardwareKeyboard.instance.addHandler(_track);
  }

  static bool _track(KeyEvent e) {
    _currentIsRepeat = e is KeyRepeatEvent;
    return false;
  }

  /// Vrai si le déplacement du focus demandé maintenant est autorisé.
  /// Un premier appui passe toujours ; une répétition trop proche du dernier
  /// déplacement est ignorée.
  static bool allowMove() {
    ensureHooked();
    final now = clock();
    final last = _lastMove;
    if (_currentIsRepeat && last != null && now - last < repeatInterval) {
      return false;
    }
    _lastMove = now;
    return true;
  }

  /// Remet l'état à zéro (tests).
  static void reset() {
    HardwareKeyboard.instance.removeHandler(_track);
    _hooked = false;
    _currentIsRepeat = false;
    _lastMove = null;
    clock = () => _epoch.elapsed;
  }
}

/// Déplacement directionnel du focus, avec la cadence de [TvKeyThrottle].
/// À fournir dans `actions` de l'application (remplace l'action par défaut).
class ThrottledDirectionalFocusAction extends DirectionalFocusAction {
  @override
  void invoke(DirectionalFocusIntent intent) {
    if (!TvKeyThrottle.allowMove()) return;
    super.invoke(intent);
  }
}

/// Actions de l'application : celles de Flutter, avec le déplacement du focus
/// limité en cadence.
Map<Type, Action<Intent>> tvActions() {
  TvKeyThrottle.ensureHooked();
  return {
    ...WidgetsApp.defaultActions,
    DirectionalFocusIntent: ThrottledDirectionalFocusAction(),
  };
}
