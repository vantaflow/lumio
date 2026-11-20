import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/player/mpv_overrides.dart';

void main() {
  test('hwdec-codecs : liste fiable sur Android, mpv.conf prioritaire', () {
    final a = hwdecCodecsFor(android: true)!.split(',');
    expect(a, containsAll(['h264', 'hevc', 'vp9']));
    expect(a, isNot(contains('mpeg4')));
    expect(hwdecCodecsFor(android: false), isNull);
    expect(
      hwdecCodecsFor(android: true, overrides: {'hwdec-codecs': 'all'}),
      'all',
    );
  });

  test('playlist .m3u8 : format hls imposé, le reste en détection auto', () {
    expect(lavfFormatFor(Uri.parse('https://x.test/a/master.m3u8?t=1')), 'hls');
    expect(lavfFormatFor(Uri.parse('https://x.test/A/MASTER.M3U8')), 'hls');
    expect(lavfFormatFor(Uri.parse('https://x.test/film.mp4')), '');
    expect(lavfFormatFor(Uri.parse('https://x.test/stream')), '');
  });

  test('décodage : mediacodec direct par défaut sur Android, repli copie', () {
    final a = videoConfigFor(android: true);
    expect(a.hwdec, 'mediacodec,mediacodec-copy');
    expect(a.vo, isNull);
    expect(videoConfigFor(android: false).hwdec, isNull);
    expect(
      videoConfigFor(android: true, overrides: {'hwdec': 'no'}).hwdec,
      'no',
    );
  });

  test('mpv.conf : lignes valides de la liste blanche seulement', () {
    final o = parseMpvConf('''
# commentaire
hwdec=mediacodec
video-sync = audio
script=/sdcard/evil.lua
vo=gpu;rm
input-ipc-server=/tmp/x
cache-secs=
demuxer-max-bytes=50000000
''');
    expect(o, {
      'hwdec': 'mediacodec',
      'video-sync': 'audio',
      'demuxer-max-bytes': '50000000',
    });
  });

  test('mpv.conf vide ou illisible : rien', () {
    expect(parseMpvConf(''), isEmpty);
    expect(parseMpvConf('pas une ligne'), isEmpty);
  });
}
