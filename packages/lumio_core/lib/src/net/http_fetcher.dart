import 'dart:async';
import 'dart:io';

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
abstract class HttpFetcher {
  Future<FetchResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
  });
}

/// Implémentation `dart:io`.
///
/// Le délai couvre l'ensemble de l'opération (redirections et lecture du
/// corps comprises). La taille est comptée au fil du flux : le téléchargement
/// est interrompu dès que [maxBytes] est dépassé.
class IoHttpFetcher implements HttpFetcher {
  IoHttpFetcher({this.maxRedirects = 3});

  final int maxRedirects;

  @override
  Future<FetchResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      return await _run(client, url, headers, maxBytes).timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'Délai dépassé (${timeout.inMilliseconds} ms)',
          timeout,
        ),
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<FetchResponse> _run(
    HttpClient client,
    Uri url,
    Map<String, String> headers,
    int maxBytes,
  ) async {
    var current = url;
    var sent = headers;
    for (var hops = 0; ; hops++) {
      final req = await client.getUrl(current);
      req.followRedirects = false;
      sent.forEach(req.headers.set);
      final res = await req.close();

      if (res.isRedirect) {
        // Corps de redirection ignoré : on coupe la connexion sans le lire.
        await res.listen((_) {}).cancel();
        final location = res.headers.value(HttpHeaders.locationHeader);
        if (location == null || location.isEmpty) {
          throw const InvalidRedirectException('en-tête Location absent');
        }
        if (hops >= maxRedirects) throw TooManyRedirectsException(maxRedirects);
        final Uri next;
        try {
          next = current.resolve(location);
        } on FormatException {
          throw const InvalidRedirectException('en-tête Location illisible');
        }
        if (next.scheme != 'http' && next.scheme != 'https') {
          throw InsecureRedirectException(next);
        }
        if (current.scheme == 'https' && next.scheme != 'https') {
          throw InsecureRedirectException(next);
        }
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

bool _sameOrigin(Uri a, Uri b) =>
    a.scheme == b.scheme && a.host == b.host && a.port == b.port;

const _credentialHeaders = {'authorization', 'cookie', 'proxy-authorization'};

Map<String, String> _withoutCredentials(Map<String, String> h) => {
  for (final e in h.entries)
    if (!_credentialHeaders.contains(e.key.toLowerCase())) e.key: e.value,
};
