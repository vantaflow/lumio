// ignore_for_file: sort_child_properties_last
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/backup_files.dart';
import 'package:lumio/data/backup_service.dart';
import 'package:lumio/features/settings/settings_providers.dart';
import 'package:lumio/l10n/error_messages.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/common/tv_dialogs.dart';
import 'package:lumio/ui/focus/focus_ring.dart';
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/ui/theme.dart';
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

  /// Texte courant des fenêtres (maquette TV33 : 26, #C9D0DA).
  Widget _body(BuildContext ctx, String text) => Text(
    text,
    style: const TextStyle(
      fontFamily: 'Manrope',
      fontSize: 26,
      height: 1.4,
      color: Color(0xFFC9D0DA),
    ),
  );

  /// Fenêtre d'attente pendant [op] (dérivation de clé, installation réseau).
  Future<T> _busy<T>(String label, Future<T> Function() op) async {
    showTvPanel<void>(
      context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: TvPanel(
          title: label,
          titleSize: 38,
          width: 900,
          fitActions: true,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          children: [LinearProgressIndicator(color: context.lumio.accent)],
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
    final secrets = await showTvPanel<bool>(
      context,
      builder: (ctx) => TvPanel(
        key: const ValueKey('backup:secretsDialog'),
        title: l.backupSecretsTitle,
        titleSize: 38,
        width: 900,
        fitActions: true,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        // Maquette TV33 : titre, texte et boutons espacés de 14 (+ 12).
        gap: 14,
        actionsGap: 26,
        contentPadding: EdgeInsets.zero,
        onBack: () => Navigator.pop(ctx),
        children: [_body(ctx, l.backupSecretsWarning)],
        actions: [
          TvButton(
            label: l.cancel,
            kind: TvButtonKind.ghost,
            height: 76,
            fontSize: 28,
            horizontalPadding: 40,
            onPressed: () => Navigator.pop(ctx),
          ),
          TvButton(
            key: const ValueKey('backup:withoutSecrets'),
            label: l.backupWithoutSecrets,
            autofocus: true,
            height: 76,
            fontSize: 28,
            horizontalPadding: 40,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          TvButton(
            key: const ValueKey('backup:withSecrets'),
            label: l.backupWithSecrets,
            kind: TvButtonKind.secondary,
            height: 76,
            fontSize: 28,
            horizontalPadding: 40,
            onPressed: () => Navigator.pop(ctx, true),
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

  Future<String?> _askNewPassphrase() =>
      showTvPanel<String>(context, builder: (_) => const NewPassphraseDialog());

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
      showTvPanel<String>(
        context,
        builder: (_) => ImportPassphraseDialog(wrong: wrong),
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
      final ok = await showTvPanel<bool>(
        context,
        builder: (ctx) => TvPanel(
          key: const ValueKey('backup:confirmImport'),
          title: l.backupConfirmTitle,
          titleSize: 38,
          width: 900,
          fitActions: true,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          gap: 14,
          actionsGap: 26,
          contentPadding: EdgeInsets.zero,
          onBack: () => Navigator.pop(ctx, false),
          children: [_body(ctx, l.backupConfirmBody)],
          actions: [
            TvButton(
              label: l.cancel,
              kind: TvButtonKind.ghost,
              height: 76,
              fontSize: 28,
              horizontalPadding: 40,
              onPressed: () => Navigator.pop(ctx, false),
            ),
            TvButton(
              key: const ValueKey('backup:confirmOk'),
              label: l.backupContinue,
              autofocus: true,
              height: 76,
              fontSize: 28,
              horizontalPadding: 40,
              onPressed: () => Navigator.pop(ctx, true),
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
    return showTvPanel<void>(
      context,
      builder: (ctx) => TvPanel(
        key: const ValueKey('backup:report'),
        title: l.backupDoneTitle,
        titleSize: 38,
        width: 900,
        fitActions: true,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        gap: 10,
        actionsGap: 22,
        contentPadding: EdgeInsets.zero,
        onBack: () => Navigator.pop(ctx),
        children: [for (final s in lines) _body(ctx, s)],
        actions: [
          TvButton(
            key: const ValueKey('backup:reportOk'),
            label: l.close,
            autofocus: true,
            height: 76,
            fontSize: 28,
            horizontalPadding: 40,
            onPressed: () => Navigator.pop(ctx),
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
    final allow = await showTvPanel<bool>(
      context,
      builder: (ctx) => TvPanel(
        key: ValueKey('backup:private:${a.name}'),
        title: l.backupPrivateTitle,
        titleSize: 38,
        width: 900,
        fitActions: true,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        gap: 14,
        actionsGap: 26,
        contentPadding: EdgeInsets.zero,
        onBack: () => Navigator.pop(ctx, false),
        children: [_body(ctx, l.backupPrivateBody(a.name, a.host))],
        actions: [
          TvButton(
            label: l.addonUrlIgnore,
            kind: TvButtonKind.ghost,
            autofocus: true,
            height: 76,
            fontSize: 28,
            horizontalPadding: 40,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          TvButton(
            key: const ValueKey('backup:privateAllow'),
            label: l.addonUrlAllow,
            height: 76,
            fontSize: 28,
            horizontalPadding: 40,
            onPressed: () => Navigator.pop(ctx, true),
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
class NewPassphraseDialog extends StatefulWidget {
  const NewPassphraseDialog({super.key});

  @override
  State<NewPassphraseDialog> createState() => NewPassphraseDialogState();
}

class NewPassphraseDialogState extends State<NewPassphraseDialog> {
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
    return TvPanel(
      title: l.backupPassphraseTitle,
      width: 960,
      fitActions: true,
      onBack: () => Navigator.pop(context),
      actions: [
        TvButton(
          label: l.cancel,
          kind: TvButtonKind.ghost,
          height: 76,
          fontSize: 28,
          horizontalPadding: 40,
          onPressed: () => Navigator.pop(context),
        ),
        TvButton(
          key: const ValueKey('backup:phraseOk'),
          label: l.backupContinue,
          height: 76,
          fontSize: 28,
          horizontalPadding: 40,
          onPressed: _submit,
        ),
      ],
      children: [
        Text(
          l.backupPassphraseHint,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 28,
            height: 1.4,
            color: Color(0xFFC9D0DA),
          ),
        ),
        const SizedBox(height: 20),
        TvLabeledField(
          fieldKey: const ValueKey('backup:phrase'),
          controller: _phrase,
          label: l.passphraseLabel,
          autofocus: true,
          obscureText: true,
        ),
        const SizedBox(height: 20),
        TvLabeledField(
          fieldKey: const ValueKey('backup:phraseConfirm'),
          controller: _confirm,
          label: l.passphraseConfirmLabel,
          obscureText: true,
          error: _error,
          onSubmitted: (_) => _submit(),
        ),
      ],
    );
  }
}

/// Phrase d'une sauvegarde chiffrée à importer ; [wrong] affiche l'erreur
/// après un essai raté.
class ImportPassphraseDialog extends StatefulWidget {
  const ImportPassphraseDialog({super.key, required this.wrong});

  final bool wrong;

  @override
  State<ImportPassphraseDialog> createState() => ImportPassphraseDialogState();
}

class ImportPassphraseDialogState extends State<ImportPassphraseDialog> {
  final _phrase = TextEditingController();

  @override
  void dispose() {
    _phrase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return TvPanel(
      title: l.backupImportPassphraseTitle,
      width: 960,
      fitActions: true,
      onBack: () => Navigator.pop(context),
      actions: [
        TvButton(
          label: l.cancel,
          kind: TvButtonKind.ghost,
          height: 76,
          fontSize: 28,
          horizontalPadding: 40,
          onPressed: () => Navigator.pop(context),
        ),
        TvButton(
          key: const ValueKey('backup:importPhraseOk'),
          label: l.backupContinue,
          height: 76,
          fontSize: 28,
          horizontalPadding: 40,
          onPressed: () => Navigator.pop(context, _phrase.text),
        ),
      ],
      children: [
        Text(
          l.backupImportPassphraseHint,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 28,
            height: 1.4,
            color: Color(0xFFC9D0DA),
          ),
        ),
        const SizedBox(height: 20),
        TvLabeledField(
          fieldKey: const ValueKey('backup:importPhrase'),
          controller: _phrase,
          label: l.passphraseLabel,
          autofocus: true,
          obscureText: true,
          error: widget.wrong ? l.backupWrongPassphrase : null,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
      ],
    );
  }
}
