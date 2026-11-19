import 'package:lumio_core/lumio_core.dart';

/// Décision pour une navigation demandée par la page de configuration d'un
/// addon, affichée dans la WebView plein écran.
sealed class ConfigureNav {
  const ConfigureNav();
}

/// La page est restée chez l'addon : la WebView la charge.
class ConfigureAllow extends ConfigureNav {
  const ConfigureAllow();
}

/// Le lien d'installation est produit : on bascule sur l'aperçu d'installation
/// existant (garde réseau, confirmation d'adresse privée, SecretStore).
class ConfigureInstall extends ConfigureNav {
  const ConfigureInstall(this.manifest);
  final Uri manifest;
}

/// Hôte étranger à l'addon ou schéma interdit : rien n'est chargé.
class ConfigureBlock extends ConfigureNav {
  const ConfigureBlock();
}

/// Décide du sort de [target]. [start] est la page /configure de l'addon : on
/// ne charge que son hôte (https uniquement, sauf si l'addon est lui-même en
/// http). Les liens `stremio://`, `lumio://install` et toute URL `manifest.json`
/// deviennent un lien d'installation ; tous les autres schémas sont bloqués.
ConfigureNav decideConfigureNavigation(Uri target, {required Uri start}) {
  final scheme = target.scheme.toLowerCase();
  switch (scheme) {
    case 'stremio':
    case 'lumio':
      final m = parseInstallLink(target.toString());
      return m == null ? const ConfigureBlock() : ConfigureInstall(m);
    case 'https':
    case 'http':
      if (target.userInfo.isNotEmpty) return const ConfigureBlock();
      if (target.path.toLowerCase().endsWith('/manifest.json')) {
        final m = parseInstallLink(target.toString());
        return m == null ? const ConfigureBlock() : ConfigureInstall(m);
      }
      final sameHost = target.host.toLowerCase() == start.host.toLowerCase();
      final schemeOk = scheme == 'https' || start.scheme.toLowerCase() == 'http';
      return sameHost && schemeOk
          ? const ConfigureAllow()
          : const ConfigureBlock();
    default:
      return const ConfigureBlock();
  }
}
