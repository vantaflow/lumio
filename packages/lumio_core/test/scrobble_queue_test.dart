import 'dart:async';

import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

void main() {
  var now = DateTime.utc(2026, 1, 1, 12);
  late MemoryScrobbleStore store;
  late List<ScrobbleEvent> sent;
  late Object? failure;

  ScrobbleEvent ev(
    ScrobbleAction a, {
    double p = 10,
    String id = 'tt1',
    DateTime? at,
  }) => ScrobbleEvent(action: a, imdbId: id, progress: p, at: at ?? now);

  ScrobbleQueue queue({int max = 200}) => ScrobbleQueue(
    store,
    (profile, tracker, e) async {
      if (failure != null) throw failure!;
      sent.add(e);
    },
    now: () => now,
    maxEntries: max,
  );

  setUp(() {
    now = DateTime.utc(2026, 1, 1, 12);
    store = MemoryScrobbleStore();
    sent = [];
    failure = null;
  });

  test('envoi direct : file vide', () async {
    final q = queue();
    final r = await q.submit('p', 'trakt', ev(ScrobbleAction.start));
    expect(r.sent, 1);
    expect(await q.pending(), 0);
  });

  test('503 : mis en file puis rejoué après 1 min', () async {
    final q = queue();
    failure = const TrackerUnavailable(503);
    final r = await q.submit('p', 'trakt', ev(ScrobbleAction.stop, p: 95));
    expect(r.sent, 0);
    expect(r.remaining, 1);
    // Trop tôt : pas de nouvel essai.
    failure = null;
    now = now.add(const Duration(seconds: 59));
    expect((await q.flush()).sent, 0);
    now = now.add(const Duration(seconds: 2));
    final r2 = await q.flush();
    expect(r2.sent, 1);
    expect(r2.remaining, 0);
    expect(sent.single.progress, 95);
  });

  test('délais 1, 5 puis 30 min', () async {
    final q = queue();
    failure = const TrackerUnavailable();
    await q.submit('p', 'trakt', ev(ScrobbleAction.stop));
    final waits = <Duration>[];
    for (var i = 0; i < 4; i++) {
      final row = (await store.all()).single;
      waits.add(row.nextAttemptAt.difference(now));
      now = row.nextAttemptAt;
      await q.flush();
    }
    expect(waits, [
      const Duration(minutes: 1),
      const Duration(minutes: 5),
      const Duration(minutes: 30),
      const Duration(minutes: 30), // plafonné
    ]);
    expect((await store.all()).single.attempts, 5);
  });

  test('ordre conservé : une entrée en attente bloque les suivantes', () async {
    final q = queue();
    failure = const TrackerUnavailable();
    await q.submit('p', 'trakt', ev(ScrobbleAction.stop, id: 'tt1'));
    failure = null;
    // Le suivant est en file (la première attend son délai).
    final r = await q.submit('p', 'trakt', ev(ScrobbleAction.stop, id: 'tt2'));
    expect(r.sent, 0);
    expect(r.remaining, 2);
    now = now.add(const Duration(minutes: 2));
    await q.flush();
    expect(sent.map((e) => e.imdbId), ['tt1', 'tt2']);
  });

  test('doublon consécutif ignoré', () async {
    final q = queue();
    failure = const TrackerUnavailable();
    await q.submit('p', 'trakt', ev(ScrobbleAction.pause, p: 40));
    await q.submit('p', 'trakt', ev(ScrobbleAction.pause, p: 40.02));
    expect(await q.pending(), 1);
    await q.submit('p', 'trakt', ev(ScrobbleAction.pause, p: 41));
    expect(await q.pending(), 2);
  });

  test('plafond de 200 : les plus anciennes sont abandonnées', () async {
    final q = queue();
    failure = const TrackerUnavailable();
    for (var i = 0; i < 205; i++) {
      await q.submit('p', 'trakt', ev(ScrobbleAction.stop, id: 'tt$i'));
    }
    final rows = await store.all();
    expect(rows, hasLength(200));
    expect(rows.first.event.imdbId, 'tt5');
    expect(rows.last.event.imdbId, 'tt204');
  });

  test('refus définitif (404) : abandonné', () async {
    final q = queue();
    failure = const TrackerRejected(404);
    final r = await q.submit('p', 'trakt', ev(ScrobbleAction.stop));
    expect(r.dropped, 1);
    expect(await q.pending(), 0);
  });

  test('reconnexion nécessaire : entrées gardées, drapeau levé', () async {
    final q = queue();
    failure = const TrackerReauthRequired();
    final r = await q.submit('p', 'trakt', ev(ScrobbleAction.stop));
    expect(r.reauthRequired, isTrue);
    expect(r.remaining, 1);
    failure = null;
    expect((await q.flush()).sent, 1);
  });

  test('non configuré : rien n\'est perdu', () async {
    final q = queue();
    failure = const TrackerNotConfigured();
    final r = await q.submit('p', 'trakt', ev(ScrobbleAction.stop));
    expect(r.notConfigured, isTrue);
    expect(r.remaining, 1);
  });

  test('start périmé abandonné au rejeu, stop gardé', () async {
    final q = queue();
    failure = const TrackerUnavailable();
    await q.submit('p', 'trakt', ev(ScrobbleAction.start, id: 'tt1'));
    await q.submit('p', 'trakt', ev(ScrobbleAction.stop, id: 'tt2'));
    failure = null;
    now = now.add(const Duration(minutes: 30));
    final r = await q.flush();
    expect(r.dropped, 1);
    expect(sent.map((e) => e.imdbId), ['tt2']);
  });

  test('services et profils indépendants', () async {
    final q = queue();
    failure = const TrackerUnavailable();
    await q.submit('p1', 'trakt', ev(ScrobbleAction.stop, id: 'tt1'));
    failure = null;
    final r = await q.submit('p2', 'trakt', ev(ScrobbleAction.stop, id: 'tt2'));
    expect(r.sent, 1);
    expect(r.remaining, 1);
  });

  test(
    'déconnexion : entrées du profil abandonnées, les autres gardées',
    () async {
      final q = queue();
      failure = const TrackerUnavailable();
      await q.submit('p1', 'trakt', ev(ScrobbleAction.stop, id: 'tt1'));
      await q.submit('p2', 'trakt', ev(ScrobbleAction.stop, id: 'tt2'));
      await q.discard('p1', 'trakt');
      expect((await store.all()).map((r) => r.profileId), ['p2']);
    },
  );

  test('ajout pendant un passage : traité avant la fin', () async {
    final gate = Completer<void>();
    final q = ScrobbleQueue(store, (p, t, e) async {
      if (sent.isEmpty) await gate.future;
      sent.add(e);
    }, now: () => now);
    final first = q.submit('p', 'trakt', ev(ScrobbleAction.stop, id: 'tt1'));
    await Future<void>.delayed(Duration.zero);
    final second = q.submit('p', 'trakt', ev(ScrobbleAction.stop, id: 'tt2'));
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    await Future.wait([first, second]);
    expect(sent.map((e) => e.imdbId), ['tt1', 'tt2']);
    expect(await q.pending(), 0);
  });
}
