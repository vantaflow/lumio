import 'dart:async';
import 'dart:convert';
import 'dart:io';

enum PartyErrorCode {
  /// Serveur injoignable ou réponse invalide.
  unavailable,

  /// Lien ou code mal formé.
  invalidLink,

  /// Code d'invitation refusé.
  wrongCode,

  /// Salle pleine (8 participants).
  full,

  /// Salle inconnue, expirée ou fermée.
  notFound,
  rateLimited,
}

class PartyException implements Exception {
  const PartyException(this.code);
  final PartyErrorCode code;

  @override
  String toString() => 'PartyException: ${code.name}';
}

/// Salle créée : [inviteCode] n'est montré qu'à l'hôte, qui le transmet.
/// [hostKey] reste sur l'appareil de l'hôte (il prouve qu'il a créé la salle) :
/// il n'est jamais mis dans le lien d'invitation.
class PartyRoomInfo {
  const PartyRoomInfo({
    required this.roomId,
    required this.inviteCode,
    required this.hostKey,
    required this.expiresAt,
  });

  final String roomId;
  final String inviteCode;
  final String hostKey;
  final DateTime expiresAt;

  Uri get link => partyLink(roomId, inviteCode);
}

/// Lien d'invitation, reconnu uniquement dans l'application (aucun schéma
/// d'URL n'est enregistré auprès du système) : il contient la salle et le code,
/// jamais la clé de l'hôte ni un titre.
Uri partyLink(String roomId, String code) => Uri(
  scheme: 'lumio',
  host: 'party',
  queryParameters: {'room': roomId, 'code': code},
);

/// Extrait (salle, code) d'un texte collé ou scanné ; `null` s'il n'y a pas de
/// lien valide.
({String roomId, String code})? parsePartyLink(String text) {
  final m = RegExp(
    r'lumio://party\?\S+',
    caseSensitive: false,
  ).firstMatch(text);
  if (m == null) return null;
  final u = Uri.tryParse(m.group(0)!);
  final room = u?.queryParameters['room']?.toLowerCase();
  final code = u?.queryParameters['code']?.toUpperCase();
  if (room == null || code == null) return null;
  if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(room)) return null;
  if (!RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$').hasMatch(code)) {
    return null;
  }
  return (roomId: room, code: code);
}

/// Canal bidirectionnel de textes avec la salle ; substituable en test.
abstract class PartyChannel {
  Stream<String> get messages;
  void send(String message);
  Future<void> close();
}

/// Ouvre un canal ; [protocols] porte la clé de l'hôte (jamais dans l'URL).
typedef PartyConnector =
    Future<PartyChannel> Function(Uri url, List<String> protocols);

class IoPartyChannel implements PartyChannel {
  IoPartyChannel(this._ws);
  final WebSocket _ws;

  @override
  Stream<String> get messages => _ws.where((e) => e is String).cast<String>();

  @override
  void send(String message) => _ws.add(message);

  @override
  Future<void> close() => _ws.close(WebSocketStatus.normalClosure);
}

Future<PartyChannel> ioPartyConnector(Uri url, List<String> protocols) async {
  final ws = await WebSocket.connect(
    url.toString(),
    protocols: protocols,
  ).timeout(const Duration(seconds: 10));
  return IoPartyChannel(ws);
}

/// Réponse HTTP minimale (statut et corps texte).
class PartyHttpResponse {
  const PartyHttpResponse(this.status, this.body);
  final int status;
  final String body;
}

/// Transport HTTP du client des salles ; substituable en test.
abstract class PartyHttp {
  Future<PartyHttpResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers,
    String? body,
  });
}

class IoPartyHttp implements PartyHttp {
  const IoPartyHttp({this.timeout = const Duration(seconds: 15)});
  final Duration timeout;

  static const _maxBytes = 64 * 1024;

  @override
  Future<PartyHttpResponse> send(
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
          if (bytes.length > _maxBytes) {
            throw const PartyException(PartyErrorCode.unavailable);
          }
        }
        return PartyHttpResponse(
          res.statusCode,
          utf8.decode(bytes, allowMalformed: true),
        );
      }().timeout(timeout);
    } finally {
      client.close(force: true);
    }
  }
}

/// Client des salles de watch-party : création (HTTP) et connexion WebSocket.
/// Aucun compte : une salle est protégée par son identifiant aléatoire et son
/// code d'invitation. Seuls position et état de lecture y circulent.
class PartyClient {
  PartyClient._(this._base, this._http, this._connector);

  /// [serverUrl] : https obligatoire, sauf http vers localhost (développement).
  factory PartyClient(
    String serverUrl, {
    PartyHttp? http,
    PartyConnector? connector,
  }) {
    final u = Uri.tryParse(serverUrl.trim());
    final local =
        u != null &&
        (u.host == 'localhost' || u.host == '127.0.0.1' || u.host == '::1');
    if (u == null ||
        !u.hasAuthority ||
        !(u.scheme == 'https' || (u.scheme == 'http' && local))) {
      throw const PartyException(PartyErrorCode.unavailable);
    }
    return PartyClient._(
      u,
      http ?? const IoPartyHttp(),
      connector ?? ioPartyConnector,
    );
  }

  final Uri _base;
  final PartyHttp _http;
  final PartyConnector _connector;

  Uri _url(String path) =>
      _base.replace(path: '${_base.path.replaceAll(RegExp(r'/+$'), '')}$path');

  Future<PartyHttpResponse> _send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    String? body,
  }) async {
    try {
      return await _http.send(method, url, headers: headers, body: body);
    } on PartyException {
      rethrow;
    } on Object {
      throw const PartyException(PartyErrorCode.unavailable);
    }
  }

  Future<PartyRoomInfo> create({String? metaId, String? type}) async {
    final r = await _send(
      'POST',
      _url('/rooms'),
      body: jsonEncode({'metaId': ?metaId, 'type': ?type}),
    );
    if (r.status == 429) throw const PartyException(PartyErrorCode.rateLimited);
    if (r.status != 201) throw const PartyException(PartyErrorCode.unavailable);
    try {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return PartyRoomInfo(
        roomId: j['roomId'] as String,
        inviteCode: j['inviteCode'] as String,
        hostKey: j['hostKey'] as String,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          (j['expiresAt'] as num).toInt(),
        ),
      );
    } on Object {
      throw const PartyException(PartyErrorCode.unavailable);
    }
  }

  /// « L'hôte seul contrôle » ou « Tout le monde peut contrôler » ; réservé à
  /// l'hôte ([hostKey]).
  Future<void> setControl(
    String roomId, {
    required String hostKey,
    required bool allControl,
  }) async {
    final r = await _send(
      'POST',
      _url('/room/$roomId/control'),
      headers: {'authorization': 'Bearer $hostKey'},
      body: jsonEncode({'allControl': allControl}),
    );
    if (r.status == 204) return;
    throw PartyException(switch (r.status) {
      404 => PartyErrorCode.notFound,
      429 => PartyErrorCode.rateLimited,
      _ => PartyErrorCode.unavailable,
    });
  }

  /// Rejoint la salle avec son code. L'hôte ajoute sa [hostKey] dans l'en-tête
  /// de sous-protocole (jamais dans l'URL).
  Future<PartyChannel> connect(
    String roomId,
    String code, {
    String? hostKey,
  }) async {
    final base = _url('/room/$roomId');
    final url = base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      queryParameters: {'code': code},
    );
    try {
      return await _connector(url, ['lumio.v1', ?hostKey]);
    } on WebSocketException catch (e) {
      final status = int.tryParse(
        RegExp(r'status code: (\d+)').firstMatch(e.message)?.group(1) ?? '',
      );
      throw PartyException(switch (status) {
        403 => PartyErrorCode.wrongCode,
        404 => PartyErrorCode.notFound,
        409 => PartyErrorCode.full,
        429 => PartyErrorCode.rateLimited,
        _ => PartyErrorCode.unavailable,
      });
    } on PartyException {
      rethrow;
    } on Object {
      throw const PartyException(PartyErrorCode.unavailable);
    }
  }
}
