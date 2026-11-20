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
    // La rangée voisine se cherche d'abord dans la même liste verticale que la
    // carte courante : sinon la barre haute (fixe, donc « plus proche » dès que
    // la liste a défilé) passait avant la rangée précédente, masquée sous elle.
    final ctx = currentNode.context;
    final list = ctx == null
        ? null
        : Scrollable.maybeOf(ctx, axis: Axis.vertical);
    if (list != null) {
      final sameList = [
        for (final n in candidates)
          if (n.context != null &&
              identical(
                Scrollable.maybeOf(n.context!, axis: Axis.vertical),
                list,
              ))
            n,
      ];
      if (sameList.isNotEmpty) {
        candidates
          ..clear()
          ..addAll(sameList);
      }
    }
    // Rangée voisine : celle dont le centre vertical est le plus proche.
    double dy(FocusNode n) => (n.rect.center.dy - from.center.dy).abs();
    final nearest = candidates.map(dy).reduce((a, b) => a < b ? a : b);
    final row = [
      for (final n in candidates)
        if (dy(n) - nearest < _sameRow) n,
    ];
    double dx(FocusNode n) => (n.rect.center.dx - from.center.dx).abs();
    row.sort((a, b) => dx(a).compareTo(dx(b)));
    // Une rangée en chargement (sans carte focalisable) entre la carte
    // courante et la cible : on ne la saute pas, on attend qu'elle arrive.
    final targetY = row.first.rect.center.dy;
    for (final n in scope.descendants) {
      if (n is! RowPlaceholderNode) continue;
      final y = n.rect.center.dy;
      final between = down
          ? y > from.center.dy + _sameRow && y < targetY - _sameRow
          : y < from.center.dy - _sameRow && y > targetY + _sameRow;
      if (between) return true;
    }
    final pref = preferUp;
    if (const String.fromEnvironment('LUMIO_PERF') == '1') {
      // ignore: avoid_print
      print(
        'LUMIO_PERF traversal ${direction.name} from=${from.center.dy.round()} '
        'rowDy=${nearest.round()} candidates=${candidates.length} '
        'row=${row.length} first=${row.first.rect.center.dy.round()} '
        'pref=${pref != null && row.contains(pref)}',
      );
    }
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

/// Nœud repère d'une rangée en chargement : invisible au parcours, il sert à
/// ne pas sauter la rangée (voir [RowTraversalPolicy]).
class RowPlaceholderNode extends FocusNode {
  RowPlaceholderNode()
    : super(
        skipTraversal: true,
        canRequestFocus: false,
        debugLabel: 'RowPlaceholder',
      );
}

/// Entoure une rangée en cours de chargement : « bas » / « haut » attendent
/// plutôt que de sauter par-dessus pour atterrir sur une rangée lointaine.
class RowPlaceholder extends StatefulWidget {
  const RowPlaceholder({required this.child, super.key});
  final Widget child;

  @override
  State<RowPlaceholder> createState() => _RowPlaceholderState();
}

class _RowPlaceholderState extends State<RowPlaceholder> {
  final _node = RowPlaceholderNode();

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _node,
    skipTraversal: true,
    canRequestFocus: false,
    child: widget.child,
  );
}
