import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/features/addons/addon_labels.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/data/addon_repository.dart';
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
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl ?? '');
    if (_controller.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _schedule(immediate: true);
      });
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
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      setState(() => _error = 'Le presse-papiers est vide');
      return;
    }
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    _allowPrivate = false;
    _schedule(immediate: true);
  }

  Future<void> _fetchPreview() async {
    final gen = ++_generation;
    final text = _controller.text;
    setState(() {
      _loading = true;
      _error = null;
      _preview = null;
    });
    try {
      final m = await ref
          .read(addonRepositoryProvider)
          .preview(text, allowPrivate: _allowPrivate);
      if (!mounted || gen != _generation) return;
      setState(() {
        _preview = m;
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
        setState(
          () => _error = 'Adresse locale refusée : aucun addon installé',
        );
      }
    } on AddonException catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = 'Impossible de lire cet addon';
        _loading = false;
      });
    }
  }

  Future<bool> _confirmPrivate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adresse locale'),
        content: const Text(
          'Cette adresse pointe vers votre appareil ou votre réseau local. '
          'Ne continuez que si vous avez vous-même lancé cet addon.',
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuer'),
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
          .install(_controller.text, allowPrivate: _allowPrivate);
      await ref.read(addonsProvider.notifier).refresh();
      if (mounted) Navigator.pop(context, true);
    } on AddonException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _installing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Installation impossible';
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
              Text('Ajouter un addon', style: theme.textTheme.headlineMedium),
              const SizedBox(height: LumioSpacing.md),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onChanged: _onChanged,
                onSubmitted: (_) => _schedule(immediate: true),
                decoration: InputDecoration(
                  labelText: 'Lien de l\'addon',
                  hintText: 'https://…/manifest.json',
                  errorText: _error,
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: LumioSpacing.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: _paste,
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Coller'),
                ),
              ),
              const SizedBox(height: LumioSpacing.md),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: LumioSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_preview != null)
                _Preview(manifest: _preview!),
              const SizedBox(height: LumioSpacing.md),
              Text(
                'N\'installez que des addons de sources de confiance : un '
                'addon voit ce que vous consultez.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: LumioSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _installing
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: LumioSpacing.sm),
                  FilledButton(
                    onPressed: _preview != null && !_installing
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
                        : const Text('Installer'),
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
  const _Preview({required this.manifest});
  final AddonManifest manifest;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    final theme = Theme.of(context);
    final resources = {
      for (final r in manifest.resources) resourceLabel(r.name),
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
                  'Version ${manifest.version}',
                  style: theme.textTheme.bodySmall,
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
                      _Chip(contentTypeLabel(t), c.secondary),
                  ],
                ),
                const SizedBox(height: LumioSpacing.sm),
                Text(
                  'Fournit : ${resources.join(', ')}',
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(LumioRadius.sm),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: logo == null
          ? fallback
          : Image.network(
              logo.toString(),
              width: size,
              height: size,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}
