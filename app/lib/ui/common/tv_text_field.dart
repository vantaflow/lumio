import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';

/// Champ de saisie adapté à la télécommande (audit D4).
///
/// Sur Android TV, un `TextField` ouvre le clavier à l'écran dès qu'il prend le
/// focus (même en simple navigation) et la flèche bas ne sort plus du champ.
/// Ici : le champ se focalise sans clavier et les flèches changent d'élément ;
/// le clavier ne s'ouvre qu'avec OK / Entrée (centre du D-pad) et se referme
/// à la validation ou quand le focus s'en va. Hors TV : `TextField` normal.
class TvTextField extends StatefulWidget {
  const TvTextField({
    super.key,
    this.controller,
    this.decoration,
    this.autofocus = false,
    this.maxLength,
    this.textInputAction,
    this.keyboardType,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.style,
    this.minLines,
    this.maxLines = 1,
    this.focusNode,
    this.autocorrect = true,
    this.enableSuggestions = true,
  });

  final TextEditingController? controller;
  final InputDecoration? decoration;
  final bool autofocus;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextStyle? style;
  final int? minLines;
  final int? maxLines;
  final FocusNode? focusNode;
  final bool autocorrect;
  final bool enableSuggestions;

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  FocusNode? _own;
  bool _editing = false;

  FocusNode get _node => widget.focusNode ?? (_own ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_node.hasFocus) _stopEditing();
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChange);
    _own?.dispose();
    super.dispose();
  }

  void _stopEditing() {
    if (_editing) setState(() => _editing = false);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_editing) {
      // Retour : referme le clavier sans quitter l'écran.
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.goBack) {
        _stopEditing();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.gameButtonA) {
      if (event is KeyDownEvent) setState(() => _editing = true);
      return KeyEventResult.handled;
    }
    final dir = switch (k) {
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      LogicalKeyboardKey.arrowUp => TraversalDirection.up,
      LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
      LogicalKeyboardKey.arrowRight => TraversalDirection.right,
      _ => null,
    };
    if (dir != null) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        FocusScope.of(context).focusInDirection(dir);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tv = isTvLayout(context);
    _node.onKeyEvent = tv ? _onKey : null;
    return TextField(
      controller: widget.controller,
      focusNode: _node,
      decoration: widget.decoration,
      autofocus: widget.autofocus,
      maxLength: widget.maxLength,
      textInputAction: widget.textInputAction,
      keyboardType: widget.keyboardType,
      obscureText: widget.obscureText,
      textCapitalization: widget.textCapitalization,
      onChanged: widget.onChanged,
      style: widget.style,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      autocorrect: widget.autocorrect,
      enableSuggestions: widget.enableSuggestions,
      readOnly: tv && !_editing,
      showCursor: tv ? _editing : null,
      onSubmitted: (v) {
        _stopEditing();
        widget.onSubmitted?.call(v);
      },
      onTapOutside: tv ? (_) => _stopEditing() : null,
    );
  }
}
