import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/db_connection.dart';
import 'package:lumio/data/profile_repository.dart';
import 'package:lumio/data/progress_repository.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio/data/title_settings_store.dart';
import 'package:lumio/player/local_proxy.dart';
import 'package:lumio/player/subtitle_style.dart';
import 'package:lumio_core/lumio_core.dart' show AgeLimit;
export 'package:lumio/data/profile_repository.dart'
    show
        defaultProfileId,
        PinResult,
        Profile,
        ProfileLimitException,
        maxProfiles;

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(openAppDatabase());
  ref.onDispose(db.close);
  return db;
});

/// Proxy local du lecteur (HLS et en-têtes imposés), démarré à la demande.
final localProxyProvider = FutureProvider<LocalProxy>((ref) async {
  final proxy = await LocalProxy.start();
  ref.onDispose(proxy.close);
  return proxy;
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

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(appDatabaseProvider)),
);

/// Liste des profils ; le premier profil « Moi » est créé au premier
/// lancement.
final profilesProvider =
    AsyncNotifierProvider<ProfilesController, List<Profile>>(
      ProfilesController.new,
    );

class ProfilesController extends AsyncNotifier<List<Profile>> {
  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  @override
  Future<List<Profile>> build() async {
    await _repo.ensureDefault();
    return _repo.list();
  }

  Future<void> reload() async => state = AsyncData(await _repo.list());

  Future<Profile> create(
    String name, {
    AgeLimit? limit,
    bool isKid = false,
    bool locked = false,
  }) async {
    final p = await _repo.create(
      name,
      limit: limit,
      isKid: isKid,
      locked: locked,
    );
    await reload();
    return p;
  }

  Future<void> edit(
    String id, {
    String? name,
    AgeLimit? limit,
    bool? isKid,
    bool? locked,
  }) async {
    await _repo.update(
      id,
      name: name,
      limit: limit,
      isKid: isKid,
      locked: locked,
    );
    await reload();
    // Le profil actif suit ses propres modifications.
    final current = ref.read(currentProfileProvider);
    if (current?.id == id) {
      ref.read(currentProfileProvider.notifier).select(await _repo.get(id));
    }
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await reload();
    if (ref.read(currentProfileProvider)?.id == id) {
      ref.read(currentProfileProvider.notifier).select(null);
    }
  }
}

/// Profil actif ; nul tant que l'utilisateur n'a pas choisi (le sélecteur
/// de profils est alors affiché).
final currentProfileProvider =
    NotifierProvider<CurrentProfileController, Profile?>(
      CurrentProfileController.new,
    );

class CurrentProfileController extends Notifier<Profile?> {
  @override
  Profile? build() => null;

  void select(Profile? profile) {
    state = profile;
    final id = profile?.id;
    final repo = ref.read(profileRepositoryProvider);
    // Mémorisation best-effort : un échec n'empêche pas de changer de profil.
    (id == null ? repo.clearActive() : repo.setActive(id)).catchError((_) {});
  }
}

/// Profil actif juste avant l'ouverture du sélecteur depuis l'accueil :
/// Retour dans le sélecteur le rétablit (audit D2) au lieu de quitter l'app.
final previousProfileProvider = NotifierProvider<_PreviousProfile, Profile?>(
  _PreviousProfile.new,
);

class _PreviousProfile extends Notifier<Profile?> {
  @override
  Profile? build() => null;

  // ignore: use_setters_to_change_properties
  void set(Profile? p) => state = p;
}

/// Vrai quand l'utilisateur a demandé la gestion des profils : le sélecteur
/// s'affiche même avec un seul profil (sinon il serait choisi seul et la
/// création de profils serait inaccessible).
final profileManagementRequestedProvider = NotifierProvider<_Flag, bool>(
  _Flag.new,
);

class _Flag extends Notifier<bool> {
  @override
  bool build() => false;

  // ignore: use_setters_to_change_properties
  void set(bool v) => state = v;
}

/// Identifiant du profil actif (le profil « default » tant qu'aucun n'est
/// choisi) ; à utiliser par les écrans qui lisent ou écrivent des données de
/// profil.
final currentProfileIdProvider = Provider<String>(
  (ref) =>
      ref.watch(currentProfileProvider.select((p) => p?.id)) ??
      defaultProfileId,
);

/// Réglages par titre du profil actif, préchargés depuis SQLite.
final titleSettingsStoreProvider = FutureProvider<DriftTitleSettingsStore>((
  ref,
) async {
  final store = DriftTitleSettingsStore(ref.watch(appDatabaseProvider));
  await store.load(ref.watch(currentProfileIdProvider));
  return store;
});

final subtitleStyleStoreProvider = Provider<SubtitleStyleStore>(
  (ref) => SubtitleStyleStore(ref.watch(appDatabaseProvider)),
);

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(ref.watch(appDatabaseProvider)),
);

/// Rangée « Continuer à regarder » du profil actif.
final continueWatchingProvider = StreamProvider<List<ProgressEntry>>(
  (ref) => ref
      .watch(progressRepositoryProvider)
      .continueWatching(ref.watch(currentProfileIdProvider)),
);
