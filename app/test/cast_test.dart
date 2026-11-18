import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/title_settings_store.dart';
import 'package:lumio/features/cast/cast_button.dart';
import 'package:lumio/features/cast/player_cast.dart';
import 'package:lumio/l10n/app_localizations.dart';
import 'package:lumio/player/play_router.dart' show LocalFileSource;
import 'package:lumio/player/player_controller.dart';
import 'package:lumio/player/player_screen.dart';
import 'package:lumio/player/subtitle_style.dart';
import 'package:lumio/player/tracks_controller.dart';
import 'package:lumio/providers.dart';
import 'package:lumio/ui/theme.dart';
import 'package:lumio_core/lumio_core.dart';

CastDevice _dev(String name, {String usn = 'u'}) => CastDevice(
  usn: usn,
  friendlyName: name,
  location: Uri.parse('http://192.168.1.20/d.xml'),
  address: InternetAddress('192.168.1.20'),
  controlUrl: Uri.parse('http://192.168.1.20/c'),
  serviceType: 'urn:schemas-upnp-org:service:AVTransport:1',
);

Widget _app(Widget home) => MaterialApp(
  theme: ThemeData(extensions: const [LumioColors.dark]),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('fr'),
  home: home,
);

class _Session extends CastSession {
  _Session(CastDevice d, CastSource s)
    : super(device: d, renderer: _NoRenderer(), source: s, title: 't');
  final events = <String>[];
  Object? startError;
  Completer<void>? gate;
  Duration last = const Duration(seconds: 77);

  @override
  Future<void> start({Duration startAt = Duration.zero}) async {
    events.add('start:${startAt.inSeconds}');
    await gate?.future;
    if (startError != null) throw startError!;
  }

  @override
  Future<Duration> stop() async {
    events.add('stop');
    return last;
  }

  @override
  Duration get lastPosition => last;
}

class _NoRenderer implements CastRenderer {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  const src = CastHttpSource.new;
  final source = src(Uri.parse('http://127.0.0.1:9/v'));

  group('PlayerCast', () {
    late List<String> log;
    late _Session session;
    late PlayerCast cast;
    CastSource? current;
    var lost = 0;

    setUp(() {
      log = [];
      lost = 0;
      current = source;
      session = _Session(_dev('TV'), source);
      cast = PlayerCast(
        source: () => current,
        position: () => const Duration(seconds: 30),
        pauseLocal: () async => log.add('pause'),
        resumeLocal: (at) async => log.add('resume:${at.inSeconds}'),
        onLost: () => lost++,
        createSession: (d, s, t) => session,
      );
    });

    test(
      'start : lecture locale en pause, session lancée à la position',
      () async {
        expect(await cast.start(_dev('TV'), 'Film'), CastStart.started);
        expect(log, ['pause']);
        expect(session.events, ['start:30']);
        expect(cast.active, isTrue);
        expect(cast.device!.friendlyName, 'TV');
      },
    );

    test('flux non diffusable : rien n\'est mis en pause', () async {
      current = null;
      expect(await cast.start(_dev('TV'), 'Film'), CastStart.unsupported);
      expect(log, isEmpty);
      expect(cast.active, isFalse);
    });

    test('échec : session fermée et lecture locale reprise', () async {
      session.startError = StateError('x');
      expect(await cast.start(_dev('TV'), 'Film'), CastStart.failed);
      expect(session.events, ['start:30', 'stop']);
      expect(log, ['pause', 'resume:30']);
      expect(cast.active, isFalse);
    });

    test('pas de réseau commun : message dédié, lecture reprise', () async {
      session.startError = const CastNetworkException();
      expect(await cast.start(_dev('TV'), 'Film'), CastStart.noNetwork);
      expect(log, ['pause', 'resume:30']);
    });

    test(
      'dispose pendant un démarrage lent : session arrêtée, rien publié',
      () async {
        session.gate = Completer<void>();
        final f = cast.start(_dev('TV'), 'Film');
        await Future<void>.delayed(Duration.zero);
        cast.dispose();
        session.gate!.complete();
        expect(await f, CastStart.failed);
        expect(session.events, contains('stop'));
        expect(log, ['pause']); // pas de reprise locale sur un lecteur fermé
        expect(cast.active, isFalse);
      },
    );

    test('stop pendant un démarrage lent : annulé, serveur arrêté', () async {
      session.gate = Completer<void>();
      final f = cast.start(_dev('TV'), 'Film');
      await Future<void>.delayed(Duration.zero);
      await cast.stop();
      session.gate!.complete();
      expect(await f, CastStart.failed);
      expect(session.events, contains('stop'));
      expect(cast.active, isFalse);
    });

    test(
      'stop : reprise locale à la position atteinte sur l\'appareil',
      () async {
        await cast.start(_dev('TV'), 'Film');
        await cast.stop();
        expect(session.events, contains('stop'));
        expect(log.last, 'resume:77');
        expect(cast.active, isFalse);
      },
    );

    test(
      'appareil perdu : retour en local à la dernière position + message',
      () async {
        await cast.start(_dev('TV'), 'Film');
        session.onLost!(const Duration(seconds: 91));
        await Future<void>.delayed(Duration.zero);
        expect(log.last, 'resume:91');
        expect(lost, 1);
        expect(cast.active, isFalse);
      },
    );
  });

  group('sélecteur', () {
    testWidgets('liste les appareils trouvés et renvoie le choix', (t) async {
      final ctl = StreamController<CastDevice>();
      CastDevice? picked;
      await t.pumpWidget(
        _app(
          Builder(
            builder: (c) => TextButton(
              onPressed: () async =>
                  picked = await showCastPicker(c, discover: () => ctl.stream),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await t.tap(find.text('go'));
      await t.pump();
      expect(find.text('Recherche d\'appareils…'), findsOneWidget);
      ctl.add(_dev('Salon', usn: 'a'));
      ctl.add(_dev('Salon', usn: 'a')); // doublon ignoré
      ctl.add(_dev('Chambre', usn: 'b'));
      await t.pump();
      expect(find.text('Salon'), findsOneWidget);
      expect(find.text('Chambre'), findsOneWidget);
      await ctl.close();
      await t.pump();
      expect(find.text('Aucun appareil trouvé'), findsNothing);
      await t.tap(find.text('Chambre'));
      await t.pumpAndSettle();
      expect(picked?.friendlyName, 'Chambre');
    });

    testWidgets('aucun appareil : message, Réessayer relance la recherche', (
      t,
    ) async {
      var runs = 0;
      await t.pumpWidget(
        _app(
          Builder(
            builder: (c) => TextButton(
              onPressed: () => showCastPicker(
                c,
                discover: () {
                  runs++;
                  return const Stream<CastDevice>.empty();
                },
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      expect(find.text('Aucun appareil trouvé'), findsOneWidget);
      // Le focus est sur « Réessayer » (télécommande).
      final retry = find.byKey(const ValueKey('cast:retry'));
      expect(retry, findsOneWidget);
      await t.tap(retry);
      await t.pumpAndSettle();
      expect(runs, 2);
      expect(find.text('Aucun appareil trouvé'), findsOneWidget);
    });

    testWidgets('erreur de découverte : même message, pas de plantage', (
      t,
    ) async {
      await t.pumpWidget(
        _app(
          Builder(
            builder: (c) => TextButton(
              onPressed: () => showCastPicker(
                c,
                discover: () => Stream<CastDevice>.error(StateError('x')),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      expect(find.text('Aucun appareil trouvé'), findsOneWidget);
    });
  });

  testWidgets('lecteur : bouton Cast ouvre le sélecteur', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          titleSettingsStoreProvider.overrideWith(
            (ref) async => DriftTitleSettingsStore(db),
          ),
          subtitleStyleStoreProvider.overrideWithValue(SubtitleStyleStore(db)),
        ],
        child: _app(
          PlayerScreen(
            item: StreamItem(
              addonId: 'ad',
              title: 'Film',
              url: Uri.parse('https://x.test/v.mp4'),
            ),
            controller: _Ctl(source),
            videoBuilder: (_) => const ColoredBox(color: Colors.black),
            tracksBackend: (_) => _Backend(),
            castEnabled: true,
            castDiscover: () => const Stream<CastDevice>.empty(),
          ),
        ),
      ),
    );
    await t.pump();
    final button = find.bySemanticsLabel('Diffuser sur un appareil');
    expect(button, findsOneWidget);
    await t.tap(button);
    await t.pumpAndSettle();
    expect(find.text('Aucun appareil trouvé'), findsOneWidget);
  });
}

class _Ctl extends Fake implements PlayerController {
  _Ctl(this._src);
  final CastSource _src;
  final _state = ValueNotifier<PlayerState>(
    const PlayerState(phase: PlayerPhase.paused),
  );
  @override
  CastSource? get castSource => _src;
  @override
  ValueListenable<PlayerState> get stateListenable => _state;
  @override
  PlayerState get state => _state.value;
  @override
  Future<void> open(
    StreamItem s, {
    bool allowPrivate = false,
    bool trustedLocal = false,
    LocalFileSource? local,
    Duration start = Duration.zero,
  }) async {}
}

class _Backend implements TracksBackend {
  @override
  final audioTracks = const <TrackOption>[];
  @override
  final subtitleTracks = const <TrackOption>[];
  @override
  String? get selectedAudioId => null;
  @override
  String? get selectedSubtitleId => null;
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  Future<void> selectAudio(String id) async {}
  @override
  Future<void> selectSubtitle(String? id) async {}
  @override
  Future<void> loadExternalSubtitle(
    String path, {
    String? title,
    String? lang,
  }) async {}
  @override
  Future<void> setSubtitleDelay(int ms) async {}
  @override
  Future<void> applySubtitleStyle(SubtitleStyle style) async {}
}
