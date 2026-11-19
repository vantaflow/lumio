import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:lumio/ui/focus/focus_return.dart';

/// Observateur de routes partagé : les écrans qui doivent réagir à un autre
/// écran poussé par-dessus (RouteAware) s'y abonnent.
final RouteObserver<ModalRoute<void>> appRouteObserver = _PageRouteObserver();

/// Ne signale que les écrans pleine page : un dialogue ou un panneau poussé
/// par-dessus un écran ne le « recouvre » pas (la confirmation d'adresse
/// locale doit laisser le serveur du téléphone en route).
class _PageRouteObserver extends RouteObserver<ModalRoute<void>> {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) super.didRemove(route, previousRoute);
  }
}

/// Restaure systématiquement le focus quand une route (écran ou dialogue) se
/// ferme ou s'ouvre : sans cela, si l'élément focalisé avant l'ouverture a
/// disparu (liste reconstruite, bouton remplacé), aucun élément n'a le focus
/// et OK / flèches agissent sur l'écran caché (audit D1).
///
/// - À l'ouverture d'une route, l'élément focalisé est mémorisé.
/// - À la fermeture, il est rendu s'il existe encore ; sinon le premier
///   élément focalisable de la route révélée prend le focus.
class FocusRescueObserver extends NavigatorObserver {
  final Map<Route<dynamic>, FocusNode?> _before = {};

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final f = FocusManager.instance.primaryFocus;
    _before[route] = (f == null || f is FocusScopeNode) ? null : f;
    _rescueLater(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final node = _before.remove(route);
    _rescueLater(previousRoute, prefer: node, returning: true);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _before.remove(route);
    _rescueLater(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _rescueLater(newRoute);
  }

  void _rescueLater(
    Route<dynamic>? route, {
    FocusNode? prefer,
    bool returning = false,
  }) {
    if (route == null) return;
    // Au retour, l'élément d'origine reprend le focus même si un autre l'a
    // pris entre-temps (onglet « Accueil » réclamé par la route révélée),
    // tant que l'utilisateur n'a pas touché à la télécommande depuis.
    final since = _KeyClock.now;
    // Plusieurs tentatives : la transition et la reconstruction de la liste
    // prennent quelques images sur une box lente.
    for (final ms in const [0, 120, 350, 800]) {
      void attempt() => rescueFocus(
        route,
        prefer: prefer,
        force: returning && !_KeyClock.since(since),
      );
      if (ms == 0) {
        SchedulerBinding.instance.addPostFrameCallback((_) => attempt());
      } else {
        Future<void>.delayed(Duration(milliseconds: ms), attempt);
      }
    }
  }
}

/// Vrai si [f] est un vrai élément focalisé de la portée [scope].
bool _healthy(FocusNode? f, FocusScopeNode scope) =>
    f != null &&
    f is! FocusScopeNode &&
    f.context != null &&
    f.canRequestFocus &&
    f.ancestors.contains(scope);

/// Horloge des touches : compte les appuis de télécommande pour savoir si
/// l'utilisateur a repris la main depuis un instant donné.
class _KeyClock {
  static int _count = 0;
  static bool _hooked = false;

  static int get now {
    if (!_hooked) {
      _hooked = true;
      HardwareKeyboard.instance.addHandler((e) {
        if (e is KeyDownEvent) _count++;
        return false;
      });
    }
    return _count;
  }

  static bool since(int mark) => _count != mark;
}

/// Donne le focus à [prefer] (s'il vit encore), sinon à l'élément mémorisé de
/// la route (voir [FocusReturn]), sinon au premier élément de la route, si
/// rien de valable n'est focalisé dans la route courante. Avec [force],
/// [prefer] reprend le focus même si un autre élément l'a déjà.
void rescueFocus(
  Route<dynamic> route, {
  FocusNode? prefer,
  bool force = false,
}) {
  if (!route.isCurrent || route is! ModalRoute) return;
  final ctx = route.subtreeContext;
  if (ctx == null || !ctx.mounted) return;
  final scope = FocusScope.of(ctx);
  if (!scope.canRequestFocus) return;
  final preferAlive =
      prefer != null &&
      prefer.context != null &&
      prefer.canRequestFocus &&
      prefer.ancestors.contains(scope);
  if (force) {
    if (preferAlive) {
      if (!prefer.hasPrimaryFocus) prefer.requestFocus();
      return;
    }
    if (FocusReturn.restore(route)) return;
  }
  if (_healthy(FocusManager.instance.primaryFocus, scope)) return;
  if (preferAlive) {
    prefer.requestFocus();
    return;
  }
  final policy =
      FocusTraversalGroup.maybeOf(ctx) ?? ReadingOrderTraversalPolicy();
  final first = policy.findFirstFocus(scope);
  first?.requestFocus();
}
