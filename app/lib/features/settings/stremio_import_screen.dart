import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/backup_files.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/features/settings/backup_section.dart';
import 'package:lumio/l10n/error_messages.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/focus/focus_ring.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

/// Lecture hors de l'interface : `null` si le texte n'est pas un export
/// reconnu (JSON illisible ou forme inattendue).
StremioImportResult? _parse(({String text, bool addons}) job) {
  try {
    final json = jsonDecode(job.text);
    if (json == null) return null;
    return job.addons
        ? parseStremioAddonCollection(json as Object)
        : parseStremioLibrary(json as Object);
  } on Object {
    return null;
  }
}

/// Hors d'une méthode d'instance : la fermeture envoyée à l'isolat ne doit pas
/// capturer l'état de l'écran (contrôleurs, contexte), non transmissible.
Future<StremioImportResult?> _parseOffThread(
  String text, {
  required bool addons,
}) => Isolate.run(() => _parse((text: text, addons: addons)));

enum _Phase { form, running, done }

/// Import depuis un autre client compatible (story 4.5) : l'utilisateur fournit
/// ses fichiers JSON exportés (choisis ou collés). Aucun compte n'est contacté.
class StremioImportScreen extends ConsumerStatefulWidget {
  const StremioImportScreen({super.key});

  @override
  ConsumerState<StremioImportScreen> createState() =>
      _StremioImportScreenState();
}

class _StremioImportScreenState extends ConsumerState<StremioImportScreen> {
  final _addonsCtl = TextEditingController();
  final _libraryCtl = TextEditingController();
  String? _addonsFile, _addonsFileName;
  String? _libraryFile, _libraryFileName;
  _Phase _phase = _Phase.form;
  String? _error;

  // Progression et bilan.
  int _done = 0, _total = 0;
  bool _libraryStep = false;
  int _installed = 0, _already = 0;
  int _failedInvalid = 0, _failedUnreachable = 0, _failedOther = 0;
  int _libAdded = 0, _libAlready = 0, _libFailed = 0;
  int _libDone = 0, _libTotal = 0;
  final _skipped = <String>[];
  final _pending = <Uri>[];
  bool _nothing = false;

  @override
  void dispose() {
    _addonsCtl.dispose();
    _libraryCtl.dispose();
    super.dispose();
  }

  String? _source(bool addons) {
    final file = addons ? _addonsFile : _libraryFile;
    if (file != null) return file;
    final t = (addons ? _addonsCtl : _libraryCtl).text.trim();
    return t.isEmpty ? null : t;
  }

  // --- Choix d'un fichier -----------------------------------------------------

  Future<BackupFile?> _chooseFile() async {
    final l = context.l10n;
    final files = ref.read(backupFilesProvider);
    if (files.hasPicker) return files.pick();
    final local = await files.listLocal(anyJson: true);
    if (!mounted) return null;
    if (local.isEmpty) {
      final dir = await files.directory;
      if (mounted) setState(() => _error = l.otherImportNoFiles(dir));
      return null;
    }
    return showDialog<BackupFile>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.otherImportPickTitle),
        children: [
          for (final (i, f) in local.indexed)
            FocusRing(
              child: ListTile(
                key: ValueKey('otherImport:file:${f.name}'),
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

  Future<void> _pickFile({required bool addons}) async {
    final l = context.l10n;
    setState(() => _error = null);
    try {
      final file = await _chooseFile();
      if (file == null || !mounted) return;
      // Taille vérifiée avant toute lecture.
      if (file.length > Backup.maxBytes) {
        setState(() => _error = l.otherImportErrTooLarge);
        return;
      }
      final bytes = await file.read();
      // La taille annoncée peut mentir : on revérifie ce qui a été lu.
      if (bytes.length > Backup.maxBytes) {
        setState(() => _error = l.otherImportErrTooLarge);
        return;
      }
      final text = utf8.decode(bytes);
      if (!mounted) return;
      setState(() {
        if (addons) {
          _addonsFile = text;
          _addonsFileName = file.name;
        } else {
          _libraryFile = text;
          _libraryFileName = file.name;
        }
      });
    } on Object {
      if (mounted) setState(() => _error = l.backupErrFile);
    }
  }

  void _clearFile({required bool addons}) => setState(() {
    if (addons) {
      _addonsFile = _addonsFileName = null;
    } else {
      _libraryFile = _libraryFileName = null;
    }
  });

  // --- Import -----------------------------------------------------------------

  Future<void> _run() async {
    final l = context.l10n;
    final addonsText = _source(true);
    final libraryText = _source(false);
    if (addonsText == null && libraryText == null) {
      setState(() => _error = l.otherImportNothing);
      return;
    }
    if ((addonsText?.length ?? 0) > Backup.maxBytes ||
        (libraryText?.length ?? 0) > Backup.maxBytes) {
      setState(() => _error = l.otherImportErrTooLarge);
      return;
    }
    setState(() {
      _error = null;
      _phase = _Phase.running;
      _libraryStep = false;
      _done = _total = 0;
    });
    try {
      final addons = addonsText == null
          ? const StremioImportResult()
          : await _parseOffThread(addonsText, addons: true);
      final library = libraryText == null
          ? const StremioImportResult()
          : await _parseOffThread(libraryText, addons: false);
      if (!mounted) return;
      if (addons == null || library == null) {
        setState(() {
          _phase = _Phase.form;
          _error = l.otherImportErrFormat(
            addons == null ? l.otherImportWhatAddons : l.otherImportWhatLibrary,
          );
        });
        return;
      }

      _installed = _already = 0;
      _failedInvalid = _failedUnreachable = _failedOther = 0;
      _libAdded = _libAlready = _libFailed = _libDone = _libTotal = 0;
      _skipped
        ..clear()
        ..addAll(addons.skipped)
        ..addAll(library.skipped);
      _pending.clear();
      _nothing = addons.addonUrls.isEmpty && library.library.isEmpty;

      final repo = ref.read(addonRepositoryProvider);
      setState(() => _total = addons.addonUrls.length);
      for (final url in addons.addonUrls) {
        if (!mounted) return;
        // Un par un, par le chemin d'installation normal : validation, garde
        // d'adresse locale (jamais autorisée sans confirmation), doublons.
        try {
          if (await repo.isInstalled(url.toString())) {
            _already++;
          } else {
            await repo.install(url.toString());
            _installed++;
          }
        } on PrivateAddressException {
          _pending.add(url);
        } on DuplicateAddonException {
          _already++;
        } on AddonException catch (e) {
          switch (e.code) {
            case AddonErrorCode.manifestInvalid ||
                AddonErrorCode.invalidJson ||
                AddonErrorCode.tooLarge ||
                AddonErrorCode.invalidAddress ||
                AddonErrorCode.addressRefused:
              _failedInvalid++;
            case AddonErrorCode.timeout ||
                AddonErrorCode.unreachable ||
                AddonErrorCode.tlsFailed ||
                AddonErrorCode.notFound ||
                AddonErrorCode.serverError ||
                AddonErrorCode.refused ||
                AddonErrorCode.redirect:
              _failedUnreachable++;
            default:
              _failedOther++;
          }
        } on Object {
          _failedOther++;
        }
        if (mounted) setState(() => _done++);
      }
      if (!mounted) return;
      if (_installed > 0) {
        try {
          await ref.read(addonsProvider.notifier).refresh();
        } on Object {
          // Le rapport prime : la liste se rafraîchira à la prochaine lecture.
        }
      }

      if (library.library.isNotEmpty) {
        setState(() {
          _libraryStep = true;
          _libTotal = library.library.length;
        });
        final lib = ref.read(libraryRepositoryProvider);
        final profileId = ref.read(currentProfileIdProvider);
        for (final m in library.library) {
          if (!mounted) return;
          // Un titre en échec ne perd pas le bilan des autres.
          try {
            if (await lib.contains(profileId, m.id)) {
              _libAlready++;
            } else {
              await lib.add(profileId, m);
              _libAdded++;
            }
          } on Object {
            _libFailed++;
          }
          if (mounted) setState(() => _libDone++);
        }
      }
      if (mounted) setState(() => _phase = _Phase.done);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.form;
        _error = e is BackupFormatException
            ? l10nForError(l, e)
            : l.backupErrFile;
      });
    }
  }

  Future<void> _allow(Uri url) async {
    try {
      await ref
          .read(addonRepositoryProvider)
          .install(url.toString(), allowPrivate: true);
      if (!mounted) return;
      await ref.read(addonsProvider.notifier).refresh();
      setState(() {
        _pending.remove(url);
        _installed++;
      });
    } on DuplicateAddonException {
      if (mounted) {
        setState(() {
          _pending.remove(url);
          _already++;
        });
      }
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10nForError(context.l10n, e))));
    }
  }

  void _ignore(Uri url) => setState(() => _pending.remove(url));

  // --- Interface ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope(
      canPop: _phase != _Phase.running,
      child: TvScaffold(
        child: Scaffold(
          appBar: AppBar(title: Text(l.otherImportTitle)),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(LumioSpacing.lg),
                children: switch (_phase) {
                  _Phase.form => _form(l),
                  _Phase.running => _running(l),
                  _Phase.done => _report(l),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _section({required AppLocalizations l, required bool addons}) {
    final key = addons ? 'addons' : 'library';
    final fileName = addons ? _addonsFileName : _libraryFileName;
    return [
      Text(
        addons ? l.otherImportAddonsLabel : l.otherImportLibraryLabel,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: LumioSpacing.sm),
      if (fileName != null)
        Row(
          children: [
            const Icon(Icons.description_outlined),
            const SizedBox(width: LumioSpacing.sm),
            Expanded(
              child: Text(
                l.otherImportFileLoaded(fileName),
                key: ValueKey('otherImport:$key:fileName'),
              ),
            ),
            FocusRing(
              child: TextButton(
                key: ValueKey('otherImport:$key:remove'),
                onPressed: () => _clearFile(addons: addons),
                child: Text(l.otherImportRemoveFile),
              ),
            ),
          ],
        )
      else ...[
        TextField(
          key: ValueKey('otherImport:$key:text'),
          controller: addons ? _addonsCtl : _libraryCtl,
          minLines: 2,
          maxLines: 4,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(hintText: l.otherImportPasteHint),
        ),
        const SizedBox(height: LumioSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FocusRing(
            child: OutlinedButton.icon(
              key: ValueKey('otherImport:$key:pick'),
              onPressed: () => _pickFile(addons: addons),
              icon: const Icon(Icons.folder_open),
              label: Text(l.otherImportChooseFile),
            ),
          ),
        ),
      ],
      const SizedBox(height: LumioSpacing.lg),
    ];
  }

  List<Widget> _form(AppLocalizations l) => [
    Text(l.otherImportHelp, key: const ValueKey('otherImport:help')),
    const SizedBox(height: LumioSpacing.lg),
    ..._section(l: l, addons: true),
    ..._section(l: l, addons: false),
    if (_error != null) ...[
      Text(
        _error!,
        key: const ValueKey('otherImport:error'),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      const SizedBox(height: LumioSpacing.md),
    ],
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: FocusRing(
        child: FilledButton(
          key: const ValueKey('otherImport:run'),
          onPressed: _run,
          child: Text(l.otherImportRun),
        ),
      ),
    ),
  ];

  List<Widget> _running(AppLocalizations l) => [
    const SizedBox(height: LumioSpacing.xl),
    Text(
      _libraryStep
          ? '${l.otherImportProgressLibrary} $_libDone/$_libTotal'
          : l.otherImportProgressAddons(_done, _total),
      key: const ValueKey('otherImport:progress'),
      style: Theme.of(context).textTheme.titleMedium,
    ),
    const SizedBox(height: LumioSpacing.md),
    LinearProgressIndicator(
      value: _libraryStep
          ? (_libTotal > 0 ? _libDone / _libTotal : null)
          : (_total > 0 ? _done / _total : null),
    ),
  ];

  List<Widget> _report(AppLocalizations l) {
    final lines = <String>[
      if (_installed > 0) l.otherImportSumInstalled(_installed),
      if (_already > 0) l.otherImportSumAlready(_already),
      if (_pending.isNotEmpty) l.otherImportSumPending(_pending.length),
      if (_failedInvalid > 0) l.otherImportSumFailedInvalid(_failedInvalid),
      if (_failedUnreachable > 0)
        l.otherImportSumFailedUnreachable(_failedUnreachable),
      if (_failedOther > 0) l.otherImportSumFailedOther(_failedOther),
      if (_libFailed > 0) l.otherImportSumLibraryFailed(_libFailed),
      if (_libAdded > 0) l.otherImportSumLibrary(_libAdded),
      if (_libAlready > 0) l.otherImportSumLibraryAlready(_libAlready),
      if (_skipped.isNotEmpty)
        l.otherImportSumSkipped(
          _skipped.length,
          _skipped.take(8).join(', ') + (_skipped.length > 8 ? '…' : ''),
        ),
    ];
    if (_nothing && lines.isEmpty) lines.add(l.otherImportSumNothing);
    return [
      Text(
        l.otherImportDoneTitle,
        key: const ValueKey('otherImport:done'),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: LumioSpacing.md),
      for (final s in lines)
        Padding(
          padding: const EdgeInsets.only(bottom: LumioSpacing.sm),
          child: Text(s),
        ),
      for (final u in List.of(_pending)) ...[
        const SizedBox(height: LumioSpacing.md),
        Text(l.otherImportPendingItem(u.host)),
        const SizedBox(height: LumioSpacing.sm),
        Row(
          children: [
            FocusRing(
              child: FilledButton(
                key: ValueKey('otherImport:allow:${u.host}'),
                onPressed: () => _allow(u),
                child: Text(l.addonSyncAllow),
              ),
            ),
            const SizedBox(width: LumioSpacing.sm),
            FocusRing(
              child: TextButton(
                key: ValueKey('otherImport:ignore:${u.host}'),
                onPressed: () => _ignore(u),
                child: Text(l.addonSyncIgnore),
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: LumioSpacing.lg),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: FocusRing(
          child: FilledButton(
            key: const ValueKey('otherImport:close'),
            autofocus: true,
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l.close),
          ),
        ),
      ),
    ];
  }
}
