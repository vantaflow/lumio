import 'package:flutter/material.dart';
import 'package:lumio/ui/theme.dart';

/// Anneau de focus Lumio autour d'un composant Material sans anneau propre
/// (ListTile, SwitchListTile, ChoiceChip...) : trait [lumioFocusWidth] dans la
/// couleur `focusRing` dès qu'un descendant est focalisé. Dessiné par-dessus,
/// sans décalage de mise en page.
class FocusRing extends StatefulWidget {
  const FocusRing({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(LumioRadius.md)),
  });

  final Widget child;
  final BorderRadius borderRadius;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (f) => setState(() => _focused = f),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          border: _focused
              ? Border.all(
                  color: context.lumio.focusRing,
                  width: lumioFocusWidth,
                )
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}
