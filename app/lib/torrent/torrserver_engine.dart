import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:lumio/torrent/torrent_engine.dart';

/// Adresse et identifiants du TorrServer local (mot de passe aléatoire par
/// lancement, jamais journalisé).
class TorrServerEndpoint {
  const TorrServerEndpoint({
    required this.port,
    required this.user,
    required this.password,
  });
  final int port;
  final String user;
  final String password;

  Uri get base => Uri(scheme: 'http', host: '127.0.0.1', port: port);

  String get authHeader =>
      'Basic ${base64.encode(utf8.encode('$user:$password'))}';

  @override
  String toString() => 'TorrServerEndpoint(127.0.0.1:$port)';
}

/// Processus TorrServer (côté Android : `TorrServerManager`) ; remplacé en test.
abstract class TorrServerProcess {
  /// Démarre le processus s'il ne tourne pas (sinon rend l'existant).
  Future<TorrServerEndpoint> start();

  /// Arrête le processus ; sans effet s'il est arrêté.
  Future<void> stop();
}

/// Le moteur n'a pas répondu après son démarrage.
class TorrServerStartException implements Exception {
  const TorrServerStartException(this.message);
  final String message;
  @override
  String toString() => 'TorrServerStartException: $message';
}

/// Le moteur refuse de servir le flux (réponse non 2xx) : l'URL n'est jamais
/// rendue au lecteur.
class TorrServerStreamException implements Exception {
  const TorrServerStreamException(this.status);
  final int status;
  @override
  String toString() => 'TorrServerStreamException: moteur HTTP $status';
}

/// Réponse d'erreur du moteur ; le code seul est conservé (ni URL, ni
/// identifiants).
class TorrServerHttpException extends HttpException {
  TorrServerHttpException(String path, this.status)
    : super('TorrServer $path : HTTP $status');
  final int status;
}

const _videoExtensions = {
  'mkv', 'mp4', 'm4v', 'avi', 'mov', 'ts', 'm2ts', 'mts', 'webm', 'wmv', //
  'flv', 'mpg', 'mpeg', 'ogv', '3gp',
};

bool isStreamableName(String name) {
  final dot = name.lastIndexOf('.');
  return dot >= 0 &&
      _videoExtensions.contains(name.substring(dot + 1).toLowerCase());
}

const _mib = 1024 * 1024;

/// Trackers publics ajoutés à ceux du magnet (mode « ajouter »). Sans eux,
/// les métadonnées d'un magnet maigre mettent ~4 s (DHT seul) au lieu de
/// ~1,4 s sur la box. Liste courte et fixe, à la place de la liste par défaut
/// de TorrServer (trackers russes, HTTP en clair) ; aucune liste distante.
const publicTrackers = [
  'udp://tracker.opentrackr.org:1337/announce',
  'udp://open.tracker.cl:1337/announce',
  'udp://tracker.torrent.eu.org:451/announce',
  'udp://open.stealth.si:80/announce',
  'udp://exodus.desync.com:6969/announce',
  'udp://explodie.org:6969/announce',
];

/// Réglages envoyés à TorrServer (`POST /settings`, clés de `BTSets`).
///
/// - Cache sur disque, borné par [TorrentSettings.maxCacheBytes], dans le
///   dossier de cache de l'application ; supprimé quand le torrent est retiré.
/// - Envoi : coupé sans ensemencement, sinon limite en Kio/s (0 = illimité).
/// - DHT actif ; UPnP, découverte locale (LPD), Bonjour, DLNA, recherche et
///   liste de trackers distante coupés : rien n'est annoncé sur le réseau local
///   ni demandé à un tiers hors des trackers du magnet et de [publicTrackers].
Map<String, Object?> torrServerSettings(TorrentSettings s) {
  final cache = s.maxCacheBytes < 64 * _mib ? 64 * _mib : s.maxCacheBytes;
  int pct(int bytes) => (bytes * 100 ~/ cache).clamp(1, 95);
  return {
    'UseDisk': true,
    'TorrentsSavePath': s.savePath,
    'CacheSize': cache,
    'RemoveCacheOnDrop': true,
    // Fenêtre de lecture anticipée ~96 Mo, préchargement ~16 Mo.
    'ReaderReadAHead': pct(96 * _mib),
    'PreloadCache': pct(16 * _mib),
    'DisableUpload': !s.seed,
    'UploadRateLimit': s.seed && s.uploadLimit > 0 ? s.uploadLimit ~/ 1024 : 0,
    'DownloadRateLimit': s.downloadLimit > 0 ? s.downloadLimit ~/ 1024 : 0,
    'DisableDHT': false,
    'DisableUPNP': true,
    'EnableLPD': false,
    'EnableBonjour': false,
    'EnableDLNA': false,
    'EnableIPv6': false,
    'EnableRutorSearch': false,
    'EnableTorznabSearch': false,
    'RetrackersMode': 1,
    'DefaultTrackers': publicTrackers.join('\n'),
    'TrackersListURL': '',
    'EnableDebug': false,
    // Un torrent en pause ne doit pas être abandonné trop vite.
    'TorrentDisconnectTimeout': 300,
  };
}

/// Adaptateur de TorrServer (MatriX.150) par son API HTTP locale. Aucun type
/// TorrServer ne sort de cette classe.
class TorrServerEngine implements TorrentEngine {
  TorrServerEngine({
    required this.process,
    this.statusInterval = const Duration(seconds: 1),
    this.startTimeout = const Duration(seconds: 20),
    HttpClient Function()? clientFactory,
  }) : _newClient = clientFactory ?? HttpClient.new;

  final TorrServerProcess process;
  final Duration statusInterval;
  final Duration startTimeout;
  final HttpClient Function() _newClient;

  HttpClient? _client;
  TorrentSettings? _settings;
  TorrServerEndpoint? _ep;
  Future<void>? _recovering;
  final _magnets = <String, String>{}; // hash -> magnet (reprise après crash)
  final _tickers = <String, Set<Timer>>{};

  HttpClient get _http => _client ??= _newClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..idleTimeout = const Duration(seconds: 10);

  bool get _ready => _settings != null;

  void _requireReady() {
    if (!_ready) throw StateError('moteur non initialisé');
  }

  // ---------------------------------------------------------------- HTTP

  Future<String> _send(
    String method,
    String path,
    Object? body, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final ep = _ep ?? (throw const SocketException('moteur arrêté'));
    final req = await _http.openUrl(method, ep.base.replace(path: path));
    req.headers
      ..set(HttpHeaders.authorizationHeader, ep.authHeader)
      ..contentType = ContentType.json;
    if (body != null) req.add(utf8.encode(jsonEncode(body)));
    final res = await req.close().timeout(timeout);
    final text = await utf8.decodeStream(res).timeout(timeout);
    if (res.statusCode >= 400) {
      throw TorrServerHttpException(path, res.statusCode);
    }
    return text;
  }

  /// Le moteur ne répond plus, ou n'est plus d'accord avec nous (mot de passe
  /// périmé après une relance native) : à relancer, pas à signaler.
  static bool _isStale(Object e) =>
      e is SocketException ||
      e is TimeoutException ||
      (e is TorrServerHttpException && (e.status == 401 || e.status == 403)) ||
      (e is HttpException && e is! TorrServerHttpException);

  /// Appel JSON ; un moteur mort, bloqué ou désaccordé (401) est relancé une
  /// fois, ses torrents sont rajoutés, puis l'appel est rejoué.
  Future<Object?> _call(String path, Map<String, Object?> body) async {
    try {
      return _decode(await _send('POST', path, body));
    } on Object catch (e) {
      if (!_isStale(e)) rethrow;
      await _recover();
      return _decode(await _send('POST', path, body));
    }
  }

  static Object? _decode(String text) => text.isEmpty ? null : jsonDecode(text);

  Future<void> _waitEcho() async {
    final watch = Stopwatch()..start();
    while (true) {
      try {
        await _send('GET', '/echo', null, timeout: const Duration(seconds: 2));
        return;
      } on Object {
        if (watch.elapsed > startTimeout) {
          throw const TorrServerStartException('pas de réponse du moteur');
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  Future<void> _boot() async {
    _ep = await process.start();
    await _waitEcho();
    // `set` remplace tout (et relance le client BitTorrent, ~3,5 s sur la
    // box) : on part des réglages courants et on n'écrit que s'il y a un
    // écart. TorrServer garde ses réglages dans son dossier de données : aux
    // lancements suivants, plus rien à écrire.
    final current = _decode(
      await _send('POST', '/settings', {'action': 'get'}),
    );
    final wanted = torrServerSettings(_settings!);
    final base = current is Map<String, Object?>
        ? current
        : <String, Object?>{};
    final differs = wanted.entries.any(
      (e) => jsonEncode(base[e.key]) != jsonEncode(e.value),
    );
    if (differs) {
      await _send('POST', '/settings', {
        'action': 'set',
        'sets': {...base, ...wanted},
      });
    }
  }

  Future<void> _addMagnet(String magnet) => _send('POST', '/torrents', {
    'action': 'add',
    'link': magnet,
    'save_to_db': false,
  });

  /// Relance réelle du moteur : arrêt du processus, nouveau démarrage (le
  /// gestionnaire natif rend de nouvelles coordonnées), torrents rajoutés.
  Future<void> _recover() {
    return _recovering ??= () async {
      try {
        debugPrint('TorrServerEngine : moteur indisponible, relance');
        _client?.close(force: true); // connexions vers l'ancien processus
        _client = null;
        _ep = null;
        try {
          await process.stop();
        } on Object {
          // Déjà arrêté.
        }
        await _boot();
        for (final magnet in _magnets.values.toList()) {
          await _addMagnet(magnet);
        }
      } finally {
        _recovering = null;
      }
    }();
  }

  /// Contrôle d'état authentifié avant d'ouvrir un flux : le moteur répond
  /// avec nos identifiants (sinon relance) et connaît nos torrents (sinon
  /// ils sont rajoutés). `/echo` ne suffit pas : il ne demande pas de mot de
  /// passe.
  Future<void> _ensureHealthy() async {
    final running = _recovering;
    if (running != null) return running;
    Object? list;
    try {
      list = _decode(
        await _send('POST', '/torrents', {
          'action': 'list',
        }, timeout: const Duration(seconds: 5)),
      );
    } on Object catch (e) {
      if (!_isStale(e)) rethrow;
      await _recover();
      return;
    }
    final known = <String>{
      if (list is List)
        for (final t in list)
          if (t is Map && t['hash'] is String)
            (t['hash'] as String).toLowerCase(),
    };
    for (final e in _magnets.entries.toList()) {
      if (!known.contains(e.key)) await _addMagnet(e.value);
    }
  }

  /// Rajoute le torrent [id] au moteur s'il est connu de l'adaptateur.
  Future<bool> _readd(String id) async {
    final magnet = _magnets[id];
    if (magnet == null) return false;
    await _addMagnet(magnet);
    return true;
  }

  // -------------------------------------------------------------- contrat

  @override
  Future<void> init(TorrentSettings s) async {
    if (_ready) throw StateError('moteur déjà initialisé');
    _settings = s;
    try {
      await _boot();
    } on Object {
      _settings = null;
      await process.stop();
      rethrow;
    }
  }

  static String _hashOf(String magnet) {
    final m = RegExp(
      r'xt=urn:btih:([0-9a-fA-F]{40})',
      caseSensitive: false,
    ).firstMatch(magnet);
    if (m == null) throw ArgumentError('magnet sans infoHash hexadécimal');
    return m.group(1)!.toLowerCase();
  }

  @override
  Future<String> add(String magnetOrInfoHash) async {
    _requireReady();
    final magnet = isInfoHash(magnetOrInfoHash)
        ? magnetFromInfoHash(magnetOrInfoHash)
        : magnetOrInfoHash;
    final hash = _hashOf(magnet);
    await _ensureHealthy();
    _magnets[hash] = magnet;
    final r = await _call('/torrents', {
      'action': 'add',
      'link': magnet,
      'save_to_db': false,
    });
    final got = r is Map ? r['hash'] : null;
    return got is String && got.isNotEmpty ? got.toLowerCase() : hash;
  }

  Future<Map<String, Object?>> _info(String id) async {
    Object? r;
    try {
      r = await _call('/torrents', {'action': 'get', 'hash': id});
    } on TorrServerHttpException catch (e) {
      if (e.status != 404) rethrow;
    }
    if (r is! Map<String, Object?>) {
      // Torrent disparu côté moteur : ré-ajout transparent, une seule fois.
      if (!await _readd(id)) throw StateError('torrent inconnu : $id');
      r = await _call('/torrents', {'action': 'get', 'hash': id});
      if (r is! Map<String, Object?>) {
        throw StateError('torrent inconnu : $id');
      }
    }
    return r;
  }

  @override
  Future<List<TorrentFile>> files(String id) async {
    _requireReady();
    final stats = (await _info(id))['file_stats'];
    if (stats is! List) return const [];
    final out = <TorrentFile>[];
    for (final f in stats) {
      if (f is! Map) continue;
      final path = '${f['path']}';
      final slash = path.lastIndexOf('/');
      final name = slash < 0 ? path : path.substring(slash + 1);
      // TorrServer numérote à partir de 1 ; l'interface, comme `fileIdx` des
      // addons, à partir de 0.
      out.add(
        TorrentFile(
          index: ((f['id'] as num).toInt()) - 1,
          name: name,
          path: path,
          size: (f['length'] as num?)?.toInt() ?? 0,
          streamable: isStreamableName(name),
        ),
      );
    }
    return out;
  }

  @override
  Future<Uri> stream(String id, {int? fileIndex}) async {
    _requireReady();
    await _ensureHealthy();
    var index = fileIndex;
    if (index == null) {
      final list = await files(id);
      TorrentFile? best;
      for (final f in list) {
        if (f.streamable && (best == null || f.size > best.size)) best = f;
      }
      index = (best ?? (list.isEmpty ? null : list.first))?.index;
      if (index == null) throw StateError('aucun fichier : $id');
    }
    Uri build() {
      final ep = _ep ?? (throw StateError('moteur arrêté'));
      return Uri(
        scheme: 'http',
        userInfo: '${ep.user}:${ep.password}',
        host: '127.0.0.1',
        port: ep.port,
        path: '/stream',
        query: 'link=$id&index=${index! + 1}&play',
      );
    }

    // Jamais d'URL au lecteur sans réponse 2xx du moteur : mpv prendrait le
    // corps d'erreur pour une liste de lecture. Un refus 401 ou une connexion
    // coupée relance le moteur, un 404 rajoute le torrent ; un second échec
    // est une erreur.
    var status = await _probeStream(build());
    for (var attempt = 0; attempt < 2 && !_ok(status); attempt++) {
      if (status == 404) {
        if (!await _readd(id)) break;
      } else if (status == null || status == 401 || status == 403) {
        await _recover();
      } else {
        break;
      }
      status = await _probeStream(build());
    }
    if (!_ok(status)) throw TorrServerStreamException(status ?? 0);
    return build();
  }

  static bool _ok(int? status) => status != null && status ~/ 100 == 2;

  /// Code HTTP rendu par le flux (requête d'un octet, abandonnée aussitôt).
  /// Un moteur qui n'a pas encore répondu après quelques secondes (torrent en
  /// préchargement) n'est pas une erreur : rendu 200 ; `null` : moteur
  /// injoignable.
  Future<int?> _probeStream(Uri url) async {
    final probe = _newClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await probe.getUrl(url.replace(userInfo: ''));
      final ep = _ep!;
      req.headers
        ..set(HttpHeaders.authorizationHeader, ep.authHeader)
        ..set(HttpHeaders.rangeHeader, 'bytes=0-0');
      final res = await req.close().timeout(const Duration(seconds: 4));
      return res.statusCode;
    } on TimeoutException {
      return 200;
    } on SocketException {
      return null;
    } on HttpException {
      return null;
    } finally {
      probe.close(force: true);
    }
  }

  TorrentStatus _map(Map<String, Object?> t) {
    int i(String k) => (t[k] as num?)?.toInt() ?? 0;
    final total = i('torrent_size');
    final cap = _settings?.maxCacheBytes ?? 0;
    // Tampon : octets préchargés par rapport à ce qu'il faut pour démarrer
    // (préchargement visé, borné par la taille du torrent).
    final target = total > 0 && cap > 0
        ? [16 * _mib, total].reduce((a, b) => a < b ? a : b)
        : 0;
    final loaded = i('loaded_size') > i('preloaded_bytes')
        ? i('loaded_size')
        : i('preloaded_bytes');
    final progress = target > 0 ? (loaded / target).clamp(0.0, 1.0) : 0.0;
    return TorrentStatus(
      peers: i('active_peers'),
      seeders: i('connected_seeders'),
      downloadRate: ((t['download_speed'] as num?) ?? 0).round(),
      uploadRate: ((t['upload_speed'] as num?) ?? 0).round(),
      progress: progress.toDouble(),
    );
  }

  @override
  Stream<TorrentStatus> status(String id) {
    _requireReady();
    return Stream<TorrentStatus>.multi((c) {
      var busy = false;
      Future<void> tick() async {
        if (busy || c.isClosed) return;
        busy = true;
        try {
          final s = _map(await _info(id));
          if (!c.isClosed) c.add(s);
        } on Object catch (e) {
          if (!c.isClosed) {
            c.add(
              TorrentStatus(
                peers: 0,
                seeders: 0,
                downloadRate: 0,
                uploadRate: 0,
                progress: 0,
                error: e.runtimeType.toString(),
              ),
            );
          }
        } finally {
          busy = false;
        }
      }

      unawaited(tick());
      final timer = Timer.periodic(statusInterval, (_) => unawaited(tick()));
      (_tickers[id] ??= {}).add(timer);
      c.onCancel = () {
        timer.cancel();
        _tickers[id]?.remove(timer);
      };
    });
  }

  @override
  Future<void> stop(String id, {bool deleteData = true}) async {
    _requireReady();
    _magnets.remove(id);
    for (final t in _tickers.remove(id) ?? const <Timer>{}) {
      t.cancel();
    }
    // `rem` retire le torrent (et, avec RemoveCacheOnDrop, son cache) ;
    // `drop` le déconnecte seulement.
    await _call('/torrents', {
      'action': deleteData ? 'rem' : 'drop',
      'hash': id,
    });
  }

  @override
  Future<void> clearCache() async {
    if (!_ready || _ep == null) return;
    _magnets.clear();
    final list = await _call('/torrents', {'action': 'list'});
    if (list is! List) return;
    for (final t in list) {
      final h = t is Map ? t['hash'] : null;
      if (h is String) await _call('/torrents', {'action': 'rem', 'hash': h});
    }
  }

  @override
  Future<void> dispose() async {
    if (!_ready) return;
    _settings = null;
    for (final set in _tickers.values) {
      for (final t in set) {
        t.cancel();
      }
    }
    _tickers.clear();
    _magnets.clear();
    _ep = null;
    _client?.close(force: true);
    _client = null;
    await process.stop();
  }
}
