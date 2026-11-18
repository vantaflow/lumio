import 'dart:async';

import 'tracker.dart';

/// Entrée de la file : un événement à renvoyer pour [trackerId] et
/// [profileId].
class QueuedScrobble {
  const QueuedScrobble({
    required this.id,
    required this.profileId,
    required this.trackerId,
    required this.event,
    this.attempts = 0,
    required this.nextAttemptAt,
  });

  final int id;
  final String profileId;
  final String trackerId;
  final ScrobbleEvent event;
  final int attempts;
  final DateTime nextAttemptAt;
}

/// Stockage de la file (SQLite côté application, mémoire dans les tests).
abstract class ScrobbleStore {
  /// Entrées dans l'ordre d'ajout.
  Future<List<QueuedScrobble>> all();

  /// Ajoute une entrée et rend son identifiant.
  Future<int> add(
    String profileId,
    String trackerId,
    ScrobbleEvent event,
    DateTime nextAttemptAt,
  );

  Future<void> remove(int id);

  /// Enregistre un nouvel essai raté.
  Future<void> markFailed(int id, int attempts, DateTime nextAttemptAt);
}

class MemoryScrobbleStore implements ScrobbleStore {
  final _rows = <QueuedScrobble>[];
  int _next = 1;

  @override
  Future<List<QueuedScrobble>> all() async => List.of(_rows);

  @override
  Future<int> add(
    String profileId,
    String trackerId,
    ScrobbleEvent event,
    DateTime nextAttemptAt,
  ) async {
    final id = _next++;
    _rows.add(
      QueuedScrobble(
        id: id,
        profileId: profileId,
        trackerId: trackerId,
        event: event,
        nextAttemptAt: nextAttemptAt,
      ),
    );
    return id;
  }

  @override
  Future<void> remove(int id) async => _rows.removeWhere((r) => r.id == id);

  @override
  Future<void> markFailed(int id, int attempts, DateTime nextAttemptAt) async {
    final i = _rows.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final r = _rows[i];
    _rows[i] = QueuedScrobble(
      id: r.id,
      profileId: r.profileId,
      trackerId: r.trackerId,
      event: r.event,
      attempts: attempts,
      nextAttemptAt: nextAttemptAt,
    );
  }
}

/// Envoie un événement ; lève une [TrackerException] en cas d'échec.
typedef ScrobbleSender =
    Future<void> Function(
      String profileId,
      String trackerId,
      ScrobbleEvent event,
    );

/// Résultat d'un passage de la file.
class FlushResult {
  const FlushResult({
    this.sent = 0,
    this.dropped = 0,
    this.remaining = 0,
    this.reauthRequired = false,
    this.notConfigured = false,
  });

  final int sent;
  final int dropped;
  final int remaining;

  /// Un envoi a été refusé faute de jeton valide : reconnexion à proposer.
  final bool reauthRequired;
  final bool notConfigured;
}

/// File d'attente persistée des événements de suivi.
///
/// Un échec passager (réseau, 5xx) garde l'événement et le rejoue avec un
/// délai croissant ([backoff] : 1, 5 puis 30 min). Les événements d'un même
/// service restent dans l'ordre : un événement en attente bloque les suivants.
/// Au plus [maxEntries] entrées : les plus anciennes sont abandonnées.
class ScrobbleQueue {
  ScrobbleQueue(
    this._store,
    this._send, {
    DateTime Function()? now,
    this.maxEntries = 200,
    this.backoff = const [
      Duration(minutes: 1),
      Duration(minutes: 5),
      Duration(minutes: 30),
    ],
    this.liveEventMaxAge = const Duration(minutes: 10),
  }) : _now = now ?? DateTime.now;

  final ScrobbleStore _store;
  final ScrobbleSender _send;
  final DateTime Function() _now;
  final int maxEntries;
  final List<Duration> backoff;

  /// Un `start` ou `pause` plus ancien est périmé (état « en cours » sans
  /// intérêt) et abandonné au rejeu ; `stop` (historique) est toujours gardé.
  final Duration liveEventMaxAge;

  bool _flushing = false;
  final _last = <String, ScrobbleEvent>{};

  /// Nombre d'entrées en attente.
  Future<int> pending() async => (await _store.all()).length;

  /// Signale [event] : envoi immédiat, ou mise en file si une entrée du même
  /// service attend déjà ou si l'envoi échoue passagèrement. Un événement
  /// identique au précédent du même profil et service est ignoré.
  Future<FlushResult> submit(
    String profileId,
    String trackerId,
    ScrobbleEvent event,
  ) async {
    final key = '$profileId|$trackerId';
    final prev = _last[key];
    if (prev != null && prev.sameAs(event)) return const FlushResult();
    _last[key] = event;
    await _store.add(profileId, trackerId, event, _now());
    await _trim();
    return flush();
  }

  /// Abandonne les entrées en attente d'un profil et d'un service
  /// (déconnexion).
  Future<void> discard(String profileId, String trackerId) async {
    for (final r in await _store.all()) {
      if (r.profileId == profileId && r.trackerId == trackerId) {
        await _store.remove(r.id);
      }
    }
    _last.remove('$profileId|$trackerId');
  }

  Future<void> _trim() async {
    final rows = await _store.all();
    for (var i = 0; i < rows.length - maxEntries; i++) {
      await _store.remove(rows[i].id);
    }
  }

  /// Rejoue les entrées échues, dans l'ordre. S'arrête à la première panne
  /// passagère (ordre conservé).
  Future<FlushResult> flush() async {
    if (_flushing) return FlushResult(remaining: await pending());
    _flushing = true;
    var sent = 0;
    var dropped = 0;
    var reauth = false;
    var notConfigured = false;
    final blocked = <String>{};
    try {
      for (final row in await _store.all()) {
        final key = '${row.profileId}|${row.trackerId}';
        if (blocked.contains(key)) continue;
        if (row.nextAttemptAt.isAfter(_now())) {
          blocked.add(key);
          continue;
        }
        final live = row.event.action != ScrobbleAction.stop;
        if (live && _now().difference(row.event.at) > liveEventMaxAge) {
          await _store.remove(row.id);
          dropped++;
          continue;
        }
        try {
          await _send(row.profileId, row.trackerId, row.event);
          await _store.remove(row.id);
          sent++;
        } on TrackerUnavailable {
          final n = row.attempts + 1;
          final wait = backoff[(n - 1).clamp(0, backoff.length - 1)];
          await _store.markFailed(row.id, n, _now().add(wait));
          blocked.add(key);
        } on TrackerReauthRequired {
          reauth = true;
          blocked.add(key); // gardé : repart après la reconnexion
        } on TrackerNotConfigured {
          notConfigured = true;
          blocked.add(key);
        } on TrackerRejected {
          await _store.remove(row.id);
          dropped++;
        }
      }
    } finally {
      _flushing = false;
    }
    return FlushResult(
      sent: sent,
      dropped: dropped,
      remaining: await pending(),
      reauthRequired: reauth,
      notConfigured: notConfigured,
    );
  }
}
