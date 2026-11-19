// ignore_for_file: sort_child_properties_last
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/ui/common/tv_dialogs.dart';
import 'package:lumio/ui/focus/tv_button.dart';

/// Avertissement de première utilisation : les autres pairs voient l'adresse
/// IP, un VPN est recommandé. `true` = continuer. Le focus part sur
/// « Continuer » ; télécommande : gauche/droite passent d'un bouton à l'autre.
Future<bool> showIpWarningDialog(BuildContext context) async {
  final ok = await showTvPanel<bool>(
    context,
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
    // Maquette P04 : panneau de 920, texte 28, Annuler (texte) + Continuer.
    return Focus(
      canRequestFocus: false,
      onKeyEvent: _onKey,
      child: TvPanel(
        title: l.torrentIpWarningTitle,
        width: 920,
        fitActions: true,
        contentPadding: EdgeInsets.zero,
        gap: 20,
        actionsGap: 26,
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 44),
        children: [
          Text(
            l.torrentIpWarningBody,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 28,
              height: 1.4,
              color: Color(0xFFC9D0DA),
            ),
          ),
        ],
        actions: [
          TvButton(
            key: const ValueKey('ipWarning:cancel'),
            focusNode: _cancel,
            kind: TvButtonKind.ghost,
            label: l.torrentIpWarningCancel,
            height: 76,
            fontSize: 28,
            horizontalPadding: 40,
            onPressed: () => Navigator.pop(context, false),
          ),
          TvButton(
            key: const ValueKey('ipWarning:continue'),
            focusNode: _continue,
            autofocus: true,
            label: l.torrentIpWarningContinue,
            height: 76,
            fontSize: 28,
            horizontalPadding: 40,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
  }
}
