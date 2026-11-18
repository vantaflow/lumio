import 'dart:math';

import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

void main() {
  group('PinHasher', () {
    test('PIN correct accepté, incorrect refusé', () {
      final h = PinHasher.hash('1234');
      expect(h, startsWith(r'pbkdf2$100000$'));
      expect(PinHasher.verify('1234', h), isTrue);
      expect(PinHasher.verify('1235', h), isFalse);
    });

    test('sel aléatoire : deux hachages du même PIN diffèrent', () {
      expect(PinHasher.hash('1234'), isNot(PinHasher.hash('1234')));
    });

    test('sel fourni : résultat déterministe', () {
      final salt = List<int>.generate(16, (i) => i);
      expect(
        PinHasher.hash('0000', salt: salt),
        PinHasher.hash('0000', salt: salt),
      );
    });

    test('vecteur PBKDF2-HMAC-SHA256 (RFC 7914 §11, c=1)', () {
      const stored =
          r'pbkdf2$1$c2FsdA==$'
          'VawEblbjCJ/sFpHCJUS2BflBhSFt3gRl5oudV8INrLw=';
      expect(PinHasher.verify('passwd', stored), isTrue);
      expect(PinHasher.verify('passwd2', stored), isFalse);
    });

    test('formats invalides refusés sans exception', () {
      expect(PinHasher.verify('1234', ''), isFalse);
      expect(PinHasher.verify('1234', r'pbkdf2$x$y$z'), isFalse);
      expect(PinHasher.verify('1234', r'md5$1$AA==$AA=='), isFalse);
      expect(PinHasher.verify('1234', r'pbkdf2$1$!!$!!'), isFalse);
    });

    test('isValidPin : exactement 4 chiffres', () {
      expect(isValidPin('1234'), isTrue);
      expect(isValidPin('123'), isFalse);
      expect(isValidPin('12345'), isFalse);
      expect(isValidPin('12a4'), isFalse);
    });
  });

  group('RecoveryCode', () {
    test('10 caractères Crockford', () {
      final c = RecoveryCode.generate(Random(1));
      expect(c, matches(RegExp(r'^[0-9A-HJKMNP-TV-Z]{10}$')));
    });

    test('normalisation : tirets, casse, confusions O/I/L', () {
      expect(RecoveryCode.normalize('abcde-fghjk'), 'ABCDEFGHJK');
      expect(RecoveryCode.normalize('0123 4O1I L7'), '0123401117');
      expect(RecoveryCode.normalize('court'), isNull);
      expect(RecoveryCode.normalize('ABCDEFGHJU'), isNull);
    });
  });

  group('PinLockout', () {
    late DateTime clock;
    late PinLockout lock;
    setUp(() {
      clock = DateTime.utc(2026, 11, 18, 12);
      lock = PinLockout(now: () => clock);
    });

    test('3 échecs verrouillent, 5 minutes plus tard déverrouillé', () {
      lock
        ..fail()
        ..fail();
      expect(lock.locked, isFalse);
      lock.fail();
      expect(lock.locked, isTrue);
      clock = clock.add(const Duration(minutes: 4, seconds: 59));
      expect(lock.locked, isTrue);
      clock = clock.add(const Duration(seconds: 1));
      expect(lock.locked, isFalse);
      // Compteur remis à zéro : il faut de nouveau 3 échecs.
      lock.fail();
      expect(lock.locked, isFalse);
    });

    test('un succès remet le compteur à zéro', () {
      lock
        ..fail()
        ..fail()
        ..success()
        ..fail();
      expect(lock.locked, isFalse);
    });

    test('état persistable', () {
      lock
        ..fail()
        ..fail()
        ..fail();
      final restored = PinLockout.fromJson(lock.toJson(), now: () => clock);
      expect(restored.locked, isTrue);
      expect(restored.remaining, const Duration(minutes: 5));
      clock = clock.add(const Duration(minutes: 5));
      expect(restored.locked, isFalse);
    });

    test('échecs partiels persistés', () {
      lock
        ..fail()
        ..fail();
      final restored = PinLockout.fromJson(lock.toJson(), now: () => clock)
        ..fail();
      expect(restored.locked, isTrue);
    });

    test('JSON corrompu : état neutre', () {
      final r = PinLockout.fromJson({'failures': 'x', 'until': 'y'});
      expect(r.locked, isFalse);
    });
  });
}
