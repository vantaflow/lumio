import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

void main() {
  const wlan = NetInterface('wlan0');
  const tun = NetInterface('tun0');

  test('interface requise absente : stop', () {
    const g = NetworkGuard(requiredInterface: 'tun0');
    expect(g.evaluate([wlan]), isA<GuardStop>());
    expect(g.evaluate(const []), isA<GuardStop>());
  });

  test('interface requise présente : allow', () {
    const g = NetworkGuard(requiredInterface: 'tun0');
    expect(g.evaluate([wlan, tun]), same(GuardDecision.allow));
  });

  test('VPN anonyme (Android) ne satisfait pas une interface précise', () {
    const g = NetworkGuard(requiredInterface: 'tun0');
    expect(
      g.evaluate([wlan, const NetInterface('vpn', anonymousVpn: true)]),
      isA<GuardStop>(),
    );
  });

  test('aucune exigence et aucun VPN : warnNoVpn', () {
    const g = NetworkGuard(requiredInterface: null);
    expect(g.evaluate([wlan]), same(GuardDecision.warnNoVpn));
    expect(g.evaluate([wlan, tun]), same(GuardDecision.allow));
    expect(g.enforcing, isFalse);
  });

  test('VPN exigé sans nom : n\'importe quel VPN, sinon stop', () {
    const g = NetworkGuard(requiredInterface: null, requireVpn: true);
    expect(g.enforcing, isTrue);
    expect(g.evaluate([wlan]), isA<GuardStop>());
    expect(g.evaluate([wlan, const NetInterface('wg0')]), GuardDecision.allow);
    expect(
      g.evaluate([const NetInterface('vpn', anonymousVpn: true)]),
      GuardDecision.allow,
    );
  });

  test('noms VPN reconnus', () {
    for (final n in [
      'tun0',
      'wg0',
      'ppp0',
      'utun3',
      'ipsec0',
      'tap0',
      'TUN1',
    ]) {
      expect(NetInterface(n).isVpn, isTrue, reason: n);
    }
    for (final n in ['wlan0', 'eth0', 'lo', 'rmnet0', 'en0']) {
      expect(NetInterface(n).isVpn, isFalse, reason: n);
    }
  });
}
