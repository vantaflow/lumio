import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:lumio/player/hls_rewriter.dart';
import 'package:lumio_core/lumio_core.dart';

/// Événement du proxy : réponse de la source ou refus (jamais d'URL).
class ProxyEvent {
  const ProxyEvent(this.status, {this.refused = false, this.error});

  /// Statut renvoyé par la source (0 si injoignable ou refusé).
  final int status;
  final bool refused;
  final Object? error;
}

/// Proxy HTTP local (127.0.0.1, port aléatoire) qui fait les requêtes
/// sortantes avec `dart:io` : contourne le TLS de libmpv (échec sur certains
/// CDN HLS), impose les en-têtes demandés par l'addon et réécrit les
/// playlists `.m3u8` pour que les segments repassent par ici.
///
/// Route : `/p/<secret>?u=<b64url cible>&h=<b64url json en-têtes>[&a=1]`.
/// Le secret est tiré au hasard à chaque démarrage : une autre application
/// locale ne peut pas s'en servir comme relais ouvert ; tout le reste → 404.
class LocalProxy {
  LocalProxy._(
    this._server,
    this._secret,
    this._clientFactory,
    this._guard,
    this._lookup,
    this._enforceResolved,
  ) {
    _server.listen(_handle);
  }

  final HttpServer _server;
  final String _secret;
  final HttpClient Function() _clientFactory;
  final void Function(Uri, {bool allowPrivate}) _guard;
  final HostLookup? _lookup;
  final bool _enforceResolved;
  final _events = StreamController<ProxyEvent>.broadcast();
  final _active = <HttpClient>{};
  bool _closed = false;

  /// En-têtes qu'un addon ne peut pas imposer (le Range du lecteur prime).
  static const _reservedHeaders = {
    'host',
    'content-length',
    'transfer-encoding',
    'connection',
    'range',
  };

  static const _sniffBytes = 16;
  static const _maxRedirects = 5;
  static const _maxPlaylistBytes = 5 * 1024 * 1024;
  static const _connectTimeout = Duration(seconds: 15);
  static const _headersTimeout = Duration(seconds: 20);

  /// Démarre le proxy. [clientFactory] sert aux tests.
  static Future<LocalProxy> start({
    HttpClient Function()? clientFactory,
    @visibleForTesting void Function(Uri, {bool allowPrivate})? guard,
    @visibleForTesting HostLookup? lookup,
    @visibleForTesting bool enforceResolvedAddresses = true,
  }) async {
    final rnd = Random.secure();
    final secret = [
      for (var i = 0; i < 16; i++)
        rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return LocalProxy._(
      server,
      secret,
      clientFactory ??
          () => HttpClient()
            ..connectionTimeout = _connectTimeout
            ..autoUncompress = false,
      guard ?? UrlGuard.check,
      lookup,
      enforceResolvedAddresses,
    );
  }

  int get port => _server.port;

  /// Connexions sortantes ouvertes (tests : doit retomber à 0).
  @visibleForTesting
  int get activeUpstreams => _active.length;

  /// Adresse d'écoute (toujours la boucle locale IPv4).
  InternetAddress get address => _server.address;

  /// Réponses des sources (statut seulement) : sert à expliquer un échec.
  Stream<ProxyEvent> get events => _events.stream;

  /// URL locale qui relaie [target]. [allowPrivate] n'est à passer que pour un
  /// flux d'un addon que l'utilisateur a autorisé sur le réseau privé.
  Uri wrap(
    Uri target, {
    Map<String, String> headers = const {},
    bool allowPrivate = false,
  }) {
    String b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');
    return Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: port,
      path: '/p/$_secret',
      queryParameters: {
        'u': b64(utf8.encode(target.toString())),
        if (headers.isNotEmpty) 'h': b64(utf8.encode(jsonEncode(headers))),
        if (allowPrivate) 'a': '1',
      },
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final c in _active.toList()) {
      c.close(force: true);
    }
    await _server.close(force: true);
    await _events.close();
  }

  static String _unb64(String s) =>
      utf8.decode(base64Url.decode(base64Url.normalize(s)));

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      final seg = req.uri.pathSegments;
      if ((req.method != 'GET' && req.method != 'HEAD') ||
          seg.length != 2 ||
          seg[0] != 'p' ||
          !_constantTimeEquals(seg[1], _secret)) {
        res.statusCode = HttpStatus.notFound;
        return;
      }
      final Uri target;
      final Map<String, String> headers;
      try {
        target = Uri.parse(_unb64(req.uri.queryParameters['u'] ?? ''));
        final h = req.uri.queryParameters['h'];
        headers = h == null
            ? const {}
            : (jsonDecode(_unb64(h)) as Map).map(
                (k, v) => MapEntry(k.toString(), v.toString()),
              );
      } catch (_) {
        res.statusCode = HttpStatus.badRequest;
        return;
      }
      final allowPrivate = req.uri.queryParameters['a'] == '1';
      if (target.scheme != 'http' && target.scheme != 'https') {
        res.statusCode = HttpStatus.notFound;
        return;
      }
      try {
        _guard(target, allowPrivate: allowPrivate);
      } on UnsafeUrlException {
        res.statusCode = HttpStatus.forbidden;
        _emit(const ProxyEvent(0, refused: true));
        return;
      }
      await _relay(req, target, headers, allowPrivate);
    } catch (e) {
      // Client parti ou erreur interne : rien à renvoyer de plus.
      try {
        res.statusCode = HttpStatus.badGateway;
      } catch (_) {}
    } finally {
      try {
        await res.close();
      } catch (_) {}
    }
  }

  Future<void> _relay(
    HttpRequest req,
    Uri target,
    Map<String, String> imposed,
    bool allowPrivate,
  ) async {
    final res = req.response;
    final client = _clientFactory();
    if (_enforceResolved) {
      client.connectionFactory = guardedConnectionFactory(
        allowPrivate: allowPrivate,
        lookup: _lookup,
      );
    }
    _active.add(client);
    try {
      final forwarded = <String, String>{
        'User-Agent': 'Lumio/1.0',
        'Accept-Encoding': 'identity',
        for (final n in const ['range', 'if-range'])
          if (req.headers.value(n) != null) n: req.headers.value(n)!,
        for (final e in imposed.entries)
          if (!_reservedHeaders.contains(e.key.toLowerCase())) e.key: e.value,
      };

      var current = target;
      var sent = forwarded;
      HttpClientResponse? up;
      for (var hops = 0; ; hops++) {
        final r = await client.openUrl(req.method, current);
        r.followRedirects = false;
        sent.forEach(r.headers.set);
        up = await r.close().timeout(_headersTimeout);
        if (!up.isRedirect) break;
        await up.listen((_) {}).cancel();
        final location = up.headers.value(HttpHeaders.locationHeader);
        if (location != null && location.isNotEmpty && hops >= _maxRedirects) {
          throw TooManyRedirectsException(_maxRedirects);
        }
        final next = validateRedirect(current, location);
        _guard(next, allowPrivate: allowPrivate);
        if (!(current.scheme == next.scheme &&
            current.host == next.host &&
            current.port == next.port)) {
          sent = {
            for (final e in sent.entries)
              if (!const [
                'authorization',
                'cookie',
                'proxy-authorization',
              ].contains(e.key.toLowerCase()))
                e.key: e.value,
          };
        }
        current = next;
      }

      _emit(ProxyEvent(up.statusCode));
      final type = up.headers.value(HttpHeaders.contentTypeHeader) ?? '';
      final playlistLike =
          up.statusCode < 400 &&
          (type.toLowerCase().contains('mpegurl') ||
              current.path.toLowerCase().endsWith('.m3u8'));
      var isPlaylist = playlistLike && req.method == 'GET';
      Stream<List<int>> body = up;
      final head = <int>[];
      if (!isPlaylist &&
          req.method == 'GET' &&
          up.statusCode < 400 &&
          (up.statusCode != HttpStatus.partialContent ||
              (up.headers.value(HttpHeaders.contentRangeHeader) ?? '')
                  .startsWith('bytes 0-'))) {
        // Une playlist servie avec un autre type (video/mp4, text/plain)
        // doit être réécrite aussi : sinon le lecteur irait chercher les
        // segments directement, hors garde.
        final it = StreamIterator<List<int>>(up);
        while (head.length < _sniffBytes && await it.moveNext()) {
          head.addAll(it.current);
        }
        isPlaylist = _isPlaylistBody(head);
        body = _chain(head, it);
      }

      res.statusCode = up.statusCode;
      if (isPlaylist) {
        final bytes = <int>[];
        await for (final chunk in body) {
          bytes.addAll(chunk);
          if (bytes.length > _maxPlaylistBytes) {
            throw const ResponseTooLargeException(_maxPlaylistBytes);
          }
        }
        final text = rewriteM3u8(
          utf8.decode(bytes, allowMalformed: true),
          current,
          (u) => wrap(
            u,
            headers: sameOrigin(u, current)
                ? imposed
                : withoutCredentials(imposed),
            allowPrivate: allowPrivate,
          ),
        );
        final out = utf8.encode(text);
        res.statusCode = HttpStatus.ok;
        res.headers
          ..set(HttpHeaders.contentTypeHeader, 'application/vnd.apple.mpegurl')
          ..set(HttpHeaders.cacheControlHeader, 'no-store');
        res.headers.contentLength = out.length;
        res.add(out);
        return;
      }

      if (playlistLike && req.method == 'HEAD') {
        // La longueur réelle change à la réécriture : ne pas relayer l'amont.
        await up.listen((_) {}).cancel();
        res.headers
          ..set(HttpHeaders.contentTypeHeader, 'application/vnd.apple.mpegurl')
          ..set(HttpHeaders.cacheControlHeader, 'no-store');
        return;
      }
      for (final n in const [
        HttpHeaders.contentTypeHeader,
        HttpHeaders.contentLengthHeader,
        HttpHeaders.contentRangeHeader,
        HttpHeaders.acceptRangesHeader,
      ]) {
        final v = up.headers.value(n);
        if (v != null) res.headers.set(n, v);
      }
      if (req.method == 'GET' && up.statusCode >= 400) {
        await up.listen((_) {}).cancel();
        res.headers.contentLength = 0;
        return;
      }
      if (req.method == 'HEAD') {
        await up.listen((_) {}).cancel();
        return;
      }
      // Streaming : si le lecteur part avant la fin, addStream annule la
      // lecture amont et le `finally` ferme la connexion à la source.
      await res.addStream(body);
    } on TimeoutException catch (e) {
      _emit(ProxyEvent(0, error: e));
      res.statusCode = HttpStatus.gatewayTimeout;
    } on UnsafeUrlException catch (e) {
      _emit(ProxyEvent(0, refused: true, error: e));
      res.statusCode = HttpStatus.forbidden;
    } on SocketException catch (e) {
      _emit(ProxyEvent(0, error: e));
      res.statusCode = HttpStatus.badGateway;
    } on InsecureRedirectException catch (e) {
      _emit(ProxyEvent(0, refused: true, error: e));
      res.statusCode = HttpStatus.badGateway;
    } on TooManyRedirectsException catch (e) {
      _emit(ProxyEvent(0, error: e));
      res.statusCode = HttpStatus.badGateway;
    } on InvalidRedirectException catch (e) {
      _emit(ProxyEvent(0, error: e));
      res.statusCode = HttpStatus.badGateway;
    } on ResponseTooLargeException catch (e) {
      _emit(ProxyEvent(0, error: e));
      res.statusCode = HttpStatus.badGateway;
    } on HttpException catch (e) {
      _emit(ProxyEvent(0, error: e));
      res.statusCode = HttpStatus.badGateway;
    } finally {
      _active.remove(client);
      client.close(force: true);
    }
  }

  static bool _isPlaylistBody(List<int> head) {
    var i = 0;
    if (head.length >= 3 &&
        head[0] == 0xEF &&
        head[1] == 0xBB &&
        head[2] == 0xBF) {
      i = 3;
    }
    const magic = [0x23, 0x45, 0x58, 0x54, 0x4D, 0x33, 0x55]; // #EXTM3U
    if (head.length < i + magic.length) return false;
    for (var k = 0; k < magic.length; k++) {
      if (head[i + k] != magic[k]) return false;
    }
    return true;
  }

  /// [head] déjà lu, puis la suite de [it] ; annuler ferme la lecture amont.
  static Stream<List<int>> _chain(
    List<int> head,
    StreamIterator<List<int>> it,
  ) async* {
    try {
      if (head.isNotEmpty) yield head;
      while (await it.moveNext()) {
        yield it.current;
      }
    } on HttpException {
      // Amont coupé (lecteur parti ou source fermée) : fin du flux.
    } on SocketException {
      // idem
    } finally {
      await it.cancel();
    }
  }

  void _emit(ProxyEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var d = 0;
    for (var i = 0; i < a.length; i++) {
      d |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return d == 0;
  }
}
