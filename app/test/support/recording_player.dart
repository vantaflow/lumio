import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/player/player_controller.dart';
import 'package:lumio/player/subtitle_style.dart';
import 'package:lumio/player/tracks_controller.dart';
import 'package:lumio_core/lumio_core.dart';

/// Contrôleur de lecteur factice qui note les ouvertures, `trustedLocal` et
/// les erreurs affichées.
class RecordingPlayerController extends Fake implements PlayerController {
  final _state = ValueNotifier<PlayerState>(const PlayerState());
  final opened = <StreamItem>[];
  final trusted = <bool>[];
  final failures = <String>[];

  @override
  ValueListenable<PlayerState> get stateListenable => _state;
  @override
  PlayerState get state => _state.value;
  @override
  void showOpening() =>
      _state.value = const PlayerState(phase: PlayerPhase.opening);
  @override
  void fail(String message) {
    failures.add(message);
    _state.value = PlayerState(phase: PlayerPhase.failed, error: message);
  }

  @override
  Future<void> open(
    StreamItem s, {
    bool allowPrivate = false,
    bool trustedLocal = false,
    Duration start = Duration.zero,
  }) async {
    opened.add(s);
    trusted.add(trustedLocal);
    _state.value = const PlayerState(phase: PlayerPhase.playing);
  }
}

class NoTracksBackend implements TracksBackend {
  @override
  final audioTracks = const <TrackOption>[];
  @override
  final subtitleTracks = const <TrackOption>[];
  @override
  String? get selectedAudioId => null;
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
