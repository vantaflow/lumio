import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/features/tracking/tracking_providers.dart';
import 'package:lumio/player/playback_events.dart';

/// Bus d'événements du lecteur, avec ses écouteurs branchés (suivi Trakt).
/// Le lecteur n'émet que des [PlaybackEvent] et ignore qui écoute.
final playbackEventsProvider = Provider<PlaybackEvents>((ref) {
  final events = PlaybackEvents();
  events.addListener((e) => ref.read(trackingServiceProvider).onPlayback(e));
  return events;
});
