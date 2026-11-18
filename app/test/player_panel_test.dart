import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/title_settings_store.dart';
import 'package:lumio/player/play_router.dart' show LocalFileSource;
import 'package:lumio/player/player_controller.dart';
import 'package:lumio/player/player_screen.dart';
import 'package:lumio/player/subtitle_style.dart';
import 'package:lumio/player/tracks_controller.dart';
import 'package:lumio/player/tracks_panel.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

class FakeCtl extends Fake implements PlayerController {
  final _state = ValueNotifier<PlayerState>(
    const PlayerState(phase: PlayerPhase.paused),
  );
  @override
  ValueListenable<PlayerState> get stateListenable => _state;
  @override
  PlayerState get state => _state.value;
  @override
  Future<void> open(
    StreamItem s, {
    bool allowPrivate = false,
    bool trustedLocal = false,
    LocalFileSource? local,
    Duration start = Duration.zero,
  }) async {}
}

class Backend implements TracksBackend {
  @override
  final audioTracks = const [
    TrackOption(id: '1', label: 'Français', lang: 'fr'),
    TrackOption(id: '2', label: 'English', lang: 'en'),
  ];
  @override
  final subtitleTracks = const <TrackOption>[];
  @override
  String? get selectedAudioId => '1';
  @override
  String? get selectedSubtitleId => null;
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  Future<void> selectAudio(String id) async {}
  @override
  Future<void> selectSubtitle(String? id) async {}
  @override
  Future<void> loadExternalSubtitle(
    String path, {
    String? title,
    String? lang,
  }) async {}
  @override
  Future<void> setSubtitleDelay(int ms) async {}
  @override
  Future<void> applySubtitleStyle(SubtitleStyle style) async {}
}

void main() {
  testWidgets(
    'panneau : focus au D-pad piégé, Retour le ferme et rend le focus',
    (t) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = DriftTitleSettingsStore(db);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            titleSettingsStoreProvider.overrideWith((ref) async => store),
            subtitleStyleStoreProvider.overrideWithValue(
              SubtitleStyleStore(db),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: const [LumioColors.dark]),
            home: PlayerScreen(
              item: StreamItem(
                addonId: 'ad',
                title: 'Film',
                url: Uri.parse('https://x.test/v.mp4'),
              ),
              metaId: 'tt1',
              controller: FakeCtl(),
              videoBuilder: (_) => const ColoredBox(color: Colors.black),
              tracksBackend: (_) => Backend(),
            ),
          ),
        ),
      );
      final button = find.bySemanticsLabel('Pistes et sous-titres');
      for (var i = 0; i < 20 && button.evaluate().isEmpty; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await t.pump();
      }
      expect(button, findsOneWidget);
      await t.tap(button);
      await t.pumpAndSettle();
      expect(find.byType(TracksPanel), findsOneWidget);

      bool inPanel() {
        final ctx = FocusManager.instance.primaryFocus?.context;
        if (ctx == null) return false;
        return find
            .descendant(
              of: find.byType(TracksPanel),
              matching: find.byElementPredicate((e) => e == ctx),
            )
            .evaluate()
            .isNotEmpty;
      }

      // Focus d'emblée sur la première piste audio.
      expect(inPanel(), isTrue);
      for (var i = 0; i < 25; i++) {
        await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await t.pump();
        expect(inPanel(), isTrue, reason: 'bas #$i');
      }
      for (var i = 0; i < 8; i++) {
        await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await t.pump();
        expect(inPanel(), isTrue);
      }
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.byType(TracksPanel), findsNothing);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'player-tracks');
    },
  );
}
