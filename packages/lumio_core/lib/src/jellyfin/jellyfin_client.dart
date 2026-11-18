import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import '../net/http_fetcher.dart';
import '../net/url_guard.dart';

/// Cause d'un échec [JellyfinException].
enum JellyfinErrorCode {
  timeout,
  unreachable,
  serverError,
  refused,
  tooLarge,
  redirect,
  invalidResponse,
  invalidServer,
}

/// Échec réseau ou réponse inexploitable du serveur Jellyfin. Le message est
/// pour les journaux : l'interface affiche un texte traduit selon [code].
class JellyfinException implements Exception {
  const JellyfinException(this.code, {this.status, this.message = ''});

  final JellyfinErrorCode code;
  final int? status;
  final String message;

  @override
  String toString() => 'JellyfinException(${code.name}, $status) $message';
}

/// Identifiants refusés (401/403). [expired] : le jeton d'une session
/// existante n'est plus accepté (et non un mauvais mot de passe).
class JellyfinAuthException implements Exception {
  const JellyfinAuthException({this.expired = false});

  final bool expired;

  @override
  String toString() => 'JellyfinAuthException(expired: $expired)';
}

/// Session obtenue par [JellyfinClient.authenticate].
class JellyfinSession {
  const JellyfinSession({
    required this.token,
    required this.userId,
    this.userName = '',
    this.serverName = '',
  });

  final String token;
  final String userId;
  final String userName;
  final String serverName;
}

/// Bibliothèque du serveur (films, séries…).
class JellyfinView {
  const JellyfinView({
    required this.id,
    required this.name,
    this.collectionType,
  });

  final String id;
  final String name;
  final String? collectionType;
}

/// Élément d'une bibliothèque.
class JellyfinItem {
  const JellyfinItem({
    required this.id,
    required this.name,
    required this.type,
    this.year,
    this.officialRating,
    this.overview,
    this.imageTag,
    this.isFolder = false,
    this.runtimeTicks,
    this.seriesName,
    this.season,
    this.episode,
  });

  final String id;
  final String name;

  /// `Movie`, `Series`, `Season`, `Episode`, `BoxSet`, `Folder`…
  final String type;
  final int? year;

  /// Classification d'âge brute du serveur (`PG-13`, `FSK-12`…).
  final String? officialRating;
  final String? overview;

  /// Étiquette de l'image principale ; `null` : pas d'affiche.
  final String? imageTag;
  final bool isFolder;
  final int? runtimeTicks;
  final String? seriesName;
  final int? season;
  final int? episode;

  /// Vrai si l'élément se lit directement (film, épisode, vidéo).
  bool get playable =>
      !isFolder && (type == 'Movie' || type == 'Episode' || type == 'Video');

  /// Certification pour le filtre d'âge (`ratingAllows`) ; `null` si
  /// absente ou inconnue (alors masqué aux profils enfants).
  String? get certification => jellyfinCertification(officialRating);
}

/// Page d'éléments (pagination `StartIndex` / `Limit`).
class JellyfinPage {
  const JellyfinPage({
    required this.items,
    required this.total,
    required this.skip,
  });

  final List<JellyfinItem> items;

  /// Nombre total d'éléments côté serveur.
  final int total;
  final int skip;

  bool get hasMore => skip + items.length < total && items.isNotEmpty;
}

/// Classification d'âge de Jellyfin vers une certification comprise par
/// `ratingAllows`. Vide, `NR` ou inconnue : `null`.
String? jellyfinCertification(String? raw) {
  if (raw == null) return null;
  final c = raw.trim().toUpperCase();
  if (c.isEmpty) return null;
  // Allemagne : `FSK-12`, `DE-16`, `12`…
  final de = RegExp(r'^(?:FSK|DE)[-: ]?(0|6|12|16|18)$').firstMatch(c);
  if (de != null) {
    return switch (de.group(1)) {
      '0' => 'G',
      '6' => 'PG',
      '12' => 'FR-12',
      '16' => 'FR-16',
      _ => 'FR-18',
    };
  }
  const unrated = {'NR', 'UNRATED', 'NOT RATED', 'N/A', 'NA', '-', 'NONE'};
  if (unrated.contains(c)) return null;
  return c;
}

/// Client Jellyfin minimal : authentification, bibliothèques, éléments et
/// URL de lecture.
///
/// Le jeton n'est jamais placé dans une URL : il part dans l'en-tête
/// `Authorization: MediaBrowser … Token="…"` ([authorization]), y compris pour
/// la lecture ([streamHeaders]). Un certificat invalide lève
/// [CertificateException] et n'est jamais accepté en silence. Aucun jeton ni
/// mot de passe n'apparaît dans les messages d'erreur.
class JellyfinClient {
  JellyfinClient(
    Uri server,
    this._fetcher, {
    required this.deviceId,
    this.deviceName = 'Lumio',
    this.version = '1.0.0',
    this.allowPrivate = false,
    this.token,
    this.userId,
    this.timeout = const Duration(seconds: 15),
  }) : server = normalizeServer(server);

  final Uri server;
  final HttpFetcher _fetcher;

  /// Identifiant d'appareil stable (tiré au hasard une fois, mémorisé).
  final String deviceId;

  /// Nom de plateforme (`Android`, `Windows`…).
  final String deviceName;
  final String version;

  /// Réseau privé accepté : l'adresse saisie par l'utilisateur vaut accord.
  final bool allowPrivate;
  final Duration timeout;

  String? token;
  String? userId;

  /// Serveur sans barre finale, requête, fragment ni identifiants. Lève
  /// [JellyfinException] (`invalidServer`) si l'adresse n'est pas http(s).
  static Uri normalizeServer(Uri u) {
    if ((u.scheme != 'http' && u.scheme != 'https') ||
        u.host.isEmpty ||
        u.userInfo.isNotEmpty) {
      throw const JellyfinException(JellyfinErrorCode.invalidServer);
    }
    var path = u.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return Uri(
      scheme: u.scheme,
      host: u.host.toLowerCase(),
      port: u.hasPort ? u.port : null,
      path: path,
    );
  }

  /// Identifiant court et stable d'un serveur (pour `jellyfin:<hash>:<id>`).
  static String serverHash(Uri server) {
    final n = normalizeServer(server).toString();
    return sha1.convert(utf8.encode(n)).toString().substring(0, 12);
  }

  /// Valeur d'un champ de l'en-tête : guillemets et contrôles retirés.
  static String _field(String v) =>
      v.replaceAll(RegExp(r'["\\\x00-\x1f\x7f]'), '');

  /// En-tête `Authorization` (avec `Token` une fois connecté).
  String get authorization {
    final t = token;
    return 'MediaBrowser Client="Lumio", Device="${_field(deviceName)}", '
        'DeviceId="${_field(deviceId)}", Version="${_field(version)}"'
        '${t == null ? '' : ', Token="${_field(t)}"'}';
  }

  Map<String, String> get _headers => {
    'Authorization': authorization,
    'Accept': 'application/json',
  };

  Uri _uri(String path, [Map<String, String>? query]) => server.replace(
    path: '${server.path}$path',
    queryParameters: query == null || query.isEmpty ? null : query,
  );

  void _guard(Uri u) => UrlGuard.check(u, allowPrivate: allowPrivate);

  /// `POST /Users/AuthenticateByName`. Mémorise le jeton dans le client ;
  /// c'est à l'appelant de le ranger dans le `SecretStore`.
  Future<JellyfinSession> authenticate(String user, String password) async {
    final body = await _send(
      () => _post().post(
        _uri('/Users/AuthenticateByName'),
        body: utf8.encode(jsonEncode({'Username': user, 'Pw': password})),
        headers: {..._headers, 'Content-Type': 'application/json'},
        timeout: timeout,
        guard: _guard,
      ),
      authIsBadCredentials: true,
    );
    final json = _object(body);
    final tok = json['AccessToken'];
    final u = json['User'];
    final id = u is Map ? u['Id'] : null;
    if (tok is! String || tok.isEmpty || id is! String || id.isEmpty) {
      throw const JellyfinException(JellyfinErrorCode.invalidResponse);
    }
    token = tok;
    userId = id;
    return JellyfinSession(
      token: tok,
      userId: id,
      userName: u is Map && u['Name'] is String ? u['Name'] as String : user,
      serverName: json['ServerName'] is String
          ? json['ServerName'] as String
          : '',
    );
  }

  HttpPostFetcher _post() {
    final f = _fetcher;
    if (f is HttpPostFetcher) return f;
    throw UnsupportedError('Le fetcher ne sait pas envoyer de POST');
  }

  String get _user {
    final id = userId;
    if (id == null || token == null) {
      throw const JellyfinAuthException(expired: true);
    }
    return Uri.encodeComponent(id);
  }

  /// `GET /Users/{id}/Views` : bibliothèques de l'utilisateur.
  Future<List<JellyfinView>> views() async {
    final json = _object(await _get('/Users/$_user/Views'));
    return [
      for (final e in _list(json['Items']))
        if (e is Map && e['Id'] is String)
          JellyfinView(
            id: e['Id'] as String,
            name: e['Name'] is String ? e['Name'] as String : e['Id'] as String,
            collectionType: e['CollectionType'] is String
                ? e['CollectionType'] as String
                : null,
          ),
    ];
  }

  /// `GET /Users/{id}/Items?ParentId=…&StartIndex=…&Limit=…` : une page du
  /// contenu direct de [parentId] (jamais tout d'un coup).
  Future<JellyfinPage> items(
    String parentId, {
    int skip = 0,
    int limit = 50,
  }) async {
    final start = skip < 0 ? 0 : skip;
    final lim = limit.clamp(1, 200);
    final json = _object(
      await _get('/Users/$_user/Items', {
        'ParentId': parentId,
        'StartIndex': '$start',
        'Limit': '$lim',
        'SortBy': 'SortName',
        'SortOrder': 'Ascending',
        'Fields': 'OfficialRating,ProductionYear,Overview',
        'EnableImageTypes': 'Primary',
      }),
    );
    final list = [
      for (final e in _list(json['Items']))
        if (e is Map) ?_item(e),
    ];
    final total = json['TotalRecordCount'];
    return JellyfinPage(
      items: list,
      total: total is int ? total : start + list.length,
      skip: start,
    );
  }

  /// `GET /Users/{id}/Items/{itemId}` : un élément.
  Future<JellyfinItem> item(String itemId) async {
    final json = _object(
      await _get('/Users/$_user/Items/${Uri.encodeComponent(itemId)}'),
    );
    final it = _item(json);
    if (it == null) {
      throw const JellyfinException(JellyfinErrorCode.invalidResponse);
    }
    return it;
  }

  /// Termine la session côté serveur (`POST /Sessions/Logout`). Le jeton local
  /// est oublié même si le serveur ne répond pas ; l'appelant supprime
  /// l'exemplaire du `SecretStore`.
  Future<void> logout() async {
    final t = token;
    token = null;
    userId = null;
    if (t == null) return;
    final withToken = {
      ..._headers,
      'Authorization':
          'MediaBrowser Client="Lumio", Device="${_field(deviceName)}", '
          'DeviceId="${_field(deviceId)}", Version="${_field(version)}", '
          'Token="${_field(t)}"',
    };
    try {
      await _send(
        () => _post().post(
          _uri('/Sessions/Logout'),
          body: const [],
          headers: withToken,
          timeout: timeout,
          guard: _guard,
        ),
      );
    } on Object {
      // Meilleur effort : la session locale est déjà fermée.
    }
  }

  /// URL du flux d'un élément. Sans jeton : à passer avec [streamHeaders] au
  /// proxy local du lecteur, qui impose l'en-tête.
  Uri streamUrl(String itemId) => _uri(
    '/Videos/${Uri.encodeComponent(itemId)}/stream',
    {'static': 'true', 'mediaSourceId': itemId},
  );

  /// En-têtes à imposer à la lecture (jeton dans `Authorization`).
  Map<String, String> streamHeaders() => {'Authorization': authorization};

  /// URL de l'affiche (image publique côté Jellyfin, sans jeton).
  Uri imageUrl(String itemId, {String? tag, int maxHeight = 450}) => _uri(
    '/Items/${Uri.encodeComponent(itemId)}/Images/Primary',
    {'maxHeight': '$maxHeight', 'quality': '90', 'tag': ?tag},
  );

  // --- interne ---

  Future<List<int>> _get(String path, [Map<String, String>? query]) => _send(
    () => _fetcher.get(
      _uri(path, query),
      headers: _headers,
      timeout: timeout,
      guard: _guard,
    ),
  );

  Future<List<int>> _send(
    Future<FetchResponse> Function() call, {
    bool authIsBadCredentials = false,
  }) async {
    final FetchResponse res;
    try {
      res = await call();
    } on UnsafeUrlException {
      rethrow;
    } on HandshakeException catch (e) {
      throw CertificateException('Certificat refusé', e.osError);
    } on TlsException catch (e) {
      throw CertificateException('Connexion sécurisée impossible', e.osError);
    } on TimeoutException {
      throw const JellyfinException(JellyfinErrorCode.timeout);
    } on ResponseTooLargeException {
      throw const JellyfinException(JellyfinErrorCode.tooLarge);
    } on InsecureRedirectException {
      throw const JellyfinException(JellyfinErrorCode.redirect);
    } on InvalidRedirectException {
      throw const JellyfinException(JellyfinErrorCode.redirect);
    } on TooManyRedirectsException {
      throw const JellyfinException(JellyfinErrorCode.redirect);
    } on SocketException {
      throw const JellyfinException(JellyfinErrorCode.unreachable);
    } on HttpException {
      throw const JellyfinException(JellyfinErrorCode.unreachable);
    }
    final s = res.status;
    if (s == 401 || s == 403) {
      throw JellyfinAuthException(expired: !authIsBadCredentials);
    }
    if (s >= 300 && s < 400) {
      throw JellyfinException(JellyfinErrorCode.redirect, status: s);
    }
    if (s >= 500) {
      throw JellyfinException(JellyfinErrorCode.serverError, status: s);
    }
    if (s < 200 || s >= 300) {
      throw JellyfinException(JellyfinErrorCode.refused, status: s);
    }
    return res.body;
  }

  static Map<String, Object?> _object(List<int> body) {
    try {
      final v = jsonDecode(utf8.decode(body));
      if (v is Map) return v.cast<String, Object?>();
    } on FormatException {
      // tombe sur l'erreur ci-dessous
    }
    throw const JellyfinException(JellyfinErrorCode.invalidResponse);
  }

  static List<Object?> _list(Object? v) => v is List ? v : const [];

  static JellyfinItem? _item(Map<dynamic, dynamic> e) {
    final id = e['Id'];
    if (id is! String || id.isEmpty) return null;
    final tags = e['ImageTags'];
    final tag = tags is Map && tags['Primary'] is String
        ? tags['Primary'] as String
        : null;
    String? str(Object? v) => v is String && v.isNotEmpty ? v : null;
    return JellyfinItem(
      id: id,
      name: str(e['Name']) ?? id,
      type: str(e['Type']) ?? 'Video',
      year: e['ProductionYear'] is int ? e['ProductionYear'] as int : null,
      officialRating: str(e['OfficialRating']),
      overview: str(e['Overview']),
      imageTag: tag,
      isFolder: e['IsFolder'] == true,
      runtimeTicks: e['RunTimeTicks'] is int ? e['RunTimeTicks'] as int : null,
      seriesName: str(e['SeriesName']),
      season: e['ParentIndexNumber'] is int
          ? e['ParentIndexNumber'] as int
          : null,
      episode: e['IndexNumber'] is int ? e['IndexNumber'] as int : null,
    );
  }
}
