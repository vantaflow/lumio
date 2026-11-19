import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio/features/addons/add_addon_screen.dart';
import 'package:lumio/features/phone/phone_add.dart';
import 'package:lumio/features/phone/phone_providers.dart';
import 'package:lumio/features/phone/phone_server.dart';
import 'package:lumio/features/settings/settings_screen.dart';
import 'package:lumio/providers.dart';
import 'package:lumio_core/lumio_core.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'support/app_harness.dart';
import 'support/fake_addon_fetcher.dart';
import 'support/fake_catalog.dart';
import 'support/fake_phone.dart';

const _alpha = 'https://alpha.example.com/manifest.json';

class _Home extends StatelessWidget {
  const _Home({this.tab});
  final AddAddonTab? tab;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => showAddAddonScreen(context, initialTab: tab),
        child: const Text('OUVRIR'),
      ),
    ),
  );
}

Override _repo() => addonRepositoryProvider.overrideWith(
  (ref) => AddonRepository(
    ref.watch(appDatabaseProvider),
    MemorySecretStore(),
    clientFactory: ({required allowPrivate}) => AddonClient(
      FakeAddonFetcher({
        _alpha: sampleManifest(id: 'alpha', name: 'Alpha Addon'),
      }),
      allowPrivate: allowPrivate,
      retries: 0,
    ),
  ),
);

class _Setup {
  _Setup(this.t, {this.tab, this.initial, this.startState}) : h = AppHarness(t);
  final WidgetTester t;
  final PhoneServerState? initial;
  final PhoneServerState? startState;
  final AppHarness h;
  final AddAddonTab? tab;
  late final session = FakePhoneSession(
    initial: initial,
    startState: startState,
  );

  Future<void> open() async {
    await h.pump(
      _Home(tab: tab),
      extra: [
        catalogOverride(FakeCatalogSite(cards: const [], details: const {})),
        phoneSessionFactoryProvider.overrideWithValue((_) => session),
        _repo(),
      ],
    );
    await t.tap(find.text('OUVRIR'));
    await h.settle();
  }
}

void main() {
  testWidgets('onglet téléphone : QR, adresse, code, état', (t) async {
    final s = _Setup(t, initial: const PhoneServerState());
    await s.open();
    await t.tap(find.byKey(const ValueKey('addtab:phone')));
    await s.h.settle();
    expect(s.session.events, contains('start'));
    expect(
      find.byKey(const ValueKey('qr:http://192.168.0.45:8790/#c=482913')),
      findsOneWidget,
    );
    expect(find.text('192.168.0.45:8790'), findsOneWidget);
    expect(find.textContaining('482 913'), findsOneWidget);
    expect(
      find.textContaining('Page ouverte tant que cet écran'),
      findsOneWidget,
    );
    // Un téléphone se connecte.
    s.session.set(
      const PhoneServerState(
        status: PhoneServerStatus.listening,
        host: '192.168.0.45',
        port: 8790,
        code: '482913',
        connected: true,
      ),
    );
    await s.h.settle();
    expect(find.textContaining('Téléphone connecté'), findsOneWidget);
    await s.h.close();
  });

  testWidgets('quitter l\'onglet arrête le serveur, y revenir le relance', (
    t,
  ) async {
    final s = _Setup(t, tab: AddAddonTab.phone);
    await s.open();
    expect(s.session.events.where((e) => e == 'start'), hasLength(1));
    await t.tap(find.byKey(const ValueKey('addtab:catalog')));
    await s.h.settle();
    expect(s.session.events.last, 'stop');
    await t.tap(find.byKey(const ValueKey('addtab:phone')));
    await s.h.settle();
    expect(s.session.events.where((e) => e == 'start'), hasLength(2));
    await s.h.close();
  });

  testWidgets('quitter l\'écran arrête et libère le serveur', (t) async {
    final s = _Setup(t, tab: AddAddonTab.phone);
    await s.open();
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await s.h.settle();
    expect(s.session.events, containsAllInOrder(['start', 'stop', 'dispose']));
    await s.h.close();
  });

  testWidgets('pas de réseau local : message et Relancer', (t) async {
    final s = _Setup(
      t,
      tab: AddAddonTab.phone,
      startState: const PhoneServerState(status: PhoneServerStatus.noNetwork),
    );
    await s.open();
    expect(find.text('Pas de réseau local'), findsOneWidget);
    expect(find.byKey(const ValueKey('phone-restart')), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    await s.h.close();
  });

  testWidgets('arrêt pour inactivité : message et Relancer', (t) async {
    final s = _Setup(
      t,
      tab: AddAddonTab.phone,
      initial: const PhoneServerState(idleStopped: true),
    );
    await s.open();
    s.session.set(const PhoneServerState(idleStopped: true));
    await s.h.settle();
    expect(find.textContaining('10 minutes'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('phone-restart')));
    await s.h.settle();
    expect(find.byType(QrImageView), findsOneWidget);
    await s.h.close();
  });

  testWidgets('lien du téléphone : aperçu sur la TV, la TV confirme', (
    t,
  ) async {
    final s = _Setup(t, tab: AddAddonTab.phone);
    await s.open();
    final req = s.session.adds.submit(Uri.parse(_alpha));
    await s.h.settle();
    // Aperçu existant sur « Par lien », rien n'est installé tant que la TV
    // n'a pas confirmé.
    expect(find.text('APERÇU · v1.0.0'), findsOneWidget);
    expect(find.text('Alpha Addon'), findsWidgets);
    expect(req.state, PhoneAddState.waiting);
    expect(
      await s.h.container.read(addonRepositoryProvider).isInstalled(_alpha),
      isFalse,
    );
    await t.tap(find.byKey(const ValueKey('link-install')));
    await s.h.settle();
    expect(req.state, PhoneAddState.installed);
    expect(req.name, 'Alpha Addon');
    expect(
      await s.h.container.read(addonRepositoryProvider).isInstalled(_alpha),
      isTrue,
    );
    // La TV revient sur l'onglet du téléphone, serveur toujours actif.
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.byType(AddAddonScreen), findsOneWidget);
    expect(s.session.events, isNot(contains('stop')));
    await s.h.close();
  });

  testWidgets('lien du téléphone injoignable : échec rapporté', (t) async {
    final s = _Setup(t, tab: AddAddonTab.phone);
    await s.open();
    final req = s.session.adds.submit(
      Uri.parse('https://inconnu.example.com/manifest.json'),
    );
    await s.h.settle();
    expect(req.state, PhoneAddState.failed);
    expect(find.byType(QrImageView), findsOneWidget);
    await s.h.close();
  });

  testWidgets('quitter l\'aperçu sans confirmer annule la demande', (t) async {
    final s = _Setup(t, tab: AddAddonTab.phone);
    await s.open();
    final req = s.session.adds.submit(Uri.parse(_alpha));
    await s.h.settle();
    await t.tap(find.byKey(const ValueKey('addtab:catalog')));
    await s.h.settle();
    expect(req.state, PhoneAddState.cancelled);
    expect(s.session.events.last, 'stop');
    await s.h.close();
  });

  testWidgets('app en pause : serveur arrêté, Relancer à la reprise', (
    t,
  ) async {
    final s = _Setup(t, tab: AddAddonTab.phone);
    await s.open();
    expect(s.session.events.where((e) => e == 'start'), hasLength(1));
    for (final st in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      t.binding.handleAppLifecycleStateChanged(st);
    }
    await s.h.settle();
    expect(s.session.events.last, 'stop');
    for (final st in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      t.binding.handleAppLifecycleStateChanged(st);
    }
    await s.h.settle();
    expect(find.byKey(const ValueKey('phone-restart')), findsOneWidget);
    expect(s.session.events.where((e) => e == 'start'), hasLength(1));
    await t.tap(find.byKey(const ValueKey('phone-restart')));
    await s.h.settle();
    expect(s.session.events.where((e) => e == 'start'), hasLength(2));
    await s.h.close();
  });

  testWidgets('écran poussé par-dessus : serveur arrêté, repris au retour', (
    t,
  ) async {
    final s = _Setup(t, tab: AddAddonTab.phone);
    await s.open();
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('SECOND')),
        ),
      ),
    );
    await s.h.settle();
    expect(s.session.events.last, 'stop');
    nav.pop();
    await s.h.settle();
    expect(s.session.events.where((e) => e == 'start'), hasLength(2));
    await s.h.close();
  });

  testWidgets('retour sur un autre onglet : le serveur ne redémarre pas', (
    t,
  ) async {
    final s = _Setup(t, tab: AddAddonTab.phone);
    await s.open();
    await t.tap(find.byKey(const ValueKey('addtab:catalog')));
    await s.h.settle();
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('SECOND')),
        ),
      ),
    );
    await s.h.settle();
    nav.pop();
    await s.h.settle();
    expect(s.session.events.where((e) => e == 'start'), hasLength(1));
    await s.h.close();
  });

  testWidgets('trop d\'essais : message et Relancer sur la TV', (t) async {
    final s = _Setup(t, tab: AddAddonTab.phone);
    await s.open();
    s.session.set(const PhoneServerState(tooManyTries: true));
    await s.h.settle();
    expect(find.textContaining('Trop d\'essais'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('phone-restart')));
    await s.h.settle();
    expect(find.byType(QrImageView), findsOneWidget);
    await s.h.close();
  });

  testWidgets('verrou : affiché puis effacé à l\'échéance', (t) async {
    final s = _Setup(t, tab: AddAddonTab.phone);
    await s.open();
    s.session.set(
      PhoneServerState(
        status: PhoneServerStatus.listening,
        host: '192.168.0.45',
        port: 8790,
        code: '482913',
        lockedUntil: DateTime.now().add(const Duration(seconds: 60)),
      ),
    );
    await t.pump();
    expect(find.textContaining('Trop d\'essais'), findsOneWidget);
    await t.pump(const Duration(seconds: 61));
    expect(find.textContaining('Trop d\'essais'), findsNothing);
    expect(
      find.textContaining('Page ouverte tant que cet écran'),
      findsOneWidget,
    );
    // Un verrou déjà échu n'est jamais affiché.
    s.session.set(
      PhoneServerState(
        status: PhoneServerStatus.listening,
        host: '192.168.0.45',
        port: 8790,
        code: '111111',
        lockedUntil: DateTime.now().subtract(const Duration(seconds: 5)),
      ),
    );
    await t.pump();
    expect(find.textContaining('Trop d\'essais'), findsNothing);
    await s.h.close();
  });

  testWidgets('lien privé du téléphone : confirmation d\'adresse locale', (
    t,
  ) async {
    final s = _Setup(t, tab: AddAddonTab.phone);
    await s.open();
    final req = s.session.adds.submit(
      Uri.parse('http://192.168.1.50:7000/manifest.json'),
    );
    await s.h.settle();
    // La TV demande confirmation ; rien n'est installé ni annulé, et le
    // serveur du téléphone reste en route derrière le dialogue.
    expect(find.text('Adresse locale'), findsOneWidget);
    expect(req.state, PhoneAddState.waiting);
    expect(s.session.events, isNot(contains('stop')));
    await t.tap(find.text('Annuler'));
    await s.h.settle();
    expect(req.state, PhoneAddState.failed);
    expect(find.byType(QrImageView), findsOneWidget);
    await s.h.close();
  });

  testWidgets(
    'carte du rail des Réglages : adresse, ouvre l\'onglet téléphone',
    (t) async {
      final h = AppHarness(t);
      final session = FakePhoneSession();
      await h.pump(
        const SettingsScreen(),
        extra: [
          catalogOverride(FakeCatalogSite(cards: const [], details: const {})),
          phoneSessionFactoryProvider.overrideWithValue((_) => session),
        ],
      );
      await h.settle();
      expect(find.text('Gérer depuis le téléphone'), findsOneWidget);
      expect(find.text('192.168.0.45:8790'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('settings-phone')));
      await h.settle();
      expect(find.byType(QrImageView), findsOneWidget);
      expect(session.events, contains('start'));
      await h.close();
    },
  );

  testWidgets('carte du rail sans réseau local', (t) async {
    final h = AppHarness(t);
    await h.pump(
      const SettingsScreen(),
      extra: [lanAddressSourceProvider.overrideWithValue(const FakeLan(null))],
    );
    await h.settle();
    expect(find.text('Réseau local indisponible'), findsOneWidget);
    await h.close();
  });
}
