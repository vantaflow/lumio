import 'dart:async';
import 'dart:convert';

import '../net/http_fetcher.dart';
import '../net/url_guard.dart';
import 'tracker.dart';

/// Client Trakt : autorisation d'appareil, renouvellement du jeton et
/// scrobbling (`/scrobble/start|pause|stop`).
///
/// Sans [clientId] ou [clientSecret] ([TrackerNotConfigured]) rien n'est
/// envoyé. Le client ne journalise rien : ni jeton, ni code d'appareil.
class TraktClient implements Tracker {
  TraktClient(
    this._fetcher, {
    required this.clientId,
    required this.clientSecret,
    TrackerToken? token,
    this.onToken,
    Uri? baseUrl,
    DateTime Function()? now,
    this.refreshMargin = const Duration(hours: 1),
    this.allowPrivate = false,
  }) : _token = token,
       _base = baseUrl ?? Uri.parse('https://api.trakt.tv'),
       _now = now ?? DateTime.now;

  final HttpPostFetcher _fetcher;
  final String clientId;
  final String clientSecret;
  final Uri _base;
  final DateTime Function() _now;

  /// Renouvelle le jeton s'il expire dans moins de [refreshMargin].
  final Duration refreshMargin;

  /// Autorise une adresse de réseau privé (tests locaux uniquement) ; sinon
  /// toute requête vers un hôte local ou privé est refusée.
  final bool allowPrivate;

  /// Appelé avec le nouveau jeton après un renouvellement (à persister) ; avec
  /// `null` quand le renouvellement est refusé (jeton à oublier).
  final Future<void> Function(TrackerToken? token)? onToken;

  TrackerToken? _token;
  Future<TrackerToken>? _refreshing;

  TrackerToken? get token => _token;

  bool get configured => clientId.isNotEmpty && clientSecret.isNotEmpty;

  void _requireConfigured() {
    if (!configured) throw const TrackerNotConfigured();
  }

  Map<String, String> get _headers => {
    'content-type': 'application/json',
    'trakt-api-version': '2',
    'trakt-api-key': clientId,
  };

  Future<FetchResponse> _post(
    String path,
    Map<String, Object?> body, {
    String? bearer,
  }) async {
    final url = _base.replace(path: path);
    try {
      UrlGuard.check(url, allowPrivate: allowPrivate);
    } on UnsafeUrlException {
      throw const TrackerRejected(0); // adresse refusée : rien n'est envoyé
    }
    try {
      return await _fetcher.post(
        url,
        guard: (u) => UrlGuard.check(u, allowPrivate: allowPrivate),
        body: utf8.encode(jsonEncode(body)),
        headers: {
          ..._headers,
          if (bearer != null) 'authorization': 'Bearer $bearer',
        },
        maxBytes: 256 * 1024,
        timeout: const Duration(seconds: 10),
      );
    } on TrackerException {
      rethrow;
    } on Object {
      // Réseau, délai, TLS, redirection : le service est injoignable.
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

  @override
  Future<DeviceCode> startDeviceAuth() async {
    _requireConfigured();
    final r = await _post('/oauth/device/code', {'client_id': clientId});
    if (r.status != 200) throw _failure(r.status);
    final j = _json(r);
    try {
      return DeviceCode(
        deviceCode: j['device_code'] as String,
        userCode: j['user_code'] as String,
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
    final r = await _post('/oauth/device/token', {
      'code': c.deviceCode,
      'client_id': clientId,
      'client_secret': clientSecret,
    });
    switch (r.status) {
      case 200:
        return _tokenFrom(_json(r), r.status);
      case 400:
        return null; // en attente
      case 404 || 409 || 410:
        throw const TrackerAuthExpired();
      case 418:
        throw const TrackerAuthDenied();
      case 429:
        throw const TrackerSlowDown();
      default:
        throw _failure(r.status);
    }
  }

  TrackerToken _tokenFrom(Map<String, dynamic> j, int status) {
    try {
      final created = j['created_at'] is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (j['created_at'] as num).toInt() * 1000,
              isUtc: true,
            )
          : _now().toUtc();
      return TrackerToken(
        access: j['access_token'] as String,
        refresh: j['refresh_token'] as String,
        expiresAt: created.add(
          Duration(seconds: (j['expires_in'] as num).toInt()),
        ),
      );
    } on Object {
      throw TrackerUnavailable(status);
    }
  }

  /// 4xx : refus définitif ; le reste : panne passagère.
  TrackerException _failure(int status) =>
      status >= 400 && status < 500 && status != 408 && status != 429
      ? TrackerRejected(status)
      : TrackerUnavailable(status);

  /// Renouvelle le jeton (une seule requête même si plusieurs appelants).
  Future<TrackerToken> _refresh() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<TrackerToken> _doRefresh() async {
    final old = _token;
    if (old == null || old.refresh.isEmpty) {
      throw const TrackerReauthRequired();
    }
    final r = await _post('/oauth/token', {
      'refresh_token': old.refresh,
      'client_id': clientId,
      'client_secret': clientSecret,
      'redirect_uri': 'urn:ietf:wg:oauth:2.0:oob',
      'grant_type': 'refresh_token',
    });
    if (r.status == 200) {
      final t = _tokenFrom(_json(r), r.status);
      _token = t;
      await onToken?.call(t);
      return t;
    }
    if (r.status == 400 || r.status == 401 || r.status == 403) {
      _token = null;
      await onToken?.call(null);
      throw const TrackerReauthRequired();
    }
    throw _failure(r.status);
  }

  @override
  Future<void> scrobble(ScrobbleEvent e) async {
    _requireConfigured();
    var t = _token;
    if (t == null) throw const TrackerReauthRequired();
    if (t.expiresWithin(refreshMargin, _now())) t = await _refresh();
    var r = await _send(e, t);
    if (r.status == 401) {
      // Un autre appel a déjà renouvelé le jeton : inutile de recommencer.
      final current = _token;
      if (current == null) throw const TrackerReauthRequired();
      t = identical(current, t) ? await _refresh() : current;
      r = await _send(e, t);
      if (r.status == 401) throw const TrackerReauthRequired();
    }
    // 409 : même lecture déjà signalée récemment, rien à refaire.
    if (r.status == 200 || r.status == 201 || r.status == 409) return;
    throw _failure(r.status);
  }

  Future<FetchResponse> _send(ScrobbleEvent e, TrackerToken t) =>
      _post('/scrobble/${e.action.name}', {
        if (e.isEpisode) ...{
          'show': {
            'ids': {'imdb': e.imdbId},
          },
          'episode': {'season': e.season, 'number': e.episode},
        } else
          'movie': {
            'ids': {'imdb': e.imdbId},
          },
        'progress': e.progress,
      }, bearer: t.access);

  /// Révoque le jeton (déconnexion) ; meilleur effort, sans exception.
  Future<void> revoke() async {
    final t = _token;
    if (t == null || !configured) return;
    try {
      await _post('/oauth/revoke', {
        'token': t.access,
        'client_id': clientId,
        'client_secret': clientSecret,
      });
    } on Object {
      // La déconnexion locale suffit.
    }
    _token = null;
  }
}
