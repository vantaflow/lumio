import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hachage de PIN : `pbkdf2$100000$<sel b64>$<hash b64>`.
///
/// 100 000 itérations coûtent cher sur un petit processeur : les appelants
/// de l'interface doivent l'exécuter hors du fil d'interface (Isolate.run).
class PinHasher {
  static const iterations = 100000;
  static const saltLength = 16;
  static const _keyLength = 32;

  static String hash(String pin, {List<int>? salt}) {
    final s = salt ?? _randomBytes(saltLength);
    final dk = _pbkdf2(utf8.encode(pin), s, iterations);
    return 'pbkdf2\$$iterations\$${base64.encode(s)}\$${base64.encode(dk)}';
  }

  static bool verify(String pin, String stored) {
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != 'pbkdf2') return false;
    final iter = int.tryParse(parts[1]);
    if (iter == null || iter < 1 || iter > 10000000) return false;
    final List<int> salt;
    final List<int> expected;
    try {
      salt = base64.decode(parts[2]);
      expected = base64.decode(parts[3]);
    } on FormatException {
      return false;
    }
    final actual = _pbkdf2(utf8.encode(pin), salt, iter);
    return constantTimeEquals(actual, expected);
  }

  /// Comparaison en temps constant (la longueur n'est pas secrète).
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// PBKDF2-HMAC-SHA256, un seul bloc de 32 octets.
  static List<int> _pbkdf2(List<int> password, List<int> salt, int iter) {
    final hmac = Hmac(sha256, password);
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final t = Uint8List.fromList(u);
    for (var i = 1; i < iter; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < _keyLength; j++) {
        t[j] ^= u[j];
      }
    }
    return t;
  }

  static List<int> _randomBytes(int n) {
    final r = Random.secure();
    return List<int>.generate(n, (_) => r.nextInt(256));
  }
}

/// PIN parent à 4 chiffres.
bool isValidPin(String pin) => RegExp(r'^\d{4}$').hasMatch(pin);

/// Code de récupération : 10 caractères en base32 Crockford, affiché une
/// seule fois ; seul son hachage est conservé.
class RecoveryCode {
  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const length = 10;

  static String generate([Random? random]) {
    final r = random ?? Random.secure();
    return String.fromCharCodes(
      List.generate(length, (_) => _alphabet.codeUnitAt(r.nextInt(32))),
    );
  }

  /// Forme canonique saisie par l'utilisateur : majuscules, sans espaces ni
  /// tirets, O -> 0, I/L -> 1 (règles Crockford). Null si invalide.
  static String? normalize(String input) {
    final c = input
        .toUpperCase()
        .replaceAll(RegExp(r'[\s-]'), '')
        .replaceAll('O', '0')
        .replaceAll('I', '1')
        .replaceAll('L', '1');
    if (c.length != length) return null;
    for (final ch in c.split('')) {
      if (!_alphabet.contains(ch)) return null;
    }
    return c;
  }

  /// Affichage par groupes de 5 (`ABCDE-FGHJK`).
  static String format(String code) =>
      '${code.substring(0, 5)}-${code.substring(5)}';
}

/// Verrou après échecs : 3 échecs consécutifs verrouillent, d'abord 5 min,
/// puis 15 min, puis 60 min à chaque cycle suivant ; seul un succès remet les
/// cycles à zéro. L'état est sérialisable (survit au redémarrage) ; l'horloge
/// est injectable.
///
/// Limite acceptée : l'horloge de l'appareil fait foi, un changement d'heure
/// manuel contourne donc le verrou.
class PinLockout {
  PinLockout({
    DateTime Function()? now,
    int failures = 0,
    int cycles = 0,
    DateTime? lockedUntil,
  }) : _now = now ?? DateTime.now,
       _failures = failures,
       _cycles = cycles,
       _lockedUntil = lockedUntil;

  factory PinLockout.fromJson(
    Map<String, Object?> json, {
    DateTime Function()? now,
  }) {
    final until = json['until'];
    return PinLockout(
      now: now,
      failures: json['failures'] is int ? json['failures']! as int : 0,
      cycles: json['cycles'] is int ? json['cycles']! as int : 0,
      lockedUntil: until is int
          ? DateTime.fromMillisecondsSinceEpoch(until, isUtc: true)
          : null,
    );
  }

  static const maxFailures = 3;
  static const lockDuration = Duration(minutes: 5);

  /// Durée du verrou selon le nombre de verrous déjà subis (le dernier
  /// palier sert ensuite de plafond).
  static const lockDurations = [
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 60),
  ];

  final DateTime Function() _now;
  int _failures;
  int _cycles;
  DateTime? _lockedUntil;

  bool get locked {
    final until = _lockedUntil;
    if (until == null) return false;
    if (_now().isBefore(until)) return true;
    // Verrou échu : on repart de zéro.
    _lockedUntil = null;
    _failures = 0;
    return false;
  }

  /// Temps restant avant déverrouillage (zéro si déverrouillé).
  Duration get remaining {
    if (!locked) return Duration.zero;
    return _lockedUntil!.difference(_now());
  }

  void fail() {
    if (locked) return;
    _failures++;
    if (_failures >= maxFailures) {
      final i = _cycles.clamp(0, lockDurations.length - 1);
      _lockedUntil = _now().add(lockDurations[i]);
      _cycles++;
      _failures = 0;
    }
  }

  void success() {
    _failures = 0;
    _cycles = 0;
    _lockedUntil = null;
  }

  Map<String, Object?> toJson() => {
    'failures': _failures,
    'cycles': _cycles,
    'until': _lockedUntil?.toUtc().millisecondsSinceEpoch,
  };
}
