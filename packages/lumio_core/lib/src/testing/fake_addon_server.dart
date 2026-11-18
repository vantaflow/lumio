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

/// Requête reçue par [FakeAddonServer] (journal pour les assertions).
class RecordedRequest {
  const RecordedRequest(this.method, this.uri, this.headers, this.body);

  final String method;
  final Uri uri;

  /// En-têtes (noms en minuscules).
  final Map<String, String> headers;
  final List<int> body;

  String get bodyText => utf8.decode(body, allowMalformed: true);
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
  final Map<String, FakeResponse Function(RecordedRequest)> _handlers = {};

  /// Requêtes reçues, dans l'ordre.
  final List<RecordedRequest> requests = [];

  static Future<FakeAddonServer> start() async =>
      FakeAddonServer._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  Uri get baseUrl => Uri(scheme: 'http', host: '127.0.0.1', port: _server.port);

  /// Associe [path] (ex. `/manifest.json`) à [r] ; remplace une route existante.
  void route(String path, FakeResponse r) {
    _handlers.remove(path);
    _routes[path] = r;
  }

  /// Comme [route], mais la réponse dépend de la requête (en-têtes, requête,
  /// corps).
  void routeWith(String path, FakeResponse Function(RecordedRequest r) f) =>
      _handlers[path] = f;

  Future<void> close() async {
    await _sub.cancel();
    await _server.close(force: true);
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      final body = <int>[];
      if (req.method != 'GET' && req.method != 'HEAD') {
        await for (final c in req) {
          body.addAll(c);
        }
      }
      final headers = <String, String>{};
      req.headers.forEach((n, v) => headers[n.toLowerCase()] = v.join(', '));
      final rec = RecordedRequest(req.method, req.uri, headers, body);
      requests.add(rec);
      final dynamicRoute = _handlers[req.uri.path];
      final r = dynamicRoute != null
          ? dynamicRoute(rec)
          : _routes[req.uri.path];
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
