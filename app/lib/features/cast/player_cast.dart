import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lumio_core/lumio_core.dart';

/// Résultat d'une tentative de cast.
enum CastStart { started, unsupported, noNetwork, failed }

/// Cast d'une lecture en cours du lecteur : met la lecture locale en pause,
/// envoie le média au téléviseur, et rend la main au lecteur local à la
/// position atteinte quand le cast s'arrête ou que l'appareil est perdu.
///
/// Les règles d'accès du média (VPN/avertissement IP des torrents, profil
/// enfant, verrous) sont celles de la lecture locale : on ne peut diffuser
/// que ce qui a déjà été ouvert par le lecteur.
class PlayerCast extends ChangeNotifier {
  PlayerCast({
    required this.source,
    required this.position,
    required this.pauseLocal,
    required this.resumeLocal,
    required this.onLost,
    CastSession Function(CastDevice device, CastSource source, String title)?
    createSession,
  }) : _create = createSession ?? _defaultSession;

  /// Source relayable de la lecture en cours (`null` : non diffusable).
  final CastSource? Function() source;
  final Duration Function() position;
  final Future<void> Function() pauseLocal;

  /// Reprend la lecture locale à la position donnée.
  final Future<void> Function(Duration at) resumeLocal;

  /// Appelé après un retour automatique en local (appareil perdu).
  final VoidCallback onLost;
  final CastSession Function(CastDevice, CastSource, String) _create;

  CastSession? _session;
  CastDevice? _device;
  bool _paused = false;
  bool _busy = false;

  static CastSession _defaultSession(
    CastDevice d,
    CastSource s,
    String title,
  ) => CastSession(
    device: d,
    renderer: DlnaRenderer(d),
    source: s,
    title: title,
  );

  bool get active => _session != null;
  CastDevice? get device => _device;
  bool get paused => _paused;

  Future<CastStart> start(CastDevice device, String title) async {
    if (_busy || _session != null) return CastStart.failed;
    final src = source();
    if (src == null) return CastStart.unsupported;
    _busy = true;
    final at = position();
    final session = _create(device, src, title);
    try {
      await pauseLocal();
      session.onLost = (last) => unawaited(_lost(session, last));
      await session.start(startAt: at);
    } on CastNetworkException {
      await resumeLocal(at);
      return CastStart.noNetwork;
    } on Object {
      await session.stop();
      await resumeLocal(at);
      return CastStart.failed;
    } finally {
      _busy = false;
    }
    _session = session;
    _device = device;
    _paused = false;
    notifyListeners();
    return CastStart.started;
  }

  Future<void> _lost(CastSession session, Duration last) async {
    if (!identical(session, _session)) return;
    _clear();
    await resumeLocal(last);
    onLost();
  }

  void _clear() {
    _session = null;
    _device = null;
    _paused = false;
    notifyListeners();
  }

  Future<void> togglePause() async {
    final s = _session;
    if (s == null) return;
    try {
      if (_paused) {
        await s.resume();
      } else {
        await s.pause();
      }
      _paused = !_paused;
      notifyListeners();
    } on Object {
      // Commande refusée : l'état affiché reste celui de l'appareil.
    }
  }

  Future<void> seekBy(Duration delta) async {
    final s = _session;
    if (s == null) return;
    var t = s.lastPosition + delta;
    if (t < Duration.zero) t = Duration.zero;
    try {
      await s.seek(t);
    } on Object {
      // Seek refusé par l'appareil : sans effet.
    }
  }

  /// Arrête le cast (serveur fermé). [resume] : le lecteur local reprend à la
  /// position atteinte sur l'appareil.
  Future<void> stop({bool resume = true}) async {
    final s = _session;
    if (s == null) return;
    _clear();
    final last = await s.stop();
    if (resume) await resumeLocal(last);
  }

  @override
  void dispose() {
    final s = _session;
    _session = null;
    if (s != null) unawaited(s.stop());
    super.dispose();
  }
}
