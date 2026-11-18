import 'package:lumio/player/local_proxy.dart';
import 'package:lumio_core/lumio_core.dart';

/// Comment l'URL est transmise à libmpv.
enum PlayRouteKind { proxy, direct }

class PlayRoute {
  const PlayRoute(this.kind, this.url);
  final PlayRouteKind kind;
  final Uri url;
}

/// Décide de la route d'un flux d'addon.
///
/// Toute URL venant d'un addon passe par le proxy local : chaque redirection
/// y est contrôlée par `UrlGuard`, ce que libmpv ne fait pas. La lecture
/// directe est réservée aux URL produites par nos propres composants
/// ([trustedLocal] : proxy, serveur de flux du moteur de torrents), jamais à
/// des données d'addon.
///
/// Lève [UnsafeUrlException] pour une cible refusée (hôte local ou réseau
/// privé sans [allowPrivate], schéma autre que http/https).
Future<PlayRoute> routePlayback(
  StreamItem s, {
  required Future<LocalProxy> Function() proxy,
  bool allowPrivate = false,
  bool trustedLocal = false,
}) async {
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
