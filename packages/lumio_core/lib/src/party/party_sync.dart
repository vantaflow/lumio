import 'dart:convert';

/// État de lecture reçu d'un autre participant (position + lecture/pause).
/// Seuls ces deux champs circulent : jamais d'URL, de flux ni de titre.
class PartyState {
  const PartyState({required this.position, required this.playing});

  final Duration position;
  final bool playing;
}

/// État du lecteur local.
class LocalState {
  const LocalState({required this.position, required this.playing});

  final Duration position;
  final bool playing;
}

/// Correction à appliquer au lecteur local : [seekTo] (position) et/ou [play]
/// (`true` lire, `false` mettre en pause). Un champ nul : rien à changer.
class PlaybackCommand {
  const PlaybackCommand({this.seekTo, this.play});

  final Duration? seekTo;
  final bool? play;

  @override
  String toString() => 'PlaybackCommand(seekTo: $seekTo, play: $play)';
}

/// Calcule la correction de dérive entre l'état distant et l'état local.
class PartySync {
  const PartySync({this.driftThreshold = const Duration(milliseconds: 1500)});

  /// Au-delà de cet écart, on se recale (seek) ; en deçà, on laisse faire pour
  /// éviter les saccades.
  final Duration driftThreshold;

  /// [rtt] : temps d'aller-retour mesuré avec le serveur. Un message a mis
  /// environ `rtt / 2` pour arriver : si l'autre lit, sa position réelle a
  /// avancé d'autant. Renvoie `null` quand le local est déjà aligné.
  PlaybackCommand? reconcile(
    PartyState remote,
    LocalState local,
    Duration rtt,
  ) {
    final latency = rtt.isNegative ? Duration.zero : rtt ~/ 2;
    final expected =
        remote.position + (remote.playing ? latency : Duration.zero);
    final drift = (local.position - expected).abs();
    final seek = drift > driftThreshold
        ? (expected.isNegative ? Duration.zero : expected)
        : null;
    final play = remote.playing != local.playing ? remote.playing : null;
    if (seek == null && play == null) return null;
    return PlaybackCommand(seekTo: seek, play: play);
  }
}

// --- Protocole (voir backend/src/room.ts) ------------------------------------

/// Message reçu du serveur.
sealed class PartyEvent {
  const PartyEvent();
}

/// Première réponse : état de la salle et dernière position connue.
class PartyHello extends PartyEvent {
  const PartyHello({
    required this.participants,
    required this.host,
    required this.allControl,
    required this.metaId,
    required this.expiresAt,
    this.state,
  });

  final int participants;
  final bool host;
  final bool allControl;
  final String? metaId;
  final DateTime? expiresAt;
  final PartyState? state;
}

class PartyRemoteState extends PartyEvent {
  const PartyRemoteState(this.state);
  final PartyState state;
}

/// Arrivée ou départ : [participants] est le nouveau total.
class PartyCount extends PartyEvent {
  const PartyCount(this.participants, {required this.joined});
  final int participants;
  final bool joined;
}

class PartyControl extends PartyEvent {
  const PartyControl({required this.allControl});
  final bool allControl;
}

/// Réponse à un `ping` : [sentAt] est l'horodatage envoyé (mesure du RTT).
class PartyPong extends PartyEvent {
  const PartyPong(this.sentAt);
  final int sentAt;
}

/// Décode un message serveur ; `null` s'il est inconnu ou mal formé.
PartyEvent? decodePartyEvent(String raw) {
  try {
    final j = jsonDecode(raw);
    if (j is! Map<String, dynamic>) return null;
    PartyState? state(Object? v) {
      if (v is! Map) return null;
      final p = v['positionMs'];
      final pl = v['playing'];
      if (p is! num || pl is! bool) return null;
      return PartyState(
        position: Duration(milliseconds: p.toInt()),
        playing: pl,
      );
    }

    switch (j['type']) {
      case 'hello':
        final exp = j['expiresAt'];
        return PartyHello(
          participants: (j['participants'] as num).toInt(),
          host: j['host'] == true,
          allControl: j['allControl'] == true,
          metaId: j['metaId'] as String?,
          expiresAt: exp is num
              ? DateTime.fromMillisecondsSinceEpoch(exp.toInt())
              : null,
          state: state(j['state']),
        );
      case 'state':
        final s = state(j);
        return s == null ? null : PartyRemoteState(s);
      case 'join':
      case 'leave':
        return PartyCount(
          (j['participants'] as num).toInt(),
          joined: j['type'] == 'join',
        );
      case 'control':
        return PartyControl(allControl: j['allControl'] == true);
      case 'pong':
        return PartyPong((j['sentAt'] as num).toInt());
    }
  } on Object {
    return null;
  }
  return null;
}

/// Messages envoyés au serveur : uniquement type, position, état, horodatage.
abstract final class PartyWire {
  static String state(
    Duration position, {
    required bool playing,
    required int sentAt,
  }) => jsonEncode({
    'type': 'state',
    'positionMs': position.inMilliseconds < 0 ? 0 : position.inMilliseconds,
    'playing': playing,
    'sentAt': sentAt,
  });

  static String ping(int sentAt) =>
      jsonEncode({'type': 'ping', 'sentAt': sentAt});

  static String leave(int sentAt) =>
      jsonEncode({'type': 'leave', 'sentAt': sentAt});

  /// Demande de re-synchronisation (le serveur répond par un `hello`).
  static String join(
    Duration position, {
    required bool playing,
    required int sentAt,
  }) => jsonEncode({
    'type': 'join',
    'positionMs': position.inMilliseconds < 0 ? 0 : position.inMilliseconds,
    'playing': playing,
    'sentAt': sentAt,
  });
}
