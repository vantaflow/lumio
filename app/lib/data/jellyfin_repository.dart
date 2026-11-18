import 'dart:convert';
import 'dart:math';

import 'package:lumio/data/secret_store.dart';
import 'package:lumio_core/lumio_core.dart';

/// Source des éléments Jellyfin dans les aperçus (`MetaPreview.sourceKind`).
const jellyfinSourceKind = 'jellyfin';

/// Préfixe des identifiants de titres Jellyfin : `jellyfin:<serveur>:<id>`.
const jellyfinIdPrefix = 'jellyfin:';

bool isJellyfinId(String id) => id.startsWith(jellyfinIdPrefix);

String jellyfinItemId(String serverId, String itemId) =>
    '$jellyfinIdPrefix$serverId:$itemId';

/// (serveur, élément) d'un identifiant `jellyfin:<serveur>:<id>`, ou `null`.
({String serverId, String itemId})? parseJellyfinId(String id) {
  if (!isJellyfinId(id)) return null;
  final rest = id.substring(jellyfinIdPrefix.length);
  final i = rest.indexOf(':');
  if (i <= 0 || i == rest.length - 1) return null;
  return (serverId: rest.substring(0, i), itemId: rest.substring(i + 1));
}

/// Adresse saisie en http sur Internet : le mot de passe circulerait en clair.
/// L'appelant doit avoir obtenu la confirmation de l'utilisateur
/// (`confirmedInsecure: true`).
class JellyfinInsecureException implements Exception {
  const JellyfinInsecureException();

  @override
  String toString() => 'JellyfinInsecureException';
}

/// Serveur Jellyfin enregistré. Le jeton n'y figure pas (voir
/// [JellyfinRepository.client]).
class JellyfinServer {
  const JellyfinServer({
    required this.id,
    required this.name,
    required this.url,
    required this.allowPrivate,
    required this.userId,
    required this.userName,
  });

  /// Empreinte courte de l'adresse ([JellyfinClient.serverHash]).
  final String id;
  final String name;

  /// Adresse du serveur : traitée comme un secret, jamais journalisée.
  final Uri url;

  /// Réseau privé accepté : l'utilisateur a saisi lui-même l'adresse.
  final bool allowPrivate;
  final String userId;
  final String userName;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'url': url.toString(),
    'allowPrivate': allowPrivate,
    'userId': userId,
    'userName': userName,
  };

  static JellyfinServer? tryParse(Object? j) {
    if (j is! Map) return null;
    final url = j['url'] is String ? Uri.tryParse(j['url'] as String) : null;
    final id = j['id'];
    final userId = j['userId'];
    if (url == null || id is! String || userId is! String) return null;
    return JellyfinServer(
      id: id,
      name: j['name'] is String ? j['name'] as String : url.host,
      url: url,
      allowPrivate: j['allowPrivate'] == true,
      userId: userId,
      userName: j['userName'] is String ? j['userName'] as String : '',
    );
  }
}

/// Vrai si l'adresse désigne l'appareil ou un réseau privé.
bool isPrivateServer(Uri u) {
  try {
    UrlGuard.check(u);
    return false;
  } on UnsafeUrlException catch (e) {
    return e.code == UnsafeUrlReason.privateAddress;
  }
}

/// Serveurs Jellyfin de l'utilisateur. Liste, jetons et identifiant d'appareil
/// vivent dans le [SecretStore] : rien en clair dans SQLite ni en journal.
class JellyfinRepository {
  JellyfinRepository(
    this._store,
    this._fetcher, {
    this.version = '',
    this.platform = 'Android',
  });

  final SecretStore _store;
  final HttpFetcher _fetcher;
  final String version;
  final String platform;

  static const _serversKey = 'jellyfin.servers';
  static const _deviceKey = 'jellyfin.deviceId';
  static String _tokenKey(String serverId) => 'jellyfin.token.$serverId';

  Future<List<JellyfinServer>> list() async {
    final raw = await _store.read(_serversKey);
    if (raw == null) return const [];
    try {
      final j = jsonDecode(raw);
      if (j is! List) return const [];
      return [for (final e in j) ?JellyfinServer.tryParse(e)];
    } on FormatException {
      return const [];
    }
  }

  Future<void> _save(List<JellyfinServer> servers) => _store.write(
    _serversKey,
    jsonEncode([for (final s in servers) s.toJson()]),
  );

  /// Identifiant d'appareil aléatoire, tiré une fois puis mémorisé.
  Future<String> deviceId() async {
    final known = await _store.read(_deviceKey);
    if (known != null && known.isNotEmpty) return known;
    final rnd = Random.secure();
    final id = [
      for (var i = 0; i < 16; i++)
        rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    await _store.write(_deviceKey, id);
    return id;
  }

  JellyfinClient _make(JellyfinServer s, String deviceId, {String? token}) =>
      JellyfinClient(
        s.url,
        _fetcher,
        deviceId: deviceId,
        deviceName: platform,
        version: version.isEmpty ? '1.0.0' : version,
        allowPrivate: s.allowPrivate,
        token: token,
        userId: s.userId,
      );

  /// Client connecté du serveur [serverId], `null` s'il est inconnu ou sans
  /// jeton (déconnecté).
  Future<JellyfinClient?> client(String serverId) async {
    final server = (await list()).where((s) => s.id == serverId).firstOrNull;
    if (server == null) return null;
    final token = await _store.read(_tokenKey(serverId));
    if (token == null || token.isEmpty) return null;
    return _make(server, await deviceId(), token: token);
  }

  /// Serveur enregistré d'identifiant [serverId].
  Future<JellyfinServer?> server(String serverId) async =>
      (await list()).where((s) => s.id == serverId).firstOrNull;

  /// Se connecte puis enregistre le serveur et le jeton. L'adresse saisie
  /// par l'utilisateur vaut accord pour le réseau privé. Une adresse http
  /// publique exige [confirmedInsecure] (mot de passe en clair). Reconnecter
  /// un serveur déjà connu remplace sa session.
  Future<JellyfinServer> addServer(
    Uri input,
    String user,
    String password, {
    bool confirmedInsecure = false,
  }) async {
    final url = JellyfinClient.normalizeServer(input);
    final priv = isPrivateServer(url);
    if (url.scheme == 'http' && !priv && !confirmedInsecure) {
      throw const JellyfinInsecureException();
    }
    final id = JellyfinClient.serverHash(url);
    final draft = JellyfinServer(
      id: id,
      name: url.host,
      url: url,
      allowPrivate: priv,
      userId: '',
      userName: user,
    );
    final c = _make(draft, await deviceId());
    final session = await c.authenticate(user, password);
    final server = JellyfinServer(
      id: id,
      name: session.serverName.isEmpty ? url.host : session.serverName,
      url: url,
      allowPrivate: priv,
      userId: session.userId,
      userName: session.userName,
    );
    await _store.write(_tokenKey(id), session.token);
    final others = [
      for (final s in await list())
        if (s.id != id) s,
    ];
    await _save([...others, server]);
    return server;
  }

  /// Déconnecte (meilleur effort côté serveur) puis oublie le serveur et son
  /// jeton, quoi qu'il arrive.
  Future<void> remove(String serverId) async {
    try {
      await (await client(serverId))?.logout();
    } on Object {
      // Serveur injoignable : on oublie quand même le jeton ci-dessous.
    }
    await _store.delete(_tokenKey(serverId));
    await _save([
      for (final s in await list())
        if (s.id != serverId) s,
    ]);
  }

  /// Aperçu d'un élément pour l'accueil et la progression.
  MetaPreview preview(
    JellyfinServer server,
    JellyfinClient client,
    JellyfinItem it,
  ) => MetaPreview(
    id: jellyfinItemId(server.id, it.id),
    type: it.playable ? 'movie' : 'series',
    name: it.name,
    poster: it.imageTag == null
        ? null
        : client.imageUrl(it.id, tag: it.imageTag),
    releaseInfo: it.year?.toString(),
    certification: it.certification,
    sourceAddonId: server.id,
    sourceKind: jellyfinSourceKind,
  );
}
