import 'dart:async';
import 'dart:convert';

import 'package:lumio_core/src/sync/sync_models.dart';

/// Échanges avec le serveur de synchronisation.
abstract class SyncTransport {
  /// `GET /sync?since=` : une page d'éléments plus récents que [since].
  Future<SyncPage> pull(int since);

  /// `POST /sync` : envoie [items] et renvoie la version attribuée.
  Future<int> push(List<SyncItem> items);
}

/// Base locale vue par le moteur.
abstract class LocalSyncStore {
  /// Dernière version serveur déjà appliquée (0 au départ).
  Future<int> lastVersion();

  Future<void> setLastVersion(int version);

  /// Changements locaux à envoyer (au plus [limit]).
  Future<List<PendingChange>> pending(int limit);

  /// Retire de la file les changements envoyés (ceux dont [PendingChange.seq]
  /// n'a pas changé depuis).
  Future<void> acknowledge(List<PendingChange> sent);

  /// Applique des éléments du serveur (mises à jour et pierres tombales) SANS
  /// les remettre dans la file d'envoi. Les clés qui ont un changement local
  /// en attente sont laissées intactes : le prochain envoi les départagera.
  Future<void> apply(List<SyncItem> remote);
}

/// Moteur de synchronisation : envoie les changements locaux, tire depuis la
/// dernière version connue, applique les pierres tombales. L'ordre est celui
/// des versions du serveur ; l'horloge locale n'intervient jamais.
class SyncEngine {
  SyncEngine(
    this._transport,
    this._store, {
    this.kinds = SyncKind.enabled,
    this.maxPulls = 100,
    this.maxPushRounds = 20,
  });

  final SyncTransport _transport;
  final LocalSyncStore _store;

  /// Types traités. `addons` n'y figure pas (voir [SyncKind.addons]).
  final Set<String> kinds;

  /// Garde-fou contre un serveur qui répondrait `more` sans fin.
  final int maxPulls;

  /// Garde-fou : une file qui se remplit sans cesse ne bloque pas le tirage.
  final int maxPushRounds;

  Future<void>? _running;

  /// Une synchronisation à la fois : un appel pendant une synchro en cours
  /// attend celle-ci. Les erreurs de transport remontent à l'appelant.
  Future<void> syncOnce() => _running ??= _run().whenComplete(() {
    _running = null;
  });

  Future<void> _run() async {
    await _pushAll();
    await _pullAll();
  }

  Future<void> _pushAll() async {
    for (var round = 0; round < maxPushRounds; round++) {
      final batch = await _store.pending(SyncLimits.maxItemsPerRequest);
      if (batch.isEmpty) return;
      final send = <PendingChange>[];
      final drop = <PendingChange>[];
      var bytes = 0;
      for (final c in batch) {
        if (!isPushable(c.item, kinds: kinds)) {
          drop.add(c);
          continue;
        }
        final size = utf8.encode(jsonEncode(c.item.toPushJson())).length + 1;
        if (send.isNotEmpty && bytes + size > SyncLimits.targetBodyBytes) break;
        bytes += size;
        send.add(c);
      }
      if (send.isNotEmpty) {
        await _transport.push([for (final c in send) c.item]);
      }
      // Un élément invalide est abandonné (il bloquerait la file à jamais).
      await _store.acknowledge([...send, ...drop]);
      if (send.isEmpty && drop.isEmpty) return;
    }
  }

  Future<void> _pullAll() async {
    var since = await _store.lastVersion();
    for (var i = 0; i < maxPulls; i++) {
      final page = await _transport.pull(since);
      final items = [
        for (final it in page.items)
          if (kinds.contains(it.kind)) it,
      ];
      if (items.isNotEmpty) await _store.apply(items);
      // Un serveur remis à zéro peut renvoyer une version plus petite : on la
      // suit, sinon la file locale ne serait plus jamais confrontée.
      if (page.version != since) {
        await _store.setLastVersion(page.version);
        since = page.version;
      }
      if (!page.more) return;
    }
  }
}
