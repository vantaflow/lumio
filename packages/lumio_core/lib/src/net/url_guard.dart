import 'dart:io';

/// URL refusée par [UrlGuard] (schéma interdit, hôte local ou réseau privé).
class UnsafeUrlException implements Exception {
  const UnsafeUrlException(this.reason);
  final String reason;

  @override
  String toString() => 'UnsafeUrlException: $reason';
}

/// Garde d'URL pour les requêtes vers des addons (anti-SSRF).
///
/// Refuse les schémas autres que http/https, `localhost` et les adresses IP
/// littérales de boucle locale, de réseau privé, de lien local ou réservées
/// (IPv4 et IPv6, y compris IPv4 mappées en IPv6 et formes décimales ou
/// hexadécimales d'IPv4).
///
/// Limite connue : un nom de domaine public qui *résout* vers une adresse
/// privée n'est pas détecté (pas de résolution DNS ici).
class UrlGuard {
  const UrlGuard._();

  static void check(Uri u, {bool allowPrivate = false}) {
    if (u.scheme != 'http' && u.scheme != 'https') {
      throw const UnsafeUrlException('schéma non autorisé');
    }
    var host = u.host.toLowerCase();
    // `127.0.0.1.` et `localhost.` désignent les mêmes hôtes.
    while (host.endsWith('.')) {
      host = host.substring(0, host.length - 1);
    }
    if (host.isEmpty) throw const UnsafeUrlException('hôte absent');
    if (allowPrivate) return;

    if (host == 'localhost' || host.endsWith('.localhost')) {
      throw const UnsafeUrlException('hôte local');
    }
    // Formes numériques (127.1, 0177.0.0.1, 0x7f.1, 2130706433) que le
    // résolveur système interprète comme des IPv4 : seule la forme décimale
    // canonique à 4 octets sans zéro de tête est analysée, le reste refusé.
    if (_numericHost.hasMatch(host)) {
      if (!_canonicalV4.hasMatch(host)) {
        throw const UnsafeUrlException('adresse IP non canonique');
      }
    }
    final addr = InternetAddress.tryParse(host);
    if (addr != null && _isPrivate(addr)) {
      throw const UnsafeUrlException('réseau privé');
    }
  }

  static final _canonicalV4 = RegExp(
    r'^(0|[1-9]\d{0,2})(\.(0|[1-9]\d{0,2})){3}$',
  );

  static final _numericHost = RegExp(
    r'^(0x[0-9a-f]+|\d+)(\.(0x[0-9a-f]+|\d+))*$',
    caseSensitive: false,
  );

  static bool _isPrivate(InternetAddress a) {
    final b = a.rawAddress;
    if (b.length == 4) return _isPrivateV4(b);
    // IPv6
    if (a.isLoopback || a.isLinkLocal) return true;
    final allZeroPrefix = b.sublist(0, 10).every((x) => x == 0);
    if (allZeroPrefix && b[10] == 0 && b[11] == 0) {
      // :: et ::1 (et IPv4 compatible dépréciée) : non routables.
      return true;
    }
    if (allZeroPrefix && b[10] == 0xff && b[11] == 0xff) {
      return _isPrivateV4(b.sublist(12));
    }
    // NAT64 64:ff9b::/96 : IPv4 embarquée dans les 4 derniers octets.
    if (b[0] == 0x00 &&
        b[1] == 0x64 &&
        b[2] == 0xff &&
        b[3] == 0x9b &&
        b.sublist(4, 12).every((x) => x == 0)) {
      return _isPrivateV4(b.sublist(12));
    }
    if ((b[0] & 0xfe) == 0xfc) return true; // fc00::/7 (ULA)
    if (b[0] == 0xfe && (b[1] & 0xc0) == 0x80) return true; // fe80::/10
    if (b[0] == 0xfe && (b[1] & 0xc0) == 0xc0) return true; // fec0::/10
    return false;
  }

  static bool _isPrivateV4(List<int> b) {
    final a0 = b[0], a1 = b[1];
    if (a0 == 0 || a0 == 10 || a0 == 127) return true;
    if (a0 == 169 && a1 == 254) return true;
    if (a0 == 172 && a1 >= 16 && a1 <= 31) return true;
    if (a0 == 192 && a1 == 168) return true;
    if (a0 == 100 && a1 >= 64 && a1 <= 127) return true; // CGNAT
    if (a0 == 198 && (a1 == 18 || a1 == 19)) return true; // 198.18.0.0/15
    if (a0 == 192 && a1 == 0 && b[2] == 0) return true; // 192.0.0.0/24
    if (a0 >= 224) return true; // multicast, réservé, diffusion
    return false;
  }
}
