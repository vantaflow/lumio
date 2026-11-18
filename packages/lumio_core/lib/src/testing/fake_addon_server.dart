import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Réponse préparée d'avance pour une route de [FakeAddonServer].
class FakeResponse {
  /// Corps JSON encodé en UTF-8, `content-type: application/json`.
  FakeResponse.json(
    Object body, {
    this.status = 200,
    this.delay = Duration.zero,
    this.headers = const {},
  }) : bytes = utf8.encode(jsonEncode(body)),
       contentType = 'application/json; charset=utf-8';

  /// Octets arbitraires (JSON tronqué, HTML, gros corps…).
  FakeResponse.raw(
    this.bytes, {
    this.contentType = 'application/octet-stream',
    this.status = 200,
    this.delay = Duration.zero,
    this.headers = const {},
  });

  final List<int> bytes;
  final String contentType;
  final int status;
  final Duration delay;

  /// En-têtes supplémentaires (ex. `location` pour une redirection).
  final Map<String, String> headers;
}

/// Serveur HTTP local (boucle locale, port éphémère) imitant un addon.
///
/// Les chemins sans route répondent 404. Sert aux tests du cœur : addon lent,
/// en erreur ou renvoyant un JSON invalide.
class FakeAddonServer {
  FakeAddonServer._(this._server) {
    _sub = _server.listen(_handle);
  }

  final HttpServer _server;
  late final StreamSubscription<HttpRequest> _sub;
  final Map<String, FakeResponse> _routes = {};

  static Future<FakeAddonServer> start() async =>
      FakeAddonServer._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  Uri get baseUrl => Uri(scheme: 'http', host: '127.0.0.1', port: _server.port);

  /// Associe [path] (ex. `/manifest.json`) à [r] ; remplace une route existante.
  void route(String path, FakeResponse r) => _routes[path] = r;

  Future<void> close() async {
    await _sub.cancel();
    await _server.close(force: true);
  }

  Future<void> _handle(HttpRequest req) async {
    final r = _routes[req.uri.path];
    try {
      if (r == null) {
        req.response.statusCode = HttpStatus.notFound;
        return;
      }
      if (r.delay > Duration.zero) await Future<void>.delayed(r.delay);
      req.response
        ..statusCode = r.status
        ..headers.set(HttpHeaders.contentTypeHeader, r.contentType)
        ..headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
      r.headers.forEach(req.response.headers.set);
      req.response.add(r.bytes);
    } finally {
      try {
        await req.response.close();
      } catch (_) {
        // Client déjà parti (délai dépassé) : sans importance pour un faux.
      }
    }
  }
}
