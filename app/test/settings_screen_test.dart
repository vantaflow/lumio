import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/app_settings.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/profile_repository.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio/data/stream_prefs.dart';
import 'package:lumio/features/detail/playback_service.dart';
import 'package:lumio/features/settings/settings_providers.dart';
import 'package:lumio/features/settings/settings_screen.dart';
import 'package:lumio/features/addons/addon_labels.dart';
import 'package:lumio/l10n/app_localizations_en.dart';
import 'package:lumio/l10n/app_localizations_fr.dart';
import 'package:lumio/l10n/error_messages.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/player/playback_report.dart';
import 'package:lumio/player/tracks_controller.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/torrent/torrent_providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

import 'support/fake_addon_fetcher.dart';
import 'support/settings_nav.dart';
import 'support/fake_network.dart';
import 'tracks_panel_test.dart' show FakeBackend;

const _urlA = 'https://a.example.com/tok-a/manifest.json';
const _urlB = 'https://b.example.com/tok-b/manifest.json';

class _H {
  _H(this.tester);
  final WidgetTester tester;
  late AppDatabase db;
  late AddonRepository repo;
  late ProviderContainer container;

  void start({Profile? profile}) {
    db = AppDatabase(NativeDatabase.memory());
    final fetcher = FakeAddonFetcher({
      _urlA: sampleManifest(id: 'a', name: 'Alpha'),
      _urlB: sampleManifest(id: 'b', name: 'Bravo'),
    });
    repo = AddonRepository(
      db,
      MemorySecretStore(),
      clientFactory: ({required allowPrivate}) =>
          AddonClient(fetcher, allowPrivate: allowPrivate, retries: 0),
    );
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        addonRepositoryProvider.overrideWithValue(repo),
        appVersionProvider.overrideWith((ref) async => '1.2.3'),
        networkProbeProvider.overrideWithValue(
          FakeNetworkProbe(const [
            NetInterface('wlan0'),
            NetInterface('wg0'),
            NetInterface('vpn', anonymousVpn: true),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
  }

  Future<T> run<T>(Future<T> Function() f) async =>
      (await tester.runAsync(f)) as T;

  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> pump(Widget home) async {
    tester.view.physicalSize = const Size(1920, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: LumioTheme.dark(),
            locale: ref.watch(localeProvider),
            supportedLocales: supportedUiLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: home,
          ),
        ),
      ),
    );
    await settle();
  }

  Future<void> tapText(String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await settle();
  }

  Future<void> tapTile(String id) async {
    await openSettingsPageFor(tester, id, settle);
    final f = find.byKey(ValueKey('setting:$id'));
    await tester.ensureVisible(f);
    await tester.tap(f);
    await settle();
  }

  Future<String?> stored(String key) =>
      run(() => AppSettingsStore(db).read(key));

  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets(
    'langue : passer en anglais change les libellés sans redémarrer',
    (tester) async {
      final h = _H(tester)..start();
      await h.pump(const SettingsScreen());
      expect(find.text('Réglages'), findsOneWidget);

      await h.tapTile('locale');
      expect(find.text('Langue de l\'interface'), findsWidgets);
      await h.tapText('English');

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Interface language'), findsWidgets);
      expect(find.text('Réglages'), findsNothing);
      expect(await h.stored(AppSettingsStore.localeKey), 'en');
      await h.dispose();
    },
  );

  testWidgets('langue : le choix est relu au démarrage suivant', (
    tester,
  ) async {
    final h = _H(tester)..start();
    await h.run(
      () => AppSettingsStore(h.db).write(AppSettingsStore.localeKey, 'en'),
    );
    await h.pump(const SettingsScreen());
    expect(find.text('Settings'), findsOneWidget);
    await h.dispose();
  });

  testWidgets('addons : le tuile ouvre la gestion des addons', (tester) async {
    final h = _H(tester)..start();
    await h.run(() => h.repo.install(_urlA));
    await h.pump(const SettingsScreen());
    await h.tapTile('addons');
    expect(find.text('Alpha'), findsOneWidget);
    await h.dispose();
  });

  testWidgets('dossiers locaux : section dédiée, la tuile ouvre l\'écran', (
    tester,
  ) async {
    final h = _H(tester)..start();
    await h.pump(const SettingsScreen());
    expect(find.text('Dossiers locaux'), findsWidgets);
    await h.tapTile('localFolders');
    expect(find.textContaining('Aucun dossier'), findsOneWidget);
    expect(find.text('Ajouter un dossier'), findsOneWidget);
    await h.dispose();
  });

  testWidgets('langues et qualité : modifient les préférences du profil', (
    tester,
  ) async {
    final h = _H(tester)..start();
    await h.pump(const SettingsScreen());
    await openSettingsPageFor(tester, 'quality', h.settle);
    expect(find.text('Qualité préférée'), findsOneWidget);

    await h.tapTile('audio');
    await h.tapText('English');
    await h.tapTile('quality');
    await h.tapText('720p');
    await h.tapTile('subtitles');
    await h.tapText('Español');

    final prefs = await h.run(
      () => StreamPrefsStore(h.db).load(defaultProfileId),
    );
    expect(prefs.languages.first, 'en');
    expect(prefs.maxQuality, Quality.hd720);
    expect(
      await h.stored(AppSettingsStore.subtitleLangKey(defaultProfileId)),
      'es',
    );
    expect(
      await h.run(() => h.container.read(defaultAudioLangProvider.future)),
      'en',
    );
    await h.dispose();
  });

  testWidgets('liens directs préférés : actif par défaut, modifiable', (
    tester,
  ) async {
    final h = _H(tester)..start();
    await h.pump(const SettingsScreen());
    await openSettingsPageFor(tester, 'preferDirect', h.settle);
    expect(
      find.text('Préférer les liens directs aux torrents'),
      findsOneWidget,
    );
    expect(
      (await h.run(
        () => StreamPrefsStore(h.db).load(defaultProfileId),
      )).preferDirect,
      isTrue,
    );
    // Interrupteur : un appui bascule.
    await h.tapTile('preferDirect');
    final prefs = await h.run(
      () => StreamPrefsStore(h.db).load(defaultProfileId),
    );
    expect(prefs.preferDirect, isFalse);
    expect(prefs.languages, ['fr']); // le reste est conservé
    await h.dispose();
  });

  testWidgets('cache torrents et débit montant : enregistrés', (tester) async {
    final h = _H(tester)..start();
    await h.pump(const SettingsScreen());

    await h.tapTile('cache');
    await h.tapText('5 Go');
    await h.tapTile('upload');
    await h.tapText('512 Ko/s');

    final t = h.container.read(torrentSettingsProvider);
    expect(t.cacheGb, 5);
    expect(t.uploadKbps, 512);
    expect(await h.stored(AppSettingsStore.torrentCacheKey), '5');
    expect(await h.stored(AppSettingsStore.uploadKey), '512');
    await h.dispose();
  });

  testWidgets('VPN exigé et interface : enregistrés, interfaces VPN actives', (
    tester,
  ) async {
    final h = _H(tester)..start();
    await h.pump(const SettingsScreen());
    await openSettingsPageFor(tester, 'requireVpn', h.settle);
    expect(h.container.read(torrentSettingsProvider).requireVpn, isFalse);
    expect(find.text('Exiger un VPN pour les torrents'), findsOneWidget);

    await h.tapTile('requireVpn'); // interrupteur
    expect(h.container.read(torrentSettingsProvider).requireVpn, isTrue);
    expect(await h.stored(AppSettingsStore.requireVpnKey), '1');

    await h.tapTile('vpnInterface');
    // Seules les interfaces VPN nommées actuellement actives, plus « tout VPN ».
    expect(find.text('wlan0'), findsNothing);
    expect(find.text('vpn'), findsNothing);
    expect(find.text('N\'importe quel VPN'), findsWidgets);
    await h.tapText('wg0');
    expect(h.container.read(torrentSettingsProvider).vpnInterface, 'wg0');
    expect(await h.stored(AppSettingsStore.vpnInterfaceKey), 'wg0');

    await h.tapTile('vpnInterface');
    await h.tapText('N\'importe quel VPN');
    expect(h.container.read(torrentSettingsProvider).vpnInterface, isNull);
    expect(await h.stored(AppSettingsStore.vpnInterfaceKey), '');
    await h.dispose();
  });

  testWidgets('vider le cache à la fermeture et ensemencement coupé', (
    tester,
  ) async {
    final h = _H(tester)..start();
    await h.pump(const SettingsScreen());
    await openSettingsPageFor(tester, 'clearCache', h.settle);

    // Débit montant 0 = ensemencement désactivé, valeur par défaut.
    expect(find.text('Désactivé (pas d\'ensemencement)'), findsOneWidget);
    expect(h.container.read(torrentSettingsProvider).clearCacheOnExit, isFalse);

    await h.tapTile('clearCache'); // interrupteur

    expect(h.container.read(torrentSettingsProvider).clearCacheOnExit, isTrue);
    expect(await h.stored(AppSettingsStore.clearCacheOnExitKey), '1');
    await h.dispose();
  });

  testWidgets('version : menu debug caché, débloqué après 7 appuis', (
    tester,
  ) async {
    final h = _H(tester)..start();
    await h.pump(const SettingsScreen());
    await openSettingsPageFor(tester, 'version', h.settle);
    expect(find.text('Lumio 1.2.3'), findsOneWidget);
    expect(find.text('Menu debug'), findsNothing);

    for (var i = 0; i < debugUnlockPresses - 1; i++) {
      await tester.tap(find.text('Lumio 1.2.3'));
      await tester.pump();
    }
    expect(find.text('Menu debug'), findsNothing);
    await tester.tap(find.text('Lumio 1.2.3'));
    await h.settle();

    await h.tapTile('debug');
    expect(find.text('Spike torrent'), findsOneWidget);
    expect(find.text('Spike lecteur'), findsOneWidget);
    expect(find.text('Boucle d\'endurance'), findsOneWidget);
    await h.dispose();
  });

  testWidgets('à propos : licence GPL-3.0, crédits et licences', (
    tester,
  ) async {
    final h = _H(tester)..start();
    await h.pump(const SettingsScreen());
    await h.tapTile('about');
    expect(find.textContaining('GPL-3.0'), findsWidgets);
    expect(find.textContaining('libmpv'), findsWidgets);
    expect(find.textContaining('libtorrent'), findsWidgets);
    expect(find.text('Licences open source'), findsOneWidget);
    await h.dispose();
  });

  testWidgets('addon désactivé : absent des requêtes (enabledOnly)', (
    tester,
  ) async {
    final h = _H(tester)..start();
    await h.run(() async {
      await h.repo.install(_urlA);
      await h.repo.install(_urlB);
    });
    expect((await h.run(h.repo.list)).map((a) => a.id), ['a', 'b']);

    await h.run(() => h.repo.setEnabled('a', false));
    expect((await h.run(h.repo.list)).length, 2);
    expect(
      (await h.run(() => h.repo.list(enabledOnly: true))).map((a) => a.id),
      ['b'],
    );

    // Les chemins de requête (accueil, recherche, flux) lisent la liste active.
    await h.run(() => h.container.read(addonsProvider.future));
    expect(h.container.read(activeAddonsProvider).map((a) => a.storageId), [
      'b',
    ]);
    await h.run(
      () => h.container.read(addonsProvider.notifier).setEnabled('b', false),
    );
    expect(h.container.read(activeAddonsProvider), isEmpty);
    await h.dispose();
  });

  testWidgets('profil enfant : réglages derrière le PIN parent', (
    tester,
  ) async {
    final h = _H(tester)..start();
    final repo = ProfileRepository(
      h.db,
      hashPin: (p) async => 'h:$p',
      verifyPin: (p, s) async => s == 'h:$p',
    );
    await h.run(repo.ensureDefault);
    final kid = await h.run(() => repo.create('Léa', isKid: true));
    await h.run(() => repo.createParentPin('1234'));
    h.container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(h.db),
        profileRepositoryProvider.overrideWithValue(repo),
        appVersionProvider.overrideWith((ref) async => '1.2.3'),
      ],
    );
    addTearDown(h.container.dispose);
    h.container.read(currentProfileProvider.notifier).select(kid);
    await h.pump(
      Consumer(
        builder: (context, ref, _) => Scaffold(
          body: TextButton(
            onPressed: () => openSettings(context, ref),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );

    await h.tapText('ouvrir');
    expect(find.text('PIN parent'), findsOneWidget);
    expect(find.text('Réglages'), findsNothing);
    for (final d in '1234'.split('')) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await h.settle();
    expect(find.text('Réglages'), findsOneWidget);
    await h.dispose();
  });

  testWidgets('profil adulte : réglages ouverts sans PIN', (tester) async {
    final h = _H(tester)..start();
    await h.pump(
      Consumer(
        builder: (context, ref, _) => Scaffold(
          body: TextButton(
            onPressed: () => openSettings(context, ref),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );
    await h.tapText('ouvrir');
    expect(find.text('Réglages'), findsOneWidget);
    await h.dispose();
  });

  test('fichiers arb : mêmes clés en français et en anglais', () {
    Map<String, dynamic> load(String f) =>
        jsonDecode(File('lib/l10n/$f').readAsStringSync())
            as Map<String, dynamic>;
    final fr = load('app_fr.arb').keys.where((k) => !k.startsWith('@')).toSet();
    final en = load('app_en.arb').keys.where((k) => !k.startsWith('@')).toSet();
    expect(en.difference(fr), isEmpty);
    expect(fr.difference(en), isEmpty);
  });

  test('messages de lecture traduits (anglais)', () {
    final en = AppLocalizationsEn();
    expect(
      explainFailure('x', httpStatus: 404, l10n: en),
      'The source replied 404: the file no longer exists.',
    );
    expect(explainFailure('x', httpStatus: 404), contains('n\'existe plus'));
  });

  test(
    'pistes : langues par défaut des réglages sans mémoire du titre',
    () async {
      final backend = FakeBackend();
      final c = TracksController(
        backend: backend,
        store: InMemoryTitleSettingsStore(),
        profileId: 'p',
        metaId: 'm',
        defaultAudioLang: 'en',
        defaultSubtitleLang: 'fr',
      );
      addTearDown(c.dispose);
      backend.emit();
      await pumpEventQueue();
      expect(backend.calls, containsAll(['audio:2', 'sub:10']));
    },
  );

  testWidgets('erreurs d\'addon traduites : doublon et injoignable (anglais)', (
    tester,
  ) async {
    final h = _H(tester)..start();
    final en = AppLocalizationsEn();
    await h.run(() => h.repo.install(_urlA));
    final dup = await h.run<Object?>(() async {
      try {
        await h.repo.install(_urlA);
      } on Object catch (e) {
        return e;
      }
      return null;
    });
    expect(dup, isA<DuplicateAddonException>());
    expect(l10nForError(en, dup!), 'This addon is already installed');
    expect(
      l10nForError(AppLocalizationsFr(), dup),
      'Cet addon est déjà installé',
    );

    final unreachable = AddonClient(_DownFetcher(), retries: 0);
    final err = await h.run<Object?>(() async {
      try {
        await unreachable.fetchManifest(Uri.parse(_urlB));
      } on Object catch (e) {
        return e;
      }
      return null;
    });
    expect(err, isA<ManifestException>());
    expect(l10nForError(en, err!), 'Addon unreachable');
    expect(
      l10nForError(en, const ProfileLimitException()),
      'Six profiles maximum',
    );
    expect(resourceLabel('catalog', en), 'Catalogs');
    await h.dispose();
  });
}

class _DownFetcher implements HttpFetcher {
  @override
  Future<FetchResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) async => throw const SocketException('down');
}
