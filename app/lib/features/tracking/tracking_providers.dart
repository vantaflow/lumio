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

final trackingFetcherProvider = Provider<HttpPostFetcher>(
  (ref) => IoHttpFetcher(),
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
      final fetcher = ref.watch(trackingFetcherProvider);
      final clock = ref.watch(trackingClockProvider);
      return (id, profileId) async {
        final token = profileId.isEmpty
            ? null
            : await repo.token(id, profileId);
        return TraktClient(
          fetcher,
          clientId: creds.id,
          clientSecret: creds.secret,
          token: token,
          now: clock,
          onToken: (t) => t == null
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

final trackingServiceProvider = Provider<TrackingService>((ref) {
  final creds = ref.watch(traktCredentialsProvider);
  return TrackingService(
    repo: ref.watch(trackingRepositoryProvider),
    profiles: ref.watch(profileRepositoryProvider),
    queue: ref.watch(scrobbleQueueProvider),
    now: ref.watch(trackingClockProvider),
    configured: (id) =>
        id == traktId && creds.id.isNotEmpty && creds.secret.isNotEmpty,
    trackerFor: ref.watch(trackerFactoryProvider),
  );
});

/// État du suivi Trakt d'un profil, pour l'écran des réglages.
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

final trackingStatusProvider = FutureProvider.family<TrackingStatus, String>((
  ref,
  profileId,
) async {
  final creds = ref.watch(traktCredentialsProvider);
  final repo = ref.watch(trackingRepositoryProvider);
  return TrackingStatus(
    configured: creds.id.isNotEmpty && creds.secret.isNotEmpty,
    connected: await repo.token(traktId, profileId) != null,
    reauthRequired: await repo.reauthRequired(traktId, profileId),
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
