import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/profile_repository.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio/features/addons/add_addon_screen.dart';
import 'package:lumio/features/addons/install_link_handler.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

import 'support/fake_addon_fetcher.dart';
import 'support/fake_catalog.dart';

const _urlA = 'https://a.example.com/tok-a/manifest.json';

class _FakeSource implements InstallLinkSource {
  _FakeSource([this.initial]);
  final String? initial;
  final controller = StreamController<String>.broadcast();

  @override
  Future<String?> initialLink() async => initial;

  @override
  Stream<String> get links => controller.stream;
}

class _H {
  _H(this.tester);
  final WidgetTester tester;
  late AppDatabase db;
  late AddonRepository addons;
  late ProfileRepository profiles;
  late ProviderContainer container;

  Future<T> run<T>(Future<T> Function() f) async =>
      (await tester.runAsync(f)) as T;

  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 700));
    }
  }

  Future<void> start(_FakeSource source, {String? clipboard}) async {
    db = AppDatabase(NativeDatabase.memory());
    addons = AddonRepository(
      db,
      MemorySecretStore(),
      clientFactory: ({required allowPrivate}) => AddonClient(
        FakeAddonFetcher({_urlA: sampleManifest(id: 'a', name: 'Alpha')}),
        allowPrivate: allowPrivate,
        retries: 0,
      ),
    );
    profiles = ProfileRepository(
      db,
      hashPin: (p) async => 'h:$p',
      verifyPin: (p, s) async => s == 'h:$p',
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? (clipboard == null ? null : <String, Object?>{'text': clipboard})
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        addonRepositoryProvider.overrideWithValue(addons),
        profileRepositoryProvider.overrideWithValue(profiles),
        installLinkSourceProvider.overrideWithValue(source),
        catalogOverride(FakeCatalogSite(offline: true)),
      ],
    );
    addTearDown(container.dispose);
  }

  Future<void> pump({Widget? home}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LumioTheme.dark(),
          home: InstallLinkHandler(
            child: home ?? const Scaffold(body: Text('ACCUEIL')),
          ),
        ),
      ),
    );
    await settle();
  }

  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  }
}

Future<void> _type(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.text(d));
    await tester.pump();
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('lien stremio:// reçu : dialogue prérempli, rien installé', (
    tester,
  ) async {
    final src = _FakeSource();
    final h = _H(tester);
    await h.start(src);
    await h.run(h.profiles.ensureDefault);
    await h.pump();

    src.controller.add('stremio://a.example.com/tok-a/manifest.json');
    await h.settle();

    expect(find.text('Ajouter un addon'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text(_urlA), findsOneWidget);
    expect(await h.run(h.addons.list), isEmpty);
    await h.dispose();
  });

  testWidgets('lien présent au démarrage (lumio://install) : prérempli', (
    tester,
  ) async {
    final src = _FakeSource(
      'lumio://install?url=${Uri.encodeComponent(_urlA)}',
    );
    final h = _H(tester);
    await h.start(src);
    await h.run(h.profiles.ensureDefault);
    await h.pump();

    expect(find.text('Alpha'), findsOneWidget);
    expect(await h.run(h.addons.list), isEmpty);
    await h.dispose();
  });

  testWidgets('texte partagé contenant une URL : prérempli', (tester) async {
    final src = _FakeSource();
    final h = _H(tester);
    await h.start(src);
    await h.run(h.profiles.ensureDefault);
    await h.pump();

    src.controller.add('Mon addon : $_urlA, merci !');
    await h.settle();

    expect(find.text('Alpha'), findsOneWidget);
    expect(await h.run(h.addons.list), isEmpty);
    await h.dispose();
  });

  testWidgets('lien invalide : message, pas de dialogue', (tester) async {
    final src = _FakeSource();
    final h = _H(tester);
    await h.start(src);
    await h.run(h.profiles.ensureDefault);
    await h.pump();

    src.controller.add('javascript:alert(1)');
    await h.settle();

    expect(find.text('Ajouter un addon'), findsNothing);
    expect(find.textContaining('pas un lien d\'installation'), findsOneWidget);
    await h.dispose();
  });

  testWidgets('profil enfant : PIN parent avant le dialogue', (tester) async {
    final src = _FakeSource();
    final h = _H(tester);
    await h.start(src);
    await h.run(h.profiles.ensureDefault);
    final kid = await h.run(() => h.profiles.create('Léa', isKid: true));
    await h.run(() => h.profiles.createParentPin('1234'));
    h.container.read(currentProfileProvider.notifier).select(kid);
    await h.pump();

    src.controller.add('stremio://a.example.com/tok-a/manifest.json');
    await h.settle();
    expect(find.text('PIN parent'), findsOneWidget);
    expect(find.text('Ajouter un addon'), findsNothing);

    await _type(tester, '1234');
    await h.settle();
    expect(find.text('Ajouter un addon'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(await h.run(h.addons.list), isEmpty);
    await h.dispose();
  });

  testWidgets('profil enfant : mauvais PIN, aucun dialogue', (tester) async {
    final src = _FakeSource();
    final h = _H(tester);
    await h.start(src);
    await h.run(h.profiles.ensureDefault);
    final kid = await h.run(() => h.profiles.create('Léa', isKid: true));
    await h.run(() => h.profiles.createParentPin('1234'));
    h.container.read(currentProfileProvider.notifier).select(kid);
    await h.pump();

    src.controller.add(_urlA);
    await h.settle();
    await _type(tester, '0000');
    await h.settle();
    expect(find.text('Ajouter un addon'), findsNothing);
    await h.dispose();
  });

  Future<void> openDialog(_H h) async {
    await h.pump(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showAddAddonScreen(context),
            child: const Text('OUVRIR'),
          ),
        ),
      ),
    );
    await h.tester.tap(find.text('OUVRIR'));
    await h.settle();
    // Onglet « Par lien » : c'est lui qui propose le lien copié.
    await h.tester.tap(find.byKey(const ValueKey('addtab:link')));
    await h.settle();
  }

  testWidgets('presse-papiers plausible : bouton proposé, jamais prérempli', (
    tester,
  ) async {
    final h = _H(tester);
    await h.start(_FakeSource(), clipboard: _urlA);
    await h.run(h.profiles.ensureDefault);
    await openDialog(h);

    expect(find.text('Utiliser le lien copié'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );

    await tester.tap(find.text('Utiliser le lien copié'));
    await h.settle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Utiliser le lien copié'), findsNothing);
    expect(await h.run(h.addons.list), isEmpty);
    await h.dispose();
  });

  testWidgets('presse-papiers quelconque : aucune proposition', (tester) async {
    final h = _H(tester);
    await h.start(_FakeSource(), clipboard: 'https://exemple.org/page.html');
    await h.run(h.profiles.ensureDefault);
    await openDialog(h);

    expect(find.text('Utiliser le lien copié'), findsNothing);
    await h.dispose();
  });

  testWidgets('lien http privé reçu : confirmation réseau local demandée', (
    tester,
  ) async {
    final src = _FakeSource();
    final h = _H(tester);
    await h.start(src);
    await h.run(h.profiles.ensureDefault);
    await h.pump();

    src.controller.add('http://192.168.1.20:7000/manifest.json');
    await h.settle();

    expect(find.text('Adresse locale'), findsOneWidget);
    expect(await h.run(h.addons.list), isEmpty);
    await h.dispose();
  });
}
