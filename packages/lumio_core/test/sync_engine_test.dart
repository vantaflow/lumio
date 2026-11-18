import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

/// Serveur en mémoire : mêmes règles que le Worker (version = max + 1 par
/// envoi, dernier écrivain gagnant sauf progression : `updatedAt` le plus
/// récent).
class FakeServer implements SyncTransport {
  int version = 0;
  final Map<String, SyncItem> items = {};
  int pushes = 0;
  int pulls = 0;
  int pageSize = 500;
  Object? failNext;

  @override
  Future<int> push(List<SyncItem> sent) async {
    pushes++;
    if (failNext != null) {
      final e = failNext!;
      failNext = null;
      throw e;
    }
    if (sent.isEmpty) return version;
    version++;
    for (final i in sent) {
      final k = '${i.kind}/${i.key}';
      final old = items[k];
      if (i.kind == SyncKind.progress && old != null && !i.deleted) {
        final a = (i.payload!['updatedAt'] as num).toInt();
        final b = ((old.payload?['updatedAt']) as num?)?.toInt() ?? 0;
        if (a < b) continue;
      }
      items[k] = SyncItem(
        kind: i.kind,
        key: i.key,
        payload: i.deleted ? null : i.payload,
        version: version,
        deleted: i.deleted,
      );
    }
    return version;
  }

  @override
  Future<SyncPage> pull(int since) async {
    pulls++;
    final all = items.values.where((i) => i.version > since).toList()
      ..sort((a, b) => a.version.compareTo(b.version));
    final page = all.take(pageSize).toList();
    final more = all.length > page.length;
    return SyncPage(
      items: page,
      version: more ? page.last.version : version,
      more: more,
    );
  }
}

/// Appareil : contenu local + file d'envoi, avec une horloge propre.
class FakeDevice implements LocalSyncStore {
  FakeDevice(this.name, {this.clockOffsetMs = 0});

  final String name;
  final int clockOffsetMs;
  int last = 0;
  int _seq = 0;
  final Map<String, Map<String, dynamic>> data = {};
  final Map<String, ({int seq, bool deleted})> outbox = {};

  int get now => 1_800_000_000_000 + clockOffsetMs;

  void put(String kind, String key, Map<String, dynamic> payload) {
    data['$kind/$key'] = payload;
    outbox['$kind/$key'] = (seq: ++_seq, deleted: false);
  }

  void remove(String kind, String key) {
    data.remove('$kind/$key');
    outbox['$kind/$key'] = (seq: ++_seq, deleted: true);
  }

  @override
  Future<int> lastVersion() async => last;

  @override
  Future<void> setLastVersion(int v) async => last = v;

  @override
  Future<List<PendingChange>> pending(int limit) async => [
    for (final e in outbox.entries.take(limit))
      PendingChange(
        SyncItem(
          kind: e.key.split('/').first,
          key: e.key.substring(e.key.indexOf('/') + 1),
          payload: e.value.deleted ? null : data[e.key],
          deleted: e.value.deleted,
        ),
        e.value.seq,
      ),
  ];

  @override
  Future<void> acknowledge(List<PendingChange> sent) async {
    for (final c in sent) {
      final k = '${c.item.kind}/${c.item.key}';
      if (outbox[k]?.seq == c.seq) outbox.remove(k);
    }
  }

  @override
  Future<void> apply(List<SyncItem> remote) async {
    for (final r in remote) {
      final k = '${r.kind}/${r.key}';
      if (outbox.containsKey(k)) continue;
      if (r.deleted) {
        data.remove(k);
      } else {
        data[k] = r.payload!;
      }
    }
  }
}

void main() {
  late FakeServer server;
  late FakeDevice a;
  late FakeDevice b;
  late SyncEngine ea;
  late SyncEngine eb;

  setUp(() {
    server = FakeServer();
    a = FakeDevice('A');
    b = FakeDevice('B');
    ea = SyncEngine(server, a);
    eb = SyncEngine(server, b);
  });

  test('un changement local atteint l\'autre appareil', () async {
    a.put('library', 'p|tt1', {'name': 'Sintel'});
    await ea.syncOnce();
    await eb.syncOnce();
    expect(b.data['library/p|tt1'], {'name': 'Sintel'});
    expect(a.outbox, isEmpty);
    expect(b.last, server.version);
  });

  test(
    'A supprime, B a l\'élément : supprimé chez B et ne revient pas',
    () async {
      a.put('library', 'p|tt1', {'name': 'Sintel'});
      await ea.syncOnce();
      await eb.syncOnce();
      expect(b.data, contains('library/p|tt1'));

      a.remove('library', 'p|tt1');
      await ea.syncOnce();
      await eb.syncOnce();
      expect(b.data, isNot(contains('library/p|tt1')));
      expect(
        b.outbox,
        isEmpty,
        reason: 'la suppression reçue n\'est pas renvoyée',
      );

      // Plusieurs cycles : l'élément ne ressuscite pas.
      await eb.syncOnce();
      await ea.syncOnce();
      await eb.syncOnce();
      expect(a.data, isNot(contains('library/p|tt1')));
      expect(b.data, isNot(contains('library/p|tt1')));
      expect(server.items['library/p|tt1']!.deleted, isTrue);
    },
  );

  test(
    'horloge de B fausse de +2 ans : l\'ordre suit les versions serveur',
    () async {
      final b2 = FakeDevice('B', clockOffsetMs: 2 * 365 * 24 * 3600 * 1000);
      final eb2 = SyncEngine(server, b2);
      // B (horloge en avance) écrit d'abord, A écrit ensuite : A est le plus
      // récent pour le serveur, donc A gagne malgré l'horloge de B.
      b2.put('settings', 'ui_locale', {'value': 'en', 'at': b2.now});
      await eb2.syncOnce();
      a.put('settings', 'ui_locale', {'value': 'fr', 'at': a.now});
      await ea.syncOnce();
      await eb2.syncOnce();
      expect(b2.data['settings/ui_locale']!['value'], 'fr');
      expect(a.data['settings/ui_locale']!['value'], 'fr');
      expect(server.items['settings/ui_locale']!.version, 2);
      // Et l'inverse : la dernière écriture reçue par le serveur gagne.
      b2.put('settings', 'ui_locale', {'value': 'en', 'at': b2.now});
      await eb2.syncOnce();
      await ea.syncOnce();
      expect(a.data['settings/ui_locale']!['value'], 'en');
    },
  );

  test(
    'progression : la plus récente (updatedAt) l\'emporte, pas l\'ordre d\'envoi',
    () async {
      a.put('progress', 'p|tt1', {'positionMs': 900, 'updatedAt': 2000});
      b.put('progress', 'p|tt1', {'positionMs': 100, 'updatedAt': 1000});
      await ea.syncOnce();
      await eb.syncOnce(); // envoi plus ancien : refusé par le serveur
      await ea.syncOnce();
      expect(b.data['progress/p|tt1']!['positionMs'], 900);
      expect(a.data['progress/p|tt1']!['positionMs'], 900);
    },
  );

  test(
    'un changement local en attente n\'est pas écrasé par la réception',
    () async {
      a.put('library', 'p|x', {'name': 'v1'});
      await ea.syncOnce();
      await eb.syncOnce();
      a.put('library', 'p|x', {'name': 'v-a'});
      await ea.syncOnce();
      // B modifie localement pendant son tirage : la version reçue ne l'écrase
      // pas ; elle est envoyée au cycle suivant et devient la plus récente.
      final racing = _Hook(
        server,
        onPull: () => b.put('library', 'p|x', {'name': 'v-b'}),
      );
      await SyncEngine(racing, b).syncOnce();
      expect(b.data['library/p|x'], {'name': 'v-b'});
      expect(b.outbox, isNotEmpty);
      await eb.syncOnce();
      await ea.syncOnce();
      expect(a.data['library/p|x'], {'name': 'v-b'});
    },
  );

  test('une modification pendant l\'envoi reste en attente', () async {
    a.put('library', 'p|x', {'name': 'v1'});
    var once = true;
    final slow = _Hook(
      server,
      onPush: () {
        if (once) a.put('library', 'p|x', {'name': 'v2'});
        once = false;
      },
    );
    await SyncEngine(slow, a, maxPushRounds: 1).syncOnce();
    // v1 envoyé, mais v2 (seq plus récent) est toujours à envoyer.
    expect(a.outbox, isNotEmpty);
    await ea.syncOnce();
    expect(server.items['library/p|x']!.payload, {'name': 'v2'});
    expect(a.outbox, isEmpty);
  });

  test('pagination : toutes les pages sont tirées', () async {
    for (var i = 0; i < 7; i++) {
      a.put('library', 'p|$i', {'name': '$i'});
      await ea.syncOnce();
    }
    server.pageSize = 3;
    await eb.syncOnce();
    expect(b.data.length, 7);
    expect(b.last, server.version);
    expect(server.pulls, greaterThanOrEqualTo(3));
  });

  test('envoi par paquets de 500 éléments', () async {
    for (var i = 0; i < 1200; i++) {
      a.put('library', 'p|$i', {'n': i});
    }
    await ea.syncOnce();
    expect(server.pushes, 3);
    expect(server.items.length, 1200);
    expect(a.outbox, isEmpty);
  });

  test('envoi découpé selon la taille (corps < 200 Ko)', () async {
    final big = 'x' * 15000;
    for (var i = 0; i < 40; i++) {
      a.put('library', 'p|$i', {'blob': big});
    }
    final seen = <int>[];
    final spy = _Hook(server, onPushItems: (n) => seen.add(n));
    await SyncEngine(spy, a).syncOnce();
    expect(seen.length, greaterThan(1));
    expect(seen.every((n) => n * 15000 < SyncLimits.maxBodyBytes), isTrue);
    expect(server.items.length, 40);
  });

  test('éléments invalides abandonnés, pas de file bloquée', () async {
    a.put('settings', 'parent_pin_hash', {'value': 'pbkdf2\$x'});
    a.put('settings', 'active_profile', {'value': 'p1'});
    a.put('profiles', 'p1', {'name': 'Léa', 'pinHash': 'secret'});
    a.put('library', 'p|trop-gros', {'name': 'x' * 17000});
    a.put('addons', 'default', {'blob': 'AAAA'});
    a.put('library', 'p|ok', {'name': 'ok'});
    await ea.syncOnce();
    expect(server.items.keys, ['library/p|ok']);
    expect(a.outbox, isEmpty);
  });

  test('éléments reçus de types non activés (addons) ignorés', () async {
    server.version = 1;
    server.items['addons/default'] = const SyncItem(
      kind: 'addons',
      key: 'default',
      payload: {'blob': 'AAAA'},
      version: 1,
    );
    await eb.syncOnce();
    expect(b.data, isEmpty);
    expect(b.last, 1);
  });

  test('erreur réseau : file intacte, reprise au cycle suivant', () async {
    a.put('library', 'p|1', {'name': 'x'});
    server.failNext = Exception('hors ligne');
    await expectLater(ea.syncOnce(), throwsException);
    expect(a.outbox, isNotEmpty);
    await ea.syncOnce();
    expect(a.outbox, isEmpty);
    expect(server.items, isNotEmpty);
  });

  test('appels simultanés : une seule synchronisation', () async {
    a.put('library', 'p|1', {'name': 'x'});
    await Future.wait([ea.syncOnce(), ea.syncOnce(), ea.syncOnce()]);
    expect(server.pushes, 1);
  });

  test('isSyncableSettingKey : liste blanche stricte', () {
    for (final k in [
      'ui_locale',
      'home_layout:default',
      'stream_prefs:p1',
      'subtitle_lang:p1',
    ]) {
      expect(isSyncableSettingKey(k), isTrue, reason: k);
    }
    for (final k in [
      'parent_pin_hash',
      'parent_recovery_hash',
      'parent_lockout',
      'active_profile',
      'onboarding_done',
      'sync_session',
      'home_layout:',
      'ui_locale:x',
    ]) {
      expect(isSyncableSettingKey(k), isFalse, reason: k);
    }
  });
}

/// Transport qui exécute un rappel autour de l'envoi.
class _Hook implements SyncTransport {
  _Hook(this._inner, {this.onPush, this.onPushItems, this.onPull});
  final SyncTransport _inner;
  final void Function()? onPush;
  final void Function(int)? onPushItems;
  final void Function()? onPull;

  @override
  Future<SyncPage> pull(int since) async {
    final page = await _inner.pull(since);
    onPull?.call();
    return page;
  }

  @override
  Future<int> push(List<SyncItem> items) async {
    onPushItems?.call(items.length);
    final v = await _inner.push(items);
    onPush?.call();
    return v;
  }
}
