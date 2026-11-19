import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/player/subtitle_style.dart';
import 'package:lumio/player/tracks_controller.dart';
import 'package:lumio/player/tracks_panel.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

class ThrowingStore implements TitleSettingsStore {
  @override
  TitleSettings forTitle(String p, String m) => const TitleSettings();
  @override
  void save(String p, String m, TitleSettings s) => throw StateError('disque');
}

class FakeFetcher implements HttpFetcher {
  FakeFetcher(this.status);
  final int status;
  int? maxBytesSeen;
  @override
  Future<FetchResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) async {
    guard?.call(url);
    maxBytesSeen = maxBytes;
    return FetchResponse(status: status, body: [65]);
  }
}

SubtitleItem addonSub(String id, String url, {String lang = 'fr'}) =>
    SubtitleItem(id: id, url: Uri.parse(url), lang: lang, addonId: 'ad');

class FakeBackend implements TracksBackend {
  @override
  List<TrackOption> audioTracks = const [
    TrackOption(id: '1', label: 'Français', lang: 'fr'),
    TrackOption(id: '2', label: 'English', lang: 'en'),
  ];
  @override
  List<TrackOption> subtitleTracks = const [
    TrackOption(id: '10', label: 'Français SDH', lang: 'fr'),
  ];
  @override
  String? selectedAudioId = '1';
  @override
  String? selectedSubtitleId;
  final calls = <String>[];
  final _c = StreamController<void>.broadcast();
  void emit() => _c.add(null);
  @override
  Stream<void> get changes => _c.stream;

  @override
  Future<void> selectAudio(String id) async {
    calls.add('audio:$id');
    selectedAudioId = id;
  }

  @override
  Future<void> selectSubtitle(String? id) async {
    calls.add('sub:$id');
    selectedSubtitleId = id;
  }

  @override
  Future<void> loadExternalSubtitle(
    String path, {
    String? title,
    String? lang,
  }) async => calls.add('ext:$path');

  @override
  Future<void> setSubtitleDelay(int ms) async => calls.add('delay:$ms');

  @override
  Future<void> applySubtitleStyle(SubtitleStyle style) async =>
      calls.add('style:${style.size.name}:${style.opaqueBackground}');
}

class ErrBackend extends FakeBackend implements SubtitleErrorSource {
  final errs = StreamController<String>.broadcast();
  @override
  Stream<String> get subtitleErrors => errs.stream;
  @override
  Future<void> loadExternalSubtitle(
    String path, {
    String? title,
    String? lang,
  }) async {
    await super.loadExternalSubtitle(path, title: title, lang: lang);
    // Le moteur refuse le fichier juste après l'ajout.
    Timer(const Duration(milliseconds: 10), () => errs.add('Can not open'));
  }
}

class _OkBackend extends FakeBackend implements SubtitleErrorSource {
  @override
  Stream<String> get subtitleErrors => const Stream.empty();
}

TracksController make(
  FakeBackend b,
  InMemoryTitleSettingsStore store, {
  List<SubtitleItem> addon = const [],
  Future<List<int>> Function(SubtitleItem)? download,
  SubtitleTempStore? temp,
  String meta = 'tt1:1:2',
}) => TracksController(
  backend: b,
  store: store,
  profileId: 'p',
  metaId: meta,
  addonSubtitles: addon,
  download: download,
  tempStore: temp ?? SubtitleTempStore(() async => Directory.systemTemp),
);

Widget host(TracksController c, {VoidCallback? onClose}) => MaterialApp(
  theme: ThemeData(extensions: const [LumioColors.dark]),
  home: Scaffold(
    body: Align(
      alignment: Alignment.centerRight,
      child: TracksPanel(controller: c, onClose: onClose ?? () {}),
    ),
  ),
);

/// Écran assez haut pour afficher tout le panneau (taille, décalage, fermer).
Future<void> pumpHost(
  WidgetTester t,
  TracksController c, {
  VoidCallback? onClose,
}) async {
  t.view.physicalSize = const Size(800, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(host(c, onClose: onClose));
}

void main() {
  testWidgets('liste 2 pistes audio et la sélection appelle le contrôleur', (
    t,
  ) async {
    final b = FakeBackend();
    final c = make(b, InMemoryTitleSettingsStore());
    await pumpHost(t, c);
    expect(find.text('Français'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    await t.tap(find.text('English'));
    await t.pump();
    expect(b.calls, contains('audio:2'));
    expect(c.settings.audioLang, 'en');
  });

  testWidgets('décalage +300 ms persisté pour la série, borné à ±10 s', (
    t,
  ) async {
    final b = FakeBackend();
    final store = InMemoryTitleSettingsStore();
    final c = make(b, store);
    await pumpHost(t, c);
    for (var i = 0; i < 3; i++) {
      await t.tap(find.byKey(const ValueKey('delay-plus')));
      await t.pump();
    }
    expect(find.text('+0,3 s'), findsOneWidget);
    expect(b.calls.last, 'delay:300');
    expect(store.forTitle('p', 'tt1:5:5').subtitleDelayMs, 300);
    await c.changeDelay(50000);
    expect(c.delayMs, 10000);
    await c.changeDelay(-50000);
    expect(c.delayMs, -10000);
  });

  testWidgets('taille et fond opaque appliqués', (t) async {
    final b = FakeBackend();
    final c = make(b, InMemoryTitleSettingsStore());
    await pumpHost(t, c);
    // Normale -> Grande -> Très grande avec « + ».
    await t.tap(find.byKey(const ValueKey('size-plus')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('size-plus')));
    await t.pump();
    expect(find.text('Très grande'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('bg-toggle')));
    await t.pump();
    expect(b.calls, contains('style:xl:false'));
    expect(b.calls.last, 'style:xl:true');
    expect(const SubtitleStyle(opaqueBackground: true).mpvProperties, {
      'sub-font-size': '55',
      'sub-border-style': 'background-box',
      'sub-back-color': '#FF000000',
    });
  });

  testWidgets('sous-titre d\'addon illisible : message français', (t) async {
    final b = FakeBackend();
    final item = SubtitleItem(
      id: 'a1',
      url: Uri.parse('https://x.test/s.srt'),
      lang: 'fr',
      addonId: 'ad',
    );
    final c = make(
      b,
      InMemoryTitleSettingsStore(),
      addon: [item],
      download: (_) async => [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    );
    await pumpHost(t, c);
    await t.tap(find.text('Français · Addon'));
    await t.pump();
    await t.pump();
    expect(find.text('Sous-titre illisible'), findsOneWidget);
    expect(b.calls.where((x) => x.startsWith('ext:')), isEmpty);
  });

  testWidgets('sous-titre d\'addon valide chargé en piste externe', (t) async {
    final b = FakeBackend();
    final item = SubtitleItem(
      id: 'a1',
      url: Uri.parse('https://x.test/s.srt'),
      lang: 'fr',
      addonId: 'ad',
    );
    final c = make(
      b,
      InMemoryTitleSettingsStore(),
      addon: [item],
      download: (_) async =>
          '1\n00:00:01,000 --> 00:00:02,000\nSalut\n'.codeUnits,
    );
    await pumpHost(t, c);
    await t.runAsync(() => c.selectAddonSubtitle(item));
    await t.pump();
    expect(b.calls.where((x) => x.startsWith('ext:')), hasLength(1));
    expect(c.addonSelectedId, 'a1');
  });

  test(
    'fichier refusé par le moteur : plus choisi, message, non mémorisé',
    () async {
      final b = ErrBackend();
      final item = addonSub('a1', 'https://x.test/s.srt');
      final c = TracksController(
        backend: b,
        store: InMemoryTitleSettingsStore(),
        profileId: 'p',
        metaId: 'm',
        addonSubtitles: [item],
        download: (_) async =>
            '1\n00:00:01,000 --> 00:00:02,000\nA\n'.codeUnits,
        tempStore: SubtitleTempStore(() async => Directory.systemTemp),
        refusalWindow: const Duration(milliseconds: 100),
      );
      final msgs = <String>[];
      c.errors.listen(msgs.add);
      await c.selectAddonSubtitle(item);
      await Future<void>.delayed(Duration.zero);
      expect(c.addonSelectedId, isNull);
      expect(msgs, ['Sous-titre illisible']);
      expect(c.settings.subtitleLang, isNull);
      c.dispose();
    },
  );

  test('fichier accepté : reste choisi et mémorisé après la fenêtre', () async {
    final item = addonSub('a1', 'https://x.test/s.srt');
    final c = TracksController(
      backend: _OkBackend(),
      store: InMemoryTitleSettingsStore(),
      profileId: 'p',
      metaId: 'm',
      addonSubtitles: [item],
      download: (_) async => '1\n00:00:01,000 --> 00:00:02,000\nA\n'.codeUnits,
      tempStore: SubtitleTempStore(() async => Directory.systemTemp),
      refusalWindow: const Duration(milliseconds: 50),
    );
    await c.selectAddonSubtitle(item);
    expect(c.addonSelectedId, 'a1');
    expect(c.settings.subtitleLang, 'fr');
    c.dispose();
  });

  testWidgets('libellés des sous-titres d\'addons : langue, source, rang', (
    t,
  ) async {
    SubtitleItem sub(String id, String lang, String addonId, String? name) =>
        SubtitleItem(
          id: id,
          url: Uri.parse('https://x.test/$id.srt'),
          lang: lang,
          addonId: addonId,
          addonName: name,
        );
    final items = [
      sub('1', 'en', 'os', 'OpenSubtitles v3'),
      sub('2', 'en', 'os', 'OpenSubtitles v3'),
      sub('3', 'en', 'os', 'OpenSubtitles v3'),
      sub('4', 'fr', 'os', 'OpenSubtitles v3'),
      sub('5', 'en', 'fl', 'Films libres (test)'),
      sub('6', 'und', 'fl', 'Films libres (test)'),
    ];
    final c = make(FakeBackend(), InMemoryTitleSettingsStore(), addon: items);
    final labels = [for (final s in items) c.addonLabel(s)];
    expect(labels, [
      'English · OpenSubtitles v3 1',
      'English · OpenSubtitles v3 2',
      'English · OpenSubtitles v3 3',
      'Français · OpenSubtitles v3',
      'English · Films libres (test)',
      'Langue inconnue · Films libres (test)',
    ]);
    expect(labels.toSet(), hasLength(items.length));
  });

  testWidgets(
    'D-pad : ordre audio, taille, décalage, fond, sous-titres, fermer',
    (t) async {
      final b = FakeBackend();
      final c = make(b, InMemoryTitleSettingsStore());
      var closed = false;
      await pumpHost(t, c, onClose: () => closed = true);
      Future<void> next() async {
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump();
      }

      final order = <Key>[
        const ValueKey('audio-1'),
        const ValueKey('audio-2'),
        const ValueKey('size-minus'),
        const ValueKey('size-plus'),
        const ValueKey('delay-minus'),
        const ValueKey('delay-plus'),
        const ValueKey('bg-toggle'),
        const ValueKey('sub-off'),
        const ValueKey('sub-10'),
        const ValueKey('tracks-close'),
      ];
      await t.pump();
      for (final k in order) {
        // Le premier élément a le focus à l'ouverture (autofocus).
        if (k != order.first) await next();
        final ctx = FocusManager.instance.primaryFocus!.context;
        expect(
          find.descendant(
            of: find.byKey(k),
            matching: find.byElementPredicate((e) => e == ctx),
          ),
          findsOneWidget,
          reason: 'focus attendu sur $k',
        );
      }
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(closed, isTrue);
    },
  );

  test('réglages mémorisés réappliqués à l\'ouverture', () async {
    final store = InMemoryTitleSettingsStore()
      ..save(
        'p',
        'tt1',
        const TitleSettings(audioLang: 'en', subtitleDelayMs: 300),
      );
    final b = FakeBackend();
    final c = make(b, store, meta: 'tt1:2:4');
    await c.init();
    expect(b.calls, contains('delay:300'));
    expect(b.calls, contains('audio:2'));
  });

  group('downloadSubtitle', () {
    final priv = Uri.parse('http://192.168.1.5/s.srt');
    test('adresse privée refusée pour un addon non autorisé', () async {
      expect(
        () => downloadSubtitle(FakeFetcher(200), priv, allowPrivate: false),
        throwsA(isA<Object>()),
      );
    });
    test('adresse privée acceptée pour un addon autorisé', () async {
      final f = FakeFetcher(200);
      expect(await downloadSubtitle(f, priv, allowPrivate: true), [65]);
      expect(f.maxBytesSeen, 2 * 1024 * 1024);
    });
    test('statut différent de 200 : erreur', () async {
      expect(
        () => downloadSubtitle(
          FakeFetcher(404),
          Uri.parse('https://x.test/s.srt'),
          allowPrivate: false,
        ),
        throwsA(isA<HttpException>()),
      );
    });
  });

  group('fichiers temporaires', () {
    test('noms sans collision, dossier supprimé à la fermeture', () async {
      final base = await Directory.systemTemp.createTemp('lumio-test-');
      addTearDown(() => base.delete(recursive: true));
      final store = SubtitleTempStore(() async => base);
      final a = await store.write(Uri.parse('https://x.test/a.srt'), 'a');
      final b = await store.write(Uri.parse('https://x.test/b.srt'), 'b');
      expect(a, isNot(b));
      expect(File(a).readAsStringSync(), 'a');
      expect(File(a).parent.path, File(b).parent.path);
      expect(File(a).parent.path, isNot(base.path));
      await store.dispose();
      expect(File(a).existsSync(), isFalse);
      expect(File(a).parent.existsSync(), isFalse);
    });

    test('le contrôleur supprime ses fichiers à sa fermeture', () async {
      final base = await Directory.systemTemp.createTemp('lumio-test-');
      addTearDown(() => base.delete(recursive: true));
      final c = make(
        FakeBackend(),
        InMemoryTitleSettingsStore(),
        addon: [addonSub('a1', 'https://x.test/a.srt')],
        download: (_) async =>
            '1\n00:00:01,000 --> 00:00:02,000\nX\n'.codeUnits,
        temp: SubtitleTempStore(() async => base),
      );
      await c.selectAddonSubtitle(c.addonSubtitles.first);
      expect(base.listSync(), hasLength(1));
      c.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(base.listSync(), isEmpty);
    });
  });

  group('contrôleur', () {
    test('piste audio sans langue mémorisée par son rang', () async {
      final b = FakeBackend()
        ..audioTracks = const [
          TrackOption(id: '1', label: 'Piste 1'),
          TrackOption(id: '2', label: 'Piste 2'),
        ];
      final store = InMemoryTitleSettingsStore();
      final c = make(b, store);
      await c.selectAudio(b.audioTracks[1]);
      expect(store.forTitle('p', 'tt1').audioLang, 'idx:1');
      final b2 = FakeBackend()..audioTracks = b.audioTracks;
      await make(b2, store, meta: 'tt1:1:3').init();
      expect(b2.calls, contains('audio:2'));
    });

    test('sous-titre d\'addon de l\'épisode précédent rechargé', () async {
      final store = InMemoryTitleSettingsStore();
      final b = FakeBackend()..subtitleTracks = const [];
      final item = addonSub('a1', 'https://x.test/a.srt');
      final c = make(
        b,
        store,
        addon: [item],
        download: (_) async =>
            '1\n00:00:01,000 --> 00:00:02,000\nX\n'.codeUnits,
      );
      await c.selectAddonSubtitle(item);
      c.dispose();
      final b2 = FakeBackend()..subtitleTracks = const [];
      final next = make(
        b2,
        store,
        meta: 'tt1:1:3',
        addon: [addonSub('a2', 'https://x.test/b.srt')],
        download: (_) async =>
            '1\n00:00:01,000 --> 00:00:02,000\nY\n'.codeUnits,
      );
      await next.init();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(b2.calls.where((x) => x.startsWith('ext:')), hasLength(1));
      next.dispose();
    });

    test('échec d\'enregistrement signalé', () async {
      final c = TracksController(
        backend: FakeBackend(),
        store: ThrowingStore(),
        profileId: 'p',
        metaId: 'tt1',
      );
      final msgs = <String>[];
      c.errors.listen(msgs.add);
      await c.changeDelay(100);
      await Future<void>.delayed(Duration.zero);
      expect(msgs, ['Réglages non enregistrés']);
      c.dispose();
    });

    test('aucun effet après fermeture', () async {
      final b = FakeBackend();
      final c = make(b, InMemoryTitleSettingsStore());
      c.dispose();
      b.emit();
      await c.changeDelay(100);
      await c.selectAddonSubtitle(addonSub('x', 'https://x.test/a.srt'));
    });
  });
}
