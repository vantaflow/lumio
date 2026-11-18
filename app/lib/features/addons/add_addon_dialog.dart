import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lumio/ui/common/tv_text_field.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/l10n/error_messages.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/features/addons/addon_labels.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/ui/common/guarded_image.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

/// Ouvre l'écran d'ajout d'addon (un champ, un aperçu, un bouton). Renvoie
/// vrai si un addon a été installé. [initialUrl] pré-remplit le champ.
Future<bool> showAddAddonDialog(
  BuildContext context, {
  String? initialUrl,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AddAddonDialog(initialUrl: initialUrl),
  );
  return ok ?? false;
}

class AddAddonDialog extends ConsumerStatefulWidget {
  const AddAddonDialog({
    super.key,
    this.initialUrl,
    this.debounce = const Duration(milliseconds: 600),
  });

  final String? initialUrl;

  /// Délai entre la dernière frappe et la récupération de l'aperçu.
  final Duration debounce;

  @override
  ConsumerState<AddAddonDialog> createState() => _AddAddonDialogState();
}

class _AddAddonDialogState extends ConsumerState<AddAddonDialog> {
  late final TextEditingController _controller;
  Timer? _timer;
  int _generation = 0;

  bool _loading = false;
  bool _installing = false;
  bool _allowPrivate = false;
  AddonManifest? _preview;
  bool _already = false;
  String? _error;
  String? _copiedLink;

  /// Lien d'installation (stremio://, texte avec URL) converti en URL http(s).
  String get _effectiveUrl {
    final text = _controller.text;
    return parseInstallLink(text)?.toString() ?? text;
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (!mounted || !isPlausibleInstallLink(text)) return;
      setState(() => _copiedLink = text);
    } catch (_) {
      // Presse-papiers illisible : rien n'est proposé.
    }
  }

  void _useCopied() {
    final text = _copiedLink;
    if (text == null) return;
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    _allowPrivate = false;
    setState(() => _copiedLink = null);
    _schedule(immediate: true);
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl ?? '');
    if (_controller.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _schedule(immediate: true);
      });
    } else {
      unawaited(_checkClipboard());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    // Un nouveau texte annule la confirmation « réseau local » précédente.
    _allowPrivate = false;
    _schedule();
  }

  void _schedule({bool immediate = false}) {
    _timer?.cancel();
    _generation++;
    setState(() {
      _preview = null;
      _already = false;
      _error = null;
      _loading = false;
    });
    if (_controller.text.trim().isEmpty) return;
    if (immediate) {
      unawaited(_fetchPreview());
    } else {
      _timer = Timer(widget.debounce, _fetchPreview);
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      setState(() => _error = context.l10n.clipboardEmpty);
      return;
    }
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    _allowPrivate = false;
    _schedule(immediate: true);
  }

  Future<void> _fetchPreview() async {
    final gen = ++_generation;
    final text = _effectiveUrl;
    setState(() {
      _loading = true;
      _error = null;
      _preview = null;
    });
    try {
      final repo = ref.read(addonRepositoryProvider);
      final m = await repo.preview(text, allowPrivate: _allowPrivate);
      final already = await repo.isInstalled(text);
      if (!mounted || gen != _generation) return;
      setState(() {
        _preview = m;
        _already = already;
        _loading = false;
      });
    } on PrivateAddressException {
      if (!mounted || gen != _generation) return;
      setState(() => _loading = false);
      final ok = await _confirmPrivate();
      if (!mounted || gen != _generation) return;
      if (ok) {
        _allowPrivate = true;
        await _fetchPreview();
      } else {
        setState(() => _error = context.l10n.localAddressRefused);
      }
    } on AddonException catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = l10nForError(context.l10n, e);
        _loading = false;
      });
    } catch (_) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = context.l10n.addonUnreadable;
        _loading = false;
      });
    }
  }

  Future<bool> _confirmPrivate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.localAddressTitle),
        content: Text(ctx.l10n.localAddressBody),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.continueAction),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _install() async {
    setState(() {
      _installing = true;
      _error = null;
    });
    try {
      await ref
          .read(addonRepositoryProvider)
          .install(_effectiveUrl, allowPrivate: _allowPrivate);
      await ref.read(addonsProvider.notifier).refresh();
      if (mounted) Navigator.pop(context, true);
    } on AddonException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = l10nForError(context.l10n, e);
        _installing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.installFailed;
        _installing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LumioSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.addAddon,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: LumioSpacing.md),
              TvTextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onChanged: _onChanged,
                onSubmitted: (_) => _schedule(immediate: true),
                decoration: InputDecoration(
                  labelText: context.l10n.addonLinkLabel,
                  hintText: 'https://…/manifest.json',
                  errorText: _error,
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: LumioSpacing.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: LumioSpacing.sm,
                  runSpacing: LumioSpacing.sm,
                  children: [
                    if (_copiedLink != null)
                      FilledButton.tonalIcon(
                        onPressed: _useCopied,
                        icon: const Icon(Icons.link),
                        label: Text(context.l10n.useCopiedLink),
                      ),
                    OutlinedButton.icon(
                      onPressed: _paste,
                      icon: const Icon(Icons.content_paste),
                      label: Text(context.l10n.paste),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: LumioSpacing.md),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: LumioSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_preview != null)
                _Preview(manifest: _preview!, already: _already),
              const SizedBox(height: LumioSpacing.md),
              Text(context.l10n.trustWarning, style: theme.textTheme.bodySmall),
              const SizedBox(height: LumioSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _installing
                        ? null
                        : () => Navigator.pop(context, false),
                    child: Text(context.l10n.cancel),
                  ),
                  const SizedBox(width: LumioSpacing.sm),
                  FilledButton(
                    onPressed: _preview != null && !_already && !_installing
                        ? _install
                        : null,
                    style: FilledButton.styleFrom(
                      disabledBackgroundColor: c.surfaceFocus,
                    ),
                    child: _installing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.l10n.install),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.manifest, required this.already});
  final AddonManifest manifest;
  final bool already;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    final theme = Theme.of(context);
    final resources = {
      for (final r in manifest.resources) resourceLabel(r.name, context.l10n),
    };
    return Container(
      padding: const EdgeInsets.all(LumioSpacing.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(LumioRadius.md),
        border: Border.all(color: c.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AddonLogo(logo: manifest.logo, size: 64),
          const SizedBox(width: LumioSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(manifest.name, style: theme.textTheme.titleLarge),
                Text(
                  context.l10n.versionLabel(manifest.version),
                  style: theme.textTheme.bodySmall,
                ),
                if (already)
                  Padding(
                    padding: const EdgeInsets.only(top: LumioSpacing.xs),
                    child: Text(
                      context.l10n.alreadyInstalled,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: c.warning,
                      ),
                    ),
                  ),
                if (manifest.description != null) ...[
                  const SizedBox(height: LumioSpacing.sm),
                  Text(
                    manifest.description!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: LumioSpacing.sm),
                Wrap(
                  spacing: LumioSpacing.sm,
                  runSpacing: LumioSpacing.xs,
                  children: [
                    for (final t in manifest.types)
                      _Chip(contentTypeLabel(t, context.l10n), c.secondary),
                  ],
                ),
                const SizedBox(height: LumioSpacing.sm),
                Text(
                  context.l10n.provides(resources.join(', ')),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(LumioRadius.sm),
      border: Border.all(color: color),
    ),
    child: Text(label, style: Theme.of(context).textTheme.labelSmall),
  );
}

/// Logo d'addon avec repli sur une icône (logo absent ou illisible).
class AddonLogo extends StatelessWidget {
  const AddonLogo({super.key, required this.logo, this.size = 48});
  final Uri? logo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    final fallback = Icon(Icons.extension_outlined, color: c.accent);
    // Le logo vient de l'addon : adresse locale ou réseau privé = pas chargé.
    var safe = logo != null;
    if (safe) {
      try {
        UrlGuard.check(logo!);
      } on UnsafeUrlException {
        safe = false;
      }
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(LumioRadius.sm),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: !safe
          ? fallback
          : Image(
              image: GuardedNetworkImage(logo!, allowPrivate: false),
              width: size,
              height: size,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}
