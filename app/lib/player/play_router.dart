import 'package:lumio/player/local_proxy.dart';
import 'package:path/path.dart' as p;
import 'package:lumio_core/lumio_core.dart';

/// Comment l'URL est transmise à libmpv.
enum PlayRouteKind { proxy, direct }

class PlayRoute {
  const PlayRoute(this.kind, this.url);
  final PlayRouteKind kind;
  final Uri url;
}

/// Extensions de vidéo lues depuis un dossier local.
const localVideoExtensions = {'mkv', 'mp4', 'avi', 'm4v', 'ts', 'webm'};

/// Fichier d'un dossier local accordé par l'utilisateur : seul chemin qui
/// permet une lecture `file://`. Construit uniquement par l'écran local, à
/// partir de la base des dossiers accordés ; jamais depuis un flux d'addon.
class LocalFileSource {
  const LocalFileSource({required this.path, required this.grantedFolders});

  final String path;

  /// Dossiers accordés (chemins absolus normalisés).
  final List<String> grantedFolders;

  /// URL `file://` du fichier ; lève [UnsafeUrlException] si le chemin n'est
  /// pas absolu et normalisé, sort des dossiers accordés ou n'est pas une
  /// vidéo reconnue.
  Uri validate() {
    if (path.isEmpty ||
        path.contains('\u0000') ||
        !p.isAbsolute(path) ||
        p.normalize(path) != path) {
      throw const UnsafeUrlException('chemin local invalide');
    }
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    if (!localVideoExtensions.contains(ext)) {
      throw const UnsafeUrlException('type de fichier local non autorisé');
    }
    if (!grantedFolders.any((root) => p.isWithin(root, path))) {
      throw const UnsafeUrlException('fichier hors des dossiers accordés');
    }
    return Uri.file(path);
  }
}

/// Décide de la route d'un flux d'addon.
///
/// Toute URL venant d'un addon passe par le proxy local : chaque redirection
/// y est contrôlée par `UrlGuard`, ce que libmpv ne fait pas. La lecture
/// directe est réservée aux URL produites par nos propres composants
/// ([trustedLocal] : proxy, serveur de flux du moteur de torrents), jamais à
/// des données d'addon. Un fichier local ([local]) est lu directement en
/// `file://` s'il est dans un dossier accordé ; `trustedLocal` n'ouvre jamais
/// `file://`.
///
/// Lève [UnsafeUrlException] pour une cible refusée (hôte local ou réseau
/// privé sans [allowPrivate], schéma autre que http/https).
Future<PlayRoute> routePlayback(
  StreamItem s, {
  required Future<LocalProxy> Function() proxy,
  bool allowPrivate = false,
  bool trustedLocal = false,
  LocalFileSource? local,
}) async {
  if (local != null) return PlayRoute(PlayRouteKind.direct, local.validate());
  final url = s.url;
  if (url == null) {
    throw const UnsafeUrlException('flux sans lien direct');
  }
  if (trustedLocal) {
    if (url.scheme != 'http' && url.scheme != 'https') {
      throw const UnsafeUrlException('schéma non autorisé');
    }
    return PlayRoute(PlayRouteKind.direct, url);
  }
  UrlGuard.check(url, allowPrivate: allowPrivate);
  final p = await proxy();
  return PlayRoute(
    PlayRouteKind.proxy,
    p.wrap(url, headers: s.requestHeaders, allowPrivate: allowPrivate),
  );
}
