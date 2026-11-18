import 'dart:async';
import 'dart:io';

import 'guarded_connection.dart';

/// Réponse HTTP minimale : statut, corps complet (borné) et en-têtes
/// (noms en minuscules).
class FetchResponse {
  const FetchResponse({
    required this.status,
    required this.body,
    this.headers = const {},
  });

  final int status;
  final List<int> body;
  final Map<String, String> headers;
}

/// Le corps de la réponse dépasse la taille maximale autorisée.
class ResponseTooLargeException implements Exception {
  const ResponseTooLargeException(this.maxBytes);
  final int maxBytes;

  @override
  String toString() => 'ResponseTooLargeException: plus de $maxBytes octets';
}

/// Plus de redirections que la limite autorisée.
class TooManyRedirectsException implements Exception {
  const TooManyRedirectsException(this.max);
  final int max;

  @override
  String toString() => 'TooManyRedirectsException: plus de $max redirections';
}

/// Redirection refusée : vers un schéma autre que http/https, ou rétrogradation
/// de https vers http.
class InsecureRedirectException implements Exception {
  const InsecureRedirectException(this.target);
  final Uri target;

  @override
  String toString() => 'InsecureRedirectException: redirection refusée';
}

/// Redirection sans en-tête `Location` ou avec un `Location` illisible.
class InvalidRedirectException implements Exception {
  const InvalidRedirectException(this.reason);
  final String reason;

  @override
  String toString() => 'InvalidRedirectException: $reason';
}

/// Accès HTTP GET borné (taille, délai, redirections), abstrait pour les tests.
///
/// [guard], s'il est fourni, est appelé sur l'URL initiale puis sur la cible de
/// chaque redirection ; il lève pour refuser la requête.
abstract class HttpFetcher {
  Future<FetchResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  });
}

/// Fetcher qui sait aussi envoyer un corps (POST). Interface séparée pour ne
/// pas imposer la méthode à tous les faux de test.
abstract class HttpPostFetcher implements HttpFetcher {
  /// POST de [body] ; aucune redirection n'est suivie (le corps peut porter
  /// des identifiants) : une redirection lève [InsecureRedirectException].
  Future<FetchResponse> post(
    Uri url, {
    required List<int> body,
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  });
}

/// Implémentation `dart:io`.
///
/// Le délai couvre l'ensemble de l'opération (redirections et lecture du
/// corps comprises). La taille est comptée au fil du flux : le téléchargement
/// est interrompu dès que [maxBytes] est dépassé.
class IoHttpFetcher implements HttpPostFetcher {
  IoHttpFetcher({
    this.maxRedirects = 3,
    this.redirectGuard,
    this.connectionFactory,
  });

  /// Fabrique de connexion du client (voir `guardedConnectionFactory`) :
  /// refuse à la connexion les noms qui résolvent vers une adresse privée.
  final ConnectionFactory? connectionFactory;

  final int maxRedirects;

  /// Appelé sur la cible de chaque redirection (après [validateRedirect]) ;
  /// peut lever pour la refuser (ex. `UrlGuard.check`). L'URL initiale n'est
  /// pas concernée : c'est à l'appelant de la vérifier.
  final void Function(Uri target)? redirectGuard;

  @override
  Future<FetchResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    if (connectionFactory != null) client.connectionFactory = connectionFactory;
    try {
      guard?.call(url);
      redirectGuard?.call(url);
      return await _run(client, url, headers, maxBytes, guard).timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'Délai dépassé (${timeout.inMilliseconds} ms)',
          timeout,
        ),
      );
    } on SocketException catch (e) {
      if (_isConnectTimeout(e)) {
        throw TimeoutException(
          'Délai dépassé (${timeout.inMilliseconds} ms)',
          timeout,
        );
      }
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<FetchResponse> post(
    Uri url, {
    required List<int> body,
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    if (connectionFactory != null) client.connectionFactory = connectionFactory;
    try {
      guard?.call(url);
      redirectGuard?.call(url);
      return await _run(
        client,
        url,
        headers,
        maxBytes,
        guard,
        body: body,
      ).timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'Délai dépassé (${timeout.inMilliseconds} ms)',
          timeout,
        ),
      );
    } on SocketException catch (e) {
      if (_isConnectTimeout(e)) {
        throw TimeoutException(
          'Délai dépassé (${timeout.inMilliseconds} ms)',
          timeout,
        );
      }
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<FetchResponse> _run(
    HttpClient client,
    Uri url,
    Map<String, String> headers,
    int maxBytes,
    void Function(Uri target)? guard, {
    List<int>? body,
  }) async {
    var current = url;
    var sent = headers;
    for (var hops = 0; ; hops++) {
      final req = body == null
          ? await client.getUrl(current)
          : await client.postUrl(current);
      req.followRedirects = false;
      sent.forEach(req.headers.set);
      if (body != null) {
        req.headers.contentLength = body.length;
        req.add(body);
      }
      final res = await req.close();

      if (res.isRedirect && body != null) {
        await res.listen((_) {}).cancel();
        throw InsecureRedirectException(
          validateRedirect(current, res.headers.value('location')),
        );
      }
      if (res.isRedirect) {
        // Corps de redirection ignoré : on coupe la connexion sans le lire.
        await res.listen((_) {}).cancel();
        final location = res.headers.value(HttpHeaders.locationHeader);
        if (location != null && location.isNotEmpty && hops >= maxRedirects) {
          throw TooManyRedirectsException(maxRedirects);
        }
        final next = validateRedirect(current, location);
        guard?.call(next);
        redirectGuard?.call(next);
        if (!_sameOrigin(current, next)) sent = _withoutCredentials(sent);
        current = next;
        continue;
      }

      final out = <int>[];
      await for (final chunk in res) {
        out.addAll(chunk);
        if (out.length > maxBytes) throw ResponseTooLargeException(maxBytes);
      }
      final h = <String, String>{};
      res.headers.forEach(
        (name, values) => h[name.toLowerCase()] = values.join(', '),
      );
      return FetchResponse(status: res.statusCode, body: out, headers: h);
    }
  }
}

// Le délai de connexion de HttpClient remonte en SocketException (errno 110
// Linux/Android, 60 macOS, 10060 Windows).
bool _isConnectTimeout(SocketException e) {
  final code = e.osError?.errorCode;
  return code == 110 ||
      code == 60 ||
      code == 10060 ||
      e.message.toLowerCase().contains('timed out');
}

bool _sameOrigin(Uri a, Uri b) => sameOrigin(a, b);

/// Même schéma, hôte et port.
bool sameOrigin(Uri a, Uri b) =>
    a.scheme == b.scheme && a.host == b.host && a.port == b.port;

const _credentialHeaders = {'authorization', 'cookie', 'proxy-authorization'};

Map<String, String> _withoutCredentials(Map<String, String> h) =>
    withoutCredentials(h);

/// Copie de [h] sans Authorization, Cookie ni Proxy-Authorization.
Map<String, String> withoutCredentials(Map<String, String> h) => {
  for (final e in h.entries)
    if (!_credentialHeaders.contains(e.key.toLowerCase())) e.key: e.value,
};

/// Résout et valide la cible d'une redirection depuis [from].
///
/// Lève [InvalidRedirectException] (absente ou illisible) ou
/// [InsecureRedirectException] (schéma autre que http/https, ou https vers
/// http).
Uri validateRedirect(Uri from, String? location) {
  if (location == null || location.isEmpty) {
    throw const InvalidRedirectException('en-tête Location absent');
  }
  final Uri next;
  try {
    next = from.resolve(location);
  } on FormatException {
    throw const InvalidRedirectException('en-tête Location illisible');
  }
  if (next.scheme != 'http' && next.scheme != 'https') {
    throw InsecureRedirectException(next);
  }
  if (from.scheme == 'https' && next.scheme != 'https') {
    throw InsecureRedirectException(next);
  }
  return next;
}
