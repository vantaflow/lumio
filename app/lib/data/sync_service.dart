import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:lumio/data/addon_sync.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio/data/sync_store.dart';
import 'package:lumio_core/lumio_core.dart';

/// Réponse HTTP minimale (statut, corps texte, en-têtes en minuscules).
class SyncHttpResponse {
  const SyncHttpResponse(this.status, this.body, [this.headers = const {}]);
  final int status;
  final String body;
  final Map<String, String> headers;
}

/// Transport HTTP du client de synchronisation ; substituable en test.
abstract class SyncHttp {
  Future<SyncHttpResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers,
    String? body,
  });
}

class IoSyncHttp implements SyncHttp {
  const IoSyncHttp({this.timeout = const Duration(seconds: 15)});
  final Duration timeout;

  /// 500 éléments de 16 Ko au pire.
  static const _maxBytes = 10 * 1024 * 1024;

  @override
  Future<SyncHttpResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    String? body,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      return await () async {
        final req = await client.openUrl(method, url);
        req.followRedirects = false;
        headers.forEach(req.headers.set);
        if (body != null) {
          final bytes = utf8.encode(body);
          req.headers.contentType = ContentType.json;
          req.contentLength = bytes.length;
          req.add(bytes);
        }
        final res = await req.close();
        final bytes = <int>[];
        await for (final chunk in res) {
          bytes.addAll(chunk);
          if (bytes.length > _maxBytes) throw const SyncException.tooLarge();
        }
        final h = <String, String>{};
        res.headers.forEach((k, v) => h[k.toLowerCase()] = v.join(','));
        return SyncHttpResponse(
          res.statusCode,
          utf8.decode(bytes, allowMalformed: true),
          h,
        );
      }().timeout(timeout);
    } finally {
      client.close(force: true);
    }
  }
}

enum SyncErrorCode {
  /// L'adresse du serveur n'est pas en https.
  insecureUrl,

  /// Serveur injoignable ou réponse invalide.
  unavailable,

  /// Session expirée et non renouvelable : reconnexion nécessaire.
  signedOut,

  /// Adresse e-mail ou code refusés.
  rejected,

  /// Trop de demandes.
  rateLimited,
  tooLarge,
}

class SyncException implements Exception {
  const SyncException(this.code, {this.retryAfter});
  const SyncException.tooLarge() : this(SyncErrorCode.tooLarge);

  final SyncErrorCode code;
  final Duration? retryAfter;

  @override
  String toString() => 'SyncException: ${code.name}';
}

/// Clés du `SecretStore` : jetons de session, jamais en clair dans SQLite.
abstract final class SyncSecretKeys {
  static const session = 'sync.session';
  static const refresh = 'sync.refresh';
  static const email = 'sync.email';
}

/// Client du serveur : connexion par code reçu par e-mail, envoi et tirage
/// des éléments, suppression du compte. Le jeton de session est renouvelé
/// automatiquement avec le jeton de rafraîchissement.
class SyncApiClient implements SyncTransport {
  SyncApiClient(
    String backendUrl,
    this._secrets, {
    SyncHttp http = const IoSyncHttp(),
  }) : baseUrl = _parseBase(backendUrl),
       _http = http;

  final Uri baseUrl;
  final SecretStore _secrets;
  final SyncHttp _http;

  /// https obligatoire, sauf http vers localhost (développement).
  static Uri _parseBase(String raw) {
    final u = Uri.tryParse(raw.trim());
    final local =
        u != null &&
        (u.host == 'localhost' || u.host == '127.0.0.1' || u.host == '::1');
    if (u == null ||
        u.host.isEmpty ||
        u.hasQuery ||
        u.userInfo.isNotEmpty ||
        !(u.scheme == 'https' || (u.scheme == 'http' && local))) {
      throw const SyncException(SyncErrorCode.insecureUrl);
    }
    return u.replace(path: u.path.replaceAll(RegExp(r'/+$'), ''));
  }

  Uri _url(String path, [Map<String, String>? query]) =>
      baseUrl.replace(path: '${baseUrl.path}$path', queryParameters: query);

  Future<bool> isSignedIn() async =>
      (await _secrets.read(SyncSecretKeys.refresh)) != null;

  Future<String?> email() => _secrets.read(SyncSecretKeys.email);

  Future<SyncHttpResponse> _raw(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    String? body,
  }) async {
    try {
      return await _http.send(method, url, headers: headers, body: body);
    } on SyncException {
      rethrow;
    } on Object {
      throw const SyncException(SyncErrorCode.unavailable);
    }
  }

  SyncException _fail(SyncHttpResponse r) {
    if (r.status == 429) {
      final wait = int.tryParse(r.headers['retry-after'] ?? '');
      return SyncException(
        SyncErrorCode.rateLimited,
        retryAfter: wait == null
            ? null
            : Duration(seconds: wait.clamp(1, 3600)),
      );
    }
    if (r.status == 413) return const SyncException.tooLarge();
    return const SyncException(SyncErrorCode.unavailable);
  }

  // --- Connexion ---------------------------------------------------------

  /// Envoie le code de connexion par e-mail.
  Future<void> requestCode(String email) async {
    final r = await _raw(
      'POST',
      _url('/auth/request'),
      body: jsonEncode({'email': email.trim()}),
    );
    if (r.status == 202 || r.status == 200) return;
    if (r.status == 400) throw const SyncException(SyncErrorCode.rejected);
    throw _fail(r);
  }

  /// Échange le code contre une session ; mémorise les jetons.
  Future<void> verifyCode(String email, String code) async {
    final r = await _raw(
      'POST',
      _url('/auth/verify'),
      body: jsonEncode({'token': code.trim()}),
    );
    if (r.status == 401 || r.status == 400) {
      throw const SyncException(SyncErrorCode.rejected);
    }
    if (r.status != 200) throw _fail(r);
    await _storeTokens(r.body);
    await _secrets.write(SyncSecretKeys.email, email.trim().toLowerCase());
  }

  Future<void> _storeTokens(String body) async {
    String session;
    String refresh;
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      session = j['session'] as String;
      refresh = j['refresh'] as String;
    } on Object {
      throw const SyncException(SyncErrorCode.unavailable);
    }
    await _secrets.write(SyncSecretKeys.session, session);
    await _secrets.write(SyncSecretKeys.refresh, refresh);
  }

  /// Oublie les jetons locaux (la session côté serveur expire seule).
  Future<void> signOut() async {
    for (final k in [
      SyncSecretKeys.session,
      SyncSecretKeys.refresh,
      SyncSecretKeys.email,
    ]) {
      await _secrets.delete(k);
    }
  }

  /// Efface le compte et toutes ses données sur le serveur, puis se déconnecte.
  Future<void> deleteAccount() async {
    final r = await _authed('DELETE', _url('/account'));
    if (r.status != 204 && r.status != 200) throw _fail(r);
    await signOut();
  }

  // --- Session -----------------------------------------------------------

  Future<void>? _refreshing;

  /// Renouvelle la session ; les appels simultanés partagent un seul essai
  /// (le jeton de rafraîchissement est à usage unique).
  Future<void> _refresh() => _refreshing ??= _doRefresh().whenComplete(() {
    _refreshing = null;
  });

  Future<void> _doRefresh() async {
    final refresh = await _secrets.read(SyncSecretKeys.refresh);
    if (refresh == null) throw const SyncException(SyncErrorCode.signedOut);
    final r = await _raw(
      'POST',
      _url('/auth/refresh'),
      body: jsonEncode({'refresh': refresh}),
    );
    if (r.status == 401 || r.status == 400) {
      await signOut();
      throw const SyncException(SyncErrorCode.signedOut);
    }
    if (r.status != 200) throw _fail(r);
    await _storeTokens(r.body);
  }

  Future<SyncHttpResponse> _authed(
    String method,
    Uri url, {
    String? body,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final session = await _secrets.read(SyncSecretKeys.session);
      if (session == null) {
        if (attempt == 0 && await isSignedIn()) {
          await _refresh();
          continue;
        }
        throw const SyncException(SyncErrorCode.signedOut);
      }
      final r = await _raw(
        method,
        url,
        headers: {'Authorization': 'Bearer $session'},
        body: body,
      );
      if (r.status == 401 && attempt == 0) {
        await _refresh();
        continue;
      }
      if (r.status == 401) throw const SyncException(SyncErrorCode.signedOut);
      return r;
    }
    throw const SyncException(SyncErrorCode.signedOut);
  }

  /// Requête authentifiée pour les autres fonctions en ligne (salons) : mêmes
  /// jetons, même renouvellement automatique sur 401.
  Future<SyncHttpResponse> authedRequest(
    String method,
    Uri url, {
    String? body,
  }) => _authed(method, url, body: body);

  /// Jeton de session valide (renouvelé si absent ou si [forceRefresh]), pour
  /// les connexions WebSocket qui ne peuvent pas se renouveler en cours de route.
  Future<String> freshSession({bool forceRefresh = false}) async {
    if (forceRefresh || await _secrets.read(SyncSecretKeys.session) == null) {
      if (!await isSignedIn()) {
        throw const SyncException(SyncErrorCode.signedOut);
      }
      await _refresh();
    }
    final s = await _secrets.read(SyncSecretKeys.session);
    if (s == null) throw const SyncException(SyncErrorCode.signedOut);
    return s;
  }

  /// URL du serveur pour [path] (ex. `/rooms`).
  Uri urlFor(String path) => _url(path);

  // --- SyncTransport -----------------------------------------------------

  @override
  Future<SyncPage> pull(int since) async {
    final r = await _authed('GET', _url('/sync', {'since': '$since'}));
    if (r.status != 200) throw _fail(r);
    try {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final items = [
        for (final e in j['items'] as List)
          SyncItem.fromJson(Map<String, dynamic>.from(e as Map)),
      ];
      return SyncPage(
        items: items,
        version: (j['version'] as num).toInt(),
        more: j['more'] == true,
      );
    } on Object {
      throw const SyncException(SyncErrorCode.unavailable);
    }
  }

  @override
  Future<int> push(List<SyncItem> items) async {
    final r = await _authed(
      'POST',
      _url('/sync'),
      body: jsonEncode({
        'items': [for (final i in items) i.toPushJson()],
      }),
    );
    if (r.status != 200) throw _fail(r);
    try {
      return ((jsonDecode(r.body) as Map<String, dynamic>)['version'] as num)
          .toInt();
    } on Object {
      throw const SyncException(SyncErrorCode.unavailable);
    }
  }
}

/// État de la synchronisation, pour l'écran Compte.
enum SyncStatus { signedOut, idle, syncing, offline }

typedef TimerFactory = Timer Function(Duration d, void Function() cb);

/// Orchestre le moteur : un cycle toutes les 15 s au premier plan, un cycle
/// juste après une pause de lecture, recul exponentiel en cas d'erreur.
/// Hors ligne, rien ne casse : les changements restent dans la file locale.
class SyncService {
  SyncService({
    required SyncApiClient api,
    required DriftLocalSyncStore store,
    SyncEngine? engine,
    this.addons,
    this.interval = const Duration(seconds: 15),
    this.maxBackoff = const Duration(minutes: 5),
    this.pauseDelay = const Duration(seconds: 1),
    this.onApplied,
    TimerFactory? timer,
  }) : _api = api,
       _store = store,
       _engine = engine ?? SyncEngine(api, store),
       _timer = timer ?? Timer.new;

  final SyncApiClient _api;
  final DriftLocalSyncStore _store;
  final SyncEngine _engine;

  /// Addons chiffrés côté client ; nul = addons non synchronisés.
  final AddonSync? addons;
  final Duration interval;
  final Duration maxBackoff;

  /// Délai laissé à l'écriture de la progression avant l'envoi d'une pause.
  final Duration pauseDelay;

  /// Appelé après un cycle réussi qui a reçu des éléments (rafraîchit
  /// l'interface).
  final void Function()? onApplied;
  final TimerFactory _timer;

  Timer? _next;
  bool _started = false;
  int _failures = 0;
  bool _signedIn = false;
  SyncStatus _status = SyncStatus.signedOut;
  final _statusController = StreamController<SyncStatus>.broadcast();

  SyncStatus get status => _status;
  Stream<SyncStatus> get statusStream => _statusController.stream;
  int get failures => _failures;

  void _setStatus(SyncStatus s) {
    if (s == _status) return;
    _status = s;
    if (!_statusController.isClosed) _statusController.add(s);
  }

  /// Délai avant le prochain cycle : [interval], doublé à chaque échec
  /// consécutif jusqu'à [maxBackoff].
  Duration get nextDelay {
    if (_failures == 0) return interval;
    final ms = interval.inMilliseconds * math.pow(2, _failures.clamp(0, 16));
    return Duration(
      milliseconds: math.min(ms.toInt(), maxBackoff.inMilliseconds),
    );
  }

  /// Démarre les cycles réguliers (application au premier plan).
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _signedIn = await _api.isSignedIn();
    if (!_started) return;
    _setStatus(_signedIn ? SyncStatus.idle : SyncStatus.signedOut);
    if (_signedIn) unawaited(syncNow());
  }

  /// Arrête les cycles (application en arrière-plan).
  void stop() {
    _started = false;
    _cancelTimer();
  }

  void _cancelTimer() {
    _next?.cancel();
    _next = null;
  }

  void _schedule([Duration? d]) {
    _next?.cancel();
    _next = null;
    if (!_started || !_signedIn) return;
    _next = _timer(d ?? nextDelay, () => unawaited(syncNow()));
  }

  /// Après une pause de lecture : envoi rapide de la progression.
  void syncSoon() {
    if (!_signedIn) return;
    _next?.cancel();
    _next = _timer(pauseDelay, () => unawaited(syncNow()));
  }

  Future<void>? _running;

  /// Un cycle de synchronisation ; ne lève jamais.
  Future<void> syncNow() => _running ??= _cycle().whenComplete(() {
    _running = null;
  });

  Future<void> _cycle() async {
    if (!_signedIn) {
      _signedIn = await _api.isSignedIn();
      if (!_signedIn) {
        _setStatus(SyncStatus.signedOut);
        return;
      }
    }
    _setStatus(SyncStatus.syncing);
    Duration? forced;
    try {
      final before = await _store.lastVersion();
      await _engine.syncOnce();
      var addonsChanged = false;
      final a = addons;
      if (a != null) {
        // Un tirage complet a eu lieu : le blob distant (ou son absence) est
        // connu. Il est déchiffré et appliqué ici, puis renvoyé si besoin.
        await a.markPulled();
        final res = await _processAddons(a);
        addonsChanged = res.changedLocal;
        if (res.needsPush) await _engine.syncOnce();
      }
      _failures = 0;
      _setStatus(SyncStatus.idle);
      if (addonsChanged || await _store.lastVersion() != before) {
        onApplied?.call();
      }
    } on SyncException catch (e) {
      if (e.code == SyncErrorCode.signedOut) {
        _signedIn = false;
        _setStatus(SyncStatus.signedOut);
        return;
      }
      _failures++;
      forced = e.retryAfter;
      _setStatus(SyncStatus.offline);
      debugPrint('Synchronisation reportée (${e.code.name})');
    } on Object catch (e) {
      // Pas de détail : il pourrait contenir une adresse ou un jeton.
      _failures++;
      _setStatus(SyncStatus.offline);
      debugPrint('Synchronisation reportée (${e.runtimeType})');
    }
    final d = forced == null
        ? nextDelay
        : (forced > nextDelay ? forced : nextDelay);
    _schedule(d);
  }

  Future<AddonProcessResult> _processAddons(AddonSync a) async {
    try {
      return await a.process();
    } on Object catch (e) {
      // Pas de détail : il pourrait contenir une adresse.
      debugPrint('Addons non synchronisés (${e.runtimeType})');
      return const AddonProcessResult();
    }
  }

  // --- Compte ------------------------------------------------------------

  Future<void> requestCode(String email) => _api.requestCode(email);

  /// Valide le code, puis envoie tout le contenu local au premier cycle.
  Future<void> signIn(String email, String code) async {
    await _api.verifyCode(email, code);
    _signedIn = true;
    _failures = 0;
    // Le curseur d'un autre compte ne vaut rien ici : tout est retiré du
    // serveur, et tout le contenu local lui est proposé.
    await _store.setLastVersion(0);
    await _store.markAllDirty();
    _setStatus(SyncStatus.idle);
    if (_started) unawaited(syncNow());
  }

  /// Déconnexion : les données locales restent, la file est abandonnée.
  Future<void> signOut() async {
    _cancelTimer();
    // La phrase quitte l'appareil d'abord : même si la suite échoue.
    await addons?.forget();
    await _api.signOut();
    await _store.reset();
    _signedIn = false;
    _failures = 0;
    _setStatus(SyncStatus.signedOut);
  }

  /// Supprime le compte et ses données sur le serveur, puis se déconnecte.
  Future<void> deleteAccount() async {
    _cancelTimer();
    try {
      await _api.deleteAccount();
      await _store.reset();
    } finally {
      await addons?.forget();
    }
    _signedIn = false;
    _failures = 0;
    _setStatus(SyncStatus.signedOut);
  }

  Future<String?> email() => _api.email();

  Future<bool> isSignedIn() => _api.isSignedIn();

  Future<void> dispose() async {
    stop();
    await _statusController.close();
  }
}
