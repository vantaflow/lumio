import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/sync_providers.dart';
import 'package:lumio/data/sync_service.dart';
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
