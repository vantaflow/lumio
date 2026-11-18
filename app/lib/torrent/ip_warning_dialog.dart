import 'package:flutter/material.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/ui/focus/focus_ring.dart';

/// Avertissement de première utilisation : les autres pairs voient l'adresse
/// IP, un VPN est recommandé. `true` = continuer. Le focus part sur
/// « Continuer » ; télécommande : gauche/droite entre les deux boutons.
Future<bool> showIpWarningDialog(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final l = ctx.l10n;
      return AlertDialog(
        title: Text(l.torrentIpWarningTitle),
        content: Text(l.torrentIpWarningBody),
        actions: [
          FocusRing(
            child: TextButton(
              key: const ValueKey('ipWarning:cancel'),
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.torrentIpWarningCancel),
            ),
          ),
          FocusRing(
            child: FilledButton(
              key: const ValueKey('ipWarning:continue'),
              autofocus: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.torrentIpWarningContinue),
            ),
          ),
        ],
      );
    },
  );
  return ok ?? false;
}
