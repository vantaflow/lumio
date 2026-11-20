import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/config.dart';
import 'package:lumio/ui/common/tv_screen.dart' show TvIconButton, tvMarginOf;
import 'package:lumio/ui/focus/tv_button.dart';
import 'package:lumio/ui/icons/lumio_icons.dart';
import 'package:lumio/ui/theme.dart';
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
    this.supportedAbis,
  });

  final String manifestUrl;

  /// Substituable en test ; par défaut [IoHttpFetcher].
  final HttpFetcher? fetcher;

  /// Substituable en test ; par défaut lue via `package_info_plus`.
  final Future<String> Function()? currentVersion;

  /// Substituable en test ; par défaut `url_launcher` (navigateur externe).
  final Future<void> Function(Uri url)? openUrl;

  /// Substituable en test ; par défaut `Build.SUPPORTED_ABIS` (Android).
  final Future<List<String>> Function()? supportedAbis;

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
        supportedAbis: await _abis(),
      );
      final m = await checker.check();
      if (mounted && m != null) setState(() => _update = m);
    } catch (_) {
      // Une vérification ratée ne doit jamais gêner l'utilisateur.
    }
  }

  Future<List<String>> _abis() async {
    try {
      if (widget.supportedAbis != null) return await widget.supportedAbis!();
      return (await DeviceInfoPlugin().androidInfo).supportedAbis;
    } catch (_) {
      return const [];
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
    final c = context.lumio;
    // Maquette TV52 : bandeau de 96, fond #2A3340, marges 96, icône ambre 36,
    // texte 28 semi-gras, « Télécharger » (64) et croix ronde (64).
    return MaterialBanner(
      backgroundColor: c.surfaceFocus,
      // MaterialBanner ajoute 8 à droite de l'action : on les retire.
      padding: EdgeInsetsDirectional.only(
        start: tvMarginOf(context),
        end: tvMarginOf(context) - 8,
      ),
      leadingPadding: const EdgeInsetsDirectional.only(end: 20),
      minActionBarHeight: 96,
      elevation: 0,
      dividerColor: Colors.transparent,
      content: Text(
        context.l10n.updateAvailable(m.version),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 28,
          fontWeight: FontWeight.w600,
          fontVariations: [FontVariation.weight(600)],
        ),
      ),
      leading: LumioIconView(LumioIcon.download, size: 36, color: c.accent),
      // Une seule action (une rangée) : MaterialBanner la garde alors sur la
      // même ligne que le texte au lieu de la passer dessous.
      actions: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TvButton(
              label: context.l10n.download,
              height: 64,
              horizontalPadding: 40,
              fontSize: 28,
              onPressed: () => _open(m.apkUrl),
            ),
            const SizedBox(width: 20),
            TvIconButton(
              lumioIcon: LumioIcon.close,
              iconColor: c.text,
              background: c.surface,
              size: 64,
              label: context.l10n.close,
              onPressed: () => setState(() => _dismissed = true),
            ),
          ],
        ),
      ],
    );
  }
}
