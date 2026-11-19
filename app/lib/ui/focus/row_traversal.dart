import 'package:flutter/material.dart';

/// Parcours du focus par rangées : haut et bas vont toujours à la rangée
/// voisine (jamais une rangée sautée parce qu'elle n'a pas de carte dans la
/// même colonne), sur la carte la plus proche horizontalement. Gauche et
/// droite gardent le parcours par défaut, sauf avec [strictRow] : ils restent
/// alors dans la rangée courante (grille de résultats : « droite » ne saute
/// jamais sur une puce située plus haut) et ne quittent la rangée que s'il n'y
/// a plus de carte de ce côté.
class RowTraversalPolicy extends ReadingOrderTraversalPolicy {
  RowTraversalPolicy({this.strictRow = false, this.preferUp});

  final bool strictRow;

  /// Cible préférée d'une flèche haute : si elle fait partie de la rangée
  /// voisine (onglet courant d'une barre), elle passe avant la carte la plus
  /// proche horizontalement.
  final FocusNode? preferUp;

  /// Deux éléments dont les centres verticaux diffèrent de moins que cela
  /// sont dans la même rangée.
  static const _sameRow = 40.0;

  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    final scope = currentNode.nearestScope;
    if (direction != TraversalDirection.up &&
        direction != TraversalDirection.down) {
      if (strictRow && scope != null) {
        if (_sideInRow(currentNode, direction, scope)) return true;
        // Fin de rangée à droite : on reste sur la dernière carte.
        if (direction == TraversalDirection.right) return true;
      }
      return super.inDirection(currentNode, direction);
    }
    if (scope == null) return super.inDirection(currentNode, direction);
    final from = currentNode.rect;
    final down = direction == TraversalDirection.down;
    final candidates = <FocusNode>[
      for (final n in scope.traversalDescendants)
        if (n != currentNode &&
            n.canRequestFocus &&
            !n.skipTraversal &&
            (!strictRow || _inGroup(n)) &&
            (down
                ? n.rect.center.dy > from.center.dy + _sameRow
                : n.rect.center.dy < from.center.dy - _sameRow))
          n,
    ];
    if (candidates.isEmpty) return super.inDirection(currentNode, direction);
    // Rangée voisine : celle dont le centre vertical est le plus proche.
    double dy(FocusNode n) => (n.rect.center.dy - from.center.dy).abs();
    final nearest = candidates.map(dy).reduce((a, b) => a < b ? a : b);
    final row = [
      for (final n in candidates)
        if (dy(n) - nearest < _sameRow) n,
    ];
    double dx(FocusNode n) => (n.rect.center.dx - from.center.dx).abs();
    row.sort((a, b) => dx(a).compareTo(dx(b)));
    final pref = preferUp;
    final target = !down && pref != null && row.contains(pref)
        ? pref
        : row.first;
    requestFocusCallback(target);
    return true;
  }

  /// Vrai si [n] est un élément de ce groupe de parcours.
  bool _inGroup(FocusNode n) {
    final ctx = n.context;
    return ctx != null && identical(FocusTraversalGroup.maybeOf(ctx), this);
  }

  /// Passe à la carte voisine de la même rangée, du côté demandé ; faux s'il
  /// n'y en a pas.
  bool _sideInRow(
    FocusNode from,
    TraversalDirection direction,
    FocusScopeNode scope,
  ) {
    final r = from.rect;
    final right = direction == TraversalDirection.right;
    FocusNode? best;
    var bestGap = double.infinity;
    for (final n in scope.traversalDescendants) {
      if (n == from || !n.canRequestFocus || n.skipTraversal) continue;
      // Seules les cartes de ce groupe (la grille), pas les puces voisines.
      if (!_inGroup(n)) continue;
      final c = n.rect;
      if ((c.center.dy - r.center.dy).abs() >= _sameRow) continue;
      final gap = right ? c.center.dx - r.center.dx : r.center.dx - c.center.dx;
      if (gap <= 0 || gap >= bestGap) continue;
      best = n;
      bestGap = gap;
    }
    if (best == null) return false;
    requestFocusCallback(best);
    return true;
  }
}

/// Entoure [child] du parcours par rangées.
class RowTraversalGroup extends StatelessWidget {
  const RowTraversalGroup({
    required this.child,
    this.strictRow = false,
    this.preferUp,
    super.key,
  });
  final Widget child;

  /// Voir [RowTraversalPolicy.preferUp].
  final FocusNode? preferUp;

  /// Gauche et droite restent dans la rangée (voir [RowTraversalPolicy]).
  final bool strictRow;

  @override
  Widget build(BuildContext context) => FocusTraversalGroup(
    policy: RowTraversalPolicy(strictRow: strictRow, preferUp: preferUp),
    child: child,
  );
}
