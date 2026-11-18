import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/app_settings.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/main.dart' show LumioApp;
import 'package:lumio/data/secret_store.dart';
import 'package:lumio/features/detail/playback_service.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/features/settings/settings_providers.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/player/player_screen.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/focus/tv_detection.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

import 'fake_addon_fetcher.dart';

/// Addon factice unique : catalogue + fiche + flux.
final fakeManifest = AddonManifest(
  id: 'org.fake',
  version: '1.0.0',
  name: 'Addon factice',
  types: const ['movie'],
  resources: const [
    AddonResource('catalog'),
    AddonResource('meta'),
    AddonResource('stream'),
  ],
  catalogs: const [CatalogDecl(type: 'movie', id: 'top', name: 'Populaires')],
  transportUrl: Uri.parse('https://a.example.com/tok/manifest.json'),
);

const fakeItems = [
  MetaPreview(
    id: 'tt1',
    type: 'movie',
    name: 'Big Buck Bunny',
    sourceAddonId: 'org.fake',
    releaseInfo: '2008',
  ),
  MetaPreview(
    id: 'tt2',
    type: 'movie',
    name: 'Sintel',
    sourceAddonId: 'org.fake',
    releaseInfo: '2010',
  ),
];

class FakeAddonsController extends AddonsController {
  @override
  Future<List<InstalledAddon>> build() async => [
    InstalledAddon(
      id: 'fake',
      manifest: fakeManifest,
      position: 0,
      enabled: true,
    ),
  ];
}

class FakeAggregator implements CatalogAggregator {
  @override
  Stream<CatalogRow> rows(List<AddonManifest> addons) async* {
    yield const CatalogRow(
      addonId: 'org.fake',
      catalogId: 'top',
      type: 'movie',
      title: 'Populaires',
      items: fakeItems,
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Client d'addons factice : une fiche et un flux direct par titre.
class FakeClient extends AddonClient {
  FakeClient() : super(FakeAddonFetcher());

  @override
  Future<Map<String, dynamic>?> rawMeta(
    AddonManifest a,
    String type,
    String id,
  ) async => {
    'name': id == 'tt2' ? 'Sintel' : 'Big Buck Bunny',
    'description': 'Un court métrage libre de droits.',
    'releaseInfo': '2008',
  };

  @override
  Future<List<Map<String, dynamic>>> rawStreams(
    AddonManifest a,
    String type,
    String id,
  ) async => [
    {
      'name': '1080p',
      'title': 'Film VF 1080p',
      'url': 'https://cdn.example.com/$id.mp4',
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> rawSubtitles(
    AddonManifest a,
    String type,
    String id,
  ) async => const [];
}

/// Environnement de test commun (accessibilité, flux TV) : base mémoire,
/// addon factice, taille d'écran et détection TV réglables.
class AppHarness {
  AppHarness(
    this.t, {
    this.size = const Size(1920, 1080),
    this.tv = true,
    this.resizeView = true,
  });

  final WidgetTester t;
  final Size size;
  final bool tv;

  /// Faux sur un appareil réel (test d'intégration) : garde l'écran réel.
  final bool resizeView;
  late AppDatabase db;
  late ProviderContainer container;
  final players = <PlayerScreen>[];

  List<Override> _overrides(List<Override> extra) => [
    appDatabaseProvider.overrideWithValue(db),
    androidTvProvider.overrideWithValue(tv),
    addonsProvider.overrideWith(FakeAddonsController.new),
    addonRepositoryProvider.overrideWithValue(
      AddonRepository(
        db,
        MemorySecretStore(),
        clientFactory: ({required allowPrivate}) =>
            AddonClient(FakeAddonFetcher(), allowPrivate: allowPrivate),
      ),
    ),
    aggregatorFactoryProvider.overrideWithValue(
      ({required bool allowPrivate}) => FakeAggregator(),
    ),
    continueWatchingProvider.overrideWith((ref) => Stream.value(const [])),
    addonClientProvider.overrideWithValue(FakeClient()),
    playerBuilderProvider.overrideWithValue((screen) {
      players.add(screen);
      return const Scaffold(body: Text('PLAYER'));
    }),
    appVersionProvider.overrideWith((ref) async => '1.0.0'),
    ...extra,
  ];

  void _prepare(List<Override> extra) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    if (resizeView) {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
    }
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: _overrides(extra));
    addTearDown(container.dispose);
  }

  Future<void> pump(Widget home, {List<Override> extra = const []}) async {
    _prepare(extra);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: LumioTheme.dark(tv: tv),
            locale: ref.watch(localeProvider),
            supportedLocales: supportedUiLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => LumioThemeScope(tv: tv, child: child!),
            home: home,
          ),
        ),
      ),
    );
    await settle();
  }

  /// Lance l'application complète ([LumioApp] : assistant de premier
  /// lancement, choix du profil, accueil) avec l'addon factice ; l'assistant
  /// est marqué terminé et l'unique profil est choisi seul.
  Future<void> pumpApp({List<Override> extra = const []}) async {
    _prepare(extra);
    await t.runAsync(
      () => AppSettingsStore(db).write(AppSettingsStore.onboardingDoneKey, '1'),
    );
    await t.pumpWidget(
      UncontrolledProviderScope(container: container, child: const LumioApp()),
    );
    await settle(12);
  }

  Future<void> settle([int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> close() async {
    await t.pumpWidget(const SizedBox());
    container.dispose();
    await t.pump(const Duration(milliseconds: 50));
    await t.runAsync(db.close);
  }
}
