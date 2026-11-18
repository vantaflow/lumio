import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/config.dart' as config;
import 'package:lumio/data/tracking_repository.dart';
import 'package:lumio/data/tracking_service.dart';
import 'package:lumio/features/settings/settings_providers.dart';
import 'package:lumio/providers.dart';
import 'package:lumio_core/lumio_core.dart';

/// Identifiants de l'application Trakt (surchargés dans les tests).
final traktCredentialsProvider = Provider<({String id, String secret})>(
  (ref) => (id: config.traktClientId, secret: config.traktClientSecret),
);

/// Identifiant de l'application Simkl (surchargé dans les tests).
final simklClientIdProvider = Provider<String>((ref) => config.simklClientId);

final trackingFetcherProvider = Provider<HttpPostFetcher>(
  (ref) => IoHttpFetcher(redirectGuard: UrlGuard.check),
);

/// Horloge du suivi (surchargée dans les tests).
final trackingClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final trackingRepositoryProvider = Provider<TrackingRepository>(
  (ref) => TrackingRepository(
    ref.watch(secretStoreProvider),
    ref.watch(appSettingsStoreProvider),
  ),
);

/// Fabrique de clients de suivi : jeton du profil, renouvellement persisté.
/// Un [profileId] vide donne un client sans jeton (autorisation d'appareil).
final trackerFactoryProvider =
    Provider<Future<Tracker> Function(String trackerId, String profileId)>((
      ref,
    ) {
      final repo = ref.watch(trackingRepositoryProvider);
      final creds = ref.watch(traktCredentialsProvider);
      final simkl = ref.watch(simklClientIdProvider);
      final fetcher = ref.watch(trackingFetcherProvider);
      final clock = ref.watch(trackingClockProvider);
      return (id, profileId) async {
        final token = profileId.isEmpty
            ? null
            : await repo.token(id, profileId);
        if (id == simklId) {
          // Jeton Simkl sans échéance : rien à renouveler ni à persister.
          return SimklClient(
            fetcher,
            clientId: simkl,
            token: token,
            now: clock,
          );
        }
        return TraktClient(
          fetcher,
          clientId: creds.id,
          clientSecret: creds.secret,
          token: token,
          now: clock,
          // Sans profil (autorisation d'appareil) : rien à persister.
          onToken: profileId.isEmpty
              ? null
              : (t) => t == null
                    ? repo.clearToken(id, profileId)
                    : repo.saveToken(id, profileId, t),
        );
      };
    });

final scrobbleQueueProvider = Provider<ScrobbleQueue>(
  (ref) => ScrobbleQueue(
    DriftScrobbleStore(ref.watch(appDatabaseProvider)),
    scrobbleSender(
      ref.watch(trackingRepositoryProvider),
      ref.watch(trackerFactoryProvider),
    ),
    now: ref.watch(trackingClockProvider),
  ),
);

/// Identifiants du service [id] présents ?
bool _configured(Ref ref, String id) {
  if (id == simklId) return ref.watch(simklClientIdProvider).isNotEmpty;
  final creds = ref.watch(traktCredentialsProvider);
  return id == traktId && creds.id.isNotEmpty && creds.secret.isNotEmpty;
}

final trackingServiceProvider = Provider<TrackingService>((ref) {
  final configured = {for (final id in trackerIds) id: _configured(ref, id)};
  return TrackingService(
    repo: ref.watch(trackingRepositoryProvider),
    profiles: ref.watch(profileRepositoryProvider),
    queue: ref.watch(scrobbleQueueProvider),
    now: ref.watch(trackingClockProvider),
    configured: (id) => configured[id] ?? false,
    trackerFor: ref.watch(trackerFactoryProvider),
  );
});

/// État du suivi d'un service pour un profil, pour l'écran des réglages.
class TrackingStatus {
  const TrackingStatus({
    required this.configured,
    required this.connected,
    required this.reauthRequired,
    required this.pending,
    required this.kidAllowed,
  });

  final bool configured;
  final bool connected;
  final bool reauthRequired;
  final int pending;
  final bool kidAllowed;
}

final trackingStatusProvider =
    FutureProvider.family<
      TrackingStatus,
      ({String profileId, String trackerId})
    >((ref, key) async {
      final repo = ref.watch(trackingRepositoryProvider);
      final (:profileId, :trackerId) = key;
      return TrackingStatus(
        configured: _configured(ref, trackerId),
        connected: await repo.token(trackerId, profileId) != null,
        reauthRequired: await repo.reauthRequired(trackerId, profileId),
        pending: await ref.watch(scrobbleQueueProvider).pending(),
        kidAllowed: await repo.kidAllowed(profileId),
      );
    });

/// Attente entre deux interrogations de l'autorisation d'appareil
/// (surchargée dans les tests).
final trackingSleepProvider = Provider<Future<void> Function(Duration d)>(
  (ref) =>
      (d) => Future<void>.delayed(d),
);
