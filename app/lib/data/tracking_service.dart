import 'dart:async';

import 'package:lumio/data/profile_repository.dart';
import 'package:lumio/data/tracking_repository.dart';
import 'package:lumio/player/playback_events.dart';
import 'package:lumio_core/lumio_core.dart';

/// Chef d'orchestre du suivi : reçoit les événements du lecteur
/// ([PlaybackEvents]), applique les règles (service configuré et connecté,
/// profil enfant autorisé par un parent, titre identifié par IMDb) puis passe
/// par la [ScrobbleQueue] (envoi, file hors ligne, rejeu).
class TrackingService {
  TrackingService({
    required this.repo,
    required this.profiles,
    required this.queue,
    required this.trackerFor,
    required this.configured,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final TrackingRepository repo;
  final ProfileRepository profiles;
  final ScrobbleQueue queue;

  /// Client du service [trackerId] pour [profileId] (avec son jeton).
  final Future<Tracker> Function(String trackerId, String profileId) trackerFor;

  /// Services dont les identifiants d'application sont présents.
  final bool Function(String trackerId) configured;
  final DateTime Function() _now;

  /// Services reliés à envoyer pour [profileId] (vide : rien à faire).
  Future<List<String>> activeTrackers(String profileId) async {
    final out = <String>[];
    for (final id in trackerIds) {
      if (!configured(id)) continue;
      if (await repo.token(id, profileId) == null) continue;
      out.add(id);
    }
    if (out.isEmpty) return out;
    // Profil enfant : seulement si un parent l'a autorisé.
    final p = await profiles.get(profileId);
    if (p != null && p.isKid && !await repo.kidAllowed(profileId)) {
      return const [];
    }
    return out;
  }

  /// Écouteur à brancher sur [PlaybackEvents].
  Future<void> onPlayback(PlaybackEvent e) async {
    final event = scrobbleEventFor(
      metaId: e.metaId,
      videoId: e.videoId,
      action: switch (e.action) {
        PlaybackAction.start => ScrobbleAction.start,
        PlaybackAction.pause => ScrobbleAction.pause,
        PlaybackAction.stop => ScrobbleAction.stop,
      },
      progress: e.progress,
      at: _now().toUtc(),
    );
    if (event == null) return; // sans identifiant IMDb : ignoré
    for (final id in await activeTrackers(e.profileId)) {
      await _submit(e.profileId, id, event);
    }
  }

  Future<void> _submit(
    String profileId,
    String trackerId,
    ScrobbleEvent event,
  ) async {
    await queue.submit(profileId, trackerId, event);
  }

  /// Début de l'autorisation d'appareil (code à afficher à l'utilisateur).
  /// Lève [TrackerNotConfigured] sans identifiants d'application.
  Future<DeviceCode> beginAuth(String trackerId) async {
    if (!configured(trackerId)) throw const TrackerNotConfigured();
    return (await trackerFor(trackerId, '')).startDeviceAuth();
  }

  /// Attend l'accord de l'utilisateur puis enregistre le jeton du profil et
  /// rejoue la file. Lève [TrackerAuthDenied], [TrackerAuthExpired] ou
  /// [CancelledPoll].
  Future<void> completeAuth(
    String profileId,
    String trackerId,
    DeviceCode code, {
    Future<void> Function(Duration d)? sleep,
    bool Function()? isCancelled,
  }) async {
    final token = await waitForDeviceToken(
      await trackerFor(trackerId, ''),
      code,
      sleep: sleep,
      isCancelled: isCancelled,
    );
    await repo.saveToken(trackerId, profileId, token);
    unawaited(queue.flush().then((_) {}, onError: (Object _) {}));
  }

  /// Déconnexion : jeton révoqué (au mieux), oublié, entrées en attente
  /// abandonnées.
  Future<void> disconnect(String profileId, String trackerId) async {
    try {
      final t = await trackerFor(trackerId, profileId);
      if (t is TraktClient) await t.revoke();
    } on Object {
      // La déconnexion locale suffit.
    }
    await repo.clearToken(trackerId, profileId);
    await repo.setReauth(trackerId, profileId, false);
    await queue.discard(profileId, trackerId);
  }

  /// Rejoue la file (« Réessayer », démarrage).
  Future<FlushResult> flush() => queue.flush();
}

/// Envoi réel d'une entrée de la file (jeton du profil concerné). Un jeton
/// refusé lève le drapeau « reconnexion requise » du profil.
ScrobbleSender scrobbleSender(
  TrackingRepository repo,
  Future<Tracker> Function(String trackerId, String profileId) trackerFor,
) => (profileId, trackerId, e) async {
  try {
    await (await trackerFor(trackerId, profileId)).scrobble(e);
  } on TrackerReauthRequired {
    await repo.setReauth(trackerId, profileId, true);
    rethrow;
  }
};
