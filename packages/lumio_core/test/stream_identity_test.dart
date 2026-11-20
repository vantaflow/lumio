import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

void main() {
  group('StreamItem.identityKey', () {
    test('torrent : infoHash et fichier, sans URL', () {
      final s = StreamItem(
        addonId: 'a',
        title: 't',
        infoHash: 'ab' * 20,
        fileIdx: 3,
      );
      expect(s.identityKey, 't:${'ab' * 20}:3');
    });

    test('torrent sans fileIdx : fichier vide', () {
      final s = StreamItem(addonId: 'a', title: 't', infoHash: 'cd' * 20);
      expect(s.identityKey, 't:${'cd' * 20}:');
    });

    test('lien direct : empreinte, jamais l\'URL ni la clé', () {
      final s = StreamItem(
        addonId: 'a',
        title: 't',
        url: Uri.parse('https://cdn.example.com/x/SECRETKEY/v.mp4?k=1'),
      );
      expect(s.identityKey, startsWith('u:'));
      expect(s.identityKey.length, 2 + 64);
      expect(s.identityKey, isNot(contains('SECRETKEY')));
      expect(s.identityKey, isNot(contains('cdn.example.com')));
    });

    test('lien direct : stable malgré jeton et expiration', () {
      StreamItem at(String q) => StreamItem(
        addonId: 'a',
        title: 't',
        url: Uri.parse('https://cdn.example.com/v.mp4?$q'),
      );
      expect(at('token=1&exp=5').identityKey, at('token=2&exp=9').identityKey);
      expect(
        at('token=1').identityKey,
        isNot(
          StreamItem(
            addonId: 'a',
            title: 't',
            url: Uri.parse('https://cdn.example.com/autre.mp4?token=1'),
          ).identityKey,
        ),
      );
    });
  });
}
