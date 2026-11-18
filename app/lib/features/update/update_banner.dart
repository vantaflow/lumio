import 'package:flutter/material.dart';
import 'package:lumio/config.dart';
import 'package:lumio_core/lumio_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bannière fermable signalant une mise à jour. Invisible si
/// [manifestUrl] est vide, si l'application est à jour ou hors ligne.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({
    super.key,
    this.manifestUrl = updateManifestUrl,
    this.fetcher,
    this.currentVersion,
    this.openUrl,
  });

  final String manifestUrl;

  /// Substituable en test ; par défaut [IoHttpFetcher].
  final HttpFetcher? fetcher;

  /// Substituable en test ; par défaut lue via `package_info_plus`.
  final Future<String> Function()? currentVersion;

  /// Substituable en test ; par défaut `url_launcher` (navigateur externe).
  final Future<void> Function(Uri url)? openUrl;

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  UpdateManifest? _update;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final url = Uri.tryParse(widget.manifestUrl);
    if (widget.manifestUrl.isEmpty || url == null) return;
    try {
      final version = await (widget.currentVersion ?? _packageVersion)();
      final checker = UpdateChecker(
        widget.fetcher ?? IoHttpFetcher(),
        url,
        version,
      );
      final m = await checker.check();
      if (mounted && m != null) setState(() => _update = m);
    } catch (_) {
      // Une vérification ratée ne doit jamais gêner l'utilisateur.
    }
  }

  static Future<String> _packageVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  Future<void> _open(Uri url) async {
    if (widget.openUrl != null) return widget.openUrl!(url);
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final m = _update;
    if (m == null || _dismissed) return const SizedBox.shrink();
    return MaterialBanner(
      content: Text('Mise à jour disponible : version ${m.version}'),
      leading: const Icon(Icons.system_update),
      actions: [
        TextButton(
          onPressed: () => _open(m.apkUrl),
          child: const Text('Télécharger'),
        ),
        IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _dismissed = true),
        ),
      ],
    );
  }
}
