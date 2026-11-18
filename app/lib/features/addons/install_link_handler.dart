import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/features/addons/add_addon_dialog.dart';
import 'package:lumio/features/profiles/pin_dialog.dart' show requireParent;
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio_core/lumio_core.dart';

/// Source des liens reçus de l'extérieur (lien profond `stremio://` ou
/// `lumio://`, texte partagé). Jamais d'installation : le lien ouvre
/// seulement l'écran d'ajout prérempli.
abstract class InstallLinkSource {
  /// Lien reçu au démarrage (lu une seule fois), ou null.
  Future<String?> initialLink();

  /// Liens reçus pendant que l'appli tourne.
  Stream<String> get links;
}

/// Canal Android (`MainActivity.kt`) ; sans effet sur les autres plateformes.
class ChannelInstallLinkSource implements InstallLinkSource {
  ChannelInstallLinkSource() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'link' && call.arguments is String) {
        // Accepté seulement si l'interface écoute ; sinon le natif garde le
        // lien en attente.
        if (!_controller.hasListener) return false;
        _controller.add(call.arguments as String);
        return true;
      }
      return null;
    });
  }

  static const _channel = MethodChannel('dev.lumio.app/links');
  final _controller = StreamController<String>.broadcast();

  @override
  Future<String?> initialLink() async {
    try {
      return await _channel.invokeMethod<String>('takeLink');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Stream<String> get links => _controller.stream;
}

final installLinkSourceProvider = Provider<InstallLinkSource>(
  (ref) => ChannelInstallLinkSource(),
);

/// Écoute les liens d'installation entrants : profil enfant → PIN parent,
/// puis écran d'ajout prérempli (aperçu, l'utilisateur confirme).
class InstallLinkHandler extends ConsumerStatefulWidget {
  const InstallLinkHandler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<InstallLinkHandler> createState() => _InstallLinkHandlerState();
}

class _InstallLinkHandlerState extends ConsumerState<InstallLinkHandler> {
  StreamSubscription<String>? _sub;
  bool _busy = false;
  String? _queued;

  @override
  void initState() {
    super.initState();
    final source = ref.read(installLinkSourceProvider);
    _sub = source.links.listen((l) => unawaited(_handle(l)));
    unawaited(
      source.initialLink().then((l) {
        if (l != null && mounted) return _handle(l);
      }),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _handle(String raw) async {
    if (!mounted) return;
    if (_busy) {
      _queued = raw;
      return;
    }
    final url = parseInstallLink(raw);
    if (url == null) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(context.l10n.installLinkInvalid)));
      return;
    }
    _busy = true;
    try {
      if (!await requireParent(context, ref)) return;
      if (!mounted) return;
      await showAddAddonDialog(context, initialUrl: url.toString());
    } finally {
      _busy = false;
      final next = _queued;
      _queued = null;
      if (next != null && mounted) unawaited(_handle(next));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
