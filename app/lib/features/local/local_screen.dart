import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/local_library.dart';
import 'package:lumio/features/detail/playback_service.dart'
    show playerBuilderProvider;
import 'package:lumio/features/home/home_providers.dart' show contentAllowed;
import 'package:lumio/features/local/local_providers.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/player/play_router.dart' show LocalFileSource;
import 'package:lumio/player/player_screen.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/common/state_view.dart';
import 'package:lumio/ui/focus/focus_ring.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart'
    show MetaPreview, StreamItem, UnsafeUrlException;

// --- Ajout d'un dossier (onboarding et réglages) ---

/// Demande l'accès au stockage, fait choisir un dossier (sélecteur système,
/// ou chemin saisi quand il n'existe pas) puis l'analyse. Rend le nombre de
/// vidéos trouvées, `null` si annulé ou en échec (le message est affiché).
Future<int?> addLocalFolderFlow(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  void tell(String m) => messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  bool granted;
  try {
    granted = await ref.read(storagePermissionProvider).ensure();
  } on Object {
    granted = false;
  }
  if (!granted) {
    tell(l.localPermissionDenied);
    return null;
  }
  if (!context.mounted) return null;

  String? path;
  var typed = false;
  if (Platform.isAndroid) {
    // Sur Android le sélecteur n'atteint que le stockage interne : on laisse
    // aussi saisir un chemin (carte SD, clé USB).
    final choice = await showDialog<bool>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(ctx.l10n.localAddFolder),
        children: [
          FocusRing(
            child: ListTile(
              key: const ValueKey('local-choose'),
              autofocus: true,
              leading: const Icon(Icons.folder_open),
              title: Text(ctx.l10n.localChooseFolder),
              onTap: () => Navigator.pop(ctx, true),
            ),
          ),
          FocusRing(
            child: ListTile(
              key: const ValueKey('local-type'),
              leading: const Icon(Icons.keyboard),
              title: Text(ctx.l10n.localTypePath),
              subtitle: Text(ctx.l10n.localSdNote),
              onTap: () => Navigator.pop(ctx, false),
            ),
          ),
        ],
      ),
    );
    if (choice == null) return null;
    typed = !choice;
  }
  if (!typed) {
    try {
      path = await ref.read(folderPickerProvider).pick();
      if (path == null) return null; // annulé
    } on Object {
      typed = true;
      tell(l.localPickerUnavailable);
    }
  }
  if (typed) {
    if (!context.mounted) return null;
    path = await _askPath(context);
    if (path == null || path.trim().isEmpty) return null;
  }
  try {
    final n = await ref.read(localLibraryProvider).addFolder(path!);
    tell(l.localFolderAdded(n));
    return n;
  } on LocalFolderOverlapException {
    tell(l.localFolderOverlap);
  } on LocalScanException catch (e) {
    tell(switch (e.failure) {
      LocalScanFailure.missing => l.localFolderMissing,
      LocalScanFailure.denied => l.localFolderDenied,
      LocalScanFailure.other => l.localScanFailed,
    });
  } on Object {
    tell(l.localScanFailed);
  }
  return null;
}

Future<String?> _askPath(BuildContext context) => showDialog<String>(
  context: context,
  builder: (ctx) => _TextPrompt(
    title: ctx.l10n.localPathTitle,
    label: ctx.l10n.localPathLabel,
    hint: ctx.l10n.localPathHint,
    confirmLabel: ctx.l10n.localAddFolder,
    fieldKey: const ValueKey('local-path'),
    confirmKey: const ValueKey('local-path-ok'),
  ),
);

/// Boîte de saisie d'une ligne ; le contrôleur appartient à la boîte (jamais
/// libéré avant la fin de son animation de fermeture).
class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.fieldKey,
    required this.confirmKey,
    this.hint,
    this.helper,
    this.initial = '',
    this.maxLength,
    this.resetLabel,
    this.resetKey,
  });

  final String title, label, confirmLabel;
  final String? hint, helper, resetLabel;
  final String initial;
  final int? maxLength;
  final Key fieldKey, confirmKey;
  final Key? resetKey;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _ctl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      key: widget.fieldKey,
      controller: _ctl,
      autofocus: true,
      maxLength: widget.maxLength,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helper,
      ),
      onSubmitted: (v) => Navigator.pop(context, v),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      if (widget.resetLabel != null)
        TextButton(
          key: widget.resetKey,
          onPressed: () => Navigator.pop(context, ''),
          child: Text(widget.resetLabel!),
        ),
      FilledButton(
        key: widget.confirmKey,
        onPressed: () => Navigator.pop(context, _ctl.text),
        child: Text(widget.confirmLabel),
      ),
    ],
  );
}

// --- Correction du titre ---

/// Corrige le titre de [item] à la main (vide ou « Rétablir » : titre
/// détecté).
Future<void> showFixTitleDialog(
  BuildContext context,
  WidgetRef ref,
  LocalItem item,
) async {
  final library = ref.read(localLibraryProvider);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => _TextPrompt(
      title: ctx.l10n.localFixTitle,
      label: ctx.l10n.localFixLabel,
      helper: ctx.l10n.localDetected(item.title),
      initial: item.displayTitle,
      maxLength: 120,
      confirmLabel: ctx.l10n.save,
      fieldKey: const ValueKey('local-fix-field'),
      confirmKey: const ValueKey('local-fix-save'),
      resetLabel: item.titleOverride == null ? null : ctx.l10n.localFixReset,
      resetKey: const ValueKey('local-fix-reset'),
    ),
  );
  if (result != null) await library.setTitle(item.id, result);
}

// --- Lecture ---

/// Lance la lecture d'un fichier local : refuse un profil enfant (aucune
/// certification), vérifie que le fichier existe, puis passe par
/// [LocalFileSource] (dossier accordé) pour la lecture `file://`.
Future<void> playLocalItem(
  BuildContext context, {
  required LocalLibrary library,
  required LocalItem item,
  required String profileId,
  required bool allowed,
  required Widget Function(PlayerScreen) build,
}) async {
  final l = context.l10n;
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  void tell(String m) => messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));
  if (!allowed) {
    tell(l.notAllowedForProfile);
    return;
  }
  if (!File(item.path).existsSync()) {
    tell(l.localFileMissing);
    return;
  }
  final LocalFileSource source;
  try {
    source = await library.sourceFor(item);
    source.validate();
  } on UnsafeUrlException {
    tell(l.localPlayFailed);
    return;
  }
  await navigator.push<PlayerExit>(
    MaterialPageRoute(
      builder: (_) => build(
        PlayerScreen(
          item: StreamItem(
            addonId: localSourceKind,
            title: item.displayTitle,
            url: Uri.file(item.path),
            sizeBytes: item.sizeBytes,
          ),
          metaId: item.id,
          videoId: item.id,
          profileId: profileId,
          local: source,
        ),
      ),
    ),
  );
}

/// Lance [playLocalItem] depuis un widget.
Future<void> playLocalFromWidget(
  BuildContext context,
  WidgetRef ref,
  LocalItem item,
) => playLocalItem(
  context,
  library: ref.read(localLibraryProvider),
  item: item,
  profileId: ref.read(currentProfileIdProvider),
  allowed: contentAllowed(ref.read(currentProfileProvider), const [null]),
  build: ref.read(playerBuilderProvider),
);

// --- Carte-titre générée (pas d'affiche pour les fichiers locaux) ---

/// Visuel généré à partir du titre, en remplacement de l'affiche.
class LocalTitleCard extends StatelessWidget {
  const LocalTitleCard({super.key, required this.title, this.large = false});

  final String title;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    // Teinte stable selon le titre : ambre ou turquoise (jamais de violet).
    final tint = title.codeUnits.fold<int>(0, (a, b) => a + b).isEven
        ? c.accent
        : c.secondary;
    return Semantics(
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.surfaceRaised, c.bgAlt],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PositionedDirectional(
              start: 0,
              end: 0,
              top: 0,
              child: ColoredBox(color: tint, child: const SizedBox(height: 6)),
            ),
            Padding(
              padding: EdgeInsets.all(
                large ? LumioSpacing.lg : LumioSpacing.md,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.movie_outlined,
                    size: large ? 56 : 36,
                    color: tint,
                  ),
                  const SizedBox(height: LumioSpacing.sm),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: large ? 6 : 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: c.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Fiche d'un fichier local ---

/// Ouvre la fiche d'un fichier local.
Future<void> openLocalDetail(BuildContext context, MetaPreview item) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LocalDetailScreen(id: item.id)),
    );

String _size(int bytes) {
  if (bytes <= 0) return '';
  const units = ['o', 'Ko', 'Mo', 'Go'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i < 2 ? 0 : 1)} ${units[i]}';
}

/// Fiche : titre (corrigeable), lecture. Les fichiers locaux n'ont ni
/// certification ni affiche : un profil enfant n'y a pas accès.
class LocalDetailScreen extends ConsumerWidget {
  const LocalDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final items = ref.watch(localItemsProvider);
    final item = items.value?.where((i) => i.id == id).firstOrNull;
    final allowed = contentAllowed(ref.watch(currentProfileProvider), const [
      null,
    ]);
    Widget body;
    if (!items.hasValue) {
      body = const StateView.loading();
    } else if (!allowed) {
      body = StateView.empty(message: l.notAllowedForProfile);
    } else if (item == null) {
      body = StateView.empty(message: l.localFileMissing);
    } else {
      body = _Body(item: item);
    }
    return TvScaffold(
      child: Scaffold(
        appBar: AppBar(
          title: Text(allowed ? item?.displayTitle ?? '' : ''),
          backgroundColor: Colors.transparent,
        ),
        body: body,
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.item});

  final LocalItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final c = context.lumio;
    final meta = [
      ?item.episodeLabel,
      ?item.year?.toString(),
      if (_size(item.sizeBytes).isNotEmpty) _size(item.sizeBytes),
    ].join(' · ');
    return ListView(
      padding: const EdgeInsets.all(LumioSpacing.lg),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 200,
              height: 300,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(LumioRadius.md),
                child: LocalTitleCard(title: item.displayTitle, large: true),
              ),
            ),
            const SizedBox(width: LumioSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.displayTitle, style: theme.textTheme.headlineSmall),
                  if (meta.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: LumioSpacing.xs),
                      child: Text(
                        meta,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: c.textMuted,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: LumioSpacing.xs),
                    child: Text(
                      item.fileName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: LumioSpacing.lg),
                  Wrap(
                    spacing: LumioSpacing.sm,
                    runSpacing: LumioSpacing.sm,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('local-play'),
                        autofocus: true,
                        onPressed: () =>
                            playLocalFromWidget(context, ref, item),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(l.play),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('local-fix'),
                        onPressed: () => showFixTitleDialog(context, ref, item),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(l.localFixTitle),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// --- Gestion des dossiers ---

/// Dossiers locaux : liste, ajout, retrait, analyse, vidéos reconnues avec
/// correction du titre.
class LocalFoldersScreen extends ConsumerStatefulWidget {
  const LocalFoldersScreen({super.key});

  @override
  ConsumerState<LocalFoldersScreen> createState() => _LocalFoldersScreenState();
}

class _LocalFoldersScreenState extends ConsumerState<LocalFoldersScreen> {
  bool _scanning = false;

  Future<void> _scanAll() async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    setState(() => _scanning = true);
    try {
      await ref.read(localLibraryProvider).rescanAll(force: true);
      final n =
          (await ref.read(localLibraryProvider).watchItems().first).length;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.localScanDone(n))));
    } on Object {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.localScanFailed)));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _remove(LocalFolder f) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = context.l10n.localFolderRemoved;
    await ref.read(localLibraryProvider).removeFolder(f.path);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final folders = ref.watch(localFoldersProvider);
    final items = ref.watch(localItemsProvider).value ?? const <LocalItem>[];
    final c = context.lumio;
    return TvScaffold(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.localFolders),
          actions: [
            if (folders.value?.isNotEmpty ?? false)
              IconButton(
                key: const ValueKey('local-scan'),
                tooltip: l.localScanNow,
                onPressed: _scanning ? null : _scanAll,
                icon: _scanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: LumioSpacing.sm),
              child: FilledButton.icon(
                key: const ValueKey('local-add'),
                autofocus: true,
                onPressed: () => addLocalFolderFlow(context, ref),
                icon: const Icon(Icons.add),
                label: Text(l.localAddFolder),
              ),
            ),
          ],
        ),
        body: folders.when(
          loading: () => const StateView.loading(),
          error: (_, _) => StateView.error(
            message: l.localScanFailed,
            onRetry: () => ref.invalidate(localFoldersProvider),
          ),
          data: (list) {
            if (list.isEmpty) return StateView.empty(message: l.localEmpty);
            return ListView(
              padding: const EdgeInsets.all(LumioSpacing.md),
              children: [
                if (_scanning)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: LumioSpacing.sm),
                      child: Text(l.localScanning),
                    ),
                  ),
                for (final f in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: LumioSpacing.sm),
                    child: FocusRing(
                      child: ListTile(
                        key: ValueKey('local-folder:${f.path}'),
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(f.path),
                        subtitle: Text(
                          l.localVideoCount(
                            items.where((i) => i.folderPath == f.path).length,
                          ),
                        ),
                        trailing: IconButton(
                          key: ValueKey('local-remove:${f.path}'),
                          tooltip: l.localRemoveFolder(f.path),
                          onPressed: () => _remove(f),
                          icon: Icon(Icons.delete_outline, color: c.error),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: LumioSpacing.md),
                for (final i in items)
                  FocusRing(
                    child: ListTile(
                      key: ValueKey('local-item:${i.id}'),
                      leading: const Icon(Icons.movie_outlined),
                      title: Text(i.displayTitle),
                      subtitle: Text(
                        [?i.episodeLabel, i.fileName].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => LocalDetailScreen(id: i.id),
                        ),
                      ),
                      trailing: IconButton(
                        key: ValueKey('local-edit:${i.id}'),
                        tooltip: l.localFixTitle,
                        onPressed: () => showFixTitleDialog(context, ref, i),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
