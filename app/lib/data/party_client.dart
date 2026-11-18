import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lumio/data/sync_service.dart';

enum PartyErrorCode {
  /// Serveur injoignable ou réponse invalide.
  unavailable,

  /// Pas connecté (ou session non renouvelable).
  signedOut,

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
class PartyRoomInfo {
  const PartyRoomInfo({
    required this.roomId,
    required this.inviteCode,
    required this.expiresAt,
  });

  final String roomId;
  final String inviteCode;
  final DateTime expiresAt;

  Uri get link => partyLink(roomId, inviteCode);
}

/// Lien d'invitation, reconnu uniquement dans l'application (aucun schéma
/// d'URL n'est enregistré auprès du système) : il contient la salle et le code,
/// jamais le jeton de session ni un titre.
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

/// Ouvre un canal ; [protocols] porte le jeton (jamais dans l'URL).
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

/// Client des salles de watch-party : création (HTTP authentifié) et
/// connexion WebSocket. Seuls position et état de lecture y circulent.
class PartyClient {
  PartyClient(this._api, {PartyConnector? connector})
    : _connector = connector ?? ioPartyConnector;

  final SyncApiClient _api;
  final PartyConnector _connector;

  Future<PartyRoomInfo> create({String? metaId, String? type}) async {
    final SyncHttpResponse r;
    try {
      r = await _api.authedRequest(
        'POST',
        _api.urlFor('/rooms'),
        body: jsonEncode({'metaId': ?metaId, 'type': ?type}),
      );
    } on SyncException catch (e) {
      throw _fromSync(e);
    }
    if (r.status == 429) throw const PartyException(PartyErrorCode.rateLimited);
    if (r.status != 201) throw const PartyException(PartyErrorCode.unavailable);
    try {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return PartyRoomInfo(
        roomId: j['roomId'] as String,
        inviteCode: j['inviteCode'] as String,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          (j['expiresAt'] as num).toInt(),
        ),
      );
    } on Object {
      throw const PartyException(PartyErrorCode.unavailable);
    }
  }

  /// « L'hôte seul contrôle » ou « Tout le monde peut contrôler ».
  Future<void> setControl(String roomId, {required bool allControl}) async {
    final SyncHttpResponse r;
    try {
      r = await _api.authedRequest(
        'POST',
        _api.urlFor('/room/$roomId/control'),
        body: jsonEncode({'allControl': allControl}),
      );
    } on SyncException catch (e) {
      throw _fromSync(e);
    }
    if (r.status == 204) return;
    throw PartyException(
      r.status == 404 ? PartyErrorCode.notFound : PartyErrorCode.unavailable,
    );
  }

  /// Rejoint la salle. Le code part dans l'URL (il ne donne rien sans session
  /// valide), le jeton de session dans l'en-tête de sous-protocole.
  Future<PartyChannel> connect(String roomId, String code) async {
    final base = _api.urlFor('/room/$roomId');
    final url = base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      queryParameters: {'code': code},
    );
    for (var attempt = 0; attempt < 2; attempt++) {
      final String token;
      try {
        token = await _api.freshSession(forceRefresh: attempt > 0);
      } on SyncException catch (e) {
        throw _fromSync(e);
      }
      try {
        return await _connector(url, ['lumio.v1', token]);
      } on WebSocketException catch (e) {
        final status = int.tryParse(
          RegExp(r'status code: (\d+)').firstMatch(e.message)?.group(1) ?? '',
        );
        if (status == 401 && attempt == 0) continue;
        throw PartyException(switch (status) {
          401 => PartyErrorCode.signedOut,
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
    throw const PartyException(PartyErrorCode.signedOut);
  }

  static PartyException _fromSync(SyncException e) =>
      PartyException(switch (e.code) {
        SyncErrorCode.signedOut => PartyErrorCode.signedOut,
        SyncErrorCode.rateLimited => PartyErrorCode.rateLimited,
        _ => PartyErrorCode.unavailable,
      });
}
