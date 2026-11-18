import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/player/hls_rewriter.dart';

void main() {
  final playlist = Uri.parse('https://h/a/b.m3u8');
  Uri wrap(Uri u) => Uri.parse('http://p/x?u=${u.toString()}');

  test('segment relatif résolu puis enveloppé', () {
    final out = rewriteM3u8('#EXTM3U\n#EXTINF:4,\nseg1.ts\n', playlist, wrap);
    expect(out, contains('http://p/x?u=https://h/a/seg1.ts'));
    expect(out, isNot(contains('\nseg1.ts')));
  });

  test('segment absolu et chemin à la racine', () {
    final out = rewriteM3u8('/r/s.ts\nhttps://o/z.ts\n', playlist, wrap);
    expect(out, contains('u=https://h/r/s.ts'));
    expect(out, contains('u=https://o/z.ts'));
  });

  test('URI de clé et de map réécrites', () {
    const body =
        '#EXT-X-KEY:METHOD=AES-128,URI="key.bin",IV=0x01\n'
        '#EXT-X-MAP:URI="init.mp4",BYTERANGE="720@0"\n';
    final out = rewriteM3u8(body, playlist, wrap);
    expect(out, contains('URI="http://p/x?u=https://h/a/key.bin"'));
    expect(out, contains('URI="http://p/x?u=https://h/a/init.mp4"'));
    expect(out, contains('IV=0x01'));
    expect(out, contains('BYTERANGE="720@0"'));
  });

  test('playlists de variantes et médias alternatifs réécrits', () {
    const body =
        '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a",URI="audio/a.m3u8"\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=1000\n'
        'v/low.m3u8\n';
    final out = rewriteM3u8(body, playlist, wrap);
    expect(out, contains('u=https://h/a/audio/a.m3u8'));
    expect(out, contains('u=https://h/a/v/low.m3u8'));
  });

  test('lignes # sans URI, lignes vides et fins de ligne inchangées', () {
    const body = '#EXTM3U\r\n#EXT-X-VERSION:7\r\n\r\n#EXT-X-ENDLIST\r\n';
    expect(rewriteM3u8(body, playlist, wrap), body);
  });

  test('URI data: et clé METHOD=NONE laissées', () {
    const body =
        '#EXT-X-KEY:METHOD=NONE\n#EXT-X-KEY:METHOD=SAMPLE-AES,URI="data:text/plain;base64,AAAA"\n';
    expect(rewriteM3u8(body, playlist, wrap), body);
  });
}
