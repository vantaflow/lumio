import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

const _hash = 'ABCDEF0123456789ABCDEF0123456789ABCDEF01';

void main() {
  test('flux direct multi-lignes : qualité, taille, seeders, langue', () {
    final s = StreamNormalizer.normalize({
      'name': 'Addon\n1080p',
      'title':
          'Sintel (2010) 1080p BluRay x265 MULTI\n👤 120 💾 1.4 GB ⚙️ Source',
      'url': 'https://cdn.example.org/v/sintel.mkv?token=abc',
      'behaviorHints': {
        'notWebReady': true,
        'proxyHeaders': {
          'request': {'Referer': 'https://ref.example.org/', 'X-A': 'b'},
        },
      },
    }, 'a1')!;
    expect(s.quality, Quality.hd1080);
    expect(s.sizeBytes, 1503238553);
    expect(s.seeders, 120);
    expect(s.language, 'multi');
    expect(s.isTorrent, isFalse);
    expect(s.notWebReady, isTrue);
    expect(s.requestHeaders['Referer'], 'https://ref.example.org/');
    expect(s.signature, 'https://cdn.example.org/v/sintel.mkv|1503238553');
  });

  test('torrent infoHash + fileIdx', () {
    final s = StreamNormalizer.normalize({
      'infoHash': _hash,
      'fileIdx': 2,
      'title': 'Big Buck Bunny 4K\n👤 15 💾 700 MB',
    }, 'a1')!;
    expect(s.isTorrent, isTrue);
    expect(s.url, isNull);
    expect(s.infoHash, _hash.toLowerCase());
    expect(s.fileIdx, 2);
    expect(s.quality, Quality.uhd2160);
    expect(s.sizeBytes, 700 * 1048576);
    expect(s.signature, '${_hash.toLowerCase()}:2');
  });

  test('url et infoHash : les deux conservés, pas torrent', () {
    final s = StreamNormalizer.normalize({
      'url': 'http://x.example.org/a.mp4',
      'infoHash': _hash,
    }, 'a1')!;
    expect(s.isTorrent, isFalse);
    expect(s.infoHash, isNotNull);
  });

  test('externalUrl, ytId, schémas refusés, infoHash invalide : null', () {
    final logs = <String>[];
    StreamItem? n(Map<String, dynamic> m) =>
        StreamNormalizer.normalize(m, 'a', onReject: logs.add);
    expect(n({'externalUrl': 'https://x.example.org/p'}), isNull);
    expect(n({'ytId': 'abc'}), isNull);
    expect(n({'url': 'ftp://x.example.org/a'}), isNull);
    expect(n({'url': 'javascript:alert(1)'}), isNull);
    expect(n({'infoHash': 'zz'}), isNull);
    expect(n({'name': 'rien'}), isNull);
    expect(logs, isNotEmpty);
    expect(logs.join(), isNot(contains('token')));
  });

  test('rejet journalisé sans fuite du jeton', () {
    final logs = <String>[];
    StreamNormalizer.normalize(
      {'url': 'ftp://h.example.org/secret-token'},
      'a',
      onReject: logs.add,
    );
    expect(logs.join(), isNot(contains('secret-token')));
  });

  test('tailles : Go, GiB, MiB, virgule', () {
    int? size(String t) => StreamNormalizer.normalize({
      'url': 'https://x.example.org/a',
      'title': t,
    }, 'a')!.sizeBytes;
    expect(size('1,5 Go'), (1.5 * 1073741824).toInt());
    expect(size('2 GiB'), 2 * 1073741824);
    expect(size('350 Mo'), 350 * 1048576);
    expect(size('1.4GB'), 1503238553);
    expect(size('sans taille'), isNull);
  });

  test('qualités et langues', () {
    StreamItem s(String t) => StreamNormalizer.normalize({
      'url': 'https://x.example.org/a',
      'name': t,
    }, 'a')!;
    expect(s('Film 720p').quality, Quality.hd720);
    expect(s('Film 480p').quality, Quality.sd);
    expect(s('Film').quality, Quality.unknown);
    expect(s('Film 1080p 2160p').quality, Quality.uhd2160);
    expect(s('Film 🇫🇷').language, 'fr');
    expect(s('Film VFF').language, 'fr');
    expect(s('Film VOSTFR').language, 'fr');
    expect(s('Film FRENCH').language, 'fr');
    expect(s('Film ENG').language, 'en');
    expect(s('Film').language, isNull);
  });

  test('seeders : « seeders: 120 »', () {
    final s = StreamNormalizer.normalize({
      'url': 'https://x.example.org/a',
      'description': 'seeders: 120',
    }, 'a')!;
    expect(s.seeders, 120);
  });
}
