import 'package:flutter/material.dart';

/// Parcours du focus par rangées : haut et bas vont toujours à la rangée
/// voisine (jamais une rangée sautée parce qu'elle n'a pas de carte dans la
/// même colonne), sur la carte la plus proche horizontalement. Gauche et
/// droite gardent le parcours par défaut.
class RowTraversalPolicy extends ReadingOrderTraversalPolicy {
  /// Deux éléments dont les centres verticaux diffèrent de moins que cela
  /// sont dans la même rangée.
  static const _sameRow = 40.0;

  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    if (direction != TraversalDirection.up &&
        direction != TraversalDirection.down) {
      return super.inDirection(currentNode, direction);
    }
    final scope = currentNode.nearestScope;
    if (scope == null) return super.inDirection(currentNode, direction);
    final from = currentNode.rect;
    final down = direction == TraversalDirection.down;
    final candidates = <FocusNode>[
      for (final n in scope.traversalDescendants)
        if (n != currentNode &&
            n.canRequestFocus &&
            !n.skipTraversal &&
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
    final target = row.first;
    requestFocusCallback(target);
    return true;
  }
}

/// Entoure [child] du parcours par rangées.
class RowTraversalGroup extends StatelessWidget {
  const RowTraversalGroup({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      FocusTraversalGroup(policy: RowTraversalPolicy(), child: child);
}
