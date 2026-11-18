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

  test('clé METHOD=NONE laissée', () {
    const body = '#EXT-X-KEY:METHOD=NONE\n';
    expect(rewriteM3u8(body, playlist, wrap), body);
  });

  test('I-FRAME-STREAM-INF et BYTERANGE', () {
    const body =
        '#EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=1,URI="iframe.m3u8"\n'
        '#EXT-X-BYTERANGE:720@0\n'
        'media.mp4\n';
    final out = rewriteM3u8(body, playlist, wrap);
    expect(out, contains('URI="http://p/x?u=https://h/a/iframe.m3u8"'));
    expect(out, contains('#EXT-X-BYTERANGE:720@0\n'));
    expect(out, contains('u=https://h/a/media.mp4'));
  });

  test('URI= d\'un autre attribut (XURI=) non touché', () {
    const body = '#EXT-X-FOO:XURI="a.ts",URI="b.ts"\n';
    final out = rewriteM3u8(body, playlist, wrap);
    expect(out, contains('XURI="a.ts"'));
    expect(out, contains('URI="http://p/x?u=https://h/a/b.ts"'));
  });

  test('schémas non http(s) : segments supprimés, URI= neutralisés', () {
    const body =
        '#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="file:///etc/passwd"\n'
        '#EXT-X-MAP:URI="data:text/plain;base64,AAAA"\n'
        'concat:a|b\nfile:///etc/hosts\nrtmp://x/y\nseg.ts\n';
    final seen = <Uri>[];
    final out = rewriteM3u8(body, playlist, (u) {
      seen.add(u);
      return Uri.parse('http://p/x?u=${u.toString()}');
    });
    expect(out, isNot(contains('file:')));
    expect(out, isNot(contains('concat:')));
    expect(out, isNot(contains('rtmp:')));
    expect(out, isNot(contains('data:')));
    expect(out, contains('u=blocked:'));
    expect(out, contains('u=https://h/a/seg.ts'));
    expect(seen.where((u) => u.scheme == 'blocked').length, 2);
  });
}
