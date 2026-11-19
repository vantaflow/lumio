import 'dart:io';

/// Interfaces qu'on ne sert jamais : VPN, tunnels, données mobiles.
final _excluded = RegExp(
  r'^(tun|tap|utun|ppp|wg|ipsec|vpn|rmnet|ccmni|pdp|dummy|lo|docker|veth|br-|awdl|llw|bridge|p2p)',
  caseSensitive: false,
);

/// Interfaces Wi-Fi / Ethernet, par ordre de préférence.
final _wifi = RegExp(r'^(wlan|wl|wifi)', caseSensitive: false);
final _wired = RegExp(r'^(eth|en|usb|rndis)', caseSensitive: false);

bool _isPrivate(InternetAddress a) {
  if (a.type != InternetAddressType.IPv4) return false;
  final b = a.rawAddress;
  return b[0] == 10 ||
      (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
      (b[0] == 192 && b[1] == 168);
}

/// Adresse IPv4 privée de l'interface Wi-Fi (sinon Ethernet) du réseau local ;
/// `null` s'il n'y en a pas. Les interfaces VPN et mobiles sont ignorées.
InternetAddress? pickLanAddress(
  List<(String, List<InternetAddress>)> interfaces,
) {
  InternetAddress? wired;
  for (final (name, addrs) in interfaces) {
    if (_excluded.hasMatch(name)) continue;
    final isWifi = _wifi.hasMatch(name);
    if (!isWifi && !_wired.hasMatch(name)) continue;
    for (final a in addrs) {
      if (!_isPrivate(a)) continue;
      if (isWifi) return a;
      wired ??= a;
    }
  }
  return wired;
}

/// Adresse du réseau local ; remplacée en test.
abstract class LanAddressSource {
  Future<InternetAddress?> current();
}

class PlatformLanAddress implements LanAddressSource {
  const PlatformLanAddress();

  @override
  Future<InternetAddress?> current() async {
    try {
      final list = await NetworkInterface.list(type: InternetAddressType.IPv4);
      return pickLanAddress([
        for (final i in list) (i.name, [...i.addresses]),
      ]);
    } on Object {
      return null;
    }
  }
}
