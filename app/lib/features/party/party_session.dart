import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lumio/data/party_client.dart';
import 'package:lumio_core/lumio_core.dart';

enum PartyStatus { connecting, connected, ended, failed }

/// Ce que l'écran affiche d'une salle.
@immutable
class PartyView {
  const PartyView({
    this.status = PartyStatus.connecting,
    this.participants = 0,
    this.host = false,
    this.allControl = false,
    this.metaId,
    this.error,
  });

  final PartyStatus status;
  final int participants;
  final bool host;
  final bool allControl;

  /// Titre commun, si l'hôte l'a indiqué : chacun l'ouvre avec ses propres
  /// addons.
  final String? metaId;
  final PartyErrorCode? error;

  bool get canControl => host || allControl;

  PartyView copyWith({
    PartyStatus? status,
    int? participants,
    bool? host,
    bool? allControl,
    String? metaId,
    PartyErrorCode? error,
  }) => PartyView(
    status: status ?? this.status,
    participants: participants ?? this.participants,
    host: host ?? this.host,
    allControl: allControl ?? this.allControl,
    metaId: metaId ?? this.metaId,
    error: error ?? this.error,
  );
}

/// Le lecteur tel que la salle le voit : position, état, et trois ordres.
abstract interface class PartyPlayer {
  Duration get position;
  bool get playing;
  Future<void> seek(Duration position);
  Future<void> setPlaying(bool playing);
}

/// Une salle ouverte : connexion, mesure du RTT, application des corrections
/// de [PartySync] au lecteur, diffusion de l'état local si l'on peut contrôler.
class PartySession extends ValueNotifier<PartyView> {
  PartySession({
    required PartyClient client,
    required this.roomId,
    required this.inviteCode,
    bool host = false,
    PartySync sync = const PartySync(),
    DateTime Function()? now,
    this.heartbeat = const Duration(seconds: 2),
    this.pingEvery = const Duration(seconds: 5),
    this.minSendGap = const Duration(milliseconds: 250),
  }) : _client = client,
       _sync = sync,
       _now = now ?? DateTime.now,
       super(PartyView(host: host));

  final String roomId;
  final String inviteCode;
  final Duration heartbeat;
  final Duration pingEvery;

  /// Écart minimal entre deux envois (bien en dessous de 20 messages/s).
  final Duration minSendGap;

  final PartyClient _client;
  final PartySync _sync;
  final DateTime Function() _now;

  PartyChannel? _channel;
  StreamSubscription<String>? _sub;
  Timer? _heartbeat;
  Timer? _ping;
  PartyPlayer? _player;
  Duration _rtt = Duration.zero;
  bool _disposed = false;
  bool _closed = false;

  // Dernier état envoyé : sert à détecter un changement ou un saut local.
  ({Duration position, bool playing, DateTime at})? _lastSent;
  // Après une correction distante, le lecteur bouge « tout seul » : on ne le
  // rediffuse pas (évite les boucles entre deux contrôleurs).
  DateTime _quietUntil = DateTime.fromMillisecondsSinceEpoch(0);

  Duration get rtt => _rtt;

  int get _ms => _now().millisecondsSinceEpoch;

  Future<void> start() async {
    try {
      final ch = await _client.connect(roomId, inviteCode);
      if (_disposed) {
        unawaited(ch.close());
        return;
      }
      _channel = ch;
      _sub = ch.messages.listen(
        _onMessage,
        onError: (Object _) => _lost(),
        onDone: _lost,
      );
      _ping = Timer.periodic(pingEvery, (_) => _sendPing());
      _heartbeat = Timer.periodic(heartbeat, (_) => _beat());
      _sendPing();
    } on PartyException catch (e) {
      _fail(e.code);
    } on Object {
      _fail(PartyErrorCode.unavailable);
    }
  }

  /// Branche le lecteur (écran de lecture) ; `null` pour le débrancher.
  void attach(PartyPlayer? player) {
    _player = player;
    _lastSent = null;
  }

  void _fail(PartyErrorCode code) {
    if (_disposed) return;
    _stopTimers();
    value = value.copyWith(status: PartyStatus.failed, error: code);
  }

  void _lost() {
    if (_closed || _disposed) return;
    _stopTimers();
    value = value.copyWith(
      status: PartyStatus.failed,
      error: PartyErrorCode.unavailable,
    );
  }

  void _stopTimers() {
    _heartbeat?.cancel();
    _ping?.cancel();
  }

  void _sendPing() => _channel?.send(PartyWire.ping(_ms));

  void _onMessage(String raw) {
    final e = decodePartyEvent(raw);
    if (e == null || _disposed) return;
    switch (e) {
      case PartyHello():
        value = value.copyWith(
          status: PartyStatus.connected,
          participants: e.participants,
          host: e.host,
          allControl: e.allControl,
          metaId: e.metaId,
        );
        // Retardataire : se cale sur la position courante, même sous le seuil
        // de dérive si l'état de lecture diffère.
        if (e.state != null && !e.host) _apply(e.state!);
      case PartyRemoteState():
        _apply(e.state);
      case PartyCount():
        value = value.copyWith(participants: e.participants);
      case PartyControl():
        value = value.copyWith(allControl: e.allControl);
      case PartyPong():
        final d = Duration(milliseconds: _ms - e.sentAt);
        // Lissage : un pic isolé ne doit pas déplacer la position attendue.
        _rtt = _rtt == Duration.zero ? d : (_rtt * 3 + d) ~/ 4;
    }
  }

  void _apply(PartyState remote) {
    final p = _player;
    if (p == null) return;
    final cmd = _sync.reconcile(
      remote,
      LocalState(position: p.position, playing: p.playing),
      _rtt,
    );
    if (cmd == null) return;
    _quietUntil = _now().add(const Duration(seconds: 1));
    if (cmd.seekTo != null) unawaited(p.seek(cmd.seekTo!));
    if (cmd.play != null) unawaited(p.setPlaying(cmd.play!));
  }

  /// À appeler à chaque mise à jour du lecteur local : envoie sans attendre un
  /// changement lecture/pause ou un saut de position.
  void localChanged() {
    final p = _player;
    if (p == null || !_canSend) return;
    final now = _now();
    if (now.isBefore(_quietUntil)) return;
    final last = _lastSent;
    if (last == null) {
      _send(p);
      return;
    }
    if (now.difference(last.at) < minSendGap) return;
    final expected =
        last.position +
        (last.playing ? now.difference(last.at) : Duration.zero);
    final jumped = (p.position - expected).abs() > _sync.driftThreshold;
    if (p.playing != last.playing || jumped) _send(p);
  }

  void _beat() {
    final p = _player;
    if (p == null || !_canSend || _now().isBefore(_quietUntil)) return;
    _send(p);
  }

  bool get _canSend =>
      value.status == PartyStatus.connected &&
      value.canControl &&
      _channel != null;

  void _send(PartyPlayer p) {
    final now = _now();
    _lastSent = (position: p.position, playing: p.playing, at: now);
    _channel?.send(
      PartyWire.state(
        p.position,
        playing: p.playing,
        sentAt: now.millisecondsSinceEpoch,
      ),
    );
  }

  /// Bascule « Tout le monde peut contrôler » (hôte seulement).
  Future<void> setAllControl(bool allControl) async {
    if (!value.host) return;
    try {
      await _client.setControl(roomId, allControl: allControl);
    } on PartyException catch (e) {
      value = value.copyWith(error: e.code);
    }
  }

  /// Quitte la salle proprement.
  Future<void> leave() async {
    if (_closed) return;
    _closed = true;
    _stopTimers();
    try {
      _channel?.send(PartyWire.leave(_ms));
    } on Object {
      // déjà fermé
    }
    await _sub?.cancel();
    try {
      await _channel?.close();
    } on Object {
      // déjà fermé
    }
    if (!_disposed) value = value.copyWith(status: PartyStatus.ended);
  }

  @override
  void dispose() {
    _disposed = true;
    _closed = true;
    _stopTimers();
    unawaited(_sub?.cancel());
    unawaited(_channel?.close().catchError((Object _) {}));
    super.dispose();
  }
}
