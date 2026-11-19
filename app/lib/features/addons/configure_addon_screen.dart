import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumio/features/addons/configure_dpad.dart';
import 'package:lumio/features/addons/configure_policy.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/ui/common/tv_dialogs.dart';
import 'package:lumio/ui/common/tv_screen.dart';
import 'package:lumio/ui/common/tv_text_field.dart';
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
            unawaited(_web.runJavaScript(configureDpadScript));
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

  Object? _decode(Object raw) {
    var v = raw;
    if (v is String) {
      try {
        v = jsonDecode(v);
        if (v is String) v = jsonDecode(v);
      } catch (_) {
        return null;
      }
    }
    return v;
  }

  /// Flèche de la télécommande : le focus se déplace dans la page ; au bord
  /// de la page, la flèche haut rend la main à l'en-tête.
  Future<KeyEventResult> _move(String dir) async {
    try {
      final r = _decode(
        await _web.runJavaScriptReturningResult(
          "window.__lumioNav ? window.__lumioNav('$dir') : 'none'",
        ),
      );
      if (r == 'edge' && dir == 'up' && mounted) {
        FocusScope.of(context).focusInDirection(TraversalDirection.up);
      }
    } catch (_) {
      // Page en cours de chargement : rien à déplacer.
    }
    return KeyEventResult.handled;
  }

  /// OK : active l'élément ciblé ; les champs et listes passent par les
  /// fenêtres de la TV (clavier à l'écran, choix).
  Future<void> _ok() async {
    final l = context.l10n;
    try {
      final raw = await _web.runJavaScriptReturningResult(
        'window.__lumioOk ? window.__lumioOk() : "{}"',
      );
      final r = _decode(raw);
      if (r is! Map || !mounted) return;
      if (r['k'] == 'text') {
        final label = (r['label'] as String?) ?? '';
        final value = await _askText(
          label.isEmpty ? widget.name : label,
          (r['value'] as String?) ?? '',
          secret: r['secret'] == true,
        );
        if (value != null) {
          await _web.runJavaScript(
            'window.__lumioSetText(${jsonEncode(value)})',
          );
        }
      } else if (r['k'] == 'select') {
        final options = [for (final o in (r['options'] as List)) '$o'];
        final picked = await showTvChoice<int>(
          context,
          title: widget.name,
          options: [for (final (i, o) in options.indexed) (i, o)],
          current: r['index'] is int && (r['index'] as int) >= 0
              ? r['index'] as int
              : null,
        );
        if (picked != null) {
          await _web.runJavaScript('window.__lumioSetSelect($picked)');
        }
      }
    } catch (_) {
      if (mounted) showTvSnack(context, l.configureLoadError, error: true);
    }
  }

  Future<String?> _askText(String label, String initial, {bool secret = false}) {
    final ctrl = TextEditingController(text: initial);
    return showTvPanel<String>(
      context,
      builder: (ctx) => TvPanel(
        title: label,
        width: 900,
        onBack: () => Navigator.of(ctx).pop(),
        actions: [
          TvButton(
            key: const ValueKey('configure-text-ok'),
            label: ctx.l10n.continueAction,
            height: 76,
            fontSize: 28,
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
          ),
          TvButton(
            label: ctx.l10n.cancel,
            kind: TvButtonKind.ghost,
            height: 76,
            fontSize: 28,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
        children: [
          TvTextField(
            key: const ValueKey('configure-text'),
            controller: ctrl,
            autofocus: true,
            obscureText: secret,
            autocorrect: false,
            enableSuggestions: false,
            style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(fontSize: 32),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
        ],
      ),
    ).whenComplete(ctrl.dispose);
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
                        child: Focus(
                          autofocus: true,
                          onKeyEvent: (node, e) {
                            if (e is KeyUpEvent) return KeyEventResult.ignored;
                            final k = e.logicalKey;
                            if (k == LogicalKeyboardKey.arrowDown) {
                              unawaited(_move('down'));
                            } else if (k == LogicalKeyboardKey.arrowUp) {
                              unawaited(_move('up'));
                            } else if (k == LogicalKeyboardKey.arrowLeft) {
                              unawaited(_move('left'));
                            } else if (k == LogicalKeyboardKey.arrowRight) {
                              unawaited(_move('right'));
                            } else if (e is KeyDownEvent &&
                                (k == LogicalKeyboardKey.select ||
                                    k == LogicalKeyboardKey.enter ||
                                    k == LogicalKeyboardKey.numpadEnter ||
                                    k == LogicalKeyboardKey.gameButtonA)) {
                              unawaited(_ok());
                            } else {
                              return KeyEventResult.ignored;
                            }
                            return KeyEventResult.handled;
                          },
                          child: WebViewWidget(
                            key: const ValueKey('configure-web'),
                            controller: _web,
                          ),
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
