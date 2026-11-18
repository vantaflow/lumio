import 'dart:io';

import 'url_guard.dart';

/// Signature de `HttpClient.connectionFactory`.
typedef ConnectionFactory =
    Future<ConnectionTask<Socket>> Function(
      Uri url,
      String? proxyHost,
      int? proxyPort,
    );

/// Résolution DNS (injectable pour les tests).
typedef HostLookup = Future<List<InternetAddress>> Function(String host);

/// Fabrique de connexion qui résout l'hôte elle-même et, si [allowPrivate] est
/// faux, refuse (par [UnsafeUrlException]) toute adresse locale, privée ou de
/// lien local : un nom public qui résout vers une adresse privée n'atteint
/// jamais le réseau interne. On se connecte à l'adresse vérifiée (pas de
/// seconde résolution).
ConnectionFactory guardedConnectionFactory({
  bool allowPrivate = false,
  HostLookup? lookup,
}) {
  final resolve = lookup ?? InternetAddress.lookup;
  return (url, proxyHost, proxyPort) async {
    final host = proxyHost ?? url.host;
    final port =
        proxyPort ??
        (url.hasPort ? url.port : (url.scheme == 'https' ? 443 : 80));
    final addrs = await resolve(host);
    if (addrs.isEmpty) {
      throw SocketException('hôte introuvable', address: null, port: port);
    }
    if (!allowPrivate && addrs.any(UrlGuard.isPrivateAddress)) {
      throw const UnsafeUrlException(
        'le nom résout vers une adresse privée',
        code: UnsafeUrlReason.privateAddress,
      );
    }
    return Socket.startConnect(addrs.first, port);
  };
}
