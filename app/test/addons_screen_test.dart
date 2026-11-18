import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio/features/addons/addons_screen.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

import 'support/fake_addon_fetcher.dart';

const _urlA = 'https://a.example.com/tok-a/manifest.json';
const _urlB = 'https://b.example.com/tok-b/manifest.json';
const _lan = 'http://192.168.1.20:7000/manifest.json';

class _FailingRepo extends AddonRepository {
  _FailingRepo(super.db, super.secrets);

  @override
  Future<void> setEnabled(String id, bool on) async => throw StateError('x');

  @override
  Future<void> reorder(List<String> ids) async => throw StateError('x');

  @override
  Future<void> remove(String id) async => throw StateError('x');
}

class _Harness {
  _Harness(this.tester);
  final WidgetTester tester;
  late AppDatabase db;
  late MemorySecretStore secrets;
  late FakeAddonFetcher fetcher;
  late AddonRepository repo;

  Future<void> start() async {
    db = AppDatabase(NativeDatabase.memory());
    secrets = MemorySecretStore();
    fetcher = FakeAddonFetcher({
      _urlA: sampleManifest(id: 'a', name: 'Alpha'),
      _urlB: sampleManifest(id: 'b', name: 'Bravo', types: ['movie']),
      _lan: sampleManifest(id: 'lan', name: 'Maison'),
    });
    repo = AddonRepository(
      db,
      secrets,
      clientFactory: ({required allowPrivate}) =>
          AddonClient(fetcher, allowPrivate: allowPrivate, retries: 0),
    );
  }

  Future<void> pumpScreen([AddonRepository? r]) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [addonRepositoryProvider.overrideWithValue(r ?? repo)],
        child: MaterialApp(
          theme: LumioTheme.dark(),
          home: const AddonsScreen(),
        ),
      ),
    );
    await settle();
  }

  /// Laisse la base (vraie asynchronie) et l'interface se stabiliser.
  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 700));
    }
  }

  Future<void> dispose() async {
    await tester.runAsync(db.close);
  }
}

void main() {
  testWidgets('liste vide : message d\'aide et bouton Ajouter un addon', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.start();
    await h.pumpScreen();

    expect(find.textContaining('Aucun addon installé'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Ajouter un addon'), findsOne);
    await h.dispose();
  });

  testWidgets('ajout simple : coller, aperçu, un seul bouton Installer', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.start();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? <String, Object?>{'text': _urlA}
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await h.pumpScreen();

    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter un addon'));
    await h.settle();
    expect(find.text('Installer'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Installer'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Coller'));
    await h.settle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Films'), findsOneWidget);
    expect(find.textContaining('Fournit : Catalogues'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Installer'));
    await h.settle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Installer'), findsNothing);
    expect((await tester.runAsync(h.repo.list))!.map((a) => a.name), ['Alpha']);
    await h.dispose();
  });

  testWidgets('lien injoignable : une phrase d\'erreur, Installer inactif', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.start();
    await h.pumpScreen();
    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter un addon'));
    await h.settle();

    await tester.enterText(find.byType(TextField), 'https://nul.example.com/x');
    await h.settle();
    expect(find.text('Addon injoignable'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Installer'))
          .onPressed,
      isNull,
    );
    await h.dispose();
  });

  testWidgets('IP privée : dialogue « Adresse locale » avant allowPrivate', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.start();
    await h.pumpScreen();
    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter un addon'));
    await h.settle();

    await tester.enterText(find.byType(TextField), _lan);
    await tester.pump(const Duration(milliseconds: 700));
    await h.settle();
    expect(find.text('Adresse locale'), findsOneWidget);
    expect(h.fetcher.requested, isEmpty);

    // Refus : aucune requête, aucun aperçu.
    await tester.tap(find.text('Annuler').last);
    await h.settle();
    expect(find.text('Adresse locale'), findsNothing);
    expect(find.text('Maison'), findsNothing);
    expect(h.fetcher.requested, isEmpty);

    // Nouvelle saisie puis confirmation.
    await tester.enterText(find.byType(TextField), '$_lan ');
    await h.settle();
    await tester.tap(find.text('Continuer'));
    await h.settle();
    expect(find.text('Maison'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Installer'));
    await h.settle();
    expect((await tester.runAsync(h.repo.list))!.map((a) => a.name), [
      'Maison',
    ]);
    await h.dispose();
  });

  testWidgets('liste : monter, désactiver, supprimer avec confirmation', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.start();
    await tester.runAsync(() async {
      await h.repo.install(_urlA);
      await h.repo.install(_urlB);
    });
    await h.pumpScreen();

    List<String> order() => [
      for (final t in tester.widgetList<Text>(find.byType(Text)))
        if (t.data == 'Alpha' || t.data == 'Bravo') t.data!,
    ];
    expect(order(), ['Alpha', 'Bravo']);
    expect(find.textContaining('Films · Séries'), findsOneWidget);

    await tester.tap(find.byTooltip('Monter Bravo'));
    await h.settle();
    expect(order(), ['Bravo', 'Alpha']);

    await tester.tap(find.byType(Switch).first);
    await h.settle();
    expect(find.text('Désactivé'), findsOneWidget);

    // Annuler la suppression ne retire rien.
    await tester.tap(find.byTooltip('Supprimer Bravo'));
    await h.settle();
    expect(find.text('Supprimer cet addon ?'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await h.settle();
    expect(order(), ['Bravo', 'Alpha']);

    await tester.tap(find.byTooltip('Supprimer Bravo'));
    await h.settle();
    await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
    await h.settle();
    expect(order(), ['Alpha']);
    expect(h.secrets.snapshot, hasLength(1));
    await h.dispose();
  });

  testWidgets('échec de modification : message français, pas d\'erreur', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.start();
    await tester.runAsync(() async {
      await h.repo.install(_urlA);
      await h.repo.install(_urlB);
    });
    await h.pumpScreen(_FailingRepo(h.db, h.secrets));

    final msg = find.textContaining('Action impossible');
    await tester.tap(find.byTooltip('Monter Bravo'));
    await h.settle();
    expect(msg, findsOneWidget);
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).first),
    ).hideCurrentSnackBar();
    await h.settle();

    await tester.tap(find.byType(Switch).first);
    await h.settle();
    expect(msg, findsOneWidget);
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).first),
    ).hideCurrentSnackBar();
    await h.settle();

    await tester.tap(find.byTooltip('Supprimer Alpha'));
    await h.settle();
    await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
    await h.settle();
    expect(msg, findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.text('Alpha'), findsOneWidget);
    await h.dispose();
  });

  testWidgets('aperçu : « Déjà installé » et Installer inactif', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.start();
    await tester.runAsync(() => h.repo.install(_urlA));
    await h.pumpScreen();
    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter un addon'));
    await h.settle();
    await tester.enterText(
      find.byType(TextField),
      'https://A.example.com/tok-a',
    );
    await h.settle();
    expect(find.text('Déjà installé'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Installer'))
          .onPressed,
      isNull,
    );
    await h.dispose();
  });

  testWidgets('addon illisible : signalé, seule la suppression reste', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.start();
    final a = (await tester.runAsync(() => h.repo.install(_urlA)))!;
    await tester.runAsync(() => h.secrets.delete('addon_url:${a.id}'));
    await h.pumpScreen();
    expect(find.textContaining('Addon illisible'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    await tester.tap(find.byTooltip('Supprimer a'));
    await h.settle();
    await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
    await h.settle();
    expect(find.textContaining('Aucun addon installé'), findsOneWidget);
    await h.dispose();
  });
}
