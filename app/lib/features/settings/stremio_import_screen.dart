import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:lumio/ui/common/tv_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/backup_files.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/features/settings/backup_section.dart';
import 'package:lumio/l10n/error_messages.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/common/tv_screen.dart';
import 'package:lumio/ui/focus/focus_ring.dart';
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/ui/icons/lumio_icons.dart';
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
      // Maquette TV32 : en-tête de 152, aide de 26, cartes côte à côte.
      child: TvScreen(
        title: l.otherImportTitle,
        padding: const EdgeInsets.fromLTRB(96, 0, 96, 48),
        child: ListView(
          clipBehavior: Clip.none,
          padding: EdgeInsets.zero,
          children: switch (_phase) {
            _Phase.form => _form(l),
            _Phase.running => _running(l),
            _Phase.done => _report(l),
          },
        ),
      ),
    );
  }

  TextStyle _md(BuildContext context, {Color? color, double size = 28}) =>
      TextStyle(
        fontFamily: 'Manrope',
        fontSize: size,
        height: 1.4,
        color: color ?? const Color(0xFFC9D0DA),
      );

  TextStyle _cardTitle(BuildContext context) => Theme.of(context)
      .textTheme
      .titleMedium!
      .copyWith(fontSize: 36, height: 1.15)
      .weighted(FontWeight.w700);

  Widget _card(BuildContext context, {required List<Widget> children}) {
    final c = context.lumio;
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _section({required AppLocalizations l, required bool addons}) {
    final key = addons ? 'addons' : 'library';
    final fileName = addons ? _addonsFileName : _libraryFileName;
    final c = context.lumio;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: color, width: 2),
    );
    return _card(
      context,
      children: [
        Text(
          addons ? l.otherImportAddonsLabel : l.otherImportLibraryLabel,
          style: _cardTitle(context),
        ),
        const SizedBox(height: 16),
        if (fileName != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  l.otherImportFileLoaded(fileName),
                  key: ValueKey('otherImport:$key:fileName'),
                  style: _md(context),
                ),
              ),
              const SizedBox(width: 16),
              TvButton(
                key: ValueKey('otherImport:$key:remove'),
                label: l.otherImportRemoveFile,
                kind: TvButtonKind.ghost,
                height: 76,
                fontSize: 28,
                horizontalPadding: 40,
                onPressed: () => _clearFile(addons: addons),
              ),
            ],
          )
        else ...[
          TvTextField(
            key: ValueKey('otherImport:$key:text'),
            controller: addons ? _addonsCtl : _libraryCtl,
            minLines: 4,
            maxLines: 4,
            autocorrect: false,
            enableSuggestions: false,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 26,
              fontWeight: FontWeight.w600,
              fontVariations: const [FontVariation.weight(600)],
              color: c.text,
            ),
            decoration: InputDecoration(
              hintText: l.otherImportPasteHint,
              hintStyle: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 26,
                fontWeight: FontWeight.w600,
                fontVariations: [FontVariation.weight(600)],
                color: Color(0xFF6F7B8B),
              ),
              filled: true,
              fillColor: c.bg,
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              border: border(c.outline),
              enabledBorder: border(c.outline),
              focusedBorder: border(c.focusRing),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TvButton(
              key: ValueKey('otherImport:$key:pick'),
              autofocus: addons,
              label: l.otherImportChooseFile,
              kind: TvButtonKind.secondary,
              height: 76,
              fontSize: 28,
              horizontalPadding: 40,
              icon: LumioIconView(LumioIcon.filePlain, size: 32, color: c.text),
              onPressed: () => _pickFile(addons: addons),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _help(AppLocalizations l) => [
    Align(
      alignment: AlignmentDirectional.topStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1500),
        child: Text(
          l.otherImportHelp,
          key: const ValueKey('otherImport:help'),
          style: _md(context, size: 26),
        ),
      ),
    ),
    const SizedBox(height: 24),
  ];

  List<Widget> _form(AppLocalizations l) => [
    ..._help(l),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _section(l: l, addons: true)),
        const SizedBox(width: 28),
        Expanded(child: _section(l: l, addons: false)),
      ],
    ),
    const SizedBox(height: 24),
    if (_error != null) ...[
      Text(
        _error!,
        key: const ValueKey('otherImport:error'),
        style: _md(context, color: context.lumio.error),
      ),
      const SizedBox(height: 16),
    ],
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: TvButton(
        key: const ValueKey('otherImport:run'),
        label: l.otherImportRun,
        height: 76,
        fontSize: 28,
        horizontalPadding: 40,
        onPressed: _run,
      ),
    ),
  ];

  List<Widget> _running(AppLocalizations l) => [
    ..._help(l),
    Row(
      children: [
        TvButton(
          label: l.otherImportRun,
          height: 76,
          fontSize: 28,
          horizontalPadding: 40,
          onPressed: null,
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Text(
            _libraryStep
                ? '${l.otherImportProgressLibrary} $_libDone/$_libTotal'
                : l.otherImportProgressAddons(_done, _total),
            key: const ValueKey('otherImport:progress'),
            style: _md(context, color: context.lumio.accent),
          ),
        ),
      ],
    ),
    const SizedBox(height: 24),
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
      _card(
        context,
        children: [
          Text(
            l.otherImportDoneTitle,
            key: const ValueKey('otherImport:done'),
            style: _cardTitle(context),
          ),
          const SizedBox(height: 6),
          for (final s in lines) Text(s, style: _md(context)),
          for (final u in List.of(_pending)) ...[
            const SizedBox(height: 16),
            Text(l.otherImportPendingItem(u.host), style: _md(context)),
            const SizedBox(height: 12),
            Row(
              children: [
                TvButton(
                  key: ValueKey('otherImport:allow:${u.host}'),
                  label: l.addonUrlAllow,
                  height: 76,
                  fontSize: 28,
                  horizontalPadding: 40,
                  onPressed: () => _allow(u),
                ),
                const SizedBox(width: 16),
                TvButton(
                  key: ValueKey('otherImport:ignore:${u.host}'),
                  label: l.addonUrlIgnore,
                  kind: TvButtonKind.ghost,
                  height: 76,
                  fontSize: 28,
                  horizontalPadding: 40,
                  onPressed: () => _ignore(u),
                ),
              ],
            ),
          ],
        ],
      ),
      const SizedBox(height: 24),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TvButton(
          key: const ValueKey('otherImport:close'),
          label: l.close,
          autofocus: true,
          height: 76,
          fontSize: 28,
          horizontalPadding: 40,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
    ];
  }
}
