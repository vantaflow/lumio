import 'dart:async';

/// Code d'autorisation d'appareil : l'utilisateur saisit [userCode] sur
/// [verificationUrl] depuis un autre appareil.
///
/// Ni [userCode] ni [deviceCode] ne doivent finir dans un journal.
class DeviceCode {
  const DeviceCode({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUrl,
    required this.expiresIn,
    required this.interval,
  });

  final String deviceCode;
  final String userCode;
  final Uri verificationUrl;
  final Duration expiresIn;

  /// Délai minimal entre deux interrogations.
  final Duration interval;

  @override
  String toString() => 'DeviceCode(<masqué>)';
}

/// Jeton d'accès d'un service de suivi. Stocké dans le `SecretStore`.
class TrackerToken {
  const TrackerToken({
    required this.access,
    required this.refresh,
    required this.expiresAt,
  });

  factory TrackerToken.fromJson(Map<String, dynamic> j) => TrackerToken(
    access: j['access'] as String,
    refresh: (j['refresh'] as String?) ?? '',
    expiresAt: DateTime.fromMillisecondsSinceEpoch(
      j['expiresAt'] as int,
      isUtc: true,
    ),
  );

  final String access;
  final String refresh;
  final DateTime expiresAt;

  Map<String, Object?> toJson() => {
    'access': access,
    'refresh': refresh,
    'expiresAt': expiresAt.millisecondsSinceEpoch,
  };

  /// Expire dans moins de [margin] (ou déjà expiré).
  bool expiresWithin(Duration margin, DateTime now) =>
      !expiresAt.isAfter(now.add(margin));

  @override
  String toString() => 'TrackerToken(<masqué>)';
}

enum ScrobbleAction { start, pause, stop }

/// Événement de lecture à signaler. Le titre est identifié par son id IMDb
/// (`tt…`) ; un épisode porte [season] et [episode].
class ScrobbleEvent {
  const ScrobbleEvent({
    required this.action,
    required this.imdbId,
    required this.progress,
    required this.at,
    this.season,
    this.episode,
  });

  factory ScrobbleEvent.fromJson(Map<String, dynamic> j) => ScrobbleEvent(
    action: ScrobbleAction.values.byName(j['action'] as String),
    imdbId: j['imdb'] as String,
    season: j['season'] as int?,
    episode: j['episode'] as int?,
    progress: (j['progress'] as num).toDouble(),
    at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int, isUtc: true),
  );

  final ScrobbleAction action;
  final String imdbId;
  final int? season;
  final int? episode;

  /// Avancement en pourcentage (0 à 100).
  final double progress;

  /// Instant de l'événement (pour ignorer un `start` périmé au rejeu).
  final DateTime at;

  bool get isEpisode => season != null && episode != null;

  Map<String, Object?> toJson() => {
    'action': action.name,
    'imdb': imdbId,
    'season': ?season,
    'episode': ?episode,
    'progress': progress,
    'at': at.millisecondsSinceEpoch,
  };

  /// Deux événements identiques (même action, même titre, même avancement au
  /// dixième près) : le second est inutile.
  bool sameAs(ScrobbleEvent o) =>
      action == o.action &&
      imdbId == o.imdbId &&
      season == o.season &&
      episode == o.episode &&
      (progress * 10).round() == (o.progress * 10).round();
}

/// Extrait l'id IMDb et l'épisode d'un identifiant Lumio (`tt1`, `tt1:2:3`).
/// `null` pour tout autre identifiant (local, Jellyfin, série sans épisode…).
ScrobbleEvent? scrobbleEventFor({
  required String? metaId,
  required String? videoId,
  required ScrobbleAction action,
  required double progress,
  required DateTime at,
}) {
  final id = videoId ?? metaId;
  if (id == null) return null;
  final m = _ids.firstMatch(id);
  if (m == null) return null;
  final season = m.group(2);
  final episode = m.group(3);
  return ScrobbleEvent(
    action: action,
    imdbId: m.group(1)!,
    season: season == null ? null : int.parse(season),
    episode: episode == null ? null : int.parse(episode),
    progress: progress.isNaN ? 0 : progress.clamp(0, 100).toDouble(),
    at: at,
  );
}

final _ids = RegExp(r'^(tt\d+)(?::(\d{1,4}):(\d{1,5}))?$');

/// Service de suivi (Trakt) : autorisation d'appareil et scrobbling.
abstract class Tracker {
  Future<DeviceCode> startDeviceAuth();

  /// Une interrogation : le jeton une fois l'utilisateur d'accord, `null`
  /// tant que l'autorisation est en attente. Lève [TrackerSlowDown],
  /// [TrackerAuthDenied] ou [TrackerAuthExpired].
  Future<TrackerToken?> pollToken(DeviceCode c);

  Future<void> scrobble(ScrobbleEvent e);
}

/// Erreurs des services de suivi. Les messages ne contiennent jamais de jeton
/// ni de code utilisateur.
sealed class TrackerException implements Exception {
  const TrackerException();
}

/// Identifiants d'application absents : rien n'est envoyé.
class TrackerNotConfigured extends TrackerException {
  const TrackerNotConfigured();
  @override
  String toString() => 'TrackerNotConfigured';
}

/// Jeton refusé (même après renouvellement) ou absent : reconnexion
/// nécessaire.
class TrackerReauthRequired extends TrackerException {
  const TrackerReauthRequired();
  @override
  String toString() => 'TrackerReauthRequired';
}

/// Service injoignable ou en panne (réseau, délai, 5xx, 429) : à réessayer.
class TrackerUnavailable extends TrackerException {
  const TrackerUnavailable([this.status]);
  final int? status;
  @override
  String toString() => 'TrackerUnavailable(${status ?? '-'})';
}

/// Requête refusée définitivement (titre inconnu, 4xx) : inutile de réessayer.
class TrackerRejected extends TrackerException {
  const TrackerRejected(this.status);
  final int status;
  @override
  String toString() => 'TrackerRejected($status)';
}

/// Le service demande d'espacer les interrogations (429).
class TrackerSlowDown extends TrackerException {
  const TrackerSlowDown();
  @override
  String toString() => 'TrackerSlowDown';
}

/// L'utilisateur a refusé l'autorisation.
class TrackerAuthDenied extends TrackerException {
  const TrackerAuthDenied();
  @override
  String toString() => 'TrackerAuthDenied';
}

/// Code expiré, invalide ou déjà utilisé : recommencer.
class TrackerAuthExpired extends TrackerException {
  const TrackerAuthExpired();
  @override
  String toString() => 'TrackerAuthExpired';
}

/// Interroge [tracker] au rythme demandé jusqu'à l'obtention du jeton.
///
/// Un `slow down` allonge l'intervalle de 5 s. Lève [TrackerAuthExpired] à
/// l'expiration du code, [TrackerAuthDenied] en cas de refus, ou
/// [CancelledPoll] si [isCancelled] devient vrai. Une panne passagère
/// ([TrackerUnavailable]) ne coupe pas la boucle.
Future<TrackerToken> waitForDeviceToken(
  Tracker tracker,
  DeviceCode code, {
  Future<void> Function(Duration d)? sleep,
  DateTime Function()? now,
  bool Function()? isCancelled,
}) async {
  final wait = sleep ?? ((d) => Future<void>.delayed(d));
  final clock = now ?? DateTime.now;
  final deadline = clock().add(code.expiresIn);
  var interval = code.interval;
  while (true) {
    await wait(interval);
    if (isCancelled?.call() ?? false) throw const CancelledPoll();
    if (!clock().isBefore(deadline)) throw const TrackerAuthExpired();
    try {
      final t = await tracker.pollToken(code);
      if (t != null) return t;
    } on TrackerSlowDown {
      interval += const Duration(seconds: 5);
    } on TrackerUnavailable {
      // Réessayé au prochain tour.
    }
  }
}

/// La boucle d'autorisation a été annulée par l'appelant.
class CancelledPoll implements Exception {
  const CancelledPoll();
}
