import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/profile_repository.dart';
import 'package:lumio_core/lumio_core.dart';

void main() {
  late AppDatabase db;
  late DateTime clock;
  late ProfileRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = DateTime.utc(2026, 11, 18, 12);
    repo = ProfileRepository(db, now: () => clock);
  });
  tearDown(() => db.close());

  test('migration v3 vers v4 : colonnes ajoutées, profils conservés', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final old = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE profiles (id TEXT NOT NULL PRIMARY KEY, '
            'name TEXT NOT NULL, created_at INTEGER NOT NULL DEFAULT 0)',
          );
          raw.execute("INSERT INTO profiles VALUES ('default', 'Moi', 5)");
          raw.execute('PRAGMA user_version = 3');
        },
      ),
    );
    addTearDown(old.close);
    final p = (await old.select(old.profiles).get()).single;
    expect(p.name, 'Moi');
    expect(p.ageLimit, AgeLimit.adult.index);
    expect(p.isKid, isFalse);
    expect(p.locked, isFalse);
  });

  group('profils', () {
    test('ensureDefault : « Moi » adulte, une seule fois', () async {
      await repo.ensureDefault();
      await repo.ensureDefault();
      final all = await repo.list();
      expect(all, hasLength(1));
      expect(all.single.id, defaultProfileId);
      expect(all.single.name, 'Moi');
      expect(all.single.isKid, isFalse);
      expect(all.single.ageLimit, AgeLimit.adult.index);
    });

    test('ensureDefault : ne touche pas à un profil existant', () async {
      await repo.create('Alice');
      await repo.ensureDefault();
      expect((await repo.list()).map((p) => p.name), ['Alice']);
    });

    test('create : 6 profils au maximum, le 7e est refusé', () async {
      for (var i = 1; i <= 6; i++) {
        clock = clock.add(const Duration(seconds: 1));
        await repo.create('P$i');
      }
      expect(() => repo.create('P7'), throwsA(isA<ProfileLimitException>()));
      expect(await repo.list(), hasLength(6));
    });

    test('create : nom vide refusé, nom rogné, ordre de création', () async {
      expect(() => repo.create('  '), throwsArgumentError);
      await repo.create(' Alice ');
      clock = clock.add(const Duration(seconds: 1));
      await repo.create('Bob', limit: AgeLimit.age7, isKid: true);
      final all = await repo.list();
      expect(all.map((p) => p.name), ['Alice', 'Bob']);
      expect(all[1].ageLimit, AgeLimit.age7.index);
      expect(all[1].isKid, isTrue);
    });

    test('un profil enfant n\'est jamais sans limite d\'âge', () async {
      final a = await repo.create('Kid', isKid: true);
      final b = await repo.create('Kid2', isKid: true, limit: AgeLimit.adult);
      expect(a.ageLimit, AgeLimit.age12.index);
      expect(b.ageLimit, AgeLimit.age12.index);
    });

    test('update : nom, limite, enfant, verrou', () async {
      final p = await repo.create('Alice');
      await repo.update(p.id, name: 'Alicia', isKid: true, locked: true);
      final u = (await repo.get(p.id))!;
      expect(u.name, 'Alicia');
      expect(u.isKid, isTrue);
      expect(u.locked, isTrue);
      expect(u.ageLimit, AgeLimit.age12.index);
      await repo.update(p.id, isKid: false, limit: AgeLimit.adult);
      expect((await repo.get(p.id))!.ageLimit, AgeLimit.adult.index);
    });

    test('delete : retire profil et données, jamais le dernier', () async {
      await repo.ensureDefault();
      final p = await repo.create('Alice');
      await db
          .into(db.progress)
          .insert(
            ProgressCompanion.insert(profileId: Value(p.id), itemId: 'tt1'),
          );
      await repo.setActive(p.id);
      await repo.delete(p.id);
      expect((await repo.list()).map((x) => x.id), [defaultProfileId]);
      expect(await db.select(db.progress).get(), isEmpty);
      expect(await repo.activeId(), isNull);
      await repo.delete(defaultProfileId);
      expect(await repo.list(), hasLength(1));
    });

    test('profil actif mémorisé', () async {
      expect(await repo.activeId(), isNull);
      await repo.setActive('x');
      expect(await repo.activeId(), 'x');
      await repo.clearActive();
      expect(await repo.activeId(), isNull);
    });
  });

  group('PIN parent', () {
    test(
      'création : code de récupération, seul le hachage est stocké',
      () async {
        expect(await repo.hasParentPin(), isFalse);
        final code = await repo.createParentPin('1234');
        expect(code, matches(RegExp(r'^[0-9A-HJKMNP-TV-Z]{10}$')));
        expect(await repo.hasParentPin(), isTrue);
        final rows = await db.select(db.settings).get();
        final dump = rows.map((r) => '${r.key}=${r.value}').join('\n');
        expect(dump, contains(r'parent_pin_hash=pbkdf2$100000$'));
        expect(dump, isNot(contains('1234')));
        expect(dump, isNot(contains(code)));
      },
    );

    test('PIN invalide refusé ; deuxième création refusée', () async {
      expect(() => repo.createParentPin('12'), throwsArgumentError);
      await repo.createParentPin('1234');
      expect(() => repo.createParentPin('4321'), throwsStateError);
    });

    test('vérification correcte / incorrecte', () async {
      await repo.createParentPin('1234');
      expect(await repo.verifyParentPin('1234'), PinResult.ok);
      expect(await repo.verifyParentPin('0000'), PinResult.wrong);
      expect(await repo.verifyParentPin('abcd'), PinResult.wrong);
    });

    test('3 échecs : verrou 5 min, même avec le bon PIN, puis levé', () async {
      await repo.createParentPin('1234');
      expect(await repo.verifyParentPin('1'), PinResult.wrong);
      expect(await repo.verifyParentPin('2'), PinResult.wrong);
      expect(await repo.verifyParentPin('3'), PinResult.locked);
      expect(await repo.verifyParentPin('1234'), PinResult.locked);
      expect(await repo.lockRemaining(), const Duration(minutes: 5));
      clock = clock.add(const Duration(minutes: 5));
      expect(await repo.verifyParentPin('1234'), PinResult.ok);
    });

    test('le verrou survit au redémarrage (nouvelle instance)', () async {
      await repo.createParentPin('1234');
      for (var i = 0; i < 3; i++) {
        await repo.verifyParentPin('0000');
      }
      final again = ProfileRepository(db, now: () => clock);
      expect(await again.verifyParentPin('1234'), PinResult.locked);
      clock = clock.add(const Duration(minutes: 5, seconds: 1));
      expect(await again.verifyParentPin('1234'), PinResult.ok);
    });

    test(
      'verrous croissants persistés : 5 puis 15 min, succès remet à 0',
      () async {
        await repo.createParentPin('1234');
        Future<void> lockOut(Duration d) async {
          final r = ProfileRepository(
            db,
            now: () => clock,
            hashPin: (p) async => 'h:$p',
            verifyPin: (p, s) async => s == 'h:$p',
          );
          for (var i = 0; i < 3; i++) {
            await r.verifyParentPin('0000');
          }
          expect(await r.lockRemaining(), d);
          clock = clock.add(d);
        }

        await lockOut(const Duration(minutes: 5));
        await lockOut(const Duration(minutes: 15));
        await lockOut(const Duration(minutes: 60));
        expect(await repo.verifyParentPin('1234'), PinResult.ok);
        await lockOut(const Duration(minutes: 5));
      },
    );

    test('un succès remet le compteur à zéro', () async {
      await repo.createParentPin('1234');
      await repo.verifyParentPin('0000');
      await repo.verifyParentPin('0000');
      expect(await repo.verifyParentPin('1234'), PinResult.ok);
      expect(await repo.verifyParentPin('0000'), PinResult.wrong);
    });

    test('vérifications simultanées : le compteur ne se perd pas', () async {
      await repo.createParentPin('1234');
      final r = await Future.wait([
        repo.verifyParentPin('0000'),
        repo.verifyParentPin('0001'),
        repo.verifyParentPin('0002'),
      ]);
      expect(r.last, PinResult.locked);
    });

    test('changement de PIN : ancien exigé', () async {
      await repo.createParentPin('1234');
      expect(await repo.changeParentPin('0000', '5678'), PinResult.wrong);
      expect(await repo.changeParentPin('1234', '5678'), PinResult.ok);
      expect(await repo.verifyParentPin('1234'), PinResult.wrong);
      expect(await repo.verifyParentPin('5678'), PinResult.ok);
    });

    test('récupération : nouveau PIN, ancien code périmé', () async {
      final code = await repo.createParentPin('1234');
      final r = await repo.resetPinWithRecovery(code.toLowerCase(), '9999');
      expect(r.result, PinResult.ok);
      expect(r.newRecoveryCode, isNot(code));
      expect(await repo.verifyParentPin('9999'), PinResult.ok);
      final again = await repo.resetPinWithRecovery(code, '1111');
      expect(again.result, PinResult.wrong);
      expect(again.newRecoveryCode, isNull);
    });

    test('récupération : mauvais code compté dans le verrou', () async {
      await repo.createParentPin('1234');
      for (var i = 0; i < 2; i++) {
        final r = await repo.resetPinWithRecovery('ABCDEFGHJK', '1111');
        expect(r.result, PinResult.wrong);
      }
      final r = await repo.resetPinWithRecovery('ABCDEFGHJK', '1111');
      expect(r.result, PinResult.locked);
      expect(await repo.verifyParentPin('1234'), PinResult.locked);
    });
  });
}
