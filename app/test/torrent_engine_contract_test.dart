import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/torrent/torrent_engine.dart';

import 'support/fake_torrent_engine.dart';

void main() {
  group('magnetFromInfoHash', () {
    test('met le hash en minuscules', () {
      final m = magnetFromInfoHash('A' * 40);
      expect(m, startsWith('magnet:?xt=urn:btih:${'a' * 40}'));
    });

    test('refuse un hash de 39 caractères', () {
      expect(() => magnetFromInfoHash('a' * 39), throwsArgumentError);
    });

    test('refuse un hash non hexadécimal', () {
      expect(() => magnetFromInfoHash('z' * 40), throwsArgumentError);
    });

    test('ajoute les trackers encodés', () {
      final m = magnetFromInfoHash(
        'a' * 40,
        trackers: ['udp://tracker.example:80/announce'],
      );
      expect(m, contains('&tr=udp%3A%2F%2Ftracker.example%3A80%2Fannounce'));
    });
  });

  group('FakeTorrentEngine respecte le contrat', () {
    test('add -> files -> stream -> status -> stop', () async {
      final e = FakeTorrentEngine();
      await e.init(const TorrentSettings(savePath: '/tmp/x'));
      final id = await e.add('b' * 40);
      expect(e.addedMagnets.single, startsWith('magnet:?xt=urn:btih:'));
      final files = await e.files(id);
      expect(files, isNotEmpty);
      final url = await e.stream(id);
      expect(url.toString(), startsWith('http://127.0.0.1'));
      final st = await e.status(id).first;
      expect(st.error, isNull);
      await e.stop(id);
      expect(e.stopped, [id]);
      await e.dispose();
    });

    test('stream avant add lève une erreur', () async {
      final e = FakeTorrentEngine();
      expect(() => e.stream('inconnu'), throwsStateError);
    });
  });
}
