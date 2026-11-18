import 'dart:async';
import 'dart:io';

import 'cast_server.dart';
import 'dlna_renderer.dart';
import 'ssdp.dart';

/// Aucune interface locale ne permet de joindre l'appareil.
class CastNetworkException implements Exception {
  const CastNetworkException();

  @override
  String toString() => 'CastNetworkException: aucune interface commune';
}

/// Le cast a été arrêté pendant son démarrage.
class CastCancelledException implements Exception {
  const CastCancelledException();

  @override
  String toString() => 'CastCancelledException';
}

/// Un cast en cours : serveur éphémère + commandes de l'appareil + suivi de
/// la position. Le serveur n'existe que pendant la session.
class CastSession {
  CastSession({
    required this.device,
    required CastRenderer renderer,
    required this.source,
    required this.title,
    Future<List<InternetAddress>> Function()? localAddresses,
    this.pollInterval = const Duration(seconds: 2),
    this.lostAfter = const Duration(seconds: 10),
  }) : _renderer = renderer,
       _localAddresses = localAddresses ?? _systemAddresses;

  final CastDevice device;
  final CastSource source;
  final String title;
  final Duration pollInterval;

  /// Silence de l'appareil (aucune réponse) au bout duquel il est déclaré perdu.
  final Duration lostAfter;
  final CastRenderer _renderer;
  final Future<List<InternetAddress>> Function() _localAddresses;

  /// Appelé une seule fois quand l'appareil est perdu, avec la dernière
  /// position connue ; la session est alors déjà arrêtée.
  void Function(Duration lastPosition)? onLost;

  CastServer? _server;
  Timer? _timer;
  var _lastPosition = Duration.zero;
  late DateTime _lastOk;
  var _polling = false;
  var _stopped = false;

  static Future<List<InternetAddress>> _systemAddresses() async => [
    for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4))
      ...i.addresses,
  ];

  String _mime() {
    final s = source;
    return switch (s) {
      CastFileSource() => mimeForPath(s.file.path),
      CastHttpSource() => s.mimeType ?? 'video/mp4',
    };
  }

  bool get isActive => _server != null && !_stopped;
  Duration get lastPosition => _lastPosition;

  /// Ouvre le serveur sur l'interface du réseau de l'appareil, lui envoie
  /// l'URL, lance la lecture et reprend à [startAt]. Échec : tout est refermé.
  Future<void> start({Duration startAt = Duration.zero}) async {
    final bind = pickLanAddress(device.address, await _localAddresses());
    if (bind == null) throw const CastNetworkException();
    if (_stopped) throw const CastCancelledException();
    final server = await CastServer.start(
      bindAddress: bind,
      allowedClient: device.address,
      source: source,
    );
    _server = server;
    if (_stopped) {
      // stop() est arrivé pendant l'ouverture du serveur.
      await _teardown();
      throw const CastCancelledException();
    }
    try {
      await _renderer.setUri(server.url, title, mime: _mime());
      await _renderer.play();
      if (startAt > Duration.zero) {
        try {
          await _renderer.seek(startAt);
        } on DlnaException {
          // Certains appareils refusent Seek : la lecture repart du début.
        }
      }
    } on Object {
      await _teardown();
      rethrow;
    }
    if (_stopped) {
      await _teardown();
      throw const CastCancelledException();
    }
    _lastPosition = startAt;
    _lastOk = DateTime.now();
    _timer = Timer.periodic(pollInterval, (_) => unawaited(_poll()));
  }

  Future<void> pause() => _renderer.pause();
  Future<void> resume() => _renderer.play();
  Future<void> seek(Duration p) => _renderer.seek(p);

  Future<void> _poll() async {
    if (_polling || _stopped) return;
    _polling = true;
    try {
      _lastPosition = await _renderer.position().timeout(pollInterval * 2);
      _lastOk = DateTime.now();
    } on DlnaException {
      // L'appareil répond (même par un défaut) : il est là.
      _lastOk = DateTime.now();
    } on Object {
      if (!_stopped && DateTime.now().difference(_lastOk) >= lostAfter) {
        final cb = onLost;
        final last = _lastPosition;
        await _teardown();
        cb?.call(last);
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _teardown() async {
    _stopped = true;
    _timer?.cancel();
    _timer = null;
    final s = _server;
    _server = null;
    await s?.close();
  }

  /// Arrête l'appareil (au mieux), ferme le serveur et rend la dernière
  /// position connue. Sans effet si déjà arrêtée.
  Future<Duration> stop() async {
    if (_stopped) return _lastPosition;
    final wasActive = _server != null;
    _stopped = true;
    _timer?.cancel();
    if (wasActive) {
      try {
        _lastPosition = await _renderer.position().timeout(
          const Duration(seconds: 2),
        );
      } on Object {
        // Dernière position connue.
      }
      try {
        await _renderer.stop().timeout(const Duration(seconds: 3));
      } on Object {
        // Appareil déjà parti.
      }
    }
    await _teardown();
    return _lastPosition;
  }
}
