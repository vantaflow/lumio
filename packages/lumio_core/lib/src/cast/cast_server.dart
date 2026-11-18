import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'ssdp.dart';

/// Ressource unique servie au téléviseur.
sealed class CastSource {
  const CastSource();
}

/// Relais d'une URL de nos propres composants (proxy local, serveur du moteur
/// de torrents) : toujours sur la boucle locale.
class CastHttpSource extends CastSource {
  const CastHttpSource(this.upstream, {this.mimeType});
  final Uri upstream;

  /// Type MIME annoncé au téléviseur (par défaut `video/mp4`).
  final String? mimeType;
}

/// Fichier d'un dossier local accordé.
class CastFileSource extends CastSource {
  const CastFileSource(this.file);
  final File file;
}

/// Type MIME d'une vidéo d'après l'extension du chemin.
String mimeForPath(String path) {
  final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'mp4' || 'm4v' => 'video/mp4',
    'mkv' => 'video/x-matroska',
    'webm' => 'video/webm',
    'avi' => 'video/x-msvideo',
    'ts' => 'video/mp2t',
    _ => 'video/mp4',
  };
}

/// Choisit l'adresse locale à utiliser pour joindre [renderer] : une adresse
/// de réseau local de la même plage (/24, à défaut /16). `null` si aucune :
/// on ne diffuse jamais sur une interface sans rapport avec l'appareil.
InternetAddress? pickLanAddress(
  InternetAddress renderer,
  Iterable<InternetAddress> local,
) {
  final r = renderer.rawAddress;
  if (r.length != 4) return null;
  final candidates = [
    for (final a in local)
      if (a.rawAddress.length == 4 &&
          isLanAddress(a, allowLoopback: renderer.isLoopback))
        a,
  ];
  for (final prefix in const [3, 2]) {
    for (final a in candidates) {
      final b = a.rawAddress;
      var same = true;
      for (var i = 0; i < prefix; i++) {
        if (b[i] != r[i]) same = false;
      }
      if (same) return a;
    }
  }
  return null;
}

/// Serveur HTTP éphémère qui sert UNE ressource au téléviseur pendant un cast.
///
/// - lié à l'adresse LAN choisie (jamais `0.0.0.0` ni la boucle locale du
///   téléphone, sauf tests) ;
/// - un seul chemin : un jeton aléatoire de 128 bits ; tout autre chemin,
///   toute autre méthode que GET/HEAD et toute autre adresse cliente que celle
///   du rendu reçoivent un 404 identique ;
/// - le secret du proxy local et les URL d'addons ne figurent jamais dans
///   l'URL donnée au téléviseur : la source reste côté serveur ;
/// - les playlists HLS sont refusées (415) car leurs segments pointeraient vers
///   la boucle locale du téléphone.
class CastServer {
  CastServer._(this._server, this._token, this._allowed, this._source) {
    _server.listen(_handle);
  }

  final HttpServer _server;
  final String _token;
  final InternetAddress _allowed;
  final CastSource _source;
  final _upstreams = <HttpClient>{};
  final _sockets = <Socket>{};
  bool _closed = false;

  static const _upstreamHeaders = Duration(seconds: 20);

  /// Démarre le serveur sur [bindAddress] (port libre).
  static Future<CastServer> start({
    required InternetAddress bindAddress,
    required InternetAddress allowedClient,
    required CastSource source,
  }) async {
    if (source is CastHttpSource) {
      final h = source.upstream.host;
      if (source.upstream.scheme != 'http' ||
          !(h == '127.0.0.1' || h == 'localhost')) {
        throw ArgumentError('source amont hors boucle locale');
      }
    }
    final rnd = Random.secure();
    final token = [
      for (var i = 0; i < 16; i++)
        rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    final server = await HttpServer.bind(bindAddress, 0);
    return CastServer._(server, token, allowedClient, source);
  }

  /// URL à donner au téléviseur.
  Uri get url => Uri(
    scheme: 'http',
    host: _server.address.address,
    port: _server.port,
    path: '/$_token',
  );

  bool get isClosed => _closed;

  /// Sockets de flux encore ouvertes (tests : doit retomber à 0).
  int get openSockets => _sockets.length;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final c in _upstreams.toList()) {
      c.close(force: true);
    }
    // Sockets détachées (flux en cours) : un téléviseur figé mais non
    // déconnecté ne doit pas survivre à l'arrêt du cast.
    for (final k in _sockets.toList()) {
      k.destroy();
    }
    _sockets.clear();
    await _server.close(force: true);
  }

  static bool _eq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var d = 0;
    for (var i = 0; i < a.length; i++) {
      d |= a[i] ^ b[i];
    }
    return d == 0;
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      final from = req.connectionInfo?.remoteAddress;
      final seg = req.uri.pathSegments;
      if (_closed ||
          from == null ||
          !_eq(from.rawAddress, _allowed.rawAddress) ||
          (req.method != 'GET' && req.method != 'HEAD') ||
          seg.length != 1 ||
          !_eq(seg[0].codeUnits, _token.codeUnits)) {
        res.statusCode = HttpStatus.notFound;
        return;
      }
      res.headers
        ..set('transferMode.dlna.org', 'Streaming')
        ..set(
          'contentFeatures.dlna.org',
          'DLNA.ORG_OP=01;DLNA.ORG_CI=0;'
              'DLNA.ORG_FLAGS=01700000000000000000000000000000',
        );
      final s = _source;
      switch (s) {
        case CastHttpSource():
          await _relay(req, s.upstream);
        case CastFileSource():
          await _serveFile(req, s.file);
      }
    } catch (_) {
      _setStatus(res, HttpStatus.badGateway);
    } finally {
      try {
        await res.close();
      } catch (_) {}
    }
  }

  /// Écrit le statut seulement si les en-têtes ne sont pas déjà partis.
  static void _setStatus(HttpResponse res, int code) {
    try {
      res.statusCode = code;
    } on Object {
      // En-têtes déjà envoyés : rien à changer.
    }
  }

  Future<void> _relay(HttpRequest req, Uri upstream) async {
    final res = req.response;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5)
      ..autoUncompress = false;
    _upstreams.add(client);
    try {
      final r = await client.openUrl(req.method, upstream);
      r.followRedirects = false;
      r.headers.set('Accept-Encoding', 'identity');
      for (final n in const ['range', 'if-range']) {
        final v = req.headers.value(n);
        if (v != null) r.headers.set(n, v);
      }
      final up = await r.close().timeout(_upstreamHeaders);
      final type = up.headers.value(HttpHeaders.contentTypeHeader) ?? '';
      if (up.isRedirect || type.toLowerCase().contains('mpegurl')) {
        await up.listen((_) {}).cancel();
        res.statusCode = HttpStatus.unsupportedMediaType;
        return;
      }
      res.statusCode = up.statusCode;
      final noBody = req.method == 'HEAD' || up.statusCode >= 400;
      for (final n in const [
        HttpHeaders.contentTypeHeader,
        HttpHeaders.contentLengthHeader,
        HttpHeaders.contentRangeHeader,
        HttpHeaders.acceptRangesHeader,
      ]) {
        // Pas de Content-Length d'un corps qu'on n'envoie pas (erreurs).
        if (n == HttpHeaders.contentLengthHeader && up.statusCode >= 400) {
          continue;
        }
        final v = up.headers.value(n);
        if (v != null) res.headers.set(n, v);
      }
      if (noBody) {
        await up.listen((_) {}).cancel();
        return;
      }
      // HttpResponse.addStream ne signale pas un téléviseur parti en cours de
      // route : on détache la socket pour la surveiller et couper aussitôt la
      // connexion amont (sinon le torrent / la source remplirait un tampon).
      // Connexion non persistante, sans transfert fragmenté en brut : le corps
      // est délimité par Content-Length ou, à défaut, par la fermeture.
      res.headers.chunkedTransferEncoding = false;
      res.persistentConnection = false;
      final socket = await res.detachSocket(writeHeaders: true);
      _sockets.add(socket);
      if (_closed) {
        // close() est passé pendant le détachement : rien ne doit survivre.
        _sockets.remove(socket);
        socket.destroy();
      }
      unawaited(socket.done.then((_) {}, onError: (Object _) {}));
      // Une demi-fermeture du client juste après la requête (avant le premier
      // octet envoyé) n'est pas une déconnexion ; ensuite, la fin de lecture ou
      // une erreur d'E/S coupe l'amont.
      // (Une fermeture complète avant le premier octet est traitée comme une
      // demi-fermeture : le flux n'est coupé que par un échec d'écriture.)
      var sending = false;
      socket.listen(
        (_) {},
        onDone: () {
          if (sending) client.close(force: true);
        },
        onError: (Object _) => client.close(force: true),
        cancelOnError: true,
      );
      var ok = false;
      try {
        await socket.addStream(
          up.map((chunk) {
            sending = true;
            return chunk;
          }),
        );
        ok = true;
      } on Object {
        client.close(force: true); // client parti ou amont coupé
      } finally {
        if (ok) {
          try {
            await socket.close();
          } on Object {
            socket.destroy();
          }
        } else {
          socket.destroy();
        }
        _sockets.remove(socket);
      }
    } on TimeoutException {
      _setStatus(res, HttpStatus.gatewayTimeout);
    } on Object {
      // Le téléviseur est parti en cours de route : l'amont est coupé ci-dessous.
      _setStatus(res, HttpStatus.badGateway);
    } finally {
      _upstreams.remove(client);
      client.close(force: true);
    }
  }

  Future<void> _serveFile(HttpRequest req, File file) async {
    final res = req.response;
    final int len;
    try {
      len = await file.length();
    } on FileSystemException {
      res.statusCode = HttpStatus.notFound;
      return;
    }
    res.headers
      ..set(HttpHeaders.contentTypeHeader, mimeForPath(file.path))
      ..set(HttpHeaders.acceptRangesHeader, 'bytes');
    var start = 0;
    var end = len - 1;
    final range = req.headers.value('range');
    if (range != null) {
      final m = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(range.trim());
      if (m == null || (m[1]!.isEmpty && m[2]!.isEmpty)) {
        res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        return;
      }
      if (m[1]!.isEmpty) {
        start = max(0, len - int.parse(m[2]!));
      } else {
        start = int.parse(m[1]!);
        if (m[2]!.isNotEmpty) end = min(end, int.parse(m[2]!));
      }
      if (start > end || start >= len) {
        res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$len');
        return;
      }
      res.statusCode = HttpStatus.partialContent;
      res.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$len');
    }
    res.headers.contentLength = end - start + 1;
    if (req.method == 'HEAD') return;
    await res.addStream(file.openRead(start, end + 1));
  }
}
