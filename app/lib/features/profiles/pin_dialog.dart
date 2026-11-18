import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

/// Saisie rendue par [showPinDialog] : le PIN tapé, ou « PIN oublié ».
class PinEntry {
  const PinEntry.pin(String this.pin) : forgot = false;
  const PinEntry.forgot() : pin = null, forgot = true;

  final String? pin;
  final bool forgot;
}

String _lockMessage(Duration remaining, AppLocalizations l) {
  final min = (remaining.inSeconds / 60).ceil().clamp(1, 60);
  return l.tooManyTries(min);
}

/// Boîte de saisie du PIN : 4 points, clavier numérique focalisable à la
/// télécommande (haut/bas/gauche/droite + OK) et chiffres du clavier. Retour
/// annule. Sans [verify], le PIN saisi est rendu tel quel ; avec, il n'est
/// rendu que si la vérification renvoie [PinResult.ok].
Future<PinEntry?> showPinDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
  Future<PinResult> Function(String pin)? verify,
  Future<Duration> Function()? lockRemaining,
  String? wrongMessage,
  bool allowForgot = false,
}) => showDialog<PinEntry>(
  context: context,
  builder: (_) => PinDialog(
    title: title,
    subtitle: subtitle,
    verify: verify,
    lockRemaining: lockRemaining,
    wrongMessage: wrongMessage,
    allowForgot: allowForgot,
  ),
);

class PinDialog extends StatefulWidget {
  const PinDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.verify,
    this.lockRemaining,
    this.wrongMessage,
    this.allowForgot = false,
  });

  final String title;
  final String? subtitle;
  final Future<PinResult> Function(String pin)? verify;
  final Future<Duration> Function()? lockRemaining;
  final String? wrongMessage;
  final bool allowForgot;

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  String _digits = '';
  bool _busy = false;
  bool _locked = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _checkLock();
  }

  Future<void> _checkLock() async {
    final remaining = await widget.lockRemaining?.call();
    if (!mounted || remaining == null || remaining <= Duration.zero) return;
    setState(() {
      _locked = true;
      _message = _lockMessage(remaining, context.l10n);
    });
  }

  void _cancel() => Navigator.of(context).pop();

  void _add(String d) {
    if (_busy || _locked || _digits.length >= 4) return;
    setState(() {
      _digits += d;
      _message = null;
    });
    if (_digits.length == 4) _submit();
  }

  void _erase() {
    if (_busy || _digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  Future<void> _submit() async {
    final pin = _digits;
    final verify = widget.verify;
    if (verify == null) {
      Navigator.of(context).pop(PinEntry.pin(pin));
      return;
    }
    setState(() => _busy = true);
    PinResult result;
    Duration remaining = Duration.zero;
    try {
      result = await verify(pin);
      if (result == PinResult.locked) {
        remaining =
            await widget.lockRemaining?.call() ?? PinLockout.lockDuration;
      }
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _digits = '';
        _message = context.l10n.pinCheckFailed;
      });
      return;
    }
    if (!mounted) return;
    switch (result) {
      case PinResult.ok:
        Navigator.of(context).pop(PinEntry.pin(pin));
      case PinResult.wrong:
        setState(() {
          _busy = false;
          _digits = '';
          _message = widget.wrongMessage ?? context.l10n.pinWrong;
        });
      case PinResult.locked:
        setState(() {
          _busy = false;
          _digits = '';
          _locked = true;
          _message = _lockMessage(remaining, context.l10n);
        });
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.backspace || k == LogicalKeyboardKey.delete) {
      _erase();
      return KeyEventResult.handled;
    }
    final ch = event.character;
    if (ch != null && RegExp(r'^[0-9]$').hasMatch(ch)) {
      _add(ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: c.surfaceRaised,
      child: TvScaffold(
        onBack: _cancel,
        child: Focus(
          canRequestFocus: false,
          onKeyEvent: _onKey,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(LumioSpacing.lg),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: LumioSpacing.sm),
                      Text(
                        widget.subtitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: c.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: LumioSpacing.lg),
                    _Dots(filled: _digits.length),
                    const SizedBox(height: LumioSpacing.sm),
                    SizedBox(
                      height: 48,
                      child: Center(
                        child: Text(
                          _message ?? '',
                          key: const ValueKey('pin-message'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: c.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    _Pad(
                      enabled: !_locked && !_busy,
                      onDigit: _add,
                      onErase: _erase,
                      onCancel: _cancel,
                    ),
                    if (widget.allowForgot) ...[
                      const SizedBox(height: LumioSpacing.sm),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).pop(const PinEntry.forgot()),
                        child: Text(context.l10n.pinForgot),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.filled});
  final int filled;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    return Semantics(
      label: context.l10n.pinDotsSemantic(filled),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              key: ValueKey('dot-$i'),
              width: 24,
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: LumioSpacing.sm),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? c.accent : Colors.transparent,
                border: Border.all(color: c.accent, width: 2),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pad extends StatelessWidget {
  const _Pad({
    required this.enabled,
    required this.onDigit,
    required this.onErase,
    required this.onCancel,
  });

  final bool enabled;
  final void Function(String) onDigit;
  final VoidCallback onErase;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget key(
      String label,
      VoidCallback onTap, {
      String? semantic,
      bool autofocus = false,
      bool alwaysEnabled = false,
    }) => Padding(
      padding: const EdgeInsets.all(LumioSpacing.sm),
      child: FocusableCard(
        autofocus: autofocus,
        enabled: enabled || alwaysEnabled,
        semanticLabel: semantic ?? l.digitSemantic(label),
        onSelect: onTap,
        borderRadius: BorderRadius.circular(LumioRadius.sm),
        child: _KeyFace(label: label),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final d in row)
                key(d, () => onDigit(d), autofocus: d == '1'),
            ],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            key(l.kbErase, onErase, semantic: l.eraseLastDigit),
            key('0', () => onDigit('0')),
            key(l.cancel, onCancel, semantic: l.cancel, alwaysEnabled: true),
          ],
        ),
      ],
    );
  }
}

class _KeyFace extends StatelessWidget {
  const _KeyFace({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    final isDigit = label.length == 1;
    return Container(
      width: 88,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surfaceFocus,
        borderRadius: BorderRadius.circular(LumioRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: c.text,
          fontSize: isDigit ? 28 : 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Affiche le code de récupération, une seule fois.
Future<void> showRecoveryCodeDialog(BuildContext context, String code) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final c = ctx.lumio;
        return AlertDialog(
          title: Text(ctx.l10n.recoveryTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ctx.l10n.recoveryBody),
              const SizedBox(height: LumioSpacing.md),
              Center(
                child: SelectableText(
                  RecoveryCode.format(code),
                  key: const ValueKey('recovery-code'),
                  style: TextStyle(
                    color: c.accent,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              autofocus: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(ctx.l10n.recoveryNoted),
            ),
          ],
        );
      },
    );

/// Saisie du code de récupération (clavier du système).
Future<String?> _askRecoveryCode(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.l10n.recoveryTitle),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(hintText: 'ABCDE-FGHJK'),
        onSubmitted: (v) => Navigator.of(ctx).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(ctx.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: Text(ctx.l10n.continueAction),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

void _toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Saisie d'un nouveau PIN en deux temps ; renvoie le PIN confirmé.
Future<String?> askNewPin(BuildContext context) async {
  final first = await showPinDialog(
    context,
    title: context.l10n.choosePin,
    subtitle: context.l10n.pinHint,
  );
  final pin = first?.pin;
  if (pin == null || !context.mounted) return null;
  final second = await showPinDialog(
    context,
    title: context.l10n.confirmPin,
    verify: (p) async => p == pin ? PinResult.ok : PinResult.wrong,
    wrongMessage: context.l10n.pinMismatch,
  );
  return second?.pin;
}

/// Crée le PIN parent (saisie confirmée puis code de récupération).
Future<bool> createParentPinFlow(BuildContext context, WidgetRef ref) async {
  final pin = await askNewPin(context);
  if (pin == null || !context.mounted) return false;
  try {
    final code = await ref.read(profileRepositoryProvider).createParentPin(pin);
    if (!context.mounted) return true;
    await showRecoveryCodeDialog(context, code);
    return true;
  } on Object {
    if (context.mounted) _toast(context, context.l10n.pinSaveFailed);
    return false;
  }
}

/// PIN oublié : code de récupération puis nouveau PIN.
Future<bool> recoverParentPinFlow(BuildContext context, WidgetRef ref) async {
  final code = await _askRecoveryCode(context);
  if (code == null || !context.mounted) return false;
  final pin = await askNewPin(context);
  if (pin == null || !context.mounted) return false;
  try {
    final r = await ref
        .read(profileRepositoryProvider)
        .resetPinWithRecovery(code, pin);
    if (!context.mounted) return r.result == PinResult.ok;
    switch (r.result) {
      case PinResult.ok:
        await showRecoveryCodeDialog(context, r.newRecoveryCode!);
        return true;
      case PinResult.wrong:
        _toast(context, context.l10n.recoveryWrong);
        return false;
      case PinResult.locked:
        _toast(context, context.l10n.tooManyTriesLater);
        return false;
    }
  } on Object {
    if (context.mounted) _toast(context, context.l10n.recoveryFailed);
    return false;
  }
}

/// Exige le PIN parent (le crée s'il n'existe pas encore). Vrai si l'accès
/// est autorisé.
Future<bool> verifyParentPinFlow(
  BuildContext context,
  WidgetRef ref, {
  String? title,
  String? subtitle,
}) async {
  final repo = ref.read(profileRepositoryProvider);
  final bool hasPin;
  try {
    hasPin = await repo.hasParentPin();
  } on Object {
    // Échec fermé : sans savoir si un PIN existe, on n'autorise rien.
    if (context.mounted) {
      _toast(context, context.l10n.parentalUnavailable);
    }
    return false;
  }
  if (!hasPin) {
    if (!context.mounted) return false;
    return createParentPinFlow(context, ref);
  }
  if (!context.mounted) return false;
  final entry = await showPinDialog(
    context,
    title: title ?? context.l10n.parentPin,
    subtitle: subtitle,
    verify: repo.verifyParentPin,
    lockRemaining: repo.lockRemaining,
    allowForgot: true,
  );
  if (entry == null) return false;
  if (entry.forgot) {
    if (!context.mounted) return false;
    return recoverParentPinFlow(context, ref);
  }
  return true;
}

/// Contrôle parental : le profil enfant actif doit saisir le PIN parent pour
/// ouvrir les réglages/addons ou changer de profil. Libre pour un adulte.
Future<bool> requireParent(BuildContext context, WidgetRef ref) async {
  final current = ref.read(currentProfileProvider);
  if (current == null || !current.isKid) return true;
  return verifyParentPinFlow(context, ref, subtitle: context.l10n.askParent);
}
