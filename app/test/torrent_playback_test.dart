import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/l10n/app_localizations.dart';
import 'package:lumio/l10n/app_localizations_en.dart';
import 'package:lumio/l10n/app_localizations_fr.dart';
import 'package:lumio/player/player_screen.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/torrent/torrent_engine.dart';
import 'package:lumio/torrent/torrent_overlay.dart';
import 'package:lumio/torrent/torrent_playback.dart';
import 'package:lumio/torrent/torrent_providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

import 'support/fake_torrent_engine.dart';
import 'support/recording_player.dart';

const _hash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

StreamItem _torrent({int? fileIdx, List<String> trackers = const []}) =>
    StreamItem(
      addonId: 'a',
      title: 'Film',
      infoHash: _hash,
      fileIdx: fileIdx,
      trackers: trackers,
    );

const _noPeers = TorrentStatus(
  peers: 0,
  seeders: 0,
  downloadRate: 0,
  uploadRate: 0,
  progress: 0,
);

const _files = [
  TorrentFile(index: 0, name: 'Extras.mkv', size: 9000, streamable: false),
  TorrentFile(index: 1, name: 'S01E01.mkv', size: 500, streamable: true),
  TorrentFile(index: 2, name: 'S01E02.mkv', size: 900, streamable: true),
  TorrentFile(index: 3, name: 'S01E03.mkv', size: 100, streamable: true),
];

/// Moteur dont les métadonnées (liste de fichiers) arrivent après N lectures.
class _SlowMetadata extends FakeTorrentEngine {
  _SlowMetadata(this.emptyReads) : super(fileList: _files);
  int emptyReads;
  @override
  Future<List<TorrentFile>> files(String id) async =>
      emptyReads-- > 0 ? const [] : super.files(id);
}

TorrentPlayback _playback(
  FakeTorrentEngine e, {
  Duration timeout = const Duration(seconds: 45),
}) => TorrentPlayback(
  engine: e,
  peerTimeout: timeout,
  pollInterval: const Duration(milliseconds: 5),
);

void main() {
  group('TorrentPlayback', () {
    test('fileIdx du flux : seul ce fichier est demandé au moteur', () async {
      final e = FakeTorrentEngine(fileList: _files);
      final url = await _playback(e).prepare(_torrent(fileIdx: 2));
      expect(e.streamedIndexes, [2]);
      expect(url.host, '127.0.0.1');
      expect(url.path, endsWith('/2'));
    });

    test('sans fileIdx : le plus grand fichier lisible', () async {
      final e = FakeTorrentEngine(fileList: _files);
      await _playback(e).prepare(_torrent());
      expect(e.streamedIndexes, [2]); // 0 est plus grand mais non lisible
    });

    test('fileIdx absent de la liste : repli sur le plus grand', () async {
      final e = FakeTorrentEngine(fileList: _files);
      await _playback(e).prepare(_torrent(fileIdx: 42));
      expect(e.streamedIndexes, [2]);
    });

    test(
      'aucun fichier lisible : NoStreamableFileException et arrêt',
      () async {
        final e = FakeTorrentEngine(
          fileList: const [
            TorrentFile(index: 0, name: 'a.nfo', size: 1, streamable: false),
          ],
        );
        await expectLater(
          _playback(e).prepare(_torrent()),
          throwsA(isA<NoStreamableFileException>()),
        );
        expect(e.stopped, hasLength(1));
        expect(e.stopDeleteData, [true]);
      },
    );

    test('magnet construit avec l\'infoHash et les trackers du flux', () async {
      final e = FakeTorrentEngine(fileList: _files);
      await _playback(
        e,
      ).prepare(_torrent(trackers: ['udp://tracker.example:1337']));
      expect(e.addedMagnets.single, startsWith('magnet:?xt=urn:btih:$_hash'));
      expect(e.addedMagnets.single, contains('tracker.example'));
    });

    test(
      'aucun pair dans le délai : NoPeersException et arrêt propre',
      () async {
        final e = FakeTorrentEngine(fileList: _files, statusValue: _noPeers);
        final sw = Stopwatch()..start();
        await expectLater(
          _playback(
            e,
            timeout: const Duration(milliseconds: 80),
          ).prepare(_torrent()),
          throwsA(isA<NoPeersException>()),
        );
        expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(80));
        expect(e.stopped, ['fake-1']);
        expect(e.stopDeleteData, [true]);
        expect(e.streamedIndexes, isEmpty);
        expect(
          AppLocalizationsFr().torrentNoPeers,
          startsWith('Aucune source disponible pour ce torrent'),
        );
      },
    );

    test('délai de 45 s (horloge factice) : pas avant, NoPeers après', () {
      fakeAsync((fa) {
        final e = FakeTorrentEngine(fileList: _files, statusValue: _noPeers);
        Object? error;
        TorrentPlayback(engine: e)
            .prepare(_torrent())
            .then<void>((_) {}, onError: (Object x) => error = x);
        fa.elapse(const Duration(seconds: 44));
        expect(error, isNull);
        expect(e.stopped, isEmpty);
        fa.elapse(const Duration(seconds: 2));
        expect(error, isA<NoPeersException>());
        expect(e.stopDeleteData, [true]);
      });
    });

    test(
      'un pair qui arrive en cours d\'attente débloque la lecture',
      () async {
        final e = FakeTorrentEngine(fileList: _files, statusValue: _noPeers);
        final f = _playback(e).prepare(_torrent());
        await Future<void>.delayed(const Duration(milliseconds: 30));
        e.emitStatus(
          'fake-1',
          const TorrentStatus(
            peers: 2,
            seeders: 1,
            downloadRate: 10,
            uploadRate: 0,
            progress: 0,
          ),
        );
        expect((await f).host, '127.0.0.1');
      },
    );

    test(
      'métadonnées tardives : la liste est relue jusqu\'à son arrivée',
      () async {
        final e = _SlowMetadata(3);
        await _playback(e).prepare(_torrent());
        expect(e.streamedIndexes, [2]);
      },
    );

    test('métadonnées jamais reçues : NoPeersException', () async {
      final e = _SlowMetadata(1 << 30);
      await expectLater(
        _playback(
          e,
          timeout: const Duration(milliseconds: 60),
        ).prepare(_torrent()),
        throwsA(isA<NoPeersException>()),
      );
      expect(e.stopDeleteData, [true]);
    });

    test(
      'release() appelle stop(deleteData: true) ; sans effet ensuite',
      () async {
        final e = FakeTorrentEngine(fileList: _files);
        final p = _playback(e);
        await p.prepare(_torrent());
        await p.release();
        await p.release();
        expect(e.stopped, ['fake-1']);
        expect(e.stopDeleteData, [true]);
      },
    );

    test('release() avant prepare ne fait rien', () async {
      final e = FakeTorrentEngine();
      await _playback(e).release();
      expect(e.stopped, isEmpty);
    });

    test('release() pendant l\'attente annule et nettoie', () async {
      final e = FakeTorrentEngine(fileList: _files, statusValue: _noPeers);
      final p = _playback(e);
      final f = p.prepare(_torrent());
      final expectation = expectLater(
        f,
        throwsA(isA<TorrentCancelledException>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await p.release();
      await expectation;
      expect(e.stopped, ['fake-1']);
    });

    test('statuts transmis pendant et après la préparation', () async {
      final e = FakeTorrentEngine(fileList: _files);
      final seen = <TorrentStatus>[];
      await _playback(e).prepare(_torrent(), onStatus: seen.add);
      final n = seen.length;
      expect(n, greaterThan(0));
      e.emitStatus(
        'fake-1',
        const TorrentStatus(
          peers: 9,
          seeders: 4,
          downloadRate: 1000000,
          uploadRate: 0,
          progress: 0.5,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(seen.length, n + 1);
      expect(seen.last.peers, 9);
    });

    test(
      'perte réseau : statut en erreur transmis, l\'attente continue',
      () async {
        final e = FakeTorrentEngine(fileList: _files, statusValue: _noPeers);
        final seen = <TorrentStatus>[];
        final f = _playback(e).prepare(_torrent(), onStatus: seen.add);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        e.emitStatus(
          'fake-1',
          const TorrentStatus(
            peers: 0,
            seeders: 0,
            downloadRate: 0,
            uploadRate: 0,
            progress: 0,
            error: 'network down',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(seen.last.error, 'network down');
        e.emitStatus(
          'fake-1',
          const TorrentStatus(
            peers: 1,
            seeders: 1,
            downloadRate: 5,
            uploadRate: 0,
            progress: 0,
          ),
        );
        expect((await f).host, '127.0.0.1'); // pas de plantage, reprise
      },
    );

    test('moteur initialisé paresseusement via ready', () async {
      final e = FakeTorrentEngine(fileList: _files);
      var calls = 0;
      final p = TorrentPlayback(engine: e, ready: () async => calls++);
      expect(calls, 0);
      await p.prepare(_torrent());
      expect(calls, 1);
    });
  });

  group('messages', () {
    test('français et anglais', () {
      expect(
        AppLocalizationsFr().torrentConnectionLost,
        'Connexion perdue, nouvelle tentative…',
      );
      expect(
        AppLocalizationsEn().torrentConnectionLost,
        'Connection lost, retrying…',
      );
    });
  });

  group('TorrentOverlay', () {
    Future<void> pumpOverlay(WidgetTester t, ValueNotifier<TorrentStatus?> n) =>
        t.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: const [LumioColors.dark]),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('fr'),
            home: Scaffold(body: TorrentOverlay(status: n)),
          ),
        );

    testWidgets('sources, débit et téléchargé suivent le statut', (t) async {
      final n = ValueNotifier<TorrentStatus?>(null);
      await pumpOverlay(t, n);
      expect(find.text('Connexion aux sources…'), findsOneWidget);
      n.value = const TorrentStatus(
        peers: 12,
        seeders: 5,
        downloadRate: 1572864,
        uploadRate: 0,
        progress: 0.42,
      );
      await t.pump();
      expect(
        find.text('12 sources · 1.5 Mo/s · 42 % téléchargé'),
        findsOneWidget,
      );
      n.value = const TorrentStatus(
        peers: 3,
        seeders: 1,
        downloadRate: 358400,
        uploadRate: 0,
        progress: 0.5,
      );
      await t.pump();
      expect(find.textContaining('350 Ko/s'), findsOneWidget);
    });

    testWidgets(
      'erreur du moteur : « Connexion perdue, nouvelle tentative… »',
      (t) async {
        final n = ValueNotifier<TorrentStatus?>(
          const TorrentStatus(
            peers: 0,
            seeders: 0,
            downloadRate: 0,
            uploadRate: 0,
            progress: 0.1,
            error: 'x',
          ),
        );
        await pumpOverlay(t, n);
        expect(
          find.text('Connexion perdue, nouvelle tentative…'),
          findsOneWidget,
        );
      },
    );
  });

  group('PlayerScreen torrent', () {
    Future<RecordingPlayerController> pumpPlayer(
      WidgetTester t,
      FakeTorrentEngine e, {
      Duration timeout = const Duration(seconds: 45),
    }) async {
      final ctl = RecordingPlayerController();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            torrentPlaybackFactoryProvider.overrideWithValue(
              () => _playback(e, timeout: timeout),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: const [LumioColors.dark]),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('fr'),
            home: PlayerScreen(
              item: _torrent(fileIdx: 2),
              controller: ctl,
              videoBuilder: (_) => const ColoredBox(color: Colors.black),
              tracksBackend: (_) => NoTracksBackend(),
            ),
          ),
        ),
      );
      for (
        var i = 0;
        i < 20 && ctl.opened.isEmpty && ctl.failures.isEmpty;
        i++
      ) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 100));
      }
      return ctl;
    }

    testWidgets('ouvre l\'URL locale du moteur par trustedLocal', (t) async {
      final e = FakeTorrentEngine(fileList: _files);
      final ctl = await pumpPlayer(t, e);
      expect(ctl.opened, hasLength(1));
      expect(ctl.opened.single.url.toString(), startsWith('http://127.0.0.1'));
      expect(ctl.opened.single.isTorrent, isFalse);
      expect(ctl.trusted.single, isTrue);
      expect(e.streamedIndexes, [2]);
      expect(find.byType(TorrentOverlay), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      // Fermeture du lecteur : arrêt et suppression des données.
      expect(e.stopped, ['fake-1']);
      expect(e.stopDeleteData, [true]);
    });

    testWidgets('aucune source : message français, aucune ouverture', (
      t,
    ) async {
      final e = FakeTorrentEngine(fileList: _files, statusValue: _noPeers);
      final ctl = await pumpPlayer(
        t,
        e,
        timeout: const Duration(milliseconds: 60),
      );
      expect(ctl.opened, isEmpty);
      expect(
        ctl.failures.single,
        'Aucune source disponible pour ce torrent. Essayez un autre flux.',
      );
      await t.pumpWidget(const SizedBox());
    });
  });
}
