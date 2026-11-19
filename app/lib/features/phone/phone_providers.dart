import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/features/addons/catalog_providers.dart';
import 'package:lumio/features/addons/catalog_tab.dart'
    show
        catalogCardMeta,
        catalogChips,
        catalogMoreCategories,
        catalogMoreLabel,
        chipLabel;
import 'package:lumio/features/addons/health_providers.dart';
import 'package:lumio/features/phone/lan_address.dart';
import 'package:lumio/features/phone/phone_add.dart';
import 'package:lumio/features/phone/phone_server.dart';
import 'package:lumio/l10n/app_localizations.dart';
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
  Future<PhoneCatalogPage> catalog({
    required String lang,
    String? chip,
    String? more,
    int page = 1,
    bool refresh = false,
  }) async {
    final l = lookupAppLocalizations(Locale(lang == 'en' ? 'en' : 'fr'));
    final chipId = catalogChips.any((c) => c.id == chip) ? chip! : 'popular';
    final moreId = catalogMoreCategories.contains(more) ? more : null;
    final categories = moreId != null
        ? [moreId]
        : catalogChips.firstWhere((c) => c.id == chipId).categories;
    final r = await _ref
        .read(addonCatalogServiceProvider)
        .list(
          CatalogQuery(categories: categories, page: page),
          refresh: refresh && page == 1,
        );
    final installed = <String>{
      for (final a in await _ref.read(addonsProvider.future))
        a.name.trim().toLowerCase(),
    };
    return PhoneCatalogPage(
      chips: [for (final c in catalogChips) (c.id, chipLabel(c.id, l))],
      more: [for (final c in catalogMoreCategories) (c, catalogMoreLabel(c, l))],
      chip: chipId,
      moreSelected: moreId,
      moreLabel: moreId == null ? null : catalogMoreLabel(moreId, l),
      page: r.value.page,
      hasMore: r.value.hasMore,
      note: switch (r.origin) {
        CatalogOrigin.staleCache => 'offline',
        CatalogOrigin.fallback => 'fallback',
        _ => null,
      },
      cards: [
        for (final e in r.value.entries)
          PhoneCatalogCard(
            slug: e.slug,
            name: e.name,
            description: e.description,
            logo: e.logo,
            meta: catalogCardMeta(e, l),
            installed: installed.contains(e.name.trim().toLowerCase()),
          ),
      ],
    );
  }

  @override
  Future<PhoneCatalogChoice?> catalogChoice(String slug) async {
    final d = (await _ref.read(addonCatalogServiceProvider).detail(slug)).value;
    final instances = d.instances;
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
