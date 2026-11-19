import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/features/addons/catalog_providers.dart';
import 'package:lumio/features/addons/catalog_tab.dart' show catalogChips;
import 'package:lumio/features/addons/health_providers.dart';
import 'package:lumio/features/phone/lan_address.dart';
import 'package:lumio/features/phone/phone_add.dart';
import 'package:lumio/features/phone/phone_server.dart';
import 'package:lumio/providers.dart';
import 'package:lumio_core/lumio_core.dart';

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

  @override
  Future<List<PhoneCatalogItem>> catalog() async {
    final r = await _ref
        .read(addonCatalogServiceProvider)
        .list(CatalogQuery(categories: catalogChips.first.categories));
    return [
      for (final e in r.value.entries)
        PhoneCatalogItem(
          slug: e.slug,
          name: e.name,
          description: e.description,
        ),
    ];
  }

  @override
  Future<PhoneCatalogChoice?> catalogChoice(String slug) async {
    final service = _ref.read(addonCatalogServiceProvider);
    final page = await service.list(
      CatalogQuery(categories: catalogChips.first.categories),
    );
    CatalogEntry? entry;
    for (final e in page.value.entries) {
      if (e.slug == slug) entry = e;
    }
    if (entry == null) return null;
    var instances = entry.instances;
    if (instances.isEmpty) {
      instances = (await service.detail(slug)).value.instances;
    }
    if (instances.isEmpty) return null;
    // Une instance utilisable sans réglage d'abord, sinon la première.
    final pick = instances.firstWhere(
      (i) => !i.configurationRequired,
      orElse: () => instances.first,
    );
    return PhoneCatalogChoice(
      install: pick.manifestUrl,
      required: pick.configurationRequired,
      configure: pick.configureUrl,
    );
  }

  @override
  Future<Uri?> reconfigureUrl(String id) async {
    final url = await _ref.read(addonRepositoryProvider).urlOf(id);
    if (url.host.isEmpty) return null;
    return Uri(
      scheme: url.scheme,
      host: url.host,
      port: url.hasPort ? url.port : null,
      path: '/configure',
    );
  }
}
