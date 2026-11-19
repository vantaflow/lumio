import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumio/features/addons/configure_policy.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/ui/common/tv_dialogs.dart';
import 'package:lumio/ui/common/tv_screen.dart';
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Page de configuration d'un addon (maquette TV17), dans une WebView plein
/// écran : seul l'hôte de l'addon est chargé. Renvoie l'adresse du manifest
/// quand la page produit le lien d'installation (stremio://, lumio://install,
/// manifest.json ou lien copié), ou `null` si on revient en arrière.
/// L'adresse configurée n'est jamais journalisée.
class ConfigureAddonScreen extends StatefulWidget {
  const ConfigureAddonScreen({
    super.key,
    required this.name,
    required this.start,
  });

  final String name;
  final Uri start;

  @override
  State<ConfigureAddonScreen> createState() => _ConfigureAddonScreenState();
}

class _ConfigureAddonScreenState extends State<ConfigureAddonScreen> {
  late final WebViewController _web;
  bool _loading = true;
  bool _failed = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF4F6F9))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onRequest,
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (e) {
            if (e.isForMainFrame ?? true) {
              if (mounted) {
                setState(() {
                  _failed = true;
                  _loading = false;
                });
              }
            }
          },
        ),
      )
      ..loadRequest(widget.start);
  }

  NavigationDecision _onRequest(NavigationRequest r) {
    final target = Uri.tryParse(r.url);
    if (target == null) return NavigationDecision.prevent;
    if (!r.isMainFrame) {
      final s = target.scheme.toLowerCase();
      return s == 'https' || s == 'http' || r.url == 'about:blank'
          ? NavigationDecision.navigate
          : NavigationDecision.prevent;
    }
    switch (decideConfigureNavigation(target, start: widget.start)) {
      case ConfigureAllow():
        return NavigationDecision.navigate;
      case ConfigureInstall(:final manifest):
        _finish(manifest);
        return NavigationDecision.prevent;
      case ConfigureBlock():
        if (mounted) showTvSnack(context, context.l10n.configureBlocked);
        return NavigationDecision.prevent;
    }
  }

  void _finish(Uri manifest) {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).pop(manifest);
  }

  Future<void> _useCopied() async {
    final l = context.l10n;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text;
    final uri = isPlausibleInstallLink(text) ? parseInstallLink(text!) : null;
    if (uri == null) {
      showTvSnack(context, l.configureNoLink, error: true);
      return;
    }
    _finish(uri);
  }

  Future<void> _back() async {
    if (await _web.canGoBack()) {
      await _web.goBack();
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.lumio;
    final m = tvMarginOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: TvScreen(
        title: l.addonConfigureTitle(widget.name),
        subtitle: widget.start.host,
        onBack: () => unawaited(_back()),
        actions: [
          TvButton(
            key: const ValueKey('configure-use-copied'),
            label: l.configureUseCopied,
            kind: TvButtonKind.secondary,
            height: 64,
            fontSize: 26,
            onPressed: () => unawaited(_useCopied()),
          ),
        ],
        child: Padding(
          padding: EdgeInsets.fromLTRB(m, 8, m, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: WebViewWidget(
                          key: const ValueKey('configure-web'),
                          controller: _web,
                        ),
                      ),
                      if (_loading)
                        const Center(child: CircularProgressIndicator()),
                      if (_failed)
                        Positioned.fill(
                          child: ColoredBox(
                            color: c.bg,
                            child: Center(
                              child: Text(
                                l.configureLoadError,
                                key: const ValueKey('configure-error'),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontSize: 30, color: c.error),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  l.configureHelp,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 24,
                    color: c.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
