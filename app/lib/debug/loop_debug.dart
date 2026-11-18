import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/debug/loop_scheduler.dart';
import 'package:lumio/player/local_proxy.dart';
import 'package:lumio/player/player_controller.dart';
import 'package:lumio/torrent/torrent_playback.dart';
import 'package:lumio/torrent/torrent_providers.dart';
import 'package:lumio_core/lumio_core.dart' hide Video;
import 'package:media_kit/media_kit.dart' show PlaylistMode;
import 'package:media_kit_video/media_kit_video.dart';

/// Boucle d'endurance (`--dart-define=LUMIO_DEBUG_LOOP=1`) : fichier direct
/// (Big Buck Bunny) puis Sintel par la voie torrent, en alternance jusqu'à
/// l'arrêt de l'application. Journaux `LUMIO_PLAYER {json}` et
/// `LUMIO_TORRENT {json}` lus par `scripts/endurance.sh`.
final Uri loopDirectUrl = Uri.parse(
  'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/1080/Big_Buck_Bunny_1080_10s_5MB.mp4',
);
const loopSintelHash = '08ada5a7a6183aae1e09d831df6748d566095a10';
const loopTrackers = [
  'wss://tracker.openwebtorrent.com',
  'wss://tracker.btorrent.xyz',
  'wss://tracker.webtorrent.dev',
  'udp://tracker.opentrackr.org:1337/announce',
  'udp://open.tracker.cl:1337/announce',
  'udp://tracker.torrent.eu.org:451/announce',
];

/// Durée de chaque phase (minutes) ; `--dart-define=LUMIO_LOOP_MINUTES=N`.
const loopPhaseMinutes = int.fromEnvironment(
  'LUMIO_LOOP_MINUTES',
  defaultValue: 10,
);

void _printLog(String tag, Map<String, Object?> json) {
  // ignore: avoid_print
  print('$tag ${jsonEncode(json)}');
}

class LoopDebugScreen extends ConsumerStatefulWidget {
  const LoopDebugScreen({super.key});

  @override
  ConsumerState<LoopDebugScreen> createState() => _LoopDebugScreenState();
}

class _LoopDebugScreenState extends ConsumerState<LoopDebugScreen> {
  LocalProxy? _proxy;
  late final PlayerController _ctl = PlayerController(
    proxy: () async => _proxy ??= await LocalProxy.start(),
  );
  TorrentPlayback? _torrent;
  LoopScheduler? _sched;
  String _status = 'démarrage…';

  Map<String, Object?> _playerStatus() {
    final s = _ctl.state;
    return {
      'state': s.phase.name,
      'pos_s': s.position.inSeconds,
      'dur_s': s.duration.inSeconds,
      'error': ?s.error == null ? null : 'player_error',
    };
  }

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    // Laisse la vue se monter avant d'ouvrir (le rendu vidéo en dépend).
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    final factory = ref.read(torrentPlaybackFactoryProvider);
    final sched = _sched = LoopScheduler(
      phaseDuration: Duration(minutes: loopPhaseMinutes),
      log: (tag, json) {
        _printLog(tag, json);
        if (mounted) setState(() => _status = '${json['phase'] ?? ''}');
      },
      phases: [
        LoopPhase(
          name: 'direct',
          logTag: 'LUMIO_PLAYER',
          start: () async {
            await _ctl.open(
              StreamItem(addonId: 'debug', title: 'bbb', url: loopDirectUrl),
            );
            // Le clip dure 10 s : relu en boucle pendant toute la phase.
            await _ctl.player.setPlaylistMode(PlaylistMode.single);
          },
          stop: () async {
            await _ctl.player.setPlaylistMode(PlaylistMode.none);
            await _ctl.player.stop();
          },
          status: _playerStatus,
        ),
        LoopPhase(
          name: 'torrent',
          logTag: 'LUMIO_TORRENT',
          start: () async {
            final t = _torrent = factory();
            final url = await t.prepare(
              const StreamItem(
                addonId: 'debug',
                title: 'sintel',
                infoHash: loopSintelHash,
                trackers: loopTrackers,
              ),
            );
            await _ctl.open(
              StreamItem(addonId: 'debug', title: 'sintel', url: url),
              trustedLocal: true,
            );
          },
          stop: () async {
            await _ctl.player.stop();
            await _torrent?.release();
            _torrent = null;
          },
          status: _playerStatus,
        ),
      ],
    );
    await sched.run();
    _printLog('LUMIO_PLAYER', {'event': 'loop_end'});
  }

  @override
  void dispose() {
    _sched?.stop();
    unawaited(_torrent?.release());
    unawaited(_ctl.dispose());
    unawaited(_proxy?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        Center(
          child: Video(controller: _ctl.video, controls: NoVideoControls),
        ),
        Positioned(
          left: 24,
          top: 24,
          child: Text(
            'Endurance — $_status',
            style: const TextStyle(color: Colors.white, fontSize: 24),
          ),
        ),
      ],
    ),
  );
}
