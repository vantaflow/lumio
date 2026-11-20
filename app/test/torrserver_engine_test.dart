import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/torrent/torrent_engine.dart';
import 'package:lumio/torrent/torrserver_engine.dart';

import 'support/fake_torrserver.dart';

const _hash = '08ada5a7a6183aae1e09d831df6748d566095a10';
const _mib = 1024 * 1024;

void main() {
  group('torrServerSettings', () {
    test('cache disque borné, sans ensemencement', () {
      final m = torrServerSettings(
        const TorrentSettings(savePath: '/data/c', maxCacheBytes: 512 * _mib),
      );
      expect(m['UseDisk'], isTrue);
      expect(m['TorrentsSavePath'], '/data/c');
      expect(m['CacheSize'], 512 * _mib);
      expect(m['RemoveCacheOnDrop'], isTrue);
      expect(m['DisableUpload'], isTrue);
      expect(m['UploadRateLimit'], 0);
      expect(m['ReaderReadAHead'], 18); // ~96 Mo sur 512 Mo
      expect(m['PreloadCache'], 3); // ~16 Mo sur 512 Mo
    });

    test('ensemencement actif : limites converties en Kio/s', () {
      final m = torrServerSettings(
        const TorrentSettings(
          savePath: 'x',
          seed: true,
          uploadLimit: 200 * 1024,
          downloadLimit: 4 * _mib,
        ),
      );
      expect(m['DisableUpload'], isFalse);
      expect(m['UploadRateLimit'], 200);
      expect(m['DownloadRateLimit'], 4096);
    });

    test('rien n\'est annoncé ni demandé à un tiers', () {
      final m = torrServerSettings(const TorrentSettings(savePath: 'x'));
      expect(m['DisableDHT'], isFalse);
      expect(m['DisableUPNP'], isTrue);
      expect(m['EnableLPD'], isFalse);
      expect(m['EnableBonjour'], isFalse);
      expect(m['EnableDLNA'], isFalse);
      expect(m['TrackersListURL'], '');
      expect(m['RetrackersMode'], 1);
      expect(m['DefaultTrackers'], publicTrackers.join('\n'));
      expect(publicTrackers.every((t) => t.startsWith('udp://')), isTrue);
    });

    test('cache minimal 64 Mo, pourcentages dans [1, 95]', () {
      final m = torrServerSettings(
        const TorrentSettings(savePath: 'x', maxCacheBytes: 1),
      );
      expect(m['CacheSize'], 64 * _mib);
      expect(m['ReaderReadAHead'], 95);
      expect(m['PreloadCache'], 25);
    });
  });

  test('isStreamableName : vidéos oui, sous-titres et images non', () {
    expect(isStreamableName('a.MKV'), isTrue);
    expect(isStreamableName('a.mp4'), isTrue);
    expect(isStreamableName('a.srt'), isFalse);
    expect(isStreamableName('poster.jpg'), isFalse);
    expect(isStreamableName('sans-extension'), isFalse);
  });

  group('TorrServerEngine', () {
    late FakeTorrServer server;
    late FakeTorrServerProcess process;
    late TorrServerEngine engine;
    const settings = TorrentSettings(savePath: '/c');

    setUp(() async {
      server = FakeTorrServer();
      await server.start();
      process = FakeTorrServerProcess(server);
      engine = TorrServerEngine(
        process: process,
        statusInterval: const Duration(milliseconds: 30),
        startTimeout: const Duration(seconds: 1),
      );
    });

    tearDown(() async {
      await engine.dispose();
      await server.close();
    });

    test('init démarre le processus et fusionne les réglages', () async {
      await engine.init(settings);
      expect(process.starts, 1);
      expect(server.settingsSets, 1);
      expect(server.settings['SomeOtherKey'], 'kept');
      expect(server.settings['UseDisk'], isTrue);
      expect(server.settings['TorrentsSavePath'], '/c');
    });

    test(
      'réglages déjà en place : aucun set (relance du client évitée)',
      () async {
        server.settings = {...server.settings, ...torrServerSettings(settings)};
        await engine.init(settings);
        expect(server.settingsSets, 0);
      },
    );

    test('init échoue proprement si le moteur ne répond pas', () async {
      await server.close();
      await expectLater(
        engine.init(settings),
        throwsA(isA<TorrServerStartException>()),
      );
      expect(process.stops, 1);
      server = FakeTorrServer();
      await server.start();
      process.server = server;
      await engine.init(settings); // réessayable
    });

    test('appels avant init et second init refusés', () async {
      expect(() => engine.add(_hash), throwsStateError);
      await engine.init(settings);
      expect(() => engine.init(settings), throwsStateError);
    });

    test('add accepte un infoHash nu et un magnet', () async {
      await engine.init(settings);
      expect(await engine.add(_hash.toUpperCase()), _hash);
      expect(
        await engine.add('magnet:?xt=urn:btih:${'b' * 40}&tr=udp%3A%2F%2Fx'),
        'b' * 40,
      );
      expect(server.torrents.keys, containsAll([_hash, 'b' * 40]));
    });

    test('files : index 0-based, chemin complet, fichiers lisibles', () async {
      await engine.init(settings);
      final files = await engine.files(await engine.add(_hash));
      expect(files.map((f) => f.index), [0, 1, 2]);
      expect(files[1].name, 'film.mkv');
      expect(files[1].path, 'Film/film.mkv');
      expect(files.map((f) => f.streamable), [false, true, true]);
    });

    test('files vide tant que les métadonnées manquent', () async {
      server.metadataReady = false;
      await engine.init(settings);
      expect(await engine.files(await engine.add(_hash)), isEmpty);
    });

    test('stream : URL locale authentifiée, index en 1-based', () async {
      await engine.init(settings);
      final id = await engine.add(_hash);
      final url = await engine.stream(id, fileIndex: 1);
      expect(url.host, '127.0.0.1');
      expect(url.port, server.port);
      expect(url.path, '/stream');
      expect(url.queryParameters['link'], _hash);
      expect(url.queryParameters['index'], '2');
      expect(url.userInfo, 'lumio:pw');
      final c = HttpClient();
      final req = await c.getUrl(url);
      req.headers.set(
        HttpHeaders.authorizationHeader,
        'Basic ${base64.encode(utf8.encode(url.userInfo))}',
      );
      final res = await req.close();
      expect(res.statusCode, 206);
      await res.drain<void>();
      c.close(force: true);
      expect(server.unauthorized, 0);
    });

    test('stream sans index : plus gros fichier lisible', () async {
      await engine.init(settings);
      final url = await engine.stream(await engine.add(_hash));
      expect(url.queryParameters['index'], '2');
    });

    test('status : pairs, graines, débits et tampon', () async {
      await engine.init(settings);
      final st = await engine.status(await engine.add(_hash)).first;
      expect(st.peers, 7);
      expect(st.seeders, 4);
      expect(st.downloadRate, 1500000);
      expect(st.uploadRate, 0);
      expect(st.progress, closeTo(600000 / 1001500, 1e-9));
      expect(st.error, isNull);
    });

    test('status : tampon plein plafonné à 1', () async {
      server.stats = {
        ...server.stats,
        'loaded_size': 900000000,
        'torrent_size': 2000000000,
      };
      await engine.init(settings);
      expect((await engine.status(await engine.add(_hash)).first).progress, 1);
    });

    test('status : interrogation périodique, arrêt à l\'annulation', () async {
      await engine.init(settings);
      final id = await engine.add(_hash);
      var n = 0;
      final sub = engine.status(id).listen((_) => n++);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await sub.cancel();
      expect(n, greaterThan(2));
      final seen = server.requests.length;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(server.requests.length, seen);
    });

    test('stop supprime le torrent (rem) ou le déconnecte (drop)', () async {
      await engine.init(settings);
      await engine.stop(await engine.add(_hash));
      expect(server.torrents, isEmpty);
      await engine.stop(await engine.add(_hash), deleteData: false);
      expect(server.torrents, isEmpty);
    });

    test('clearCache retire tous les torrents', () async {
      await engine.init(settings);
      await engine.add(_hash);
      await engine.add('c' * 40);
      await engine.clearCache();
      expect(server.torrents, isEmpty);
    });

    test('moteur mort : relance, torrents rajoutés, appel rejoué', () async {
      await engine.init(settings);
      final id = await engine.add(_hash);
      await server.close();
      final fresh = FakeTorrServer();
      await fresh.start();
      process.server = fresh;
      final files = await engine.files(id);
      expect(process.starts, 2);
      expect(fresh.torrents.keys, [_hash]);
      expect(fresh.settingsSets, 1);
      expect(files, isNotEmpty);
      await fresh.close();
    });

    test('identifiants refusés : erreur HTTP, pas de boucle', () async {
      final bad = FakeTorrServer(password: 'autre');
      await bad.start();
      final wrong = FakeTorrServerProcess(bad);
      final e2 = TorrServerEngine(process: wrong);
      // Le processus annonce un mauvais mot de passe.
      wrong.server = _Liar(bad);
      await expectLater(e2.init(settings), throwsA(isA<HttpException>()));
      await bad.close();
    });

    test('dispose arrête le processus ; init possible ensuite', () async {
      await engine.init(settings);
      await engine.dispose();
      expect(process.stops, 1);
      await engine.dispose();
      expect(process.stops, 1);
      await engine.init(settings);
      expect(process.starts, 2);
    });
  });
}

/// Serveur dont l'adresse annoncée porte un mauvais mot de passe.
class _Liar extends FakeTorrServer {
  _Liar(this.real) : super(password: 'x');
  final FakeTorrServer real;
  @override
  TorrServerEndpoint get endpoint =>
      TorrServerEndpoint(port: real.port, user: 'lumio', password: 'faux');
}
