import 'package:lumio/data/app_settings.dart';
import 'package:lumio/torrent/network_watcher.dart';
import 'package:lumio_core/lumio_core.dart';

/// Interfaces pilotées par le test.
class FakeNetworkProbe implements NetworkProbe {
  FakeNetworkProbe([List<NetInterface>? up])
    : up = up ?? const [NetInterface('wlan0')];
  List<NetInterface> up;
  Object? error;
  int calls = 0;

  @override
  Future<List<NetInterface>> upInterfaces() async {
    calls++;
    if (error != null) throw error!;
    return up;
  }
}

/// Confidentialité sans avertissement ni VPN exigé : pour les tests de lecture
/// de torrent qui ne portent pas sur ce sujet.
class OpenPrivacy extends TorrentPrivacy {
  OpenPrivacy(AppSettingsStore store)
    : super(probe: FakeNetworkProbe(), store: store);

  @override
  Future<bool> ipWarningAccepted() async => true;

  @override
  Future<NetworkGuard> guard() async =>
      const NetworkGuard(requiredInterface: null);

  @override
  Future<GuardDecision> evaluate() async => GuardDecision.allow;
}
