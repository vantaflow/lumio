import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/backup_files.dart';
import 'package:lumio/data/backup_service.dart';
import 'package:lumio/features/settings/settings_providers.dart';
import 'package:lumio/l10n/error_messages.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/focus/focus_ring.dart';
import 'package:lumio/ui/focus/tv_detection.dart';
import 'package:lumio_core/lumio_core.dart';

final backupFilesProvider = Provider<BackupFiles>(
  (ref) => PlatformBackupFiles(tv: ref.watch(androidTvProvider)),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    ref.watch(appDatabaseProvider),
    ref.watch(addonRepositoryProvider),
  ),
);

/// Sauvegarde locale (story 4.3) : exporter et importer ses données depuis les
/// réglages. Sans secret par défaut ; avec les adresses d'addons, le fichier
/// est chiffré par une phrase secrète choisie à l'export.
class BackupFlows {
  const BackupFlows(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  void _say(String text) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _fail(Object e) {
    if (!context.mounted) return;
    final l = context.l10n;
    _say(
      e is BackupFormatException || e is WrongPassphraseException
          ? l10nForError(l, e)
          : l.backupErrFile,
    );
  }

  /// Fenêtre d'attente pendant [op] (dérivation de clé, installation réseau).
  Future<T> _busy<T>(String label, Future<T> Function() op) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 16),
              Flexible(child: Text(label)),
            ],
          ),
        ),
      ),
    );
    try {
      return await op();
    } finally {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  // --- Export ---------------------------------------------------------------

  Future<void> export() async {
    final l = context.l10n;
    final secrets = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('backup:secretsDialog'),
        title: Text(l.backupSecretsTitle),
        content: Text(l.backupSecretsWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FocusRing(
            child: FilledButton(
              key: const ValueKey('backup:withoutSecrets'),
              autofocus: true,
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.backupWithoutSecrets),
            ),
          ),
          FocusRing(
            child: TextButton(
              key: const ValueKey('backup:withSecrets'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.backupWithSecrets),
            ),
          ),
        ],
      ),
    );
    if (secrets == null || !context.mounted) return;

    String? passphrase;
    if (secrets) {
      passphrase = await _askNewPassphrase();
      if (passphrase == null || !context.mounted) return;
    }
    try {
      final files = ref.read(backupFilesProvider);
      final text = await _busy(
        l.backupImportBusy,
        () => ref
            .read(backupServiceProvider)
            .export(includeSecrets: secrets, passphrase: passphrase),
      );
      final path = await files.save(backupFileName(DateTime.now()), text);
      if (path != null) _say(l.backupExported(path));
    } on Object catch (e) {
      _fail(e);
    }
  }

  Future<String?> _askNewPassphrase() => showDialog<String>(
    context: context,
    builder: (_) => const _NewPassphraseDialog(),
  );

  // --- Import ---------------------------------------------------------------

  Future<BackupFile?> _chooseFile() async {
    final l = context.l10n;
    final files = ref.read(backupFilesProvider);
    if (files.hasPicker) return files.pick();
    final local = await files.listLocal();
    if (!context.mounted) return null;
    if (local.isEmpty) {
      _say(l.backupNoFiles(await files.directory));
      return null;
    }
    return showDialog<BackupFile>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.backupPickTitle),
        children: [
          for (final (i, f) in local.indexed)
            FocusRing(
              child: ListTile(
                key: ValueKey('backup:file:${f.name}'),
                autofocus: i == 0,
                leading: const Icon(Icons.description_outlined),
                title: Text(f.name),
                onTap: () => Navigator.pop(ctx, f),
              ),
            ),
        ],
      ),
    );
  }

  Future<String?> _askImportPassphrase({required bool wrong}) =>
      showDialog<String>(
        context: context,
        builder: (_) => _ImportPassphraseDialog(wrong: wrong),
      );

  Future<void> import() async {
    final l = context.l10n;
    try {
      final file = await _chooseFile();
      if (file == null || !context.mounted) return;
      // Taille vérifiée avant toute lecture.
      if (file.length > Backup.maxBytes) {
        throw const BackupFormatException(BackupFormatError.tooLarge);
      }
      final bytes = await file.read();
      BackupData? data;
      String? phrase;
      var wrong = false;
      while (data == null) {
        try {
          data = await _busy(
            l.backupImportBusy,
            () => Backup.decode(bytes, passphrase: phrase),
          );
        } on BackupFormatException catch (e) {
          if (e.error != BackupFormatError.passphraseRequired) rethrow;
          if (!context.mounted) return;
          phrase = await _askImportPassphrase(wrong: wrong);
          if (phrase == null) return;
        } on WrongPassphraseException {
          if (!context.mounted) return;
          wrong = true;
          phrase = await _askImportPassphrase(wrong: true);
          if (phrase == null) return;
        }
      }
      if (!context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const ValueKey('backup:confirmImport'),
          title: Text(l.backupConfirmTitle),
          content: Text(l.backupConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel),
            ),
            FocusRing(
              child: FilledButton(
                key: const ValueKey('backup:confirmOk'),
                autofocus: true,
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.backupContinue),
              ),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;

      final imported = data;
      final service = ref.read(backupServiceProvider);
      final report = await _busy(
        l.backupImportBusy,
        () => service.import(imported),
      );
      await _refreshAfterImport();
      if (!context.mounted) return;
      final hasPin = await ref.read(profileRepositoryProvider).hasParentPin();
      if (!context.mounted) return;
      await _showReport(
        report,
        kidNeedsPin: report.kidProfilesAdded > 0 && !hasPin,
      );
      for (final a in report.pendingAddons) {
        if (!context.mounted) return;
        await _confirmPrivate(service, a);
      }
    } on Object catch (e) {
      _fail(e);
    }
  }

  Future<void> _refreshAfterImport() async {
    ref.invalidate(localeProvider);
    ref.invalidate(titleSettingsStoreProvider);
    await ref.read(profilesProvider.notifier).reload();
    await ref.read(addonsProvider.notifier).refresh();
  }

  Future<void> _showReport(BackupImportReport r, {required bool kidNeedsPin}) {
    final l = context.l10n;
    final lines = <String>[
      if (r.profilesAdded > 0) l.backupSumProfiles(r.profilesAdded),
      if (r.libraryAdded > 0) l.backupSumLibrary(r.libraryAdded),
      if (r.progressApplied > 0) l.backupSumProgress(r.progressApplied),
      if (r.addonsInstalled > 0) l.backupSumAddons(r.addonsInstalled),
    ];
    if (lines.isEmpty &&
        r.settingsAdded == 0 &&
        r.titleSettingsAdded == 0 &&
        r.pendingAddons.isEmpty) {
      lines.add(l.backupSumNothing);
    }
    lines.addAll([
      if (r.profilesSkipped > 0) l.backupSumProfilesSkipped(r.profilesSkipped),
      if (kidNeedsPin) l.backupKidNeedsPin,
      if (r.addonsNameOnly > 0) l.backupSumNameOnly(r.addonsNameOnly),
      if (r.addonsFailed > 0) l.backupSumFailed(r.addonsFailed),
      if (r.skipped > 0) l.backupSumSkipped(r.skipped),
    ]);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('backup:report'),
        title: Text(l.backupDoneTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final s in lines) Text(s)],
          ),
        ),
        actions: [
          FocusRing(
            child: FilledButton(
              key: const ValueKey('backup:reportOk'),
              autofocus: true,
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.close),
            ),
          ),
        ],
      ),
    );
  }

  /// Adresse locale : jamais autorisée sans confirmation explicite.
  Future<void> _confirmPrivate(
    BackupService service,
    PendingBackupAddon a,
  ) async {
    final l = context.l10n;
    final allow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: ValueKey('backup:private:${a.name}'),
        title: Text(l.backupPrivateTitle),
        content: Text(l.backupPrivateBody(a.name, a.host)),
        actions: [
          FocusRing(
            child: TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.addonUrlIgnore),
            ),
          ),
          FocusRing(
            child: FilledButton(
              key: const ValueKey('backup:privateAllow'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.addonUrlAllow),
            ),
          ),
        ],
      ),
    );
    if (allow != true || !context.mounted) return;
    try {
      await _busy(l.backupImportBusy, () => service.installConfirmed(a));
      await ref.read(addonsProvider.notifier).refresh();
    } on Object catch (e) {
      if (!context.mounted) return;
      _say(l10nForError(l, e));
    }
  }
}

/// Phrase de la sauvegarde : saisie confirmée, 12 caractères au moins. Les
/// champs vivent dans l'état du dialogue (libérés après sa fermeture animée).
class _NewPassphraseDialog extends StatefulWidget {
  const _NewPassphraseDialog();

  @override
  State<_NewPassphraseDialog> createState() => _NewPassphraseDialogState();
}

class _NewPassphraseDialogState extends State<_NewPassphraseDialog> {
  final _phrase = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _phrase.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final l = context.l10n;
    if (_phrase.text.runes.length < Backup.minPassphraseLength) {
      setState(() => _error = l.passphraseErrShort);
    } else if (_phrase.text != _confirm.text) {
      setState(() => _error = l.passphraseErrMismatch);
    } else {
      Navigator.pop(context, _phrase.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.backupPassphraseTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.backupPassphraseHint),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('backup:phrase'),
              controller: _phrase,
              autofocus: true,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(labelText: l.passphraseLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('backup:phraseConfirm'),
              controller: _confirm,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l.passphraseConfirmLabel,
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FocusRing(
          child: FilledButton(
            key: const ValueKey('backup:phraseOk'),
            onPressed: _submit,
            child: Text(l.backupContinue),
          ),
        ),
      ],
    );
  }
}

/// Phrase d'une sauvegarde chiffrée à importer ; [wrong] affiche l'erreur
/// après un essai raté.
class _ImportPassphraseDialog extends StatefulWidget {
  const _ImportPassphraseDialog({required this.wrong});

  final bool wrong;

  @override
  State<_ImportPassphraseDialog> createState() =>
      _ImportPassphraseDialogState();
}

class _ImportPassphraseDialogState extends State<_ImportPassphraseDialog> {
  final _phrase = TextEditingController();

  @override
  void dispose() {
    _phrase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.backupImportPassphraseTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.backupImportPassphraseHint),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('backup:importPhrase'),
            controller: _phrase,
            autofocus: true,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l.passphraseLabel,
              errorText: widget.wrong ? l.backupWrongPassphrase : null,
            ),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FocusRing(
          child: FilledButton(
            key: const ValueKey('backup:importPhraseOk'),
            onPressed: () => Navigator.pop(context, _phrase.text),
            child: Text(l.backupContinue),
          ),
        ),
      ],
    );
  }
}
