import 'dart:async';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/tracking_repository.dart' show traktId;
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
import 'package:lumio/features/tracking/tracking_providers.dart';
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
  (ref) => (lang) {
    final backend = AppPhoneBackend(ref);
    return PhoneServer(
      backend: backend,
      trakt: backend,
      adds: PhoneAddCoordinator(),
      lan: ref.read(lanAddressSourceProvider),
      lang: lang,
    );
  },
);

/// Gestion des addons depuis le téléphone, par les opérations existantes du
/// dépôt d'addons (`AddonsController`).
class AppPhoneBackend implements PhoneBackend, PhoneTraktBackend {
  AppPhoneBackend(this._ref);

  final Ref _ref;

  // --- Trakt : le flux de code d'appareil tourne ici ---
  DeviceCode? _code;
  DateTime? _until;
  String? _failure;
  int _run = 0;

  Future<PhoneTraktState> _traktNow({String? failure}) async {
    final profileId = _ref.read(currentProfileIdProvider);
    final repo = _ref.read(trackingRepositoryProvider);
    final configured = _ref.read(traktCredentialsProvider).id.isNotEmpty;
    final profile = _ref.read(currentProfileProvider);
    final blocked =
        (profile?.isKid ?? false) && !await repo.kidAllowed(profileId);
    final connected = await repo.token(traktId, profileId) != null;
    final code = _code;
    final until = _until;
    final live = code != null && until != null && until.isAfter(DateTime.now());
    return PhoneTraktState(
      configured: configured,
      connected: connected,
      blocked: blocked,
      userCode: connected || !live ? null : code.userCode,
      verificationUrl: connected || !live ? null : code.verificationUrl,
      expiresIn: connected || !live ? null : until.difference(DateTime.now()),
      failure: failure ?? _failure,
    );
  }

  @override
  Future<PhoneTraktState> traktState() => _traktNow();

  @override
  Future<PhoneTraktState> traktConnect() async {
    final now = await _traktNow();
    if (!now.configured) return _traktNow(failure: 'not_configured');
    if (now.blocked || now.connected) return now;
    final profileId = _ref.read(currentProfileIdProvider);
    final service = _ref.read(trackingServiceProvider);
    final run = ++_run;
    _failure = null;
    final DeviceCode code;
    try {
      code = await service.beginAuth(traktId);
    } on Object {
      _failure = 'unavailable';
      return _traktNow();
    }
    _code = code;
    _until = DateTime.now().add(code.expiresIn);
    unawaited(_wait(run, profileId, code));
    return _traktNow();
  }

  Future<void> _wait(int run, String profileId, DeviceCode code) async {
    try {
      await _ref
          .read(trackingServiceProvider)
          .completeAuth(
            profileId,
            traktId,
            code,
            sleep: _ref.read(trackingSleepProvider),
            isCancelled: () => run != _run,
          );
      if (run != _run) return;
      _code = null;
      _ref.invalidate(
        trackingStatusProvider((profileId: profileId, trackerId: traktId)),
      );
    } on CancelledPoll {
      // Nouvelle demande ou déconnexion.
    } on TrackerAuthDenied {
      if (run == _run) _fail('denied');
    } on TrackerAuthExpired {
      if (run == _run) _fail('expired');
    } on Object {
      if (run == _run) _fail('unavailable');
    }
  }

  void _fail(String f) {
    _code = null;
    _failure = f;
  }

  @override
  Future<void> traktDisconnect() async {
    _run++;
    _code = null;
    _failure = null;
    final profileId = _ref.read(currentProfileIdProvider);
    await _ref.read(trackingServiceProvider).disconnect(profileId, traktId);
    _ref.invalidate(
      trackingStatusProvider((profileId: profileId, trackerId: traktId)),
    );
  }

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
          configurable: a.manifest?.configurable != false,
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
    final service = _ref.read(addonCatalogServiceProvider);
    CatalogResult<CatalogPage>? official;
    if (chipId == 'official' && moreId == null && page == 1) {
      try {
        official = await service.official(refresh: refresh);
      } catch (_) {}
    }
    var r = CatalogResult(
      CatalogPage(entries: const [], total: 0),
      CatalogOrigin.network,
      DateTime.now(),
    );
    try {
      r = await service.list(
        CatalogQuery(categories: categories, page: page),
        refresh: refresh && page == 1,
      );
    } catch (_) {
      if (official == null) rethrow;
    }
    final entries = official == null
        ? r.value.entries
        : AddonCatalogService.mergeOfficial(
            official.value.entries,
            r.value.entries,
          );
    final installed = <String>{
      for (final a in await _ref.read(addonsProvider.future))
        a.name.trim().toLowerCase(),
    };
    return PhoneCatalogPage(
      chips: [for (final c in catalogChips) (c.id, chipLabel(c.id, l))],
      more: [
        for (final c in catalogMoreCategories) (c, catalogMoreLabel(c, l)),
      ],
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
        for (final e in entries)
          PhoneCatalogCard(
            slug: e.slug,
            name: e.name,
            description: e.description,
            logo: e.logo,
            meta: catalogCardMeta(e, l),
            setup: e.instances.any(
              (i) => i.configurable || i.configurationRequired,
            ),
            installed: installed.contains(e.name.trim().toLowerCase()),
          ),
      ],
    );
  }

  @override
  Future<PhoneCatalogCard?> catalogCard(String slug) async {
    final off = await _officialEntry(slug);
    if (off != null) {
      final installed = <String>{
        for (final a in await _ref.read(addonsProvider.future))
          a.name.trim().toLowerCase(),
      };
      return PhoneCatalogCard(
        slug: off.slug,
        name: off.name,
        description: off.description,
        logo: off.logo,
        meta: '',
        installed: installed.contains(off.name.trim().toLowerCase()),
      );
    }
    final d = (await _ref.read(addonCatalogServiceProvider).detail(slug)).value;
    final installed = <String>{
      for (final a in await _ref.read(addonsProvider.future))
        a.name.trim().toLowerCase(),
    };
    return PhoneCatalogCard(
      slug: d.slug,
      name: d.name,
      description: d.description,
      logo: d.logo,
      meta: '',
      installed: installed.contains(d.name.trim().toLowerCase()),
    );
  }

  @override
  Future<PhoneCatalogChoice?> catalogChoice(String slug) async {
    final off = await _officialEntry(slug);
    final instances =
        off?.instances ??
        (await _ref.read(addonCatalogServiceProvider).detail(slug))
            .value
            .instances;
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

  /// Entrée de la collection officielle (déjà en cache après l'affichage de
  /// la puce « Officiels ») ; `null` pour un addon du site.
  Future<CatalogEntry?> _officialEntry(String slug) async {
    try {
      final r = await _ref.read(addonCatalogServiceProvider).official();
      for (final e in r.value.entries) {
        if (e.slug == slug) return e;
      }
    } catch (_) {}
    return null;
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
