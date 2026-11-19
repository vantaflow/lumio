import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/features/addons/addon_labels.dart';
import 'package:lumio/features/addons/addon_logo.dart';
import 'package:lumio/features/addons/catalog_tab.dart';
import 'package:lumio/l10n/error_messages.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/common/tv_dialogs.dart';
import 'package:lumio/ui/common/tv_screen.dart' show tvMarginOf;
import 'package:lumio/ui/common/tv_text_field.dart';
import 'package:lumio/ui/focus/focusable_card.dart';
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/ui/focus/tv_scaffold.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

/// Ouvre l'écran « Ajouter un addon » (Catalogue / Par lien / Depuis le
/// téléphone, maquettes TV16, TV08, TV09). Renvoie vrai si un addon a été
/// installé. [initialUrl] ouvre l'onglet « Par lien » prérempli.
Future<bool> showAddAddonScreen(
  BuildContext context, {
  String? initialUrl,
}) async {
  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => AddAddonScreen(initialUrl: initialUrl),
    ),
  );
  return ok ?? false;
}

enum AddAddonTab { catalog, link, phone }

class AddAddonScreen extends StatefulWidget {
  const AddAddonScreen({
    super.key,
    this.initialUrl,
    this.debounce = const Duration(milliseconds: 600),
  });

  final String? initialUrl;
  final Duration debounce;

  @override
  State<AddAddonScreen> createState() => _AddAddonScreenState();
}

class _AddAddonScreenState extends State<AddAddonScreen> {
  late AddAddonTab _tab;
  final _visited = <AddAddonTab>{};
  String? _linkUrl;
  int _linkSeq = 0;

  @override
  void initState() {
    super.initState();
    _linkUrl = widget.initialUrl;
    _tab = widget.initialUrl == null ? AddAddonTab.catalog : AddAddonTab.link;
    _visited.add(_tab);
  }

  void _select(AddAddonTab t) => setState(() {
    _tab = t;
    _visited.add(t);
  });

  /// Le catalogue confie une adresse au flux « Par lien » (aperçu, garde
  /// réseau, installation).
  void _useLink(String url) => setState(() {
    _linkUrl = url;
    _linkSeq++;
    _tab = AddAddonTab.link;
    _visited.add(AddAddonTab.link);
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.lumio;
    final m = tvMarginOf(context);
    final t = Theme.of(context).textTheme;
    return TvScaffold(
      child: Scaffold(
        body: Padding(
          padding: EdgeInsets.fromLTRB(m, 64, m, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.addAddonBreadcrumb,
                style: t.bodySmall?.copyWith(fontSize: 26, color: c.textMuted),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l.addAddon,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.headlineLarge?.copyWith(
                          fontSize: 60,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.62,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (i, tab)
                              in AddAddonTab.values.indexed) ...[
                            if (i > 0) const SizedBox(width: 12),
                            _TabPill(
                              key: ValueKey('addtab:${tab.name}'),
                              label: switch (tab) {
                                AddAddonTab.catalog => l.addonTabCatalog,
                                AddAddonTab.link => l.addonTabLink,
                                AddAddonTab.phone => l.addonTabPhone,
                              },
                              selected: _tab == tab,
                              onSelect: () => _select(tab),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: _tab == AddAddonTab.link ? 48 : 32),
              Expanded(
                child: IndexedStack(
                  index: _tab.index,
                  children: [
                    if (_visited.contains(AddAddonTab.catalog))
                      CatalogTab(
                        active: _tab == AddAddonTab.catalog,
                        onUseLink: _useLink,
                      )
                    else
                      const SizedBox.shrink(),
                    if (_visited.contains(AddAddonTab.link))
                      LinkTab(
                        key: ValueKey('link:$_linkSeq'),
                        initialUrl: _linkUrl,
                        debounce: widget.debounce,
                        active: _tab == AddAddonTab.link,
                        onInstalled: () => Navigator.of(context).pop(true),
                      )
                    else
                      const SizedBox.shrink(),
                    const _PhoneTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Onglet de l'en-tête (maquette TV16 `.tab`) : 64 de haut, texte 28 ; l'onglet
/// courant est clair, les autres sombres.
class _TabPill extends StatelessWidget {
  const _TabPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.lumio;
    final fg = selected ? c.bg : c.textMuted;
    final w = selected ? FontWeight.w700 : FontWeight.w600;
    return FocusableCard(
      scale: 1.06,
      borderRadius: BorderRadius.circular(32),
      semanticLabel: label,
      onSelect: onSelect,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.text : c.surface,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 28,
            fontWeight: w,
            fontVariations: [FontVariation.weight(w.value.toDouble())],
            color: fg,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

/// Troisième onglet : emplacement propre en attendant la page servie par la
/// box (maquette TV09).
class _PhoneTab extends StatelessWidget {
  const _PhoneTab();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.lumio;
    final t = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Container(
          key: const ValueKey('addtab:phone-body'),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.phoneTabSoonTitle,
                style: t.headlineMedium?.copyWith(fontSize: 46),
              ),
              const SizedBox(height: 16),
              Text(
                l.phoneTabSoonBody,
                style: t.bodyMedium?.copyWith(
                  fontSize: 28,
                  height: 1.4,
                  color: c.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Onglet « Par lien » (maquette TV08) : champ, Coller, aperçu du manifest,
/// Installer. Le flux est celui de l'ancien dialogue : aperçu, garde réseau,
/// confirmation d'adresse locale, installation (URL chiffrée dans SecretStore).
class LinkTab extends ConsumerStatefulWidget {
  const LinkTab({
    super.key,
    this.initialUrl,
    required this.onInstalled,
    this.active = true,
    this.debounce = const Duration(milliseconds: 600),
  });

  final String? initialUrl;
  final VoidCallback onInstalled;
  final bool active;
  final Duration debounce;

  @override
  ConsumerState<LinkTab> createState() => _LinkTabState();
}

class _LinkTabState extends ConsumerState<LinkTab> {
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
      final ok = await showTvConfirm(
        context,
        title: context.l10n.localAddressTitle,
        body: context.l10n.localAddressBody,
        confirmLabel: context.l10n.continueAction,
      );
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
      if (mounted) widget.onInstalled();
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
    final l = context.l10n;
    final c = context.lumio;
    final t = Theme.of(context).textTheme;
    final sm = t.bodySmall?.copyWith(
      fontSize: 24,
      height: 1.4,
      color: c.textMuted,
    );
    return SingleChildScrollView(
      clipBehavior: Clip.none,
      padding: const EdgeInsets.only(bottom: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 104,
                  child: TvTextField(
                    key: const ValueKey('link-field'),
                    controller: _controller,
                    autofocus: widget.active && widget.initialUrl == null,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    onChanged: _onChanged,
                    onSubmitted: (_) => _schedule(immediate: true),
                    style: const TextStyle(fontSize: 32, height: 1.25),
                    decoration: InputDecoration(
                      hintText: 'https://…/manifest.json',
                      filled: true,
                      fillColor: c.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 36,
                        vertical: 30,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: c.focusRing, width: 4),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              FocusableCard(
                key: const ValueKey('link-paste'),
                scale: 1.04,
                borderRadius: BorderRadius.circular(24),
                semanticLabel: l.paste,
                onSelect: _paste,
                child: Container(
                  height: 104,
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surfaceFocus,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    l.paste,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      fontVariations: [FontVariation.weight(600)],
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? l.addonLinkHelp,
            key: const ValueKey('link-help'),
            style: _error == null ? sm : sm?.copyWith(color: c.error),
          ),
          if (_copiedLink != null) ...[
            const SizedBox(height: 16),
            TvButton(
              key: const ValueKey('link-use-copied'),
              label: l.useCopiedLink,
              kind: TvButtonKind.secondary,
              height: 64,
              fontSize: 26,
              horizontalPadding: 32,
              onPressed: _useCopied,
            ),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_preview != null) ...[
            const SizedBox(height: 48),
            _PreviewCard(
              manifest: _preview!,
              already: _already,
              installing: _installing,
              onInstall: _install,
            ),
          ],
          const SizedBox(height: 28),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Text(l.addonLinkTrust, style: sm),
          ),
        ],
      ),
    );
  }
}

/// Aperçu du manifest (maquette TV08) : logo 150, « APERÇU · vX », nom,
/// description, pastilles de types et de capacités, bouton Installer.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.manifest,
    required this.already,
    required this.installing,
    required this.onInstall,
  });

  final AddonManifest manifest;
  final bool already;
  final bool installing;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.lumio;
    final t = Theme.of(context).textTheme;
    final caps = addonCapabilities(
      [for (final r in manifest.resources) r.name],
      manifest.catalogs.isNotEmpty,
      const [],
      l,
    );
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final action = already
        ? TvButton(
            key: const ValueKey('link-already'),
            label: l.alreadyInstalled,
            kind: TvButtonKind.secondary,
            height: 96,
            fontSize: 34,
            horizontalPadding: 48,
            onPressed: null,
          )
        : TvButton(
            key: const ValueKey('link-install'),
            autofocus: true,
            label: installing ? '…' : l.install,
            semanticLabel: l.install,
            height: 96,
            fontSize: 34,
            horizontalPadding: 64,
            onPressed: installing ? null : onInstall,
          );
    final logo = AddonLogo(
      logo: manifest.logo,
      name: manifest.name,
      size: 150,
      radius: 36,
    );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.addonPreviewLabel(manifest.version),
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            fontVariations: const [FontVariation.weight(700)],
            color: c.secondary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          manifest.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.headlineMedium?.copyWith(fontSize: 46, height: 1.2),
        ),
        if (manifest.description != null) ...[
          const SizedBox(height: 8),
          Text(
            manifest.description!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.bodySmall?.copyWith(
              fontSize: 24,
              height: 1.4,
              color: c.textMuted,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final ty in manifest.types) _Pill(contentTypeLabel(ty, l)),
            if (caps.isNotEmpty) _Pill(caps),
          ],
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(32),
      ),
      child: wide
          ? Row(
              children: [
                logo,
                const SizedBox(width: 40),
                Expanded(child: info),
                const SizedBox(width: 40),
                action,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                logo,
                const SizedBox(height: 24),
                info,
                const SizedBox(height: 24),
                action,
              ],
            ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    decoration: BoxDecoration(
      color: context.lumio.surfaceFocus,
      borderRadius: BorderRadius.circular(26),
    ),
    child: Center(
      widthFactor: 1,
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          fontVariations: [FontVariation.weight(600)],
          height: 1.2,
        ),
      ),
    ),
  );
}
