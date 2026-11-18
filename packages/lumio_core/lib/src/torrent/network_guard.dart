/// Une interface réseau active de l'appareil.
class NetInterface {
  const NetInterface(this.name, {this.anonymousVpn = false});

  /// Nom système (`tun0`, `wg0`, `wlan0`…).
  final String name;

  /// Vrai quand l'appareil signale un VPN actif sans en donner le nom
  /// (Android : transport VPN). Ne correspond qu'à « n'importe quel VPN ».
  final bool anonymousVpn;

  static const _vpnPrefixes = ['tun', 'wg', 'ppp', 'utun', 'ipsec', 'tap'];

  /// Le nom ressemble à celui d'une interface VPN.
  bool get isVpn {
    if (anonymousVpn) return true;
    final n = name.toLowerCase();
    return _vpnPrefixes.any(n.startsWith);
  }
}

/// Décision de [NetworkGuard.evaluate].
sealed class GuardDecision {
  const GuardDecision();

  /// Le trafic torrent peut démarrer ou continuer.
  static const allow = GuardAllow();

  /// Aucun VPN détecté, mais il n'est pas exigé : rappel discret.
  static const warnNoVpn = GuardWarnNoVpn();

  /// Le trafic torrent doit s'arrêter (ou ne pas démarrer) pour [reason].
  const factory GuardDecision.stop(String reason) = GuardStop;
}

class GuardAllow extends GuardDecision {
  const GuardAllow();
}

class GuardWarnNoVpn extends GuardDecision {
  const GuardWarnNoVpn();
}

class GuardStop extends GuardDecision {
  const GuardStop(this.reason);
  final String reason;
}

/// Coupe-circuit réseau des torrents (application, pas liaison système).
///
/// - [requiredInterface] : interface précise exigée (`tun0`) ;
/// - [requireVpn] : sans interface précise, n'importe quel VPN suffit ;
/// - ni l'un ni l'autre : jamais d'arrêt, seulement un rappel sans VPN.
class NetworkGuard {
  const NetworkGuard({
    required this.requiredInterface,
    this.requireVpn = false,
  });

  final String? requiredInterface;
  final bool requireVpn;

  /// Vrai quand une absence de VPN doit arrêter le trafic.
  bool get enforcing => requiredInterface != null || requireVpn;

  GuardDecision evaluate(List<NetInterface> up) {
    final wanted = requiredInterface;
    if (wanted != null) {
      final w = wanted.toLowerCase();
      final found = up.any((i) => !i.anonymousVpn && i.name.toLowerCase() == w);
      return found
          ? GuardDecision.allow
          : GuardDecision.stop('interface $wanted absente');
    }
    final vpn = up.any((i) => i.isVpn);
    if (vpn) return GuardDecision.allow;
    return requireVpn
        ? const GuardDecision.stop('aucun VPN actif')
        : GuardDecision.warnNoVpn;
  }
}
