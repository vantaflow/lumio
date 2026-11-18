import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumio/ui/theme.dart';

/// Durée d'appui sur Select à partir de laquelle on parle d'appui long.
const Duration lumioLongPress = Duration(milliseconds: 500);

final _selectKeys = {
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.gameButtonA,
  LogicalKeyboardKey.space,
};

/// Échelle de focus imposée aux cartes descendantes (rangées : 1,08).
class FocusableCardScale extends InheritedWidget {
  const FocusableCardScale({
    super.key,
    required this.scale,
    required super.child,
  });

  final double scale;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FocusableCardScale>()?.scale ??
      1.06;

  @override
  bool updateShouldNotify(FocusableCardScale old) => scale != old.scale;
}

/// Carte focalisable à la télécommande : anneau de focus 4 dp décalé de 4 dp
/// (dessiné hors de l'enfant, aucun décalage de mise en page), échelle 1,06
/// (1,08 en rangée) animée en 160 ms, sans animation avec « réduire les
/// animations ».
class FocusableCard extends StatefulWidget {
  const FocusableCard({
    super.key,
    required this.child,
    required this.onSelect,
    this.onLongPress,
    this.autofocus = false,
    this.focusNode,
    this.scale,
    this.borderRadius = const BorderRadius.all(Radius.circular(LumioRadius.md)),
    this.semanticLabel,
    this.enabled = true,
    this.onFocusChange,
  });

  final Widget child;
  final VoidCallback onSelect;
  final VoidCallback? onLongPress;
  final bool autofocus;
  final FocusNode? focusNode;

  /// Échelle au focus (1,06 par défaut ; 1,08 pour les cartes de rangée).
  final double? scale;
  final BorderRadius borderRadius;

  /// Étiquette d'accessibilité (titre + source).
  final String? semanticLabel;
  final bool enabled;
  final ValueChanged<bool>? onFocusChange;

  @override
  State<FocusableCard> createState() => _FocusableCardState();
}

class _FocusableCardState extends State<FocusableCard> {
  bool _focused = false;
  Timer? _timer;
  bool _longFired = false;
  bool _selectDown = false;

  @override
  void didUpdateWidget(FocusableCard old) {
    super.didUpdateWidget(old);
    if (!widget.enabled || widget.onLongPress == null) {
      _timer?.cancel();
      _selectDown = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.enabled || !_selectKeys.contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    final hasLong = widget.onLongPress != null;
    if (event is KeyDownEvent) {
      if (_selectDown) return KeyEventResult.handled;
      _selectDown = true;
      _longFired = false;
      if (hasLong) {
        _timer?.cancel();
        _timer = Timer(lumioLongPress, () {
          _longFired = true;
          widget.onLongPress?.call();
        });
      } else {
        widget.onSelect();
      }
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) {
      // Relâchement orphelin (la touche a été pressée avant l'arrivée du
      // focus sur cette carte) : on l'ignore.
      if (!_selectDown) return KeyEventResult.ignored;
      _selectDown = false;
      if (hasLong) {
        _timer?.cancel();
        if (!_longFired) widget.onSelect();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.handled; // répétition : absorbée
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final ring = context.lumio.focusRing;
    const out = lumioFocusOffset + lumioFocusWidth;
    final scale = _focused && widget.enabled
        ? (widget.scale ?? FocusableCardScale.of(context))
        : 1.0;

    Widget body = Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (_focused)
          Positioned(
            left: -out,
            top: -out,
            right: -out,
            bottom: -out,
            child: IgnorePointer(
              child: DecoratedBox(
                key: const ValueKey('focus-ring'),
                decoration: BoxDecoration(
                  borderRadius:
                      widget.borderRadius +
                      const BorderRadius.all(Radius.circular(out)),
                  border: Border.all(color: ring, width: lumioFocusWidth),
                ),
              ),
            ),
          ),
      ],
    );

    body = AnimatedScale(
      scale: scale,
      duration: reduce ? Duration.zero : LumioMotion.scaleCard,
      curve: Curves.easeOut,
      child: body,
    );

    return Semantics(
      container: true,
      button: true,
      enabled: widget.enabled,
      focusable: widget.enabled,
      focused: _focused,
      label: widget.semanticLabel,
      onTap: widget.enabled ? widget.onSelect : null,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      // Avec une étiquette, un seul nœud d'accessibilité décrit la carte
      // (pas de doublon « focus/tap » sans libellé pour le lecteur d'écran).
      child: ExcludeSemantics(
        excluding: widget.semanticLabel != null,
        child: Focus(
          includeSemantics: false,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          canRequestFocus: widget.enabled,
          onKeyEvent: _onKey,
          onFocusChange: (f) {
            if (!f) {
              _timer?.cancel();
              _selectDown = false;
            }
            setState(() => _focused = f);
            widget.onFocusChange?.call(f);
          },
          child: Builder(
            builder: (ctx) => GestureDetector(
              excludeFromSemantics: true,
              behavior: HitTestBehavior.opaque,
              // Un toucher ou un clic déplace aussi le focus sur la carte.
              onTap: widget.enabled
                  ? () {
                      Focus.maybeOf(ctx)?.requestFocus();
                      widget.onSelect();
                    }
                  : null,
              onLongPress: widget.enabled ? widget.onLongPress : null,
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}
