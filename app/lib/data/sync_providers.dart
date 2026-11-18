import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/config.dart';
import 'package:lumio/data/addon_sync.dart';
import 'package:lumio/data/sync_service.dart';
import 'package:lumio/data/sync_store.dart';
import 'package:lumio/features/settings/settings_providers.dart';
import 'package:lumio/providers.dart';

/// Client du serveur ; nul (synchronisation absente) si `backendUrl` est vide
/// ou invalide.
final syncApiClientProvider = Provider<SyncApiClient?>((ref) {
  if (backendUrl.isEmpty) return null;
  try {
    return SyncApiClient(backendUrl, ref.watch(secretStoreProvider));
  } on SyncException {
    return null;
  }
});

/// Addons chiffrés côté client (phrase secrète).
final addonSyncProvider = Provider<AddonSync>(
  (ref) => AddonSync(
    ref.watch(appDatabaseProvider),
    ref.watch(secretStoreProvider),
    ref.watch(addonRepositoryProvider),
  ),
);

final syncStoreProvider = Provider<DriftLocalSyncStore>(
  (ref) => DriftLocalSyncStore(
    ref.watch(appDatabaseProvider),
    addons: ref.watch(addonSyncProvider),
  ),
);

/// Service de synchronisation ; nul sans backend. Démarré et arrêté selon le
/// premier plan (voir `main.dart`).
final syncServiceProvider = Provider<SyncService?>((ref) {
  final api = ref.watch(syncApiClientProvider);
  if (api == null) return null;
  final service = SyncService(
    api: api,
    store: ref.watch(syncStoreProvider),
    addons: ref.watch(addonSyncProvider),
    onApplied: () {
      // Addons installés ou retirés par une réception.
      ref.read(addonsProvider.notifier).refresh().then((_) {}, onError: (_) {});
      // Profils, langue : relus depuis la base après une réception.
      ref.invalidate(localeProvider);
      ref.read(profilesProvider.notifier).reload().then((_) {
        final current = ref.read(currentProfileProvider);
        final list = ref.read(profilesProvider).value;
        if (current != null &&
            list != null &&
            !list.any((p) => p.id == current.id)) {
          ref.read(currentProfileProvider.notifier).select(null);
        }
      }, onError: (_) {});
    },
  );
  ref.onDispose(service.dispose);
  return service;
});

/// État de la synchronisation, pour l'écran Compte.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) async* {
  final s = ref.watch(syncServiceProvider);
  if (s == null) return;
  yield s.status;
  yield* s.statusStream;
});

/// État de la synchronisation des addons, pour l'écran Compte ; recalculé à
/// chaque changement d'état de la synchronisation (invalider après une action).
final addonSyncStateProvider = FutureProvider.autoDispose<AddonSyncState>((
  ref,
) {
  ref.watch(syncStatusProvider);
  return ref.watch(addonSyncProvider).state();
});
