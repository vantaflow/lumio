import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/addon_sync.dart';
import 'package:lumio/data/sync_providers.dart';
import 'package:lumio/data/sync_service.dart';
import 'package:lumio/features/sync/passphrase_screen.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/theme.dart';

/// Compte de synchronisation : adresse e-mail, code reçu par e-mail, état de
/// la synchronisation, déconnexion et suppression du compte.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  String? _notice;
  String? _signedInEmail;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = ref.read(syncServiceProvider);
    String? email;
    if (s != null && await s.isSignedIn()) email = await s.email();
    if (!mounted) return;
    setState(() {
      _signedInEmail = email;
      _loaded = true;
    });
  }

  String _message(Object e) {
    final l = context.l10n;
    if (e is SyncException) {
      return switch (e.code) {
        SyncErrorCode.rejected => l.accountErrRejected,
        SyncErrorCode.rateLimited => l.accountErrRate,
        _ => l.accountErrUnavailable,
      };
    }
    return l.accountErrUnavailable;
  }

  Future<void> _run(Future<void> Function() op) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await op();
    } on Object catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$');

  Future<void> _sendCode() => _run(() async {
    final email = _email.text.trim();
    if (!_emailRe.hasMatch(email)) {
      setState(() => _error = context.l10n.accountErrInvalidEmail);
      return;
    }
    await ref.read(syncServiceProvider)!.requestCode(email);
    if (mounted) {
      setState(() {
        _codeSent = true;
        _notice = context.l10n.accountCodeSent;
      });
    }
  });

  Future<void> _signIn() => _run(() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    await ref.read(syncServiceProvider)!.signIn(_email.text, code);
    _code.clear();
    await _load();
  });

  Future<void> _signOut() => _run(() async {
    await ref.read(syncServiceProvider)!.signOut();
    if (!mounted) return;
    setState(() {
      _signedInEmail = null;
      _codeSent = false;
      _notice = context.l10n.accountSignedOutDone;
    });
  });

  Future<void> _delete() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l.accountDeleteConfirm),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.accountDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      await ref.read(syncServiceProvider)!.deleteAccount();
      if (!mounted) return;
      setState(() {
        _signedInEmail = null;
        _codeSent = false;
        _notice = context.l10n.accountDeleted;
      });
    });
  }

  Future<void> _openPassphrase({required bool change}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PassphraseScreen(change: change)),
    );
    ref.invalidate(addonSyncStateProvider);
  }

  Future<void> _resetAddons() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l.passphraseResetConfirm),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            key: const ValueKey('account:resetConfirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.passphraseReset),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      await ref.read(addonSyncProvider).requestReset();
      ref.invalidate(addonSyncStateProvider);
      unawaited(ref.read(syncServiceProvider)?.syncNow());
      if (mounted) setState(() => _notice = context.l10n.passphraseResetDone);
    });
  }

  Future<void> _pending(Future<void> Function() op) async {
    await _run(op);
    ref.invalidate(addonSyncStateProvider);
    ref.read(syncServiceProvider)?.syncNow();
  }

  /// État de la synchronisation des addons et actions sur la phrase secrète.
  List<Widget> _addonsSection() {
    final l = context.l10n;
    final theme = Theme.of(context);
    if (ref.read(syncServiceProvider)?.addons == null) return const [];
    final st = ref.watch(addonSyncStateProvider).value;
    if (st == null) return const [];
    final text = switch (st.status) {
      AddonSyncStatus.noPassphrase => l.addonSyncNoPassphrase,
      AddonSyncStatus.waiting => l.addonSyncWaiting,
      AddonSyncStatus.ready => l.addonSyncReady,
      AddonSyncStatus.wrongPassphrase => l.addonSyncWrong,
      AddonSyncStatus.tooLarge => l.addonSyncTooLarge,
      AddonSyncStatus.resetting => l.addonSyncResetting,
      AddonSyncStatus.phraseReset => l.addonSyncPhraseReset,
    };
    final hasPhrase =
        st.status != AddonSyncStatus.noPassphrase &&
        st.status != AddonSyncStatus.phraseReset &&
        st.status != AddonSyncStatus.resetting;
    final bad =
        st.status == AddonSyncStatus.wrongPassphrase ||
        st.status == AddonSyncStatus.tooLarge;
    return [
      Text(l.accountAddonsTitle, style: theme.textTheme.titleMedium),
      const SizedBox(height: LumioSpacing.sm),
      Text(
        text,
        key: const ValueKey('account:addonStatus'),
        style: bad ? TextStyle(color: theme.colorScheme.error) : null,
      ),
      if (st.failed > 0) ...[
        const SizedBox(height: LumioSpacing.sm),
        Text(l.addonSyncFailed(st.failed)),
      ],
      for (final p in st.pendingPrivate) ...[
        const SizedBox(height: LumioSpacing.sm),
        Text(l.addonSyncPrivate(p.label)),
        Row(
          children: [
            OutlinedButton(
              key: ValueKey('account:allow:${p.hash}'),
              onPressed: _busy
                  ? null
                  : () => _pending(
                      () => ref
                          .read(addonSyncProvider)
                          .installPending(p.hash)
                          .then((_) {}),
                    ),
              child: Text(l.addonSyncAllow),
            ),
            const SizedBox(width: LumioSpacing.sm),
            OutlinedButton(
              key: ValueKey('account:ignore:${p.hash}'),
              onPressed: _busy
                  ? null
                  : () => _pending(
                      () => ref.read(addonSyncProvider).dismissPending(p.hash),
                    ),
              child: Text(l.addonSyncIgnore),
            ),
          ],
        ),
      ],
      const SizedBox(height: LumioSpacing.md),
      if (st.status != AddonSyncStatus.resetting)
        OutlinedButton(
          key: const ValueKey('account:passphrase'),
          onPressed: _busy
              ? null
              : () =>
                    _openPassphrase(change: st.status == AddonSyncStatus.ready),
          child: Text(switch (st.status) {
            AddonSyncStatus.noPassphrase => l.passphraseSet,
            AddonSyncStatus.ready => l.passphraseChange,
            _ => l.passphraseEnter,
          }),
        ),
      if (hasPhrase) ...[
        const SizedBox(height: LumioSpacing.md),
        OutlinedButton(
          key: const ValueKey('account:resetAddons'),
          onPressed: _busy ? null : _resetAddons,
          child: Text(l.passphraseReset),
        ),
      ],
      const SizedBox(height: LumioSpacing.lg),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final status = ref.watch(syncStatusProvider).value;
    final signedIn = _signedInEmail != null && status != SyncStatus.signedOut;
    final statusText = switch (status) {
      SyncStatus.syncing => l.accountSyncSyncing,
      SyncStatus.offline => l.accountSyncOffline,
      _ => l.accountSyncIdle,
    };
    final children = <Widget>[
      if (!_loaded)
        const Center(child: CircularProgressIndicator())
      else if (signedIn) ...[
        Text(
          l.accountSignedInAs(_signedInEmail!),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: LumioSpacing.sm),
        Text(statusText, key: const ValueKey('account:status')),
        const SizedBox(height: LumioSpacing.lg),
        ..._addonsSection(),
        FilledButton(
          key: const ValueKey('account:syncNow'),
          autofocus: true,
          onPressed: _busy
              ? null
              : () => ref.read(syncServiceProvider)!.syncNow(),
          child: Text(l.accountSyncNow),
        ),
        const SizedBox(height: LumioSpacing.md),
        OutlinedButton(
          key: const ValueKey('account:signOut'),
          onPressed: _busy ? null : _signOut,
          child: Text(l.accountSignOut),
        ),
        const SizedBox(height: LumioSpacing.md),
        OutlinedButton(
          key: const ValueKey('account:delete'),
          onPressed: _busy ? null : _delete,
          child: Text(l.accountDelete),
        ),
      ] else ...[
        Text(l.accountIntro),
        const SizedBox(height: LumioSpacing.lg),
        TextField(
          key: const ValueKey('account:email'),
          controller: _email,
          autofocus: true,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(labelText: l.accountEmailLabel),
          onSubmitted: (_) => _sendCode(),
        ),
        const SizedBox(height: LumioSpacing.md),
        FilledButton(
          key: const ValueKey('account:sendCode'),
          onPressed: _busy ? null : _sendCode,
          child: Text(l.accountSendCode),
        ),
        if (_codeSent) ...[
          const SizedBox(height: LumioSpacing.lg),
          TextField(
            key: const ValueKey('account:code'),
            controller: _code,
            enabled: !_busy,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: l.accountCodeLabel),
            onSubmitted: (_) => _signIn(),
          ),
          const SizedBox(height: LumioSpacing.md),
          FilledButton(
            key: const ValueKey('account:signIn'),
            onPressed: _busy ? null : _signIn,
            child: Text(l.accountSignIn),
          ),
        ],
      ],
      if (_notice != null) ...[
        const SizedBox(height: LumioSpacing.md),
        Text(_notice!, key: const ValueKey('account:notice')),
      ],
      if (_error != null) ...[
        const SizedBox(height: LumioSpacing.md),
        Text(
          _error!,
          key: const ValueKey('account:error'),
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ],
    ];
    return TvScaffold(
      onBack: () => Navigator.maybeOf(context)?.maybePop(),
      child: Scaffold(
        appBar: AppBar(title: Text(l.accountTitle)),
        body: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView(
              padding: const EdgeInsetsDirectional.all(LumioSpacing.xl),
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
