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
/// faux, refuse (par [UnsafeUrlException]) si une adresse résolue est locale,
/// privée ou de lien local : un nom public qui résout vers une adresse privée
/// n'atteint jamais le réseau interne.
///
/// On ne se connecte qu'aux adresses vérifiées (pas de seconde résolution),
/// dans l'ordre, la suivante prenant le relais si une connexion échoue. Pour
/// https, TLS est établi ici sur la socket (SNI et certificat vérifiés contre
/// le nom d'hôte), car `HttpClient` n'ajoute pas TLS avec une fabrique.
/// [timeout] borne la résolution et chaque tentative de connexion ;
/// [securityContext] sert aux tests (certificat de confiance).
ConnectionFactory guardedConnectionFactory({
  bool allowPrivate = false,
  HostLookup? lookup,
  Duration timeout = const Duration(seconds: 15),
  SecurityContext? securityContext,
}) {
  final resolve = lookup ?? InternetAddress.lookup;
  return (url, proxyHost, proxyPort) async {
    final host = proxyHost ?? url.host;
    final port =
        proxyPort ??
        (url.hasPort ? url.port : (url.scheme == 'https' ? 443 : 80));
    final addrs = await resolve(host).timeout(timeout);
    if (addrs.isEmpty) {
      throw SocketException('hôte introuvable', port: port);
    }
    if (!allowPrivate && addrs.any(UrlGuard.isPrivateAddress)) {
      throw const UnsafeUrlException(
        'le nom résout vers une adresse privée',
        code: UnsafeUrlReason.privateAddress,
      );
    }
    var cancelled = false;
    Future<Socket> connect() async {
      Object? last;
      for (final a in addrs) {
        if (cancelled) break;
        try {
          final raw = await Socket.connect(a, port, timeout: timeout);
          if (proxyHost == null && url.scheme == 'https') {
            return await SecureSocket.secure(
              raw,
              host: url.host,
              context: securityContext,
            );
          }
          return raw;
        } on SocketException catch (e) {
          last = e;
        }
      }
      throw last ?? SocketException('connexion annulée', port: port);
    }

    return ConnectionTask.fromSocket(connect(), () => cancelled = true);
  };
}
