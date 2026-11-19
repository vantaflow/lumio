import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lumio/ui/common/tv_scroll_clip.dart';
import 'package:lumio/ui/common/tv_text_field.dart';
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
import 'package:lumio/ui/common/tv_dialogs.dart';
import 'package:lumio/ui/common/tv_screen.dart';
import 'package:lumio/ui/focus/focus_ring.dart';
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/ui/icons/lumio_icons.dart';
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
  void tell(String m, {bool error = false}) {
    if (messenger != null && context.mounted) {
      showTvSnack(context, m, error: error);
    }
  }

  bool granted;
  try {
    granted = await ref.read(storagePermissionProvider).ensure();
  } on Object {
    granted = false;
  }
  if (!granted) {
    tell(l.localPermissionDenied, error: true);
    return null;
  }
  if (!context.mounted) return null;

  String? path;
  var typed = false;
  if (Platform.isAndroid) {
    // Sur Android le sélecteur n'atteint que le stockage interne : on laisse
    // aussi saisir un chemin (carte SD, clé USB).
    final choice = await showTvPanel<bool>(
      context,
      builder: (ctx) => TvPanel(
        title: ctx.l10n.localAddFolder,
        width: 820,
        onBack: () => Navigator.pop(ctx),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: TvTile(
              key: const ValueKey('local-choose'),
              autofocus: true,
              minHeight: 104,
              color: ctx.lumio.surfaceFocus,
              semanticLabel: ctx.l10n.localChooseFolder,
              onSelect: () => Navigator.pop(ctx, true),
              child: _ChoiceRow(
                icon: LumioIcon.folder,
                title: ctx.l10n.localChooseFolder,
              ),
            ),
          ),
          TvTile(
            key: const ValueKey('local-type'),
            minHeight: 104,
            color: ctx.lumio.bg,
            semanticLabel: ctx.l10n.localTypePath,
            onSelect: () => Navigator.pop(ctx, false),
            child: _ChoiceRow(
              icon: LumioIcon.keyboard,
              title: ctx.l10n.localTypePath,
              subtitle: ctx.l10n.localSdNote,
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
      tell(l.localPickerUnavailable, error: true);
    }
  }
  if (typed) {
    if (!context.mounted) return null;
    path = await _askPath(context);
    if (path == null || path.trim().isEmpty) return null;
  }
  try {
    final library = ref.read(localLibraryProvider);
    final n = await library.addFolder(path!);
    tell(
      library.isIncomplete(path)
          ? l.localScanIncomplete
          : l.localFolderAdded(n),
    );
    return n;
  } on LocalFolderForbiddenException {
    tell(l.localFolderForbidden, error: true);
  } on LocalFolderOverlapException {
    tell(l.localFolderOverlap, error: true);
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

Future<String?> _askPath(BuildContext context) => showTvPanel<String>(
  context,
  builder: (ctx) => _TextPrompt(
    title: ctx.l10n.localPathTitle,
    label: ctx.l10n.localPathLabel,
    hint: ctx.l10n.localPathHint,
    confirmLabel: ctx.l10n.add,
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
  Widget build(BuildContext context) {
    final c = context.lumio;
    final muted = TextStyle(
      fontFamily: 'Manrope',
      fontSize: 24,
      fontWeight: FontWeight.w600,
      fontVariations: const [FontVariation.weight(600)],
      color: c.textMuted,
    );
    // Maquette P08 (droite) : étiquette 24, champ de 80, aide 24, boutons.
    return TvPanel(
      title: widget.title,
      width: 820,
      onBack: () => Navigator.pop(context),
      actions: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                TvButton(
                  label: context.l10n.cancel,
                  kind: TvButtonKind.ghost,
                  height: 76,
                  fontSize: 28,
                  horizontalPadding: 40,
                  onPressed: () => Navigator.pop(context),
                ),
                if (widget.resetLabel != null)
                  TvButton(
                    key: widget.resetKey,
                    label: widget.resetLabel!,
                    kind: TvButtonKind.secondary,
                    height: 76,
                    fontSize: 28,
                    horizontalPadding: 40,
                    onPressed: () => Navigator.pop(context, ''),
                  ),
                TvButton(
                  key: widget.confirmKey,
                  label: widget.confirmLabel,
                  height: 76,
                  fontSize: 28,
                  horizontalPadding: 40,
                  onPressed: () => Navigator.pop(context, _ctl.text),
                ),
              ],
            ),
          ),
        ),
      ],
      children: [
        Text(widget.label, style: muted),
        const SizedBox(height: 8),
        FocusRing(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.outline, width: 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TvTextField(
                    key: widget.fieldKey,
                    controller: _ctl,
                    autofocus: true,
                    maxLength: widget.maxLength,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      fontVariations: [FontVariation.weight(600)],
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      counterText: '',
                      isCollapsed: true,
                      hintText: widget.hint,
                      hintStyle: TextStyle(color: c.textMuted),
                    ),
                    onSubmitted: (v) => Navigator.pop(context, v),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(widget.helper!, style: muted.copyWith(fontSize: 24)),
          ),
      ],
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.icon, required this.title, this.subtitle});

  final LumioIcon icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      LumioIconView(icon, size: 40, color: context.lumio.secondary),
      const SizedBox(width: 24),
      Expanded(
        child: TvTileText(title: title, subtitle: subtitle, maxLines: 3),
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
  final result = await showTvPanel<String>(
    context,
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
  void tell(String m) => showTvSnack(context, m, error: true);
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
    // Maquette TV31 : dégradé turquoise vers le fond, titre en bas à gauche.
    return Semantics(
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.45, -1),
            end: Alignment(0.45, 1.2),
            colors: [Color(0xFF2E6F7A), Color(0xFF10151B)],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(large ? 16 : LumioSpacing.md),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              title,
              maxLines: large ? 6 : 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Bricolage Grotesque',
                fontSize: large ? 26 : 22,
                height: 1.15,
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation.weight(700)],
                color: c.text,
              ),
            ),
          ),
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
    // Maquette TV31 : retour rond + titre de 56, puis affiche et texte.
    return TvScreen(
      title: allowed ? item?.displayTitle ?? '' : '',
      child: body,
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.item});

  final LocalItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.lumio;
    final detected = [item.title, ?item.year?.toString()].join(' · ');
    TextStyle style(
      double size,
      Color color, [
      FontWeight w = FontWeight.w400,
    ]) => TextStyle(
      fontFamily: 'Manrope',
      fontSize: size,
      height: 1.35,
      fontWeight: w,
      fontVariations: [FontVariation.weight(w.value.toDouble())],
      color: color,
    );
    return ListView(
      padding: const EdgeInsets.only(top: 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 360,
              height: 540,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: LocalTitleCard(title: item.displayTitle, large: true),
              ),
            ),
            const SizedBox(width: 64),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayTitle,
                      style: const TextStyle(
                        fontFamily: 'Bricolage Grotesque',
                        fontSize: 64,
                        fontWeight: FontWeight.w700,
                        fontVariations: [FontVariation.weight(700)],
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l.localDetected(detected),
                      style: style(28, c.textMuted),
                    ),
                    const SizedBox(height: 14),
                    Text(item.fileName, style: style(24, c.textMuted)),
                    const SizedBox(height: 34),
                    Row(
                      children: [
                        TvButton(
                          key: const ValueKey('local-play'),
                          autofocus: true,
                          label: l.play,
                          height: 76,
                          fontSize: 28,
                          horizontalPadding: 40,
                          icon: LumioIconView(
                            LumioIcon.play,
                            size: 32,
                            color: c.onAccent,
                          ),
                          onPressed: () =>
                              playLocalFromWidget(context, ref, item),
                        ),
                        const SizedBox(width: 16),
                        TvButton(
                          key: const ValueKey('local-fix'),
                          label: l.localFixTitle,
                          kind: TvButtonKind.secondary,
                          height: 76,
                          fontSize: 28,
                          horizontalPadding: 40,
                          icon: LumioIconView(
                            LumioIcon.pencil,
                            size: 32,
                            color: c.text,
                          ),
                          onPressed: () =>
                              showFixTitleDialog(context, ref, item),
                        ),
                      ],
                    ),
                  ],
                ),
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
    final l = context.l10n;
    setState(() => _scanning = true);
    try {
      await ref.read(localLibraryProvider).rescanAll(force: true);
      final n =
          (await ref.read(localLibraryProvider).watchItems().first).length;
      final library = ref.read(localLibraryProvider);
      final incomplete = [
        for (final f in await library.grantedFolders())
          if (library.isIncomplete(f)) f,
      ].isNotEmpty;
      if (mounted) {
        showTvSnack(
          context,
          incomplete ? l.localScanIncomplete : l.localScanDone(n),
        );
      }
    } on Object {
      if (mounted) showTvSnack(context, l.localScanFailed, error: true);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _remove(LocalFolder f) async {
    final text = context.l10n.localFolderRemoved;
    await ref.read(localLibraryProvider).removeFolder(f.path);
    if (mounted) showTvSnack(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final folders = ref.watch(localFoldersProvider);
    final items = ref.watch(localItemsProvider).value ?? const <LocalItem>[];
    final c = context.lumio;
    return TvScreen(
      title: l.localFolders,
      subtitle: l.localSubtitle,
      actions: [
        if (folders.value?.isNotEmpty ?? false)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TvIconButton(
              key: const ValueKey('local-scan'),
              lumioIcon: LumioIcon.refresh,
              background: c.surface,
              label: l.localScanNow,
              onPressed: _scanning ? null : _scanAll,
            ),
          ),
        TvButton(
          key: const ValueKey('local-add'),
          autofocus: true,
          label: l.localAddFolder,
          height: 76,
          fontSize: 28,
          horizontalPadding: 40,
          icon: LumioIconView(LumioIcon.plus, size: 32, color: c.onAccent),
          onPressed: () => addLocalFolderFlow(context, ref),
        ),
      ],
      child: folders.when(
        loading: () => const StateView.loading(),
        error: (_, _) => StateView.error(
          message: l.localScanFailed,
          onRetry: () => ref.invalidate(localFoldersProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            // Maquette TV49 : pastille de 96, message de 34, à 420 du haut.
            return Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 268),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.surface,
                      ),
                      child: LumioIconView(
                        LumioIcon.inbox,
                        size: 48,
                        color: c.textMuted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Text(
                        l.localEmpty,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 34,
                          height: 1.4,
                          color: Color(0xFFC9D0DA),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return TvScrollClip(child: ListView(
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              if (_scanning)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            color: c.accent,
                            backgroundColor: c.outline,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          l.localScanning,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 28,
                            height: 1.4,
                            color: c.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              for (final f in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    key: ValueKey('local-folder:${f.path}'),
                    constraints: const BoxConstraints(minHeight: 96),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        LumioIconView(
                          LumioIcon.folder,
                          size: 40,
                          color: c.secondary,
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: TvTileText(
                            title: f.path,
                            subtitle: l.localVideoCount(
                              items.where((i) => i.folderPath == f.path).length,
                            ),
                          ),
                        ),
                        TvIconButton(
                          key: ValueKey('local-remove:${f.path}'),
                          lumioIcon: LumioIcon.trash,
                          iconColor: c.error,
                          background: c.bg,
                          label: l.localRemoveFolder(f.path),
                          onPressed: () => _remove(f),
                        ),
                      ],
                    ),
                  ),
                ),
              for (final i in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 96),
                    padding: const EdgeInsetsDirectional.only(end: 32),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TvTile(
                            key: ValueKey('local-item:${i.id}'),
                            minHeight: 96,
                            color: Colors.transparent,
                            semanticLabel: i.displayTitle,
                            onSelect: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => LocalDetailScreen(id: i.id),
                              ),
                            ),
                            child: Row(
                              children: [
                                LumioIconView(
                                  LumioIcon.clapper,
                                  size: 40,
                                  color: c.textMuted,
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: TvTileText(
                                    title: i.displayTitle,
                                    subtitle: [
                                      ?i.episodeLabel,
                                      i.fileName,
                                    ].join(' · '),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TvIconButton(
                          key: ValueKey('local-edit:${i.id}'),
                          lumioIcon: LumioIcon.pencil,
                          background: c.bg,
                          label: l.localFixTitle,
                          onPressed: () => showFixTitleDialog(context, ref, i),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ));
        },
      ),
    );
  }
}
