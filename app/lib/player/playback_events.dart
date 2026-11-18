import 'dart:async';

/// Moment du cycle de lecture signalé aux écouteurs.
enum PlaybackAction { start, pause, stop }

/// Événement de lecture (début, pause, arrêt) d'un titre identifié.
class PlaybackEvent {
  const PlaybackEvent({
    required this.action,
    required this.profileId,
    required this.metaId,
    required this.videoId,
    required this.progress,
  });

  final PlaybackAction action;
  final String profileId;

  /// Titre ou série (`tt1`) et épisode lu (`tt1:1:2`) ; peuvent être nuls pour
  /// une lecture sans identifiant.
  final String? metaId;
  final String? videoId;

  /// Avancement en pourcentage (0 à 100).
  final double progress;
}

typedef PlaybackListener = FutureOr<void> Function(PlaybackEvent e);

/// Point d'accroche du lecteur : le lecteur émet, les services (suivi
/// Trakt…) écoutent. Une erreur d'un écouteur n'atteint jamais la lecture.
class PlaybackEvents {
  final _listeners = <PlaybackListener>[];

  void addListener(PlaybackListener l) => _listeners.add(l);
  void removeListener(PlaybackListener l) => _listeners.remove(l);

  void emit(PlaybackEvent e) {
    for (final l in List.of(_listeners)) {
      try {
        final r = l(e);
        if (r is Future<void>) unawaited(r.catchError((Object _) {}));
      } on Object {
        // Un écouteur défaillant ne doit pas gêner la lecture.
      }
    }
  }
}
