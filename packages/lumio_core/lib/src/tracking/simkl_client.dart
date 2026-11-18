import 'dart:async';
import 'dart:convert';

import '../net/http_fetcher.dart';
import '../net/url_guard.dart';
import 'tracker.dart';

/// Client Simkl : code PIN d'appareil (`/oauth/pin`) et historique
/// (`/sync/history`).
///
/// Simkl n'a pas de scrobbling en direct : seul un `stop` à 80 % ou plus
/// ([watchedThreshold]) est envoyé, comme « vu » ; `start` et `pause` sont
/// ignorés ([wants]). Le jeton n'expire pas (pas de renouvellement) : un 401
/// signifie qu'il est révoqué ([TrackerReauthRequired]).
///
/// Sans [clientId] ([TrackerNotConfigured]) rien n'est envoyé. Le client ne
/// journalise rien : ni jeton, ni code PIN.
class SimklClient implements Tracker {
  SimklClient(
    this._fetcher, {
    required this.clientId,
    TrackerToken? token,
    Uri? baseUrl,
    DateTime Function()? now,
    this.allowPrivate = false,
  }) : _token = token,
       _base = baseUrl ?? Uri.parse('https://api.simkl.com'),
       _now = now ?? DateTime.now;

  /// Avancement (en %) à partir duquel un `stop` compte comme « vu ».
  static const watchedThreshold = 80.0;

  final HttpPostFetcher _fetcher;
  final String clientId;
  final Uri _base;
  final DateTime Function() _now;

  /// Autorise une adresse de réseau privé (tests locaux uniquement) ; sinon
  /// toute requête vers un hôte local ou privé est refusée.
  final bool allowPrivate;

  final TrackerToken? _token;

  TrackerToken? get token => _token;

  bool get configured => clientId.isNotEmpty;

  /// Cet événement donne-t-il lieu à un envoi ? (`stop` à 80 % ou plus.)
  /// Sert aussi à ne pas mettre en file les événements inutiles.
  static bool wants(ScrobbleEvent e) =>
      e.action == ScrobbleAction.stop && e.progress >= watchedThreshold;

  void _requireConfigured() {
    if (!configured) throw const TrackerNotConfigured();
  }

  Map<String, String> _headers({String? bearer}) => {
    'content-type': 'application/json',
    'simkl-api-key': clientId,
    if (bearer != null) 'authorization': 'Bearer $bearer',
  };

  Uri _url(String path, [Map<String, String>? query]) =>
      _base.replace(path: path, queryParameters: query);

  void _guard(Uri url) {
    try {
      UrlGuard.check(url, allowPrivate: allowPrivate);
    } on UnsafeUrlException {
      throw const TrackerRejected(0); // adresse refusée : rien n'est envoyé
    }
  }

  Future<FetchResponse> _get(Uri url) async {
    _guard(url);
    try {
      return await _fetcher.get(
        url,
        guard: (u) => UrlGuard.check(u, allowPrivate: allowPrivate),
        headers: _headers(),
        maxBytes: 256 * 1024,
        timeout: const Duration(seconds: 10),
      );
    } on TrackerException {
      rethrow;
    } on Object {
      throw const TrackerUnavailable();
    }
  }

  Future<FetchResponse> _post(
    String path,
    Map<String, Object?> body, {
    required String bearer,
  }) async {
    final url = _url(path);
    _guard(url);
    try {
      return await _fetcher.post(
        url,
        guard: (u) => UrlGuard.check(u, allowPrivate: allowPrivate),
        body: utf8.encode(jsonEncode(body)),
        headers: _headers(bearer: bearer),
        maxBytes: 256 * 1024,
        timeout: const Duration(seconds: 10),
      );
    } on TrackerException {
      rethrow;
    } on Object {
      throw const TrackerUnavailable();
    }
  }

  Map<String, dynamic> _json(FetchResponse r) {
    try {
      final v = jsonDecode(utf8.decode(r.body, allowMalformed: true));
      if (v is Map<String, dynamic>) return v;
    } on FormatException {
      // Réponse illisible.
    }
    throw TrackerUnavailable(r.status);
  }

  /// 4xx : refus définitif ; le reste : panne passagère.
  TrackerException _failure(int status) =>
      status >= 400 && status < 500 && status != 408 && status != 429
      ? TrackerRejected(status)
      : TrackerUnavailable(status);

  @override
  Future<DeviceCode> startDeviceAuth() async {
    _requireConfigured();
    final r = await _get(_url('/oauth/pin', {'client_id': clientId}));
    if (r.status != 200) throw _failure(r.status);
    final j = _json(r);
    try {
      final userCode = j['user_code'] as String;
      return DeviceCode(
        // Simkl interroge avec le code utilisateur lui-même.
        deviceCode: userCode,
        userCode: userCode,
        verificationUrl: Uri.parse(j['verification_url'] as String),
        expiresIn: Duration(seconds: (j['expires_in'] as num).toInt()),
        interval: Duration(seconds: (j['interval'] as num).toInt()),
      );
    } on Object {
      throw TrackerUnavailable(r.status);
    }
  }

  @override
  Future<TrackerToken?> pollToken(DeviceCode c) async {
    _requireConfigured();
    final r = await _get(
      _url('/oauth/pin/${Uri.encodeComponent(c.userCode)}', {
        'client_id': clientId,
      }),
    );
    switch (r.status) {
      case 200:
        final j = _json(r);
        if (j['result'] != 'OK') return null; // en attente
        final access = j['access_token'];
        if (access is! String || access.isEmpty) {
          throw TrackerUnavailable(r.status);
        }
        // Le jeton Simkl n'expire pas : échéance lointaine.
        return TrackerToken(
          access: access,
          refresh: '',
          expiresAt: _now().toUtc().add(const Duration(days: 36500)),
        );
      case 404 || 410:
        throw const TrackerAuthExpired();
      case 429:
        throw const TrackerSlowDown();
      default:
        throw _failure(r.status);
    }
  }

  @override
  Future<void> scrobble(ScrobbleEvent e) async {
    _requireConfigured();
    if (!wants(e)) return; // pas de lecture en direct sur Simkl
    final t = _token;
    if (t == null) throw const TrackerReauthRequired();
    final when = e.at.toUtc().toIso8601String();
    final ids = {'imdb': e.imdbId};
    final body = e.isEpisode
        ? {
            'shows': [
              {
                'ids': ids,
                'seasons': [
                  {
                    'number': e.season,
                    'episodes': [
                      {'number': e.episode, 'watched_at': when},
                    ],
                  },
                ],
              },
            ],
          }
        : {
            'movies': [
              {'ids': ids, 'watched_at': when},
            ],
          };
    final r = await _post('/sync/history', body, bearer: t.access);
    if (r.status == 401) throw const TrackerReauthRequired();
    if (r.status == 200 || r.status == 201) return;
    throw _failure(r.status);
  }
}
