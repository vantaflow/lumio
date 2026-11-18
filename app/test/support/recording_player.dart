import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/player/play_router.dart' show LocalFileSource;
import 'package:lumio/player/player_controller.dart';
import 'package:lumio/player/source_fallback.dart';
import 'package:lumio/player/subtitle_style.dart';
import 'package:lumio/player/tracks_controller.dart';
import 'package:lumio_core/lumio_core.dart';

/// Contrôleur de lecteur factice qui note les ouvertures, `trustedLocal` et
/// les erreurs affichées.
class RecordingPlayerController extends Fake implements PlayerController {
  final _state = ValueNotifier<PlayerState>(const PlayerState());
  final opened = <StreamItem>[];
  final trusted = <bool>[];
  final locals = <LocalFileSource?>[];
  final failures = <String>[];

  /// Sources dont l'ouverture échoue (par titre) : `open` affiche l'échec.
  final failOpen = <String>{};

  /// Séries de basculement lancées : sources demandées.
  final fallbackRuns = <List<String>>[];
  bool _lastFallbackable = false;

  @override
  ValueListenable<PlayerState> get stateListenable => _state;
  @override
  PlayerState get state => _state.value;
  @override
  void showOpening() =>
      _state.value = const PlayerState(phase: PlayerPhase.opening);
  @override
  void fail(String message, {bool fallbackable = false}) {
    failures.add(message);
    _lastFallbackable = fallbackable;
    _state.value = PlayerState(phase: PlayerPhase.failed, error: message);
  }

  @override
  Future<void> open(
    StreamItem s, {
    bool allowPrivate = false,
    bool trustedLocal = false,
    LocalFileSource? local,
    Duration start = Duration.zero,
  }) async {
    opened.add(s);
    trusted.add(trustedLocal);
    locals.add(local);
    if (failOpen.contains(s.title)) {
      fail('échec ${s.title}', fallbackable: true);
      return;
    }
    _state.value = const PlayerState(phase: PlayerPhase.playing);
  }

  /// Même enchaînement que le vrai contrôleur : une source qui échoue sans
  /// image passe à la suivante, un échec non imputable à la source arrête.
  @override
  Future<StreamItem?> playWithFallback(
    List<StreamItem> ranked, {
    Future<void> Function(StreamItem item)? opener,
    int maxAttempts = 3,
    Duration attemptTimeout = const Duration(minutes: 3),
    Future<void> Function(StreamItem item)? onAbandon,
  }) {
    fallbackRuns.add([for (final s in ranked) s.title]);
    return runWithFallback<StreamItem>(
      ranked,
      maxAttempts: maxAttempts,
      attempt: (item, i, last) async {
        _lastFallbackable = false;
        await (opener ?? (StreamItem s) => open(s))(item);
        if (state.phase != PlayerPhase.failed) return AttemptOutcome.played;
        return _lastFallbackable
            ? AttemptOutcome.sourceFailed
            : AttemptOutcome.stopped;
      },
    );
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
