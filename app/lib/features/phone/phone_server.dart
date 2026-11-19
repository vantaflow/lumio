import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:lumio/features/phone/lan_address.dart';
import 'package:lumio/features/phone/phone_add.dart';
import 'package:lumio/features/phone/phone_page.dart';
import 'package:lumio_core/lumio_core.dart';

export 'package:lumio/features/phone/phone_page.dart'
    show phoneCss, phoneIndexHtml, phoneJs;

/// Ligne de la liste affichée sur le téléphone : jamais d'URL (ni d'addon ni
/// de logo). [id] est l'identifiant de stockage ; le téléphone n'en voit que
/// la version opaque.
class PhoneAddonView {
  const PhoneAddonView({
    required this.id,
    required this.name,
    required this.types,
    required this.health,
    required this.enabled,
    required this.position,
    this.broken = false,
  });

  final String id;
  final String name;
  final List<String> types;

  /// `reliable`, `slow`, `failing` ou `unknown`.
  final String health;
  final bool enabled;
  final int position;
  final bool broken;
}

/// Opérations de gestion exposées au téléphone (dépôt d'addons existant).
abstract class PhoneBackend {
  Future<List<PhoneAddonView>> addons();
  Future<void> move(String id, int delta);
  Future<void> setEnabled(String id, bool on);
  Future<void> remove(String id);
}

enum PhoneServerStatus { stopped, starting, listening, noNetwork, error }

class PhoneServerState {
  const PhoneServerState({
    this.status = PhoneServerStatus.stopped,
    this.host = '',
    this.port = 0,
    this.code = '',
    this.connected = false,
    this.lockedUntil,
    this.idleStopped = false,
    this.tooManyTries = false,
  });

  final PhoneServerStatus status;
  final String host;
  final int port;
  final String code;

  /// Au moins un téléphone a saisi le bon code.
  final bool connected;
  final DateTime? lockedUntil;
  final bool idleStopped;

  /// Le serveur s'est arrêté après trop de verrouillages.
  final bool tooManyTries;

  bool get listening => status == PhoneServerStatus.listening;
  String get address => '$host:$port';

  /// Contenu du QR : adresse + code dans le fragment (jamais envoyé au
  /// serveur).
  String get url => 'http://$host:$port/#c=$code';

  PhoneServerState copyWith({
    PhoneServerStatus? status,
    String? host,
    int? port,
    String? code,
    bool? connected,
    DateTime? lockedUntil,
    bool clearLock = false,
    bool? idleStopped,
  }) => PhoneServerState(
    status: status ?? this.status,
    host: host ?? this.host,
    port: port ?? this.port,
    code: code ?? this.code,
    connected: connected ?? this.connected,
    lockedUntil: clearLock ? null : (lockedUntil ?? this.lockedUntil),
    idleStopped: idleStopped ?? this.idleStopped,
  );
}

/// Ce que l'écran de la TV attend d'un serveur de téléphone.
abstract class PhoneSession {
  ValueListenable<PhoneServerState> get state;
  PhoneAddCoordinator get adds;
  Future<void> start();
  Future<void> stop();
  void dispose();
}

class _HttpError implements Exception {
  _HttpError(this.status, this.code, {this.headers = const {}});
  final int status;
  final String code;
  final Map<String, String> headers;
}

class _Session {
  _Session(this.csrf);
  final String csrf;
}

/// Serveur HTTP local de la page « Depuis le téléphone ». Voir la spec
/// `docs/superpowers/specs/2026-11-19-page-web-box-design.md`.
///
/// Aucun journal : ni adresses, ni liens, ni codes ne sont écrits nulle part.
class PhoneServer implements PhoneSession {
  PhoneServer({
    required this.backend,
    required this.adds,
    required this.lan,
    required this.lang,
    this.preferredPort = defaultPort,
    this.fontLoader = _bundleFont,
    this.idleTimeout = const Duration(minutes: 10),
    this.lockDuration = const Duration(seconds: 60),
    this.bodyTimeout = const Duration(seconds: 5),
    DateTime Function()? now,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  static const defaultPort = 8790;
  static const maxBody = 16 * 1024;
  static const maxFailures = 5;

  /// Verrouillages tolérés par ouverture du serveur ; le suivant l'arrête.
  static const maxLocks = 3;
  static const maxConnections = 16;
  static const maxConnectionsPerIp = 4;
  static const connectionIdleTimeout = Duration(seconds: 15);
  static const rateLimit = 60;
  static const rateWindow = Duration(seconds: 10);
  static const cookieName = 'lumio_sid';

  final PhoneBackend backend;
  @override
  final PhoneAddCoordinator adds;
  final LanAddressSource lan;
  final String lang;
  final int preferredPort;
  final Duration idleTimeout;
  final Duration lockDuration;

  /// Délai total de lecture d'un corps de requête.
  final Duration bodyTimeout;
  final DateTime Function() _now;
  final Random _random;

  /// Polices embarquées de l'application servies à la page (`manrope`,
  /// `bricolage`) ; `null` si inconnue.
  final Future<List<int>?> Function(String name) fontLoader;

  static Future<List<int>?> _bundleFont(String name) async {
    const files = {
      'manrope': 'assets/fonts/Manrope-Variable.ttf',
      'bricolage': 'assets/fonts/BricolageGrotesque-Variable.ttf',
    };
    final f = files[name];
    if (f == null) return null;
    final d = await rootBundle.load(f);
    return d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
  }

  final _state = ValueNotifier(const PhoneServerState());
  @override
  ValueListenable<PhoneServerState> get state => _state;

  HttpServer? _server;
  _LimitedServerSocket? _socket;
  int _locks = 0;
  bool _stopTooMany = false;
  Timer? _idle;
  final _sessions = <String, _Session>{};
  final _hits = <String, List<DateTime>>{};
  List<int> _secret = const [];
  int _failures = 0;
  int _generation = 0;

  String _token([int bytes = 32]) => List.generate(
    bytes,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  String _newCode() => List.generate(6, (_) => _random.nextInt(10)).join();

  @override
  Future<void> start() async {
    if (_server != null) return;
    final gen = ++_generation;
    _state.value = const PhoneServerState(status: PhoneServerStatus.starting);
    final addr = await lan.current();
    if (gen != _generation) return;
    if (addr == null) {
      _state.value = const PhoneServerState(
        status: PhoneServerStatus.noNetwork,
      );
      return;
    }
    HttpServer server;
    _LimitedServerSocket socket;
    try {
      ServerSocket raw;
      try {
        raw = await ServerSocket.bind(addr, preferredPort);
      } on SocketException {
        raw = await ServerSocket.bind(addr, 0);
      }
      socket = _LimitedServerSocket(raw, maxConnections, maxConnectionsPerIp);
      server = HttpServer.listenOn(socket);
      server.idleTimeout = connectionIdleTimeout;
    } on Object {
      if (gen == _generation) {
        _state.value = const PhoneServerState(status: PhoneServerStatus.error);
      }
      return;
    }
    if (gen != _generation) {
      await server.close(force: true);
      await socket.close();
      return;
    }
    _server = server;
    _socket = socket;
    _locks = 0;
    _stopTooMany = false;
    _secret = List.generate(32, (_) => _random.nextInt(256));
    _sessions.clear();
    _hits.clear();
    _failures = 0;
    _state.value = PhoneServerState(
      status: PhoneServerStatus.listening,
      host: addr.address,
      port: server.port,
      code: _newCode(),
    );
    _armIdle();
    server.listen(_handle, onError: (_) {});
  }

  void _armIdle() {
    _idle?.cancel();
    _idle = Timer(idleTimeout, () => unawaited(_stop(idle: true)));
  }

  @override
  Future<void> stop() => _stop(idle: false);

  Future<void> _stop({required bool idle, bool tooMany = false}) async {
    _generation++;
    _idle?.cancel();
    _idle = null;
    final s = _server;
    final sock = _socket;
    _server = null;
    _socket = null;
    _sessions.clear();
    _hits.clear();
    adds.cancelPending();
    _state.value = PhoneServerState(
      status: PhoneServerStatus.stopped,
      idleStopped: idle,
      tooManyTries: tooMany,
    );
    await s?.close(force: true);
    await sock?.close();
  }

  @override
  void dispose() {
    _idle?.cancel();
    _generation++;
    final s = _server;
    final sock = _socket;
    _server = null;
    _socket = null;
    unawaited(s?.close(force: true));
    unawaited(sock?.close());
    _state.dispose();
  }

  // --- requêtes ---

  Future<void> _handle(HttpRequest req) async {
    try {
      final ip = req.connectionInfo?.remoteAddress.address ?? '';
      if (!_allowRate(ip)) {
        throw _HttpError(429, 'rate', headers: {'retry-after': '10'});
      }
      if (!_hostOk(req)) throw _HttpError(421, 'host');
      await _route(req);
    } on _HttpError catch (e) {
      await _json(req, e.status, {'error': e.code}, headers: e.headers);
      if (_stopTooMany) {
        _stopTooMany = false;
        await _stop(idle: false, tooMany: true);
      }
    } on Object {
      try {
        await _json(req, 500, {'error': 'internal'});
      } on Object {
        // Connexion déjà fermée.
      }
    }
  }

  bool _allowRate(String ip) {
    final t = _now();
    final list = _hits.putIfAbsent(ip, () => []);
    list.removeWhere((x) => t.difference(x) > rateWindow);
    if (list.length >= rateLimit) return false;
    list.add(t);
    return true;
  }

  bool _hostOk(HttpRequest req) {
    final h = req.headers.value('host');
    return h != null && h.toLowerCase() == _state.value.address;
  }

  Future<void> _route(HttpRequest req) async {
    final seg = req.uri.pathSegments;
    final m = req.method;
    if (m == 'GET' && seg.isEmpty) {
      return _send(req, 200, 'text/html; charset=utf-8', phoneIndexHtml(lang));
    }
    if (m == 'GET' && seg.length == 1 && seg[0] == 'app.css') {
      return _send(req, 200, 'text/css; charset=utf-8', phoneCss);
    }
    if (m == 'GET' && seg.length == 1 && seg[0] == 'app.js') {
      return _send(req, 200, 'text/javascript; charset=utf-8', phoneJs);
    }
    if (m == 'GET' &&
        seg.length == 2 &&
        seg[0] == 'fonts' &&
        seg[1].endsWith('.ttf')) {
      final bytes = await fontLoader(seg[1].substring(0, seg[1].length - 4));
      if (bytes == null) throw _HttpError(404, 'not_found');
      return _sendBytes(req, 'font/ttf', bytes);
    }
    if (seg.isEmpty || seg[0] != 'api') throw _HttpError(404, 'not_found');

    if (m == 'POST' && seg.length == 2 && seg[1] == 'login') {
      return _login(req);
    }

    final session = _auth(req);
    _armIdle();
    final write = m != 'GET';
    if (write) _checkWrite(req, session);

    if (m == 'GET' && seg.length == 2 && seg[1] == 'session') {
      return _json(req, 200, {'csrf': session.csrf, 'lang': lang});
    }
    if (m == 'GET' && seg.length == 2 && seg[1] == 'addons') {
      final list = await backend.addons();
      return _json(req, 200, {
        'addons': [
          for (final a in list)
            {
              'id': _opaque(a.id),
              'name': a.name,
              'types': a.types,
              'health': a.health,
              'enabled': a.enabled,
              'position': a.position,
              'broken': a.broken,
            },
        ],
      });
    }
    if (seg.length == 3 && seg[1] == 'addons' && m == 'DELETE') {
      final id = await _resolve(seg[2]);
      await backend.remove(id);
      return _json(req, 200, {'ok': true});
    }
    if (seg.length == 4 && seg[1] == 'addons' && m == 'POST') {
      final body = await _body(req);
      final id = await _resolve(seg[2]);
      if (seg[3] == 'move') {
        final d = body['delta'];
        if (d is! int || (d != 1 && d != -1)) {
          throw _HttpError(400, 'bad_request');
        }
        await backend.move(id, d);
        return _json(req, 200, {'ok': true});
      }
      if (seg[3] == 'enabled') {
        final e = body['enabled'];
        if (e is! bool) throw _HttpError(400, 'bad_request');
        await backend.setEnabled(id, e);
        return _json(req, 200, {'ok': true});
      }
    }
    if (m == 'POST' && seg.length == 2 && seg[1] == 'add') {
      final body = await _body(req);
      final link = body['link'];
      final url = link is String && link.length <= 2048
          ? parseInstallLink(link)
          : null;
      if (url == null) throw _HttpError(400, 'invalid_link');
      final r = adds.submit(url);
      return _json(req, 202, {'request': r.id});
    }
    if (m == 'GET' && seg.length == 3 && seg[1] == 'add') {
      final r = adds.lookup(seg[2]);
      if (r == null) throw _HttpError(404, 'not_found');
      return _json(req, 200, {
        'state': r.state.name,
        if (r.state == PhoneAddState.installed && r.name != null)
          'name': r.name,
      });
    }
    throw _HttpError(404, 'not_found');
  }

  // --- sécurité ---

  _Session _auth(HttpRequest req) {
    for (final c in req.cookies) {
      if (c.name == cookieName) {
        final s = _sessions[c.value];
        if (s != null) return s;
      }
    }
    throw _HttpError(401, 'unauthorized');
  }

  void _checkOrigin(HttpRequest req) {
    final o = req.headers.value('origin');
    if (o == null || o.toLowerCase() != 'http://${_state.value.address}') {
      throw _HttpError(403, 'origin');
    }
  }

  void _checkWrite(HttpRequest req, _Session s) {
    _checkOrigin(req);
    final t = req.headers.value('x-csrf-token');
    if (t == null || !_safeEquals(t, s.csrf)) throw _HttpError(403, 'csrf');
  }

  Future<void> _login(HttpRequest req) async {
    _checkOrigin(req);
    final body = await _body(req);
    final locked = _state.value.lockedUntil;
    if (locked != null) {
      final left = locked.difference(_now());
      if (left > Duration.zero) {
        throw _HttpError(
          429,
          'locked',
          headers: {'retry-after': '${left.inSeconds + 1}'},
        );
      }
      _state.value = _state.value.copyWith(clearLock: true);
    }
    final code = body['code'];
    if (code is! String) throw _HttpError(400, 'bad_request');
    if (!_safeEquals(code, _state.value.code)) {
      _failures++;
      if (_failures >= maxFailures) {
        _failures = 0;
        _locks++;
        if (_locks >= maxLocks) _stopTooMany = true;
        _state.value = _state.value.copyWith(
          lockedUntil: _now().add(lockDuration),
          code: _newCode(),
        );
        throw _HttpError(
          429,
          'locked',
          headers: {'retry-after': '${lockDuration.inSeconds}'},
        );
      }
      throw _HttpError(401, 'bad_code');
    }
    _failures = 0;
    while (_sessions.length >= 8) {
      _sessions.remove(_sessions.keys.first);
    }
    final sid = _token();
    final session = _Session(_token());
    _sessions[sid] = session;
    _state.value = _state.value.copyWith(connected: true);
    _armIdle();
    await _json(
      req,
      200,
      {'csrf': session.csrf},
      headers: {
        'set-cookie': '$cookieName=$sid; Path=/; HttpOnly; SameSite=Strict',
      },
    );
  }

  /// Comparaison à temps constant.
  static bool _safeEquals(String a, String b) {
    final x = utf8.encode(a);
    final y = utf8.encode(b);
    var diff = x.length ^ y.length;
    for (var i = 0; i < x.length; i++) {
      diff |= x[i] ^ y[i % (y.isEmpty ? 1 : y.length)];
    }
    return diff == 0;
  }

  /// Identifiant opaque : HMAC de l'identifiant avec un secret de session.
  String _opaque(String id) => Hmac(
    sha256,
    _secret,
  ).convert(utf8.encode(id)).toString().substring(0, 16);

  Future<String> _resolve(String opaque) async {
    for (final a in await backend.addons()) {
      if (_opaque(a.id) == opaque) return a.id;
    }
    throw _HttpError(404, 'not_found');
  }

  Future<Map<String, Object?>> _body(HttpRequest req) async {
    final type = req.headers.contentType;
    if (type == null || type.mimeType != 'application/json') {
      throw _HttpError(415, 'content_type');
    }
    if (req.contentLength > maxBody) throw _HttpError(413, 'too_large');
    final bytes = await _readBody(req);
    try {
      final j = jsonDecode(utf8.decode(bytes));
      if (j is Map<String, Object?>) return j;
    } on FormatException {
      // Corps illisible.
    }
    throw _HttpError(400, 'bad_request');
  }

  /// Lit le corps avec un délai TOTAL (pas par octet) : une connexion qui
  /// goutte à goutte est coupée (408).
  Future<List<int>> _readBody(HttpRequest req) {
    final bytes = <int>[];
    final done = Completer<List<int>>();
    late final StreamSubscription<List<int>> sub;
    final timer = Timer(bodyTimeout, () {
      if (!done.isCompleted) done.completeError(_HttpError(408, 'timeout'));
    });
    void fail(_HttpError e) {
      if (!done.isCompleted) done.completeError(e);
    }

    sub = req.listen(
      (chunk) {
        bytes.addAll(chunk);
        if (bytes.length > maxBody) fail(_HttpError(413, 'too_large'));
      },
      onDone: () {
        if (!done.isCompleted) done.complete(bytes);
      },
      onError: (Object _) => fail(_HttpError(400, 'bad_request')),
      cancelOnError: true,
    );
    return done.future.whenComplete(() {
      timer.cancel();
      unawaited(sub.cancel());
    });
  }

  // --- réponses ---

  static const _csp =
      "default-src 'none'; script-src 'self'; style-src 'self'; "
      "connect-src 'self'; img-src 'self'; font-src 'self'; base-uri 'none'; "
      "form-action 'none'; frame-ancestors 'none'";

  Future<void> _json(
    HttpRequest req,
    int status,
    Object body, {
    Map<String, String> headers = const {},
  }) => _send(
    req,
    status,
    'application/json; charset=utf-8',
    jsonEncode(body),
    headers: headers,
  );

  Future<void> _sendBytes(HttpRequest req, String type, List<int> bytes) async {
    final r = req.response;
    r.statusCode = 200;
    r.headers
      ..set('content-type', type)
      ..set('cache-control', 'private, max-age=3600')
      ..set('x-content-type-options', 'nosniff')
      ..set('referrer-policy', 'no-referrer')
      ..set('content-security-policy', _csp);
    r.add(bytes);
    await r.close();
  }

  Future<void> _send(
    HttpRequest req,
    int status,
    String type,
    String body, {
    Map<String, String> headers = const {},
  }) async {
    final r = req.response;
    r.statusCode = status;
    r.headers
      ..set('content-type', type)
      ..set('cache-control', 'no-store')
      ..set('x-content-type-options', 'nosniff')
      ..set('referrer-policy', 'no-referrer')
      ..set('content-security-policy', _csp)
      ..set('x-frame-options', 'DENY');
    headers.forEach(r.headers.set);
    // Une erreur de corps (413) : on ferme la connexion sans lire la suite.
    if (status == 413 || status == 408) r.headers.set('connection', 'close');
    r.write(body);
    await r.close();
  }
}

/// Socket d'écoute qui refuse (ferme aussitôt) les connexions au-delà de
/// [maxTotal] actives, ou de [maxPerIp] pour une même adresse.
class _LimitedServerSocket extends StreamView<Socket> implements ServerSocket {
  _LimitedServerSocket._(this._inner, Stream<Socket> filtered)
    : super(filtered);

  factory _LimitedServerSocket(ServerSocket inner, int maxTotal, int maxPerIp) {
    var total = 0;
    final perIp = <String, int>{};
    final filtered = inner.where((s) {
      final ip = s.remoteAddress.address;
      if (total >= maxTotal || (perIp[ip] ?? 0) >= maxPerIp) {
        s.destroy();
        return false;
      }
      total++;
      perIp[ip] = (perIp[ip] ?? 0) + 1;
      void release() {
        total--;
        final n = (perIp[ip] ?? 1) - 1;
        if (n <= 0) {
          perIp.remove(ip);
        } else {
          perIp[ip] = n;
        }
      }

      s.done.then((_) => release(), onError: (Object _) => release());
      return true;
    });
    return _LimitedServerSocket._(inner, filtered);
  }

  final ServerSocket _inner;

  @override
  int get port => _inner.port;

  @override
  InternetAddress get address => _inner.address;

  @override
  Future<ServerSocket> close() async {
    await _inner.close();
    return this;
  }
}
