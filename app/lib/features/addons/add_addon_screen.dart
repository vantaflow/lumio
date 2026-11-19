import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/features/addons/addon_labels.dart';
import 'package:lumio/features/addons/addon_logo.dart';
import 'package:lumio/features/addons/catalog_tab.dart';
import 'package:lumio/features/phone/phone_add.dart';
import 'package:lumio/features/phone/phone_providers.dart';
import 'package:lumio/features/phone/phone_server.dart';
import 'package:lumio/features/phone/phone_tab.dart';
import 'package:lumio/features/settings/settings_providers.dart'
    show localeProvider;
import 'package:lumio/l10n/error_messages.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/common/tv_dialogs.dart';
import 'package:lumio/ui/common/tv_screen.dart' show tvMarginOf;
import 'package:lumio/ui/common/tv_text_field.dart';
import 'package:lumio/ui/focus/focus_rescue.dart' show appRouteObserver;
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
  AddAddonTab? initialTab,
  String? portalQuery,
  String? portalName,
}) async {
  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) =>
          AddAddonScreen(
            initialUrl: initialUrl,
            initialTab: initialTab,
            portalQuery: portalQuery,
            portalName: portalName,
          ),
    ),
  );
  return ok ?? false;
}

enum AddAddonTab { catalog, link, phone }

class AddAddonScreen extends ConsumerStatefulWidget {
  const AddAddonScreen({
    super.key,
    this.initialUrl,
    this.initialTab,
    this.portalQuery,
    this.portalName,
    this.debounce = const Duration(milliseconds: 600),
  });

  final String? initialUrl;
  final AddAddonTab? initialTab;

  /// Ouvre l'onglet du téléphone avec un QR vers la fiche d'un addon précis.
  final String? portalQuery;
  final String? portalName;
  final Duration debounce;

  @override
  ConsumerState<AddAddonScreen> createState() => _AddAddonScreenState();
}

class _AddAddonScreenState extends ConsumerState<AddAddonScreen>
    with RouteAware {
  late AddAddonTab _tab;
  final _visited = <AddAddonTab>{};
  String? _linkUrl;
  int _linkSeq = 0;

  /// Serveur de la page du téléphone : n'existe et n'écoute que pendant que
  /// l'onglet « Depuis le téléphone » est affiché (ou qu'une demande du
  /// téléphone attend la confirmation sur la TV).
  PhoneSession? _phone;

  /// Demande d'ajout venue du téléphone et en cours sur l'onglet « Par lien ».
  String? _phoneReq;

  /// Fiche d'addon à ouvrir sur le portail (QR du téléphone) : paramètre du lien
  /// et nom affiché.
  String? _portalQuery;
  String? _portalName;

  /// L'application est en arrière-plan : le serveur reste arrêté.
  bool _backgrounded = false;

  /// Un autre écran est poussé par-dessus : le serveur reste arrêté.
  bool _covered = false;

  late final AppLifecycleListener _life;
  ModalRoute<void>? _route;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(
      onHide: _onBackground,
      onPause: _onBackground,
      onShow: () => _backgrounded = false,
      onResume: () => _backgrounded = false,
    );
    _linkUrl = widget.initialUrl;
    _portalQuery = widget.portalQuery;
    _portalName = widget.portalName;
    _tab =
        widget.initialTab ??
        (widget.initialUrl == null ? AddAddonTab.catalog : AddAddonTab.link);
    _visited.add(_tab);
    if (_tab == AddAddonTab.phone) {
      _ensurePhone();
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = ModalRoute.of(context);
    if (r != _route) {
      if (_route != null) appRouteObserver.unsubscribe(this);
      _route = r;
      if (r != null) appRouteObserver.subscribe(this, r);
    }
  }

  void _onBackground() {
    _backgrounded = true;
    _suspend();
  }

  /// Arrête le serveur et abandonne la demande du téléphone en cours.
  void _suspend() {
    final id = _phoneReq;
    if (id != null) {
      _phone?.adds.resolve(id, PhoneAddState.cancelled);
      _phoneReq = null;
    }
    _sync();
  }

  @override
  void didPushNext() {
    _covered = true;
    _suspend();
  }

  @override
  void didPopNext() {
    _covered = false;
    _sync();
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _life.dispose();
    final p = _phone;
    if (p != null) {
      p.adds.pending.removeListener(_onPending);
      unawaited(p.stop());
      p.dispose();
    }
    super.dispose();
  }

  PhoneSession _ensurePhone() {
    final existing = _phone;
    if (existing != null) return existing;
    final p = ref.read(phoneSessionFactoryProvider)(
      ref.read(localeProvider).languageCode,
    );
    p.adds.pending.addListener(_onPending);
    return _phone = p;
  }

  /// Démarre ou arrête le serveur selon l'écran affiché.
  void _sync() {
    if (!mounted) return;
    final want =
        !_backgrounded &&
        !_covered &&
        (_tab == AddAddonTab.phone || _phoneReq != null);
    if (want) {
      final p = _ensurePhone();
      final st = p.state.value.status;
      if (st == PhoneServerStatus.stopped ||
          st == PhoneServerStatus.noNetwork ||
          st == PhoneServerStatus.error) {
        unawaited(p.start());
      }
    } else {
      final p = _phone;
      if (p != null && p.state.value.status != PhoneServerStatus.stopped) {
        unawaited(p.stop());
      }
    }
  }

  /// Lien reçu du téléphone : la TV affiche l'aperçu existant, l'utilisateur
  /// confirme l'installation ici.
  void _onPending() {
    final r = _phone?.adds.pending.value;
    if (r == null || !mounted) return;
    setState(() {
      _phoneReq = r.id;
      _linkUrl = r.url.toString();
      _linkSeq++;
      _tab = AddAddonTab.link;
      _visited.add(AddAddonTab.link);
    });
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.phoneAddWaiting)));
  }

  /// Fin du flux venu du téléphone : retour à l'onglet du téléphone, la page
  /// affiche le résultat.
  void _finishPhoneFlow(PhoneAddState state, {String? name}) {
    final id = _phoneReq;
    if (id == null) return;
    // Reconfiguration : le nouveau lien remplace l'ancien une fois installé.
    final replaces = _phone?.adds.lookup(id)?.replaces;
    if (state == PhoneAddState.installed && replaces != null) {
      unawaited(ref.read(addonsProvider.notifier).remove(replaces));
    }
    _phone?.adds.resolve(id, state, name: name);
    setState(() {
      _phoneReq = null;
      _tab = AddAddonTab.phone;
    });
    _sync();
  }

  /// « Configurer depuis le portail » : onglet du téléphone, QR vers la fiche.
  void _openPortal(String query, String name) {
    _select(AddAddonTab.phone);
    setState(() {
      _portalQuery = query;
      _portalName = name;
    });
  }

  void _select(AddAddonTab t) {
    if (t != AddAddonTab.phone || _tab != AddAddonTab.phone) {
      _portalQuery = null;
      _portalName = null;
    }
    final id = _phoneReq;
    if (id != null && t != AddAddonTab.link) {
      _phone?.adds.resolve(id, PhoneAddState.cancelled);
      _phoneReq = null;
    }
    setState(() {
      _tab = t;
      _visited.add(t);
    });
    _sync();
  }

  /// Le catalogue confie une adresse au flux « Par lien » (aperçu, garde
  /// réseau, installation).
  void _useLink(String url) {
    final id = _phoneReq;
    if (id != null) {
      _phone?.adds.resolve(id, PhoneAddState.cancelled);
      _phoneReq = null;
    }
    setState(() {
      _linkUrl = url;
      _linkSeq++;
      _tab = AddAddonTab.link;
      _visited.add(AddAddonTab.link);
    });
    _sync();
  }

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
              SizedBox(height: _tab == AddAddonTab.catalog ? 32 : 48),
              Expanded(
                child: IndexedStack(
                  index: _tab.index,
                  children: [
                    if (_visited.contains(AddAddonTab.catalog))
                      CatalogTab(
                        active: _tab == AddAddonTab.catalog,
                        onUseLink: _useLink,
                        onConfigure: (slug, name) =>
                            _openPortal('addon=${Uri.encodeQueryComponent(slug)}', name),
                      )
                    else
                      const SizedBox.shrink(),
                    if (_visited.contains(AddAddonTab.link))
                      LinkTab(
                        key: ValueKey('link:$_linkSeq'),
                        initialUrl: _linkUrl,
                        debounce: widget.debounce,
                        active: _tab == AddAddonTab.link,
                        onInstalled: (name) {
                          if (_phoneReq != null) {
                            _finishPhoneFlow(
                              PhoneAddState.installed,
                              name: name,
                            );
                          } else {
                            Navigator.of(context).pop(true);
                          }
                        },
                        onFailed: (message) {
                          if (_phoneReq == null) return;
                          _finishPhoneFlow(PhoneAddState.failed);
                          ScaffoldMessenger.maybeOf(context)
                            ?..hideCurrentSnackBar()
                            ..showSnackBar(SnackBar(content: Text(message)));
                        },
                      )
                    else
                      const SizedBox.shrink(),
                    if (_visited.contains(AddAddonTab.phone) && _phone != null)
                      PhoneTab(
                        session: _phone!,
                        onRestart: _sync,
                        portalQuery: _portalQuery,
                        portalName: _portalName,
                      )
                    else
                      const SizedBox.shrink(),
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

/// Onglet « Par lien » (maquette TV08) : champ, Coller, aperçu du manifest,
/// Installer. Le flux est celui de l'ancien dialogue : aperçu, garde réseau,
/// confirmation d'adresse locale, installation (URL chiffrée dans SecretStore).
class LinkTab extends ConsumerStatefulWidget {
  const LinkTab({
    super.key,
    this.initialUrl,
    required this.onInstalled,
    this.onFailed,
    this.active = true,
    this.debounce = const Duration(milliseconds: 600),
  });

  final String? initialUrl;

  /// Appelé avec le nom de l'addon une fois installé.
  final ValueChanged<String> onInstalled;

  /// Appelé avec le message affiché quand l'aperçu ou l'installation échoue.
  final ValueChanged<String>? onFailed;
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
        final msg = context.l10n.localAddressRefused;
        setState(() => _error = msg);
        widget.onFailed?.call(msg);
      }
    } on AddonException catch (e) {
      if (!mounted || gen != _generation) return;
      final msg = l10nForError(context.l10n, e);
      setState(() {
        _error = msg;
        _loading = false;
      });
      widget.onFailed?.call(msg);
    } catch (_) {
      if (!mounted || gen != _generation) return;
      final msg = context.l10n.addonUnreadable;
      setState(() {
        _error = msg;
        _loading = false;
      });
      widget.onFailed?.call(msg);
    }
  }

  Future<void> _install() async {
    final name = _preview?.name ?? '';
    setState(() {
      _installing = true;
      _error = null;
    });
    try {
      await ref
          .read(addonRepositoryProvider)
          .install(_effectiveUrl, allowPrivate: _allowPrivate);
      await ref.read(addonsProvider.notifier).refresh();
      if (mounted) widget.onInstalled(name);
    } on AddonException catch (e) {
      if (!mounted) return;
      final msg = l10nForError(context.l10n, e);
      setState(() {
        _error = msg;
        _installing = false;
      });
      widget.onFailed?.call(msg);
    } catch (_) {
      if (!mounted) return;
      final msg = context.l10n.installFailed;
      setState(() {
        _error = msg;
        _installing = false;
      });
      widget.onFailed?.call(msg);
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
