import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/player/subtitle_style.dart';
import 'package:lumio/player/tracks_controller.dart';
import 'package:lumio/player/tracks_panel.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

class FakeBackend implements TracksBackend {
  @override
  final audioTracks = const [
    TrackOption(id: '1', label: 'Français', lang: 'fr'),
    TrackOption(id: '2', label: 'English', lang: 'en'),
  ];
  @override
  final subtitleTracks = const [
    TrackOption(id: '10', label: 'Français SDH', lang: 'fr'),
  ];
  @override
  String? selectedAudioId = '1';
  @override
  String? selectedSubtitleId;
  final calls = <String>[];
  final _c = StreamController<void>.broadcast();
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

TracksController make(
  FakeBackend b,
  InMemoryTitleSettingsStore store, {
  List<SubtitleItem> addon = const [],
  Future<List<int>> Function(Uri)? download,
  String meta = 'tt1:1:2',
}) => TracksController(
  backend: b,
  store: store,
  profileId: 'p',
  metaId: meta,
  addonSubtitles: addon,
  download: download,
  writeTemp: (name, content) async => '/tmp/$name',
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

void main() {
  testWidgets('liste 2 pistes audio et la sélection appelle le contrôleur', (
    t,
  ) async {
    final b = FakeBackend();
    final c = make(b, InMemoryTitleSettingsStore());
    await t.pumpWidget(host(c));
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
    await t.pumpWidget(host(c));
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
    await t.pumpWidget(host(c));
    await t.tap(find.byKey(const ValueKey('size-xl')));
    await t.pump();
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
    await t.pumpWidget(host(c));
    await t.tap(find.text('Addon · fr'));
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
    await t.pumpWidget(host(c));
    await t.tap(find.text('Addon · fr'));
    await t.pump();
    await t.pump();
    expect(b.calls.where((x) => x.startsWith('ext:')), hasLength(1));
    expect(c.addonSelectedId, 'a1');
  });

  testWidgets('D-pad : ordre audio, sous-titres, décalage, taille, fond', (
    t,
  ) async {
    final b = FakeBackend();
    final c = make(b, InMemoryTitleSettingsStore());
    var closed = false;
    await t.pumpWidget(host(c, onClose: () => closed = true));
    Future<void> next() async {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
    }

    final order = <Key>[
      const ValueKey('audio-1'),
      const ValueKey('audio-2'),
      const ValueKey('sub-off'),
      const ValueKey('sub-10'),
      const ValueKey('delay-minus'),
      const ValueKey('delay-plus'),
      const ValueKey('size-s'),
      const ValueKey('size-m'),
      const ValueKey('size-l'),
      const ValueKey('size-xl'),
      const ValueKey('bg-toggle'),
    ];
    for (final k in order) {
      await next();
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
  });

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
}
