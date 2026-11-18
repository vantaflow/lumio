import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/ui/focus/focus_ring.dart';

/// Avertissement de première utilisation : les autres pairs voient l'adresse
/// IP, un VPN est recommandé. `true` = continuer. Le focus part sur
/// « Continuer » ; télécommande : gauche/droite passent d'un bouton à l'autre.
Future<bool> showIpWarningDialog(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _IpWarningDialog(),
  );
  return ok ?? false;
}

class _IpWarningDialog extends StatefulWidget {
  const _IpWarningDialog();

  @override
  State<_IpWarningDialog> createState() => _IpWarningDialogState();
}

class _IpWarningDialogState extends State<_IpWarningDialog> {
  final _cancel = FocusNode(debugLabel: 'ipWarning:cancel');
  final _continue = FocusNode(debugLabel: 'ipWarning:continue');

  @override
  void dispose() {
    _cancel.dispose();
    _continue.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _cancel.requestFocus();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      _continue.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Focus(
      canRequestFocus: false,
      onKeyEvent: _onKey,
      child: AlertDialog(
        title: Text(l.torrentIpWarningTitle),
        content: Text(l.torrentIpWarningBody),
        actions: [
          FocusRing(
            child: TextButton(
              key: const ValueKey('ipWarning:cancel'),
              focusNode: _cancel,
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.torrentIpWarningCancel),
            ),
          ),
          FocusRing(
            child: FilledButton(
              key: const ValueKey('ipWarning:continue'),
              focusNode: _continue,
              autofocus: true,
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.torrentIpWarningContinue),
            ),
          ),
        ],
      ),
    );
  }
}
