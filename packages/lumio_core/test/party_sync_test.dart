import 'dart:convert';

import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

Duration s(num v) => Duration(milliseconds: (v * 1000).round());

void main() {
  const sync = PartySync();
  const rtt = Duration.zero;

  group('reconcile', () {
    test('écart de 3 s : seek vers la position distante', () {
      final c = sync.reconcile(
        PartyState(position: s(100), playing: true),
        LocalState(position: s(97), playing: true),
        rtt,
      );
      expect(c!.seekTo, s(100));
      expect(c.play, isNull);
    });

    test('écart de 0,5 s : rien', () {
      expect(
        sync.reconcile(
          PartyState(position: s(100), playing: true),
          LocalState(position: s(99.5), playing: true),
          rtt,
        ),
        isNull,
      );
    });

    test('seuil : 1,5 s exactement ne déclenche pas, 1,6 s oui', () {
      PlaybackCommand? at(num local) => sync.reconcile(
        PartyState(position: s(100), playing: true),
        LocalState(position: s(local), playing: true),
        rtt,
      );
      expect(at(98.5), isNull);
      expect(at(101.5), isNull);
      expect(at(98.4)!.seekTo, s(100));
      expect(at(101.6)!.seekTo, s(100));
    });

    test('état aligné : pause distante -> pause locale, sans seek', () {
      final c = sync.reconcile(
        PartyState(position: s(50), playing: false),
        LocalState(position: s(50.2), playing: true),
        rtt,
      );
      expect(c!.play, isFalse);
      expect(c.seekTo, isNull);
    });

    test('lecture distante alors que local en pause -> play', () {
      final c = sync.reconcile(
        PartyState(position: s(50), playing: true),
        LocalState(position: s(50), playing: false),
        rtt,
      );
      expect(c!.play, isTrue);
    });

    test('RTT : la position attendue avance de rtt/2 si l\'autre lit', () {
      // Distant 100 s en lecture, RTT 4 s : attendu 102 s ; local à 102 -> rien.
      expect(
        sync.reconcile(
          PartyState(position: s(100), playing: true),
          LocalState(position: s(102), playing: true),
          s(4),
        ),
        isNull,
      );
      // Local à 105 : écart 3 s vs 102 -> seek à 102 (et non 100).
      expect(
        sync
            .reconcile(
              PartyState(position: s(100), playing: true),
              LocalState(position: s(105), playing: true),
              s(4),
            )!
            .seekTo,
        s(102),
      );
    });

    test('RTT sans effet si l\'autre est en pause', () {
      final c = sync.reconcile(
        PartyState(position: s(100), playing: false),
        LocalState(position: s(103), playing: false),
        s(4),
      );
      expect(c!.seekTo, s(100));
    });

    test('seek et état ensemble ; RTT négatif ignoré', () {
      final c = sync.reconcile(
        PartyState(position: s(10), playing: true),
        LocalState(position: s(60), playing: false),
        const Duration(seconds: -2),
      );
      expect(c!.seekTo, s(10));
      expect(c.play, isTrue);
    });
  });

  group('protocole', () {
    test('les messages envoyés ne contiennent que les champs prévus', () {
      final m =
          jsonDecode(PartyWire.state(s(12.5), playing: true, sentAt: 7))
              as Map<String, dynamic>;
      expect(m.keys.toSet(), {'type', 'positionMs', 'playing', 'sentAt'});
      expect(m['positionMs'], 12500);
      expect(jsonDecode(PartyWire.ping(3)), {'type': 'ping', 'sentAt': 3});
    });

    test('décode hello, state, join/leave, control, pong', () {
      final hello =
          decodePartyEvent(
                '{"type":"hello","participants":2,"host":false,"allControl":true,'
                '"metaId":"tt1","expiresAt":1800000000000,'
                '"state":{"positionMs":5000,"playing":true,"sentAt":1}}',
              )
              as PartyHello;
      expect(hello.participants, 2);
      expect(hello.allControl, isTrue);
      expect(hello.metaId, 'tt1');
      expect(hello.state!.position, s(5));
      final st =
          decodePartyEvent(
                '{"type":"state","positionMs":9000,"playing":false,"sentAt":1}',
              )
              as PartyRemoteState;
      expect(st.state.playing, isFalse);
      final leave =
          decodePartyEvent('{"type":"leave","participants":1}') as PartyCount;
      expect(leave.joined, isFalse);
      expect(
        (decodePartyEvent('{"type":"control","allControl":true}')
                as PartyControl)
            .allControl,
        isTrue,
      );
      expect(
        (decodePartyEvent('{"type":"pong","sentAt":42}') as PartyPong).sentAt,
        42,
      );
    });

    test('messages inconnus ou mal formés : null', () {
      expect(decodePartyEvent('nope'), isNull);
      expect(decodePartyEvent('[]'), isNull);
      expect(decodePartyEvent('{"type":"x"}'), isNull);
      expect(decodePartyEvent('{"type":"state","positionMs":"a"}'), isNull);
      expect(decodePartyEvent('{"type":"join"}'), isNull);
    });
  });
}
