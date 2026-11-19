import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
    _rescueLater(previousRoute, prefer: node);
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

  void _rescueLater(Route<dynamic>? route, {FocusNode? prefer}) {
    if (route == null) return;
    // Plusieurs tentatives : la transition et la reconstruction de la liste
    // prennent quelques images sur une box lente.
    for (final ms in const [0, 120, 350, 800]) {
      if (ms == 0) {
        SchedulerBinding.instance.addPostFrameCallback(
          (_) => rescueFocus(route, prefer: prefer),
        );
      } else {
        Future<void>.delayed(
          Duration(milliseconds: ms),
          () => rescueFocus(route, prefer: prefer),
        );
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

/// Donne le focus à [prefer] (s'il vit encore) ou au premier élément de la
/// route, si rien de valable n'est focalisé dans la route courante.
void rescueFocus(Route<dynamic> route, {FocusNode? prefer}) {
  if (!route.isCurrent || route is! ModalRoute) return;
  final ctx = route.subtreeContext;
  if (ctx == null || !ctx.mounted) return;
  final scope = FocusScope.of(ctx);
  if (!scope.canRequestFocus) return;
  if (_healthy(FocusManager.instance.primaryFocus, scope)) return;
  if (prefer != null &&
      prefer.context != null &&
      prefer.canRequestFocus &&
      prefer.ancestors.contains(scope)) {
    prefer.requestFocus();
    return;
  }
  final policy =
      FocusTraversalGroup.maybeOf(ctx) ?? ReadingOrderTraversalPolicy();
  final first = policy.findFirstFocus(scope);
  first?.requestFocus();
}
