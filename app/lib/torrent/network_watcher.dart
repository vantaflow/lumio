import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:lumio/data/app_settings.dart';
import 'package:lumio_core/lumio_core.dart';

/// Un VPN est exigé pour les torrents et aucun (ou pas le bon) n'est actif.
class VpnRequiredException implements Exception {
  const VpnRequiredException();
  @override
  String toString() => 'VpnRequiredException: VPN exigé, aucun actif';
}

/// Liste des interfaces réseau actives ; remplacée en test.
abstract class NetworkProbe {
  Future<List<NetInterface>> upInterfaces();
}

/// `NetworkInterface.list()` + sur Android la requête `TRANSPORT_VPN` du
/// ConnectivityManager (les interfaces VPN n'y sont pas toujours visibles) :
/// un VPN détecté ainsi n'a pas de nom connu ([NetInterface.anonymousVpn]).
class PlatformNetworkProbe implements NetworkProbe {
  const PlatformNetworkProbe();

  static const _channel = MethodChannel('dev.lumio.app/network');

  @override
  Future<List<NetInterface>> upInterfaces() async {
    final list = await NetworkInterface.list();
    final out = [for (final i in list) NetInterface(i.name)];
    if (Platform.isAndroid) {
      try {
        if (await _channel.invokeMethod<bool>('vpnActive') ?? false) {
          out.add(const NetInterface('vpn', anonymousVpn: true));
        }
      } on Object {
        // Canal indisponible : on s'en tient à la liste des interfaces.
      }
    }
    return out;
  }
}

/// Réglages de confidentialité réseau des torrents : décision du coupe-circuit
/// et confirmation de l'avertissement IP (première utilisation).
class TorrentPrivacy {
  TorrentPrivacy({required this.probe, required this.store});

  final NetworkProbe probe;
  final AppSettingsStore store;

  Future<NetworkGuard> guard() async {
    final require = await store.read(AppSettingsStore.requireVpnKey) == '1';
    final iface = await store.read(AppSettingsStore.vpnInterfaceKey);
    return NetworkGuard(
      requiredInterface: iface == null || iface.isEmpty ? null : iface,
      requireVpn: require,
    );
  }

  /// Décision courante. Sans VPN exigé, une liste illisible vaut « aucun VPN ».
  Future<GuardDecision> evaluate() async {
    final g = await guard();
    List<NetInterface> up;
    try {
      up = await probe.upInterfaces();
    } on Object {
      // Interfaces illisibles : exigé = on refuse, sinon simple rappel.
      return g.enforcing
          ? const GuardDecision.stop('interfaces illisibles')
          : GuardDecision.warnNoVpn;
    }
    return g.evaluate(up);
  }

  Future<bool> ipWarningAccepted() async =>
      await store.read(AppSettingsStore.ipWarningAcceptedKey) == '1';

  Future<void> acceptIpWarning() =>
      store.write(AppSettingsStore.ipWarningAcceptedKey, '1');
}

/// Pendant un torrent, interroge les interfaces toutes les 3 s et appelle
/// [onStop] (une seule fois) dès que le coupe-circuit décide l'arrêt.
class NetworkWatcher {
  NetworkWatcher({
    required this.privacy,
    required this.onStop,
    this.interval = const Duration(seconds: 3),
  });

  final TorrentPrivacy privacy;
  final void Function(String reason) onStop;
  final Duration interval;

  Timer? _timer;
  bool _busy = false;

  bool get running => _timer != null;

  void start() {
    stop();
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  Future<void> _tick() async {
    if (_busy || _timer == null) return;
    _busy = true;
    try {
      final d = await privacy.evaluate();
      if (_timer == null) return; // arrêté pendant la requête
      if (d is GuardStop) {
        stop();
        onStop(d.reason);
      }
    } on Object {
      // Lecture impossible ce tour-ci : nouvel essai au suivant.
    } finally {
      _busy = false;
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
