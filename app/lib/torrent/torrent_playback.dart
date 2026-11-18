import 'dart:async';

import 'package:lumio/torrent/torrent_engine.dart';
import 'package:lumio_core/lumio_core.dart' show StreamItem;

/// Aucune source (pair) n'a répondu dans le délai.
class NoPeersException implements Exception {
  const NoPeersException();
  @override
  String toString() => 'NoPeersException: aucune source disponible';
}

/// Le torrent ne contient aucun fichier lisible.
class NoStreamableFileException implements Exception {
  const NoStreamableFileException();
  @override
  String toString() => 'NoStreamableFileException: aucun fichier lisible';
}

/// La préparation a été annulée par [TorrentPlayback.release].
class TorrentCancelledException implements Exception {
  const TorrentCancelledException();
  @override
  String toString() => 'TorrentCancelledException';
}

/// Choisit le fichier à lire : [fileIdx] s'il existe dans [files], sinon le
/// plus grand fichier lisible ; `null` s'il n'y en a aucun.
TorrentFile? chooseTorrentFile(List<TorrentFile> files, int? fileIdx) {
  if (fileIdx != null) {
    for (final f in files) {
      if (f.index == fileIdx) return f;
    }
  }
  TorrentFile? best;
  for (final f in files) {
    if (f.streamable && (best == null || f.size > best.size)) best = f;
  }
  return best;
}

/// Une lecture de torrent : ajoute le magnet, attend une source, choisit le
/// fichier et rend l'URL locale du moteur. [release] arrête et supprime les
/// données. Une instance sert une lecture à la fois.
class TorrentPlayback {
  TorrentPlayback({
    required this.engine,
    this.ready,
    this.peerTimeout = const Duration(seconds: 45),
    this.pollInterval = const Duration(milliseconds: 500),
  });

  final TorrentEngine engine;

  /// Initialisation paresseuse du moteur (premier torrent seulement).
  final Future<void> Function()? ready;

  /// Délai d'attente d'une source (et des métadonnées).
  final Duration peerTimeout;

  /// Intervalle de lecture de la liste des fichiers (métadonnées).
  final Duration pollInterval;

  String? _id;
  StreamSubscription<TorrentStatus>? _sub;
  int _generation = 0;
  Completer<void>? _waiting;

  Future<void> _check(int gen, String? id) async {
    if (gen == _generation) return;
    if (id != null) await _stopQuietly(id);
    throw const TorrentCancelledException();
  }

  /// Prépare la lecture de [s] ; [onStatus] reçoit chaque statut jusqu'à
  /// [release], y compris après le retour (superposition sources/débit).
  Future<Uri> prepare(
    StreamItem s, {
    void Function(TorrentStatus)? onStatus,
  }) async {
    await release();
    final gen = _generation;
    final hash = s.infoHash;
    if (hash == null) {
      throw ArgumentError('flux sans infoHash : ce n\'est pas un torrent');
    }
    String? id;
    try {
      await ready?.call();
      await _check(gen, null);
      id = await engine.add(magnetFromInfoHash(hash, trackers: s.trackers));
      _id = id;
      await _check(gen, id);

      final hasPeer = Completer<void>();
      _waiting = hasPeer;
      _sub = engine.status(id).listen(
        (st) {
          onStatus?.call(st);
          if ((st.peers > 0 || st.seeders > 0) && !hasPeer.isCompleted) {
            hasPeer.complete();
          }
        },
        // Perte réseau : le moteur signale l'erreur dans le statut ; une
        // erreur de flux n'interrompt pas l'attente.
        onError: (Object _) {},
      );

      final watch = Stopwatch()..start();
      Duration left() => peerTimeout - watch.elapsed;
      try {
        await hasPeer.future.timeout(peerTimeout);
      } on TimeoutException {
        throw const NoPeersException();
      }
      await _check(gen, id);

      // Les métadonnées arrivent après les premiers pairs.
      var files = await engine.files(id);
      while (files.isEmpty) {
        if (left() <= Duration.zero) throw const NoPeersException();
        await Future<void>.delayed(pollInterval);
        await _check(gen, id);
        files = await engine.files(id);
      }
      final file = chooseTorrentFile(files, s.fileIdx);
      if (file == null) throw const NoStreamableFileException();
      final url = await engine.stream(id, fileIndex: file.index);
      await _check(gen, id);
      return url;
    } on TorrentCancelledException {
      rethrow;
    } catch (_) {
      if (gen == _generation) await release();
      rethrow;
    }
  }

  Future<void> _stopQuietly(String id) async {
    try {
      await engine.stop(id, deleteData: true);
    } on Object {
      // Déjà arrêté ou moteur fermé : rien à nettoyer.
    }
  }

  /// Arrête le torrent et supprime ses données ; sans effet s'il n'y en a pas.
  Future<void> release() async {
    _generation++;
    final id = _id;
    _id = null;
    final sub = _sub;
    _sub = null;
    final waiting = _waiting;
    _waiting = null;
    if (waiting != null && !waiting.isCompleted) {
      waiting.completeError(const TorrentCancelledException());
    }
    // Sans attendre : l'arrêt du torrent ne dépend pas de la fin de l'abonnement.
    unawaited(sub?.cancel());
    if (id != null) await _stopQuietly(id);
  }
}
