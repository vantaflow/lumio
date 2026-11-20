import 'dart:io';

import 'package:flutter/services.dart';
import 'package:lumio/torrent/torrserver_engine.dart';

/// Android : démarre et arrête le processus TorrServer par le canal natif
/// (`TorrServerManager`, voir `MainActivity`). Le serveur n'écoute que sur
/// 127.0.0.1, avec un mot de passe aléatoire propre à chaque lancement.
class PlatformTorrServerProcess implements TorrServerProcess {
  const PlatformTorrServerProcess();

  static const channel = MethodChannel('dev.lumio.app/torrserver');

  @override
  Future<TorrServerEndpoint> start() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('TorrServer n\'est embarqué que sous Android');
    }
    try {
      final m = await channel.invokeMapMethod<String, Object?>('start');
      if (m == null) throw const TorrServerStartException('réponse vide');
      return TorrServerEndpoint(
        port: m['port']! as int,
        user: m['user']! as String,
        password: m['password']! as String,
      );
    } on PlatformException catch (e) {
      throw TorrServerStartException(e.message ?? 'démarrage impossible');
    }
  }

  @override
  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await channel.invokeMethod<void>('stop');
    } on PlatformException {
      // Déjà arrêté.
    }
  }
}
