import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lumio/player/local_proxy.dart';
import 'package:lumio/player/player_controller.dart';
import 'package:lumio_core/lumio_core.dart' hide Video;
import 'package:media_kit_video/media_kit_video.dart';

/// Banc d'essai du lecteur (`--dart-define=LUMIO_DEBUG_PLAYER=1`) : lit les
/// 5 sources du spike 0.3 via [PlayerController] ; journal `LUMIO_PLAYER`.
const _sources = <String, String>{
  'HLS Mux (H.264)': 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
  'HLS Apple HEVC':
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/master.m3u8',
  'MP4 H.265 1080p':
      'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h265/1080/Big_Buck_Bunny_1080_10s_5MB.mp4',
  'MKV 1080p':
      'https://test-videos.co.uk/vids/bigbuckbunny/mkv/1080/Big_Buck_Bunny_1080_10s_5MB.mkv',
  'MP4 H.264 1080p':
      'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/1080/Big_Buck_Bunny_1080_10s_5MB.mp4',
};

class PlayerSpikeScreen extends StatefulWidget {
  const PlayerSpikeScreen({super.key});

  @override
  State<PlayerSpikeScreen> createState() => _PlayerSpikeScreenState();
}

class _PlayerSpikeScreenState extends State<PlayerSpikeScreen> {
  LocalProxy? _proxy;
  late final PlayerController _ctl = PlayerController(
    proxy: () async => _proxy ??= await LocalProxy.start(),
  );
  String _status = 'démarrage…';

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  void _log(PlaybackReport r) {
    // ignore: avoid_print
    print(r.toLogLine());
  }

  Future<void> _run() async {
    // Laisse la vue se monter avant d'ouvrir (le rendu vidéo en dépend).
    await Future<void>.delayed(const Duration(seconds: 1));
    for (final e in _sources.entries) {
      if (!mounted) return;
      setState(() => _status = e.key);
      final url = Uri.parse(e.value);
      final item = StreamItem(addonId: 'debug', title: e.key, url: url);
      var proxied = false;
      try {
        await _ctl.open(item);
        proxied = true;
        final ms = await _ctl.waitFirstFrame(const Duration(seconds: 30));
        await Future<void>.delayed(const Duration(seconds: 4));
        _log(
          PlaybackReport(
            source: e.key,
            viaProxy: proxied,
            firstFrameMs: ms,
            url: url,
            extra: {
              'size': '${_ctl.player.state.width}x${_ctl.player.state.height}',
              'ok': true,
            },
          ),
        );
      } catch (err) {
        _log(
          PlaybackReport(
            source: e.key,
            viaProxy: proxied,
            url: url,
            error: _ctl.state.error ?? explainFailure(err),
            extra: const {'ok': false},
          ),
        );
      }
      await _ctl.player.stop();
    }
    // ignore: avoid_print
    print('LUMIO_PLAYER {"event":"end"}');
    if (mounted) setState(() => _status = 'terminé');
  }

  @override
  void dispose() {
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
            'Lecteur — $_status',
            style: const TextStyle(color: Colors.white, fontSize: 24),
          ),
        ),
      ],
    ),
  );
}
