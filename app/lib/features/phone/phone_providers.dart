import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/features/addons/health_providers.dart';
import 'package:lumio/features/phone/lan_address.dart';
import 'package:lumio/features/phone/phone_add.dart';
import 'package:lumio/features/phone/phone_server.dart';
import 'package:lumio/providers.dart';

/// Adresse du réseau local ; remplacée en test.
final lanAddressSourceProvider = Provider<LanAddressSource>(
  (ref) => const PlatformLanAddress(),
);

/// Adresse locale pour afficher « IP:port » sur la carte du rail des Réglages
/// (rien n'écoute à ce stade).
final lanAddressProvider = FutureProvider.autoDispose<InternetAddress?>(
  (ref) => ref.watch(lanAddressSourceProvider).current(),
);

/// Crée le serveur du téléphone (un par ouverture de l'écran) ; remplacé en
/// test par un faux.
typedef PhoneSessionFactory = PhoneSession Function(String lang);

final phoneSessionFactoryProvider = Provider<PhoneSessionFactory>(
  (ref) =>
      (lang) => PhoneServer(
        backend: AppPhoneBackend(ref),
        adds: PhoneAddCoordinator(),
        lan: ref.read(lanAddressSourceProvider),
        lang: lang,
      ),
);

/// Gestion des addons depuis le téléphone, par les opérations existantes du
/// dépôt d'addons (`AddonsController`).
class AppPhoneBackend implements PhoneBackend {
  AppPhoneBackend(this._ref);

  final Ref _ref;

  @override
  Future<List<PhoneAddonView>> addons() async {
    final list = await _ref.read(addonsProvider.future);
    final tracker = _ref.read(healthTrackerProvider);
    return [
      for (final (i, a) in list.indexed)
        PhoneAddonView(
          id: a.id,
          name: a.name,
          types: [...?a.manifest?.types],
          health: tracker.stats(a.id).level.name,
          enabled: a.enabled,
          position: i,
          broken: a.broken,
        ),
    ];
  }

  @override
  Future<void> move(String id, int delta) =>
      _ref.read(addonsProvider.notifier).move(id, delta);

  @override
  Future<void> setEnabled(String id, bool on) =>
      _ref.read(addonsProvider.notifier).setEnabled(id, on);

  @override
  Future<void> remove(String id) =>
      _ref.read(addonsProvider.notifier).remove(id);
}
