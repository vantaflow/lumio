import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/addon_sync.dart';
import 'package:lumio/data/sync_providers.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/theme.dart';

/// Saisie de la phrase secrète de synchronisation des addons (12 caractères
/// au moins, saisie confirmée). La phrase reste sur l'appareil, dans le
/// stockage sécurisé ; le serveur ne la reçoit jamais.
///
/// [change] : changement de phrase (les addons sont rechiffrés et renvoyés),
/// sinon première saisie sur cet appareil. Se ferme avec `true` si enregistrée.
class PassphraseScreen extends ConsumerStatefulWidget {
  const PassphraseScreen({super.key, this.change = false});

  final bool change;

  @override
  ConsumerState<PassphraseScreen> createState() => _PassphraseScreenState();
}

class _PassphraseScreenState extends ConsumerState<PassphraseScreen> {
  final _phrase = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phrase.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final l = context.l10n;
    final p = _phrase.text;
    if (p.runes.length < minPassphraseLength) {
      setState(() => _error = l.passphraseErrShort);
      return;
    }
    if (p != _confirm.text) {
      setState(() => _error = l.passphraseErrMismatch);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sync = ref.read(addonSyncProvider);
      if (widget.change) {
        await sync.changePassphrase(p);
      } else {
        await sync.setPassphrase(p);
      }
      ref.invalidate(addonSyncStateProvider);
      // Envoi (ou réception) sans attendre le prochain cycle.
      final service = ref.read(syncServiceProvider);
      if (service != null) {
        await service.syncNow();
      }
      ref.invalidate(addonSyncStateProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l.passphraseErrSave;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return TvScaffold(
      onBack: () => Navigator.maybeOf(context)?.maybePop(),
      child: Scaffold(
        appBar: AppBar(title: Text(l.passphraseTitle)),
        body: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView(
              padding: const EdgeInsetsDirectional.all(LumioSpacing.xl),
              children: [
                Text(l.passphraseIntro),
                const SizedBox(height: LumioSpacing.lg),
                TextField(
                  key: const ValueKey('passphrase:phrase'),
                  controller: _phrase,
                  autofocus: true,
                  enabled: !_busy,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(labelText: l.passphraseLabel),
                ),
                const SizedBox(height: LumioSpacing.md),
                TextField(
                  key: const ValueKey('passphrase:confirm'),
                  controller: _confirm,
                  enabled: !_busy,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: l.passphraseConfirmLabel,
                  ),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: LumioSpacing.md),
                FilledButton(
                  key: const ValueKey('passphrase:save'),
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l.passphraseSave),
                ),
                if (_error != null) ...[
                  const SizedBox(height: LumioSpacing.md),
                  Text(
                    _error!,
                    key: const ValueKey('passphrase:error'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
