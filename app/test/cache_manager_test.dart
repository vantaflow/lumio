import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/torrent/cache_manager.dart';
import 'package:lumio/torrent/libtorrent_engine.dart' show engineUploadLimit;
import 'package:lumio/torrent/torrent_engine.dart'
    show TorrentFile, TorrentSettings;
import 'package:lumio/torrent/torrent_playback.dart' show TorrentPlayback;
import 'package:lumio_core/lumio_core.dart';

import 'support/fake_torrent_engine.dart';

const _mb = 1024 * 1024;
const _gb = 1024 * _mb;

class _FakeStorage implements StorageInfo {
  _FakeStorage(this.free);
  int? free;
  final asked = <String>[];
  @override
  Future<int?> freeBytes(String path) async {
    asked.add(path);
    return free;
  }
}

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('lumio_cache_test'));
  tearDown(() => root.deleteSync(recursive: true));

  CacheManager manager({
    required _FakeStorage storage,
    bool isTv = false,
    bool clearOnExit = false,
    Duration grace = Duration.zero,
  }) => CacheManager(
    recentGrace: grace,
    storage: storage,
    savePath: () async => root.path,
    isTv: isTv,
    clearOnExit: () async => clearOnExit,
  );

  Directory torrentDir(String name, int bytes, {int ageDays = 0}) {
    final d = Directory('${root.path}/$name')..createSync();
    final f = File('${d.path}/video.mkv')
      ..writeAsBytesSync(List.filled(bytes, 1));
    f.setLastModifiedSync(DateTime.now().subtract(Duration(days: ageDays)));
    return d;
  }

  group('resolve', () {
    test(
      'TV avec 4,6 Go libres : cache de 1,38 Go, ensemencement coupé',
      () async {
        final free = (4.6 * _gb).round();
        final s = await manager(
          storage: _FakeStorage(free),
          isTv: true,
        ).resolve();
        expect(s.maxCacheBytes, free * 3 ~/ 10);
        expect(s.savePath, root.path);
        expect(s.seed, isFalse);
      },
    );

    test('espace insuffisant : exception avant tout contact moteur', () async {
      final m = manager(storage: _FakeStorage(200 * _mb), isTv: true);
      await expectLater(
        m.resolve(),
        throwsA(isA<InsufficientStorageException>()),
      );
    });

    test('le réglage utilisateur est borné à 30 % du libre', () async {
      final s = await manager(
        storage: _FakeStorage(10 * _gb),
      ).resolve(requestedCacheBytes: 5 * _gb);
      expect(s.maxCacheBytes, 3 * _gb);
    });

    test('débit montant 0 : ensemencement désactivé', () async {
      final s = await manager(storage: _FakeStorage(100 * _gb)).resolve();
      expect(s.seed, isFalse);
      expect(s.uploadLimit, 0);
    });

    test('débit montant 512 Ko/s : ensemencement avec limite', () async {
      final s = await manager(
        storage: _FakeStorage(100 * _gb),
      ).resolve(uploadKbps: 512);
      expect(s.seed, isTrue);
      expect(s.uploadLimit, 512 * 1024);
    });

    test('espace libre inconnu : valeur prudente, sans erreur', () async {
      final s = await manager(
        storage: _FakeStorage(null),
        isTv: true,
      ).resolve();
      expect(s.maxCacheBytes, greaterThanOrEqualTo(minCacheBytes));
    });

    test('supprime les plus anciens au-delà de la limite', () async {
      torrentDir('old', 2 * _mb, ageDays: 5);
      torrentDir('new', 2 * _mb, ageDays: 1);
      final m = manager(storage: _FakeStorage(100 * _gb));
      await m.enforceLimit(3 * _mb);
      expect(Directory('${root.path}/old').existsSync(), isFalse);
      expect(Directory('${root.path}/new').existsSync(), isTrue);
    });

    test('enforceLimit épargne le torrent en lecture', () async {
      torrentDir('playing', 2 * _mb, ageDays: 9);
      torrentDir('other', 2 * _mb, ageDays: 1);
      final m = manager(storage: _FakeStorage(100 * _gb));
      await m.enforceLimit(1 * _mb, playingId: 'playing');
      expect(Directory('${root.path}/playing').existsSync(), isTrue);
      expect(Directory('${root.path}/other').existsSync(), isFalse);
    });
  });

  group('nettoyage', () {
    test('cleanOnStart supprime les dossiers orphelins', () async {
      torrentDir('a', 10);
      torrentDir('b', 10);
      File('${root.path}/loose.part').writeAsBytesSync([1]);
      await manager(storage: _FakeStorage(1 * _gb)).cleanOnStart();
      expect(root.listSync(), isEmpty);
      expect(root.existsSync(), isTrue);
    });

    test('cleanOnStart tolère un dossier absent', () async {
      root.deleteSync(recursive: true);
      await manager(storage: _FakeStorage(1 * _gb)).cleanOnStart();
      root.createSync();
    });

    test('cleanOnExit vide le cache si le réglage est activé', () async {
      torrentDir('a', 10);
      await manager(
        storage: _FakeStorage(1 * _gb),
        clearOnExit: true,
      ).cleanOnExit();
      expect(root.listSync(), isEmpty);
    });

    test('cleanOnExit ne touche à rien si le réglage est coupé', () async {
      torrentDir('a', 10);
      await manager(storage: _FakeStorage(1 * _gb)).cleanOnExit();
      expect(root.listSync(), hasLength(1));
    });
  });

  group('parseDfAvailableBytes', () {
    test('lit la colonne Available de df -k', () {
      const out =
          'Filesystem 1024-blocks Used Available Capacity Mounted on\n'
          '/dev/disk3s5 971350180 400000000 500000 45% /System/Volumes/Data\n';
      expect(parseDfAvailableBytes(out), 500000 * 1024);
    });

    test('sortie inattendue : null', () {
      expect(parseDfAvailableBytes('rien'), isNull);
      expect(parseDfAvailableBytes(''), isNull);
    });
  });

  group('engineUploadLimit', () {
    test(
      'ensemencement désactivé : minimum de 1 octet/s (jamais illimité)',
      () {
        expect(engineUploadLimit(const TorrentSettings(savePath: 'x')), 1);
      },
    );

    test('ensemencement actif : la limite demandée', () {
      expect(
        engineUploadLimit(
          const TorrentSettings(savePath: 'x', seed: true, uploadLimit: 524288),
        ),
        524288,
      );
    });
  });

  group('éviction en cours de session', () {
    test(
      'anciens évincés, torrent en lecture conservé, après l\'init',
      () async {
        final m = manager(storage: _FakeStorage(100 * _gb));
        await m.resolve(
          requestedCacheBytes: 2 * _gb,
        ); // limite posée, dossier vide
        torrentDir('old1', 2 * _mb, ageDays: 9);
        torrentDir('old2', 2 * _mb, ageDays: 8);
        torrentDir('playing', 2 * _mb, ageDays: 20);
        // Limite de session abaissée par resolve : on la fixe à 3 Mo.
        await m.resolve(requestedCacheBytes: minCacheBytes);
        await m.enforceLimit(3 * _mb, playingId: 'playing');
        expect(Directory('${root.path}/old1').existsSync(), isFalse);
        expect(Directory('${root.path}/old2').existsSync(), isFalse);
        expect(Directory('${root.path}/playing').existsSync(), isTrue);
      },
    );

    test('enforce sans resolve préalable : sans effet', () async {
      torrentDir('a', 2 * _mb);
      await manager(storage: _FakeStorage(1 * _gb)).enforce(playingId: 'x');
      expect(root.listSync(), hasLength(1));
    });

    test('TorrentPlayback évince pendant la session', () async {
      final m = manager(storage: _FakeStorage(100 * _gb));
      final engine = FakeTorrentEngine(
        fileList: const [
          TorrentFile(
            index: 0,
            name: 'video.mkv',
            path: 'Movie/video.mkv',
            size: 1,
            streamable: true,
          ),
        ],
      );
      // Limite effective 300 Mo (minimum) ; les fichiers pèsent 200 Mo chacun.
      await m.resolve(requestedCacheBytes: minCacheBytes);
      torrentDir('old1', 200 * _mb, ageDays: 9);
      torrentDir('old2', 200 * _mb, ageDays: 8);
      torrentDir('Movie', 200 * _mb, ageDays: 20);
      final playback = TorrentPlayback(
        engine: engine,
        pollInterval: const Duration(milliseconds: 10),
        enforceCache: (p) => m.enforce(playingId: p),
        evictInterval: Duration.zero,
      );
      await playback.prepare(
        const StreamItem(
          addonId: 'a',
          title: 't',
          infoHash: '0123456789abcdef0123456789abcdef01234567',
        ),
      );
      expect(Directory('${root.path}/old1').existsSync(), isFalse);
      expect(Directory('${root.path}/old2').existsSync(), isFalse);
      expect(Directory('${root.path}/Movie').existsSync(), isTrue);
      await playback.release();
    });
  });

  group('entrée en lecture (chemins réalistes du moteur)', () {
    Future<void> play(CacheManager m, TorrentFile file) async {
      final playback = TorrentPlayback(
        engine: FakeTorrentEngine(fileList: [file]),
        pollInterval: const Duration(milliseconds: 10),
        enforceCache: (p) => m.enforce(playingId: p),
        evictInterval: Duration.zero,
      );
      await playback.prepare(
        const StreamItem(
          addonId: 'a',
          title: 't',
          infoHash: '0123456789abcdef0123456789abcdef01234567',
        ),
      );
      await playback.release();
    }

    test('multi-fichiers : le dossier du torrent survit', () async {
      final m = manager(storage: _FakeStorage(100 * _gb));
      await m.resolve(requestedCacheBytes: minCacheBytes);
      torrentDir('old', 200 * _mb, ageDays: 9);
      torrentDir('Folder', 200 * _mb, ageDays: 30);
      await play(
        m,
        const TorrentFile(
          index: 0,
          name: 'video.mkv',
          path: 'Folder/video.mkv',
          size: 1,
          streamable: true,
        ),
      );
      expect(Directory('${root.path}/Folder').existsSync(), isTrue);
      expect(Directory('${root.path}/old').existsSync(), isFalse);
    });

    test('fichier unique : le fichier survit', () async {
      final m = manager(storage: _FakeStorage(100 * _gb));
      await m.resolve(requestedCacheBytes: minCacheBytes);
      torrentDir('old', 200 * _mb, ageDays: 9);
      final f = File('${root.path}/video.mkv')
        ..writeAsBytesSync(List.filled(200 * _mb, 1));
      f.setLastModifiedSync(DateTime.now().subtract(const Duration(days: 30)));
      await play(
        m,
        const TorrentFile(
          index: 0,
          name: 'video.mkv',
          size: 1,
          streamable: true,
        ),
      );
      expect(f.existsSync(), isTrue);
      expect(Directory('${root.path}/old').existsSync(), isFalse);
    });

    test('entrée en lecture introuvable : aucune éviction', () async {
      final m = manager(storage: _FakeStorage(100 * _gb));
      await m.resolve(requestedCacheBytes: minCacheBytes);
      torrentDir('old1', 200 * _mb, ageDays: 9);
      torrentDir('old2', 200 * _mb, ageDays: 30);
      await play(
        m,
        const TorrentFile(
          index: 0,
          name: 'video.mkv',
          path: '',
          size: 1,
          streamable: true,
        ),
      );
      expect(Directory('${root.path}/old1').existsSync(), isTrue);
      expect(Directory('${root.path}/old2').existsSync(), isTrue);
    });

    test('entrée modifiée depuis moins de 60 s : jamais évincée', () async {
      final m = manager(
        storage: _FakeStorage(100 * _gb),
        grace: const Duration(seconds: 60),
      );
      torrentDir('active', 2 * _mb, ageDays: 0);
      torrentDir('old', 2 * _mb, ageDays: 9);
      await m.enforceLimit(1 * _mb);
      expect(Directory('${root.path}/active').existsSync(), isTrue);
      expect(Directory('${root.path}/old').existsSync(), isFalse);
    });
  });

  group('liens symboliques', () {
    test('éviction et nettoyage ne suivent pas les liens', () async {
      final outside = Directory.systemTemp.createTempSync('lumio_outside');
      addTearDown(() => outside.deleteSync(recursive: true));
      File('${outside.path}/keep.txt').writeAsStringSync('x');
      Link('${root.path}/lnk').createSync(outside.path);
      final m = manager(storage: _FakeStorage(100 * _gb), clearOnExit: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      torrentDir(
        'big',
        10,
        ageDays: -1,
      ); // plus récent que le lien : le lien passe d'abord
      await m.enforceLimit(0);
      expect(File('${outside.path}/keep.txt').existsSync(), isTrue);
      expect(Link('${root.path}/lnk').existsSync(), isFalse);
      Link('${root.path}/lnk2').createSync(outside.path);
      await m.cleanOnExit();
      expect(File('${outside.path}/keep.txt').existsSync(), isTrue);
    });
  });
}
