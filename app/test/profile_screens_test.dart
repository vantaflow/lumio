import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/profile_repository.dart';
import 'package:lumio/features/profiles/pin_dialog.dart';
import 'package:lumio/features/profiles/profile_picker_screen.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

class _BrokenPinRepo extends ProfileRepository {
  _BrokenPinRepo(super.db);

  @override
  Future<bool> hasParentPin() async => throw StateError('base illisible');
}

class _H {
  _H(this.tester);
  final WidgetTester tester;
  late AppDatabase db;
  late DateTime clock;
  late ProfileRepository repo;

  void start() {
    db = AppDatabase(NativeDatabase.memory());
    clock = DateTime.utc(2026, 11, 18, 12);
    // Hachage factice : 100 000 itérations ne tiennent pas dans un test
    // d'interface (les vrais hachages sont testés dans profile_repository).
    repo = ProfileRepository(
      db,
      now: () => clock,
      hashPin: (p) async => 'h:$p',
      verifyPin: (p, s) async => s == 'h:$p',
    );
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

  Future<ProviderContainer> pump(Widget home) async {
    // Fenêtre de bureau : le pavé du PIN (maquette P01, touches de 96) y tient.
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        profileRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: LumioTheme.dark(), home: home),
      ),
    );
    await settle();
    return container;
  }

  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  }
}

const _child = Scaffold(body: Text('ACCUEIL'));

Future<void> _type(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.text(d));
    await tester.pump();
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  testWidgets('un seul profil : choisi automatiquement, sans sélecteur', (
    tester,
  ) async {
    final h = _H(tester)..start();
    await h.run(h.repo.ensureDefault);
    final c = await h.pump(const ProfileGate(child: _child));

    expect(find.text('ACCUEIL'), findsOneWidget);
    expect(find.text('Qui regarde ?'), findsNothing);
    expect(c.read(currentProfileProvider)?.name, 'Moi');
    expect(c.read(currentProfileIdProvider), defaultProfileId);
    await h.dispose();
  });

  testWidgets('premier lancement : « Moi » créé puis choisi', (tester) async {
    final h = _H(tester)..start();
    final c = await h.pump(const ProfileGate(child: _child));
    expect(find.text('ACCUEIL'), findsOneWidget);
    expect(c.read(currentProfileProvider)?.name, 'Moi');
    await h.dispose();
  });

  testWidgets('deux profils : le sélecteur d\'abord, puis l\'accueil', (
    tester,
  ) async {
    final h = _H(tester)..start();
    await h.run(h.repo.ensureDefault);
    await h.run(() => h.repo.create('Léa', limit: AgeLimit.age7, isKid: true));
    // Un profil enfant suppose un PIN parent (voir kidProfileNeedsPin).
    await h.run(() => h.repo.createParentPin('1234'));
    final c = await h.pump(const ProfileGate(child: _child));

    expect(find.text('Qui regarde ?'), findsOneWidget);
    expect(find.text('ACCUEIL'), findsNothing);
    expect(find.text('Moi'), findsOneWidget);
    expect(find.text('Léa'), findsOneWidget);
    expect(find.text('Enfant · 7+'), findsOneWidget);
    expect(find.text('Ajouter'), findsOneWidget);

    // Le profil enfant lui-même n'est pas verrouillé : on entre directement.
    await tester.tap(find.text('Léa'));
    await h.settle();
    expect(find.text('ACCUEIL'), findsOneWidget);
    expect(c.read(currentProfileProvider)?.isKid, isTrue);
    await h.dispose();
  });

  testWidgets('profil adulte verrouillé dès qu\'un enfant et un PIN existent', (
    tester,
  ) async {
    final h = _H(tester)..start();
    await h.run(h.repo.ensureDefault);
    await h.run(() => h.repo.create('Léa', isKid: true));
    await h.run(() => h.repo.createParentPin('1234'));
    final c = await h.pump(const ProfileGate(child: _child));

    expect(find.byIcon(Icons.lock), findsOneWidget);
    expect(find.text('PIN'), findsOneWidget);

    await tester.tap(find.text('Moi'));
    await h.settle();
    expect(find.text('PIN pour Moi'), findsOneWidget);

    await _type(tester, '0000');
    await h.settle();
    expect(find.text('PIN incorrect'), findsOneWidget);
    expect(c.read(currentProfileProvider), isNull);

    await _type(tester, '1234');
    await h.settle();
    expect(find.text('ACCUEIL'), findsOneWidget);
    expect(c.read(currentProfileProvider)?.name, 'Moi');
    await h.dispose();
  });

  testWidgets('3 mauvais PIN : verrouillé avec message, clavier inactif', (
    tester,
  ) async {
    final h = _H(tester)..start();
    await h.run(h.repo.ensureDefault);
    await h.run(() => h.repo.create('Léa', isKid: true));
    await h.run(() => h.repo.createParentPin('1234'));
    await h.pump(const ProfileGate(child: _child));

    await tester.tap(find.text('Moi'));
    await h.settle();
    for (var i = 0; i < 3; i++) {
      await _type(tester, '0000');
      await h.settle();
    }
    expect(find.textContaining('Trop d\'essais'), findsOneWidget);
    await _type(tester, '1234');
    await h.settle();
    expect(find.text('ACCUEIL'), findsNothing);
    await h.dispose();
  });

  testWidgets('PIN : chiffres du clavier, effacer, points de saisie', (
    tester,
  ) async {
    final h = _H(tester)..start();
    String? got;
    await h.pump(
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                got = (await showPinDialog(context, title: 'Test'))?.pin,
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await h.settle();
    expect(find.text('Test'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(find.bySemanticsLabel('1 chiffre saisi sur 4'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit8);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
    await h.settle();
    expect(got, '1987');
    await h.dispose();
  });

  testWidgets('PIN : la télécommande (D-pad + OK) saisit les chiffres', (
    tester,
  ) async {
    final h = _H(tester)..start();
    String? got;
    await h.pump(
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                got = (await showPinDialog(context, title: 'Test'))?.pin,
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await h.settle();
    // Focus initial sur « 1 » ; bas = 4, droite = 5, OK.
    await tester.sendKeyEvent(LogicalKeyboardKey.select); // 1
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.select); // 2
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.select); // 5
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.select); // 4
    await h.settle();
    expect(got, '1254');
    await h.dispose();
  });

  testWidgets('PIN : Retour annule', (tester) async {
    final h = _H(tester)..start();
    var asked = false;
    PinEntry? got;
    await h.pump(
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              got = await showPinDialog(context, title: 'Test');
              asked = true;
            },
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await h.settle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await h.settle();
    expect(find.text('Test'), findsNothing);
    expect(asked, isTrue);
    expect(got, isNull);
    await h.dispose();
  });

  Future<ProviderContainer> pumpGuard(
    _H h,
    WidgetTester tester,
    void Function(bool) onResult,
  ) => h.pump(
    Scaffold(
      body: Consumer(
        builder: (context, ref, _) => TextButton(
          onPressed: () async => onResult(await requireParent(context, ref)),
          child: const Text('réglages'),
        ),
      ),
    ),
  );

  testWidgets('profil adulte : réglages libres, sans PIN', (tester) async {
    final h = _H(tester)..start();
    await h.run(h.repo.ensureDefault);
    bool? ok;
    final c = await pumpGuard(h, tester, (v) => ok = v);
    c
        .read(currentProfileProvider.notifier)
        .select((await h.run(h.repo.list)).first);
    await tester.tap(find.text('réglages'));
    await h.settle();
    expect(ok, isTrue);
    expect(find.text('PIN parent'), findsNothing);
    await h.dispose();
  });

  testWidgets('profil enfant : réglages bloqués sans le PIN parent', (
    tester,
  ) async {
    final h = _H(tester)..start();
    await h.run(h.repo.ensureDefault);
    final kid = await h.run(() => h.repo.create('Léa', isKid: true));
    await h.run(() => h.repo.createParentPin('1234'));
    bool? ok;
    final c = await pumpGuard(h, tester, (v) => ok = v);
    c.read(currentProfileProvider.notifier).select(kid);

    await tester.tap(find.text('réglages'));
    await h.settle();
    expect(find.text('PIN parent'), findsOneWidget);
    await _type(tester, '0000');
    await h.settle();
    expect(ok, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await h.settle();
    expect(ok, isFalse);

    await tester.tap(find.text('réglages'));
    await h.settle();
    await _type(tester, '1234');
    await h.settle();
    expect(ok, isTrue);
    await h.dispose();
  });

  testWidgets('code de récupération affiché à la création du premier PIN', (
    tester,
  ) async {
    final h = _H(tester)..start();
    await h.run(h.repo.ensureDefault);
    final kid = await h.run(() => h.repo.create('Léa', isKid: true));
    bool? ok;
    final c = await pumpGuard(h, tester, (v) => ok = v);
    c.read(currentProfileProvider.notifier).select(kid);

    await tester.tap(find.text('réglages'));
    await h.settle();
    expect(find.text('Choisissez un PIN'), findsOneWidget);
    await _type(tester, '4321');
    await h.settle();
    await _type(tester, '4321');
    await h.settle();
    expect(find.text('Code de récupération'), findsOneWidget);
    final code = tester
        .widget<SelectableText>(find.byKey(const ValueKey('recovery-code')))
        .data!;
    expect(code, matches(RegExp(r'^[0-9A-Z]{5}-[0-9A-Z]{5}$')));
    await tester.tap(find.text('J\'ai noté le code'));
    await h.settle();
    expect(ok, isTrue);
    expect(await h.run(h.repo.hasParentPin), isTrue);
    await h.dispose();
  });

  testWidgets('au plus 6 profils : plus de carte « Ajouter »', (tester) async {
    final h = _H(tester)..start();
    await h.run(h.repo.ensureDefault);
    for (var i = 1; i < 6; i++) {
      h.clock = h.clock.add(const Duration(seconds: 1));
      await h.run(() => h.repo.create('P$i'));
    }
    await h.pump(const ProfileGate(child: _child));
    expect(find.text('Ajouter'), findsNothing);
    expect(find.text('Moi'), findsOneWidget);
    await h.dispose();
  });

  testWidgets('ajout d\'un profil depuis le sélecteur (sans PIN)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = _H(tester)..start();
    await h.run(h.repo.ensureDefault);
    h.clock = h.clock.add(const Duration(seconds: 1));
    await h.run(() => h.repo.create('Bob'));
    await h.pump(const ProfileGate(child: _child));

    await tester.tap(find.text('Ajouter'));
    await h.settle();
    expect(find.text('Nouveau profil'), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    await h.settle();
    expect(find.text('Donnez un nom au profil'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Zoé');
    await tester.tap(find.text('Enregistrer'));
    await h.settle();
    expect(find.text('Zoé'), findsOneWidget);
    expect((await h.run(h.repo.list)).map((p) => p.name), contains('Zoé'));
    await h.dispose();
  });

  testWidgets(
    'profil unique : gestion accessible, ajout enfant, PIN, sélecteur',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = _H(tester)..start();
      final c = await h.pump(
        const ProfileGate(
          child: Scaffold(
            body: Column(children: [ProfileButton(), Text('ACCUEIL')]),
          ),
        ),
      );
      // Base neuve : « Moi » choisi seul.
      expect(find.text('ACCUEIL'), findsOneWidget);
      expect(c.read(currentProfileProvider)?.name, 'Moi');

      // Le bouton de profil ouvre la gestion malgré l'unique profil.
      await tester.tap(find.text('Moi'));
      await h.settle();
      expect(find.text('Gérer les profils'), findsWidgets);
      expect(find.text('Terminé'), findsOneWidget);
      expect(find.text('ACCUEIL'), findsNothing);

      await tester.tap(find.text('Ajouter'));
      await h.settle();
      await tester.enterText(find.byType(TextField), 'Léa');
      await tester.tap(find.text('Profil enfant'));
      await tester.pump();
      await tester.tap(find.text('Enregistrer'));
      await h.settle();
      // Création du PIN parent, puis code de récupération.
      expect(find.text('Choisissez un PIN'), findsOneWidget);
      await _type(tester, '1234');
      await h.settle();
      await _type(tester, '1234');
      await h.settle();
      expect(find.text('Code de récupération'), findsOneWidget);
      await tester.tap(find.text('J\'ai noté le code'));
      await h.settle();
      expect((await h.run(h.repo.list)).map((p) => p.name), ['Moi', 'Léa']);
      expect(await h.run(h.repo.hasParentPin), isTrue);

      // Deux profils : à la sélection suivante, le sélecteur s'affiche.
      await tester.tap(find.text('Terminé'));
      await h.settle();
      await tester.tap(find.text('Léa'));
      await h.settle();
      expect(find.text('ACCUEIL'), findsOneWidget);
      expect(c.read(currentProfileProvider)?.name, 'Léa');
      await tester.tap(find.text('Léa').first);
      await h.settle();
      expect(find.text('PIN parent'), findsOneWidget);
      await _type(tester, '1234');
      await h.settle();
      expect(find.text('Qui regarde ?'), findsOneWidget);
      await h.dispose();
    },
  );

  testWidgets('lecture du PIN impossible : échec fermé avec message', (
    tester,
  ) async {
    final h = _H(tester)..start();
    await h.run(h.repo.ensureDefault);
    await h.run(() => h.repo.create('Léa', isKid: true));
    h.repo = _BrokenPinRepo(h.db);
    await h.pump(const ProfileGate(child: _child));
    await tester.tap(find.text('Moi'));
    await h.settle();
    expect(find.text('ACCUEIL'), findsNothing);
    expect(
      find.text('Contrôle parental indisponible. Réessayez.'),
      findsOneWidget,
    );
    await h.dispose();
  });

  test('isProfileLocked : verrou explicite ou adulte avec enfant + PIN', () {
    Profile p(String id, {bool kid = false, bool locked = false}) => Profile(
      id: id,
      name: id,
      createdAt: 0,
      ageLimit: kid ? 2 : 4,
      isKid: kid,
      locked: locked,
    );
    final adult = p('a');
    final kid = p('k', kid: true);
    expect(isProfileLocked(adult, [adult, kid], hasPin: true), isTrue);
    expect(isProfileLocked(adult, [adult, kid], hasPin: false), isFalse);
    expect(isProfileLocked(adult, [adult, p('b')], hasPin: true), isFalse);
    expect(isProfileLocked(kid, [adult, kid], hasPin: true), isFalse);
    final lockedAdult = p('l', locked: true);
    expect(isProfileLocked(lockedAdult, [lockedAdult], hasPin: true), isTrue);
  });
}
