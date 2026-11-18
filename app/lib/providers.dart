import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/db_connection.dart';
import 'package:lumio/data/secret_store.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(openAppDatabase());
  ref.onDispose(db.close);
  return db;
});

final secretStoreProvider = Provider<SecretStore>((ref) => SecureSecretStore());

final addonRepositoryProvider = Provider<AddonRepository>(
  (ref) => AddonRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(secretStoreProvider),
  ),
);

/// Liste des addons installés ; chaque mutation recharge la liste.
final addonsProvider =
    AsyncNotifierProvider<AddonsController, List<InstalledAddon>>(
      AddonsController.new,
    );

class AddonsController extends AsyncNotifier<List<InstalledAddon>> {
  AddonRepository get _repo => ref.read(addonRepositoryProvider);

  @override
  Future<List<InstalledAddon>> build() => _repo.list();

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.list);
  }

  Future<void> _then(Future<void> Function() op) async {
    await op();
    state = AsyncData(await _repo.list());
  }

  Future<void> remove(String id) => _then(() => _repo.remove(id));

  Future<void> setEnabled(String id, bool on) =>
      _then(() => _repo.setEnabled(id, on));

  /// Déplace l'addon d'une position ([delta] -1 = vers le haut).
  Future<void> move(String id, int delta) async {
    final ids = [...?state.value?.map((a) => a.id)];
    final i = ids.indexOf(id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= ids.length) return;
    ids.insert(j, ids.removeAt(i));
    await _then(() => _repo.reorder(ids));
  }

  /// À appeler après une installation réussie.
  Future<void> refresh() async => state = AsyncData(await _repo.list());
}
