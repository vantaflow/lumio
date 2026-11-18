import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/config.dart';
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

final syncStoreProvider = Provider<DriftLocalSyncStore>(
  (ref) => DriftLocalSyncStore(ref.watch(appDatabaseProvider)),
);

/// Service de synchronisation ; nul sans backend. Démarré et arrêté selon le
/// premier plan (voir `main.dart`).
final syncServiceProvider = Provider<SyncService?>((ref) {
  final api = ref.watch(syncApiClientProvider);
  if (api == null) return null;
  final service = SyncService(
    api: api,
    store: ref.watch(syncStoreProvider),
    onApplied: () {
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
