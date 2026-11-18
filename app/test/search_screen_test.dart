import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/features/search/search_providers.dart';
import 'package:lumio/ui/focus/focus_memory.dart';
import 'package:lumio/features/search/search_screen.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

AddonManifest _manifest(String id, {bool search = true}) => AddonManifest(
  id: id,
  version: '1.0.0',
  name: 'Addon $id',
  types: const ['movie'],
  resources: const [AddonResource('catalog')],
  catalogs: [
    CatalogDecl(
      type: 'movie',
      id: 'top',
      name: 'Top',
      extra: [if (search) const ExtraDecl('search')],
    ),
  ],
  transportUrl: Uri.parse('https://$id.example.com/tok/manifest.json'),
);

MetaPreview _meta(String id, {String cert = 'G', String type = 'movie'}) =>
    MetaPreview(
      id: id,
      type: type,
      name: 'Film $id',
      sourceAddonId: 'a',
      certification: cert,
    );

class _FakeAddons extends AddonsController {
  _FakeAddons(this.list);
  final List<InstalledAddon> list;

  @override
  Future<List<InstalledAddon>> build() async => list;
}

class _Mem extends FocusMemory {
  _Mem(this.id);
  final String id;

  @override
  Map<String, Map<String, String>> build() => {
    'search': {'': id},
  };
}

class _FakeProfile extends CurrentProfileController {
  _FakeProfile(this.p);
  final Profile? p;

  @override
  Profile? build() => p;
}

class _FakeSearch implements SearchService {
  final queries = <String>[];
  bool cancelled = false;
  final streams = <String, StreamController<List<MetaPreview>>>{};

  @override
  Stream<List<MetaPreview>> search(List<AddonManifest> addons, String query) {
    queries.add(query);
    return (streams[query] = StreamController<List<MetaPreview>>(
      onCancel: () => cancelled = true,
    )).stream;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeVoice implements VoiceInput {
  _FakeVoice({this.available = true});
  final bool available;
  void Function(String, bool)? onText;
  int inits = 0;

  @override
  bool get maySupport => true;

  @override
  Future<bool> init() async {
    inits++;
    return available;
  }

  @override
  Future<void> listen(void Function(String text, bool done) onText) async =>
      this.onText = onText;

  @override
  Future<void> stop() async {}
}

Future<_FakeSearch> _pump(
  WidgetTester t, {
  _FakeVoice? voice,
  Profile? profile,
  List<InstalledAddon>? addons,
  void Function(MetaPreview)? onOpen,
  String? remembered,
  bool tv = true,
}) async {
  t.view.physicalSize = const Size(1920, 1080);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final search = _FakeSearch();
  final list =
      addons ??
      [
        InstalledAddon(
          id: 'a',
          manifest: _manifest('a'),
          position: 0,
          enabled: true,
        ),
      ];
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        addonsProvider.overrideWith(() => _FakeAddons(list)),
        currentProfileProvider.overrideWith(() => _FakeProfile(profile)),
        searchServiceProvider.overrideWithValue(search),
        voiceInputProvider.overrideWithValue(voice ?? _FakeVoice()),
        if (remembered != null)
          focusMemoryProvider.overrideWith(() => _Mem(remembered)),
      ],
      child: MaterialApp(
        theme: LumioTheme.dark(),
        home: SearchScreen(onOpenItem: onOpen, tvLayout: tv),
      ),
    ),
  );
  await t.pump();
  await t.pump();
  return search;
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.tap(find.byKey(ValueKey('key-$key')));
  await t.pump();
}

void main() {
  testWidgets('anti-rebond : une seule requête pour une frappe rapide', (
    t,
  ) async {
    final s = await _pump(t);
    await _tap(t, 'm');
    await _tap(t, 'a');
    await _tap(t, 't');
    await t.pump(const Duration(milliseconds: 300));
    expect(s.queries, isEmpty);
    await t.pump(const Duration(milliseconds: 100));
    expect(s.queries, ['mat']);
  });

  testWidgets('résultats affichés, ouverture au choix', (t) async {
    MetaPreview? opened;
    final s = await _pump(t, onOpen: (m) => opened = m);
    await _tap(t, 'x');
    await t.pump(searchDebounce);
    s.streams['x']!.add([_meta('1'), _meta('2')]);
    await t.pump();
    expect(find.text('Film 1'), findsOneWidget);
    await t.tap(find.text('Film 2'));
    await t.pump();
    expect(opened?.id, '2');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('émission d\'une ancienne requête ignorée', (t) async {
    final s = await _pump(t);
    await _tap(t, 'a');
    await t.pump(searchDebounce);
    await _tap(t, 'b');
    await t.pump(searchDebounce);
    expect(s.queries, ['a', 'ab']);
    s.streams['ab']!.add([_meta('new')]);
    s.streams['a']!.add([_meta('old')]);
    await t.pump();
    expect(find.text('Film new'), findsOneWidget);
    expect(find.text('Film old'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('aucun résultat : message clair', (t) async {
    final s = await _pump(t);
    await _tap(t, 'z');
    await t.pump(searchDebounce);
    await s.streams['z']!.close();
    await t.pump();
    expect(find.text('Aucun résultat'), findsOneWidget);
  });

  testWidgets('effacer jusqu\'au vide : plus de requête', (t) async {
    final s = await _pump(t);
    await _tap(t, 'z');
    await _tap(t, 'backspace');
    await t.pump(searchDebounce);
    expect(s.queries, isEmpty);
    expect(
      find.text('Tapez un titre pour lancer la recherche'),
      findsOneWidget,
    );
  });

  testWidgets('profil enfant : certification inconnue ou interdite masquée', (
    t,
  ) async {
    final s = await _pump(
      t,
      profile: const Profile(
        id: 'kid',
        name: 'Léa',
        createdAt: 0,
        ageLimit: 1,
        isKid: true,
        locked: false,
      ),
    );
    await _tap(t, 'x');
    await t.pump(searchDebounce);
    s.streams['x']!.add([
      _meta('ok'),
      _meta('adult', cert: 'R'),
      const MetaPreview(
        id: 'unk',
        type: 'movie',
        name: 'Film unk',
        sourceAddonId: 'a',
      ),
    ]);
    await t.pump();
    expect(find.text('Film ok'), findsOneWidget);
    expect(find.text('Film adult'), findsNothing);
    expect(find.text('Film unk'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('clavier arabe', (t) async {
    final s = await _pump(t);
    await _tap(t, 'layout');
    await _tap(t, 'ك');
    await t.pump(searchDebounce);
    expect(s.queries, ['ك']);
  });

  testWidgets('micro : aucune init à l\'ouverture, masqué si refusé', (
    t,
  ) async {
    final v = _FakeVoice(available: false);
    await _pump(t, voice: v);
    expect(v.inits, 0);
    expect(find.byKey(const ValueKey('key-mic')), findsOneWidget);
    await _tap(t, 'mic');
    await t.pump();
    expect(v.inits, 1);
    expect(find.byKey(const ValueKey('key-mic')), findsNothing);
  });

  testWidgets('dictée vocale : la requête est saisie sans clavier', (t) async {
    final v = _FakeVoice();
    final s = await _pump(t, voice: v);
    await _tap(t, 'mic');
    v.onText!('matrix', true);
    await t.pump(searchDebounce);
    expect(s.queries, ['matrix']);
  });

  testWidgets('aucun addon avec recherche : message dédié', (t) async {
    final s = await _pump(
      t,
      addons: [
        InstalledAddon(
          id: 'n',
          manifest: _manifest('n', search: false),
          position: 0,
          enabled: true,
        ),
      ],
    );
    await _tap(t, 'x');
    await t.pump(searchDebounce);
    expect(s.queries, isEmpty);
    expect(
      find.text('Aucun addon actif ne propose la recherche'),
      findsOneWidget,
    );
  });

  testWidgets(
    'D-pad : droite atteint un résultat, gauche revient, select ouvre',
    (t) async {
      MetaPreview? opened;
      final s = await _pump(t, onOpen: (m) => opened = m);
      await _tap(t, 'x');
      await t.pump(searchDebounce);
      s.streams['x']!.add([_meta('1'), _meta('2')]);
      await t.pump();
      // Focus initial sur la première touche.
      expect(FocusManager.instance.primaryFocus, isNotNull);
      var guard = 0;
      // Aller à droite jusqu'à la zone résultats.
      while (!_focusIsResult(t) && guard++ < 12) {
        await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await t.pump();
      }
      expect(_focusIsResult(t), isTrue);
      guard = 0;
      while (_focusIsResult(t) && guard++ < 12) {
        await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await t.pump();
      }
      expect(_focusIsResult(t), isFalse);
      guard = 0;
      while (!_focusIsResult(t) && guard++ < 12) {
        await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await t.pump();
      }
      await t.sendKeyEvent(LogicalKeyboardKey.select);
      await t.pump();
      expect(opened, isNotNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('mémoire du focus : retour sur le résultat choisi', (t) async {
    final s = await _pump(t);
    final container = ProviderScope.containerOf(
      t.element(find.byType(SearchScreen)),
    );
    await _tap(t, 'x');
    await t.pump(searchDebounce);
    s.streams['x']!.add([_meta('1'), _meta('2'), _meta('3')]);
    await t.pump();
    // Focalise le résultat 3 puis recrée l'écran.
    var guard = 0;
    while (container.read(focusMemoryProvider.notifier).restore('search') !=
            '3' &&
        guard++ < 40) {
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pump();
    }
    expect(container.read(focusMemoryProvider.notifier).restore('search'), '3');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('mémoire du focus : le résultat mémorisé reprend le focus', (
    t,
  ) async {
    final s = await _pump(t, remembered: '2');
    await _tap(t, 'x');
    await t.pump(searchDebounce);
    s.streams['x']!.add([_meta('1'), _meta('2'), _meta('3')]);
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    final ctx = FocusManager.instance.primaryFocus!.context!;
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('result-2')),
        matching: find.byWidget(ctx.widget),
      ),
      findsWidgets,
    );
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('TV : le champ n\'est pas focalisable', (t) async {
    await _pump(t);
    final f = t.widget<TextField>(find.byType(TextField));
    expect(f.readOnly, isTrue);
    expect(f.canRequestFocus, isFalse);
  });

  testWidgets('téléphone : la saisie met à jour la requête', (t) async {
    final s = await _pump(t, tv: false);
    await t.enterText(find.byType(TextField), 'matrix');
    await t.pump(searchDebounce);
    expect(s.queries, ['matrix']);
  });

  testWidgets('TV : clavier physique ajoute des lettres', (t) async {
    final s = await _pump(t);
    await t.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    await t.sendKeyEvent(LogicalKeyboardKey.keyB, character: 'b');
    await t.pump(searchDebounce);
    expect(s.queries, ['ab']);
    await t.sendKeyEvent(LogicalKeyboardKey.backspace);
    await t.pump(searchDebounce);
    expect(s.queries, ['ab', 'a']);
  });

  testWidgets('abonnement au service annulé à la fermeture', (t) async {
    final s = await _pump(t);
    await _tap(t, 'x');
    await t.pump(searchDebounce);
    expect(s.cancelled, isFalse);
    await t.pumpWidget(const SizedBox());
    expect(s.cancelled, isTrue);
  });
}

bool _focusIsResult(WidgetTester t) {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return false;
  var found = false;
  ctx.visitAncestorElements((e) {
    final k = e.widget.key;
    if (k is ValueKey<String> && k.value.startsWith('result-')) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}
