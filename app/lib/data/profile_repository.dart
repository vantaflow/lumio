import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio_core/lumio_core.dart';

export 'package:lumio/data/db.dart' show Profile;

/// Identifiant du premier profil (celui des données antérieures aux profils).
const defaultProfileId = 'default';

/// Nombre maximal de profils.
const maxProfiles = 6;

/// Levée à la création d'un 7e profil.
class ProfileLimitException implements Exception {
  const ProfileLimitException();

  @override
  String toString() => 'Six profils au maximum';
}

/// Résultat d'une vérification de PIN.
enum PinResult { ok, wrong, locked }

/// Hachage hors du fil d'interface (100 000 itérations).
Future<String> hashPinInIsolate(String pin) =>
    Isolate.run(() => PinHasher.hash(pin));

Future<bool> verifyPinInIsolate(String pin, String stored) =>
    Isolate.run(() => PinHasher.verify(pin, stored));

const _kPinHash = 'parent_pin_hash';
const _kRecoveryHash = 'parent_recovery_hash';
const _kLockout = 'parent_lockout';
const _kActive = 'active_profile';

/// Profils, PIN parent et verrou, persistés dans SQLite. Le PIN et le code
/// de récupération ne sont jamais stockés en clair, seulement leur hachage.
class ProfileRepository {
  ProfileRepository(
    this._db, {
    DateTime Function()? now,
    Future<String> Function(String pin)? hashPin,
    Future<bool> Function(String pin, String stored)? verifyPin,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _hash = hashPin ?? hashPinInIsolate,
       _verify = verifyPin ?? verifyPinInIsolate,
       _random = random;

  final AppDatabase _db;
  final DateTime Function() _now;
  final Future<String> Function(String pin) _hash;
  final Future<bool> Function(String pin, String stored) _verify;
  final Random? _random;

  // Sérialise les opérations de PIN : deux vérifications simultanées ne
  // doivent pas se partager un compteur d'échecs périmé.
  Future<void> _tail = Future.value();

  Future<T> _serial<T>(Future<T> Function() op) {
    final next = _tail.then((_) => op());
    _tail = next.then((_) {}, onError: (_) {});
    return next;
  }

  // --- Profils ---------------------------------------------------------

  Future<List<Profile>> list() =>
      (_db.select(_db.profiles)..orderBy([
            (p) => OrderingTerm.asc(p.createdAt),
            (p) => OrderingTerm.asc(p.rowId),
          ]))
          .get();

  Future<Profile?> get(String id) => (_db.select(
    _db.profiles,
  )..where((p) => p.id.equals(id))).getSingleOrNull();

  /// Crée le profil « Moi » (adulte) au premier lancement ; sans effet si un
  /// profil existe déjà. Reprend l'identifiant « default » des données
  /// antérieures.
  Future<void> ensureDefault() async {
    if ((await list()).isNotEmpty) return;
    await _db
        .into(_db.profiles)
        .insert(
          ProfilesCompanion.insert(
            id: defaultProfileId,
            name: 'Moi',
            createdAt: Value(_now().millisecondsSinceEpoch),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// Crée un profil. Un profil enfant n'a jamais la limite « adulte » : à
  /// défaut de limite explicite il reçoit 12 ans.
  Future<Profile> create(
    String name, {
    AgeLimit? limit,
    bool isKid = false,
    bool locked = false,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Le nom est obligatoire');
    if ((await list()).length >= maxProfiles) {
      throw const ProfileLimitException();
    }
    final age = _effectiveLimit(limit, isKid);
    final id =
        'p${_now().microsecondsSinceEpoch.toRadixString(36)}'
        '${(_random ?? Random.secure()).nextInt(1 << 20).toRadixString(36)}';
    await _db
        .into(_db.profiles)
        .insert(
          ProfilesCompanion.insert(
            id: id,
            name: clean,
            createdAt: Value(_now().millisecondsSinceEpoch),
            ageLimit: Value(age.index),
            isKid: Value(isKid),
            locked: Value(locked),
          ),
        );
    return (await get(id))!;
  }

  AgeLimit _effectiveLimit(AgeLimit? limit, bool isKid) {
    if (!isKid) return limit ?? AgeLimit.adult;
    return (limit == null || limit == AgeLimit.adult) ? AgeLimit.age12 : limit;
  }

  Future<void> update(
    String id, {
    String? name,
    AgeLimit? limit,
    bool? isKid,
    bool? locked,
  }) async {
    final current = await get(id);
    if (current == null) return;
    final kid = isKid ?? current.isKid;
    final age = _effectiveLimit(
      limit ?? AgeLimit.values[current.ageLimit],
      kid,
    );
    final clean = name?.trim();
    if (clean != null && clean.isEmpty) {
      throw ArgumentError('Le nom est obligatoire');
    }
    await (_db.update(_db.profiles)..where((p) => p.id.equals(id))).write(
      ProfilesCompanion(
        name: clean == null ? const Value.absent() : Value(clean),
        ageLimit: Value(age.index),
        isKid: Value(kid),
        locked: Value(locked ?? current.locked),
      ),
    );
  }

  /// Supprime un profil et ses données (progression, bibliothèque, réglages).
  /// Le dernier profil ne peut pas être supprimé.
  Future<void> delete(String id) async {
    final all = await list();
    if (all.length <= 1 || !all.any((p) => p.id == id)) return;
    await _db.transaction(() async {
      await (_db.delete(
        _db.progress,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.libraryItems,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.titleSettingsTable,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(_db.profiles)..where((p) => p.id.equals(id))).go();
    });
    if (await activeId() == id) await _delSetting(_kActive);
  }

  /// Profil actif mémorisé (null si aucun).
  Future<String?> activeId() => _getSetting(_kActive);

  Future<void> setActive(String id) => _setSetting(_kActive, id);

  Future<void> clearActive() => _delSetting(_kActive);

  // --- PIN parent ------------------------------------------------------

  Future<bool> hasParentPin() async => (await _getSetting(_kPinHash)) != null;

  /// Crée le PIN parent et renvoie le code de récupération, à afficher une
  /// seule fois (seul son hachage est conservé).
  Future<String> createParentPin(String pin) => _serial(() async {
    _requirePin(pin);
    if (await _getSetting(_kPinHash) != null) {
      throw StateError('Un PIN parent existe déjà');
    }
    return _storePin(pin);
  });

  /// Change le PIN après vérification de l'ancien (verrou compris). Renvoie
  /// [PinResult.ok] une fois fait.
  Future<PinResult> changeParentPin(String oldPin, String newPin) {
    _requirePin(newPin);
    return _serial(() async {
      final r = await _check(oldPin);
      if (r != PinResult.ok) return r;
      await _setSetting(_kPinHash, await _hash(newPin));
      return PinResult.ok;
    });
  }

  Future<PinResult> verifyParentPin(String pin) => _serial(() => _check(pin));

  /// Remet un nouveau PIN à l'aide du code de récupération. En cas de succès
  /// renvoie le nouveau code (l'ancien est périmé), sinon `newRecoveryCode`
  /// est nul. Les essais partagent le verrou du PIN.
  Future<({PinResult result, String? newRecoveryCode})> resetPinWithRecovery(
    String code,
    String newPin,
  ) {
    _requirePin(newPin);
    return _serial(() async {
      final lock = await _loadLockout();
      if (lock.locked) return (result: PinResult.locked, newRecoveryCode: null);
      final stored = await _getSetting(_kRecoveryHash);
      final normalized = RecoveryCode.normalize(code);
      final ok =
          stored != null &&
          normalized != null &&
          await _verify(normalized, stored);
      if (!ok) {
        lock.fail();
        await _saveLockout(lock);
        return (
          result: lock.locked ? PinResult.locked : PinResult.wrong,
          newRecoveryCode: null,
        );
      }
      lock.success();
      await _saveLockout(lock);
      return (result: PinResult.ok, newRecoveryCode: await _storePin(newPin));
    });
  }

  /// Durée de verrouillage restante (zéro si déverrouillé).
  Future<Duration> lockRemaining() async => (await _loadLockout()).remaining;

  Future<PinResult> _check(String pin) async {
    final lock = await _loadLockout();
    if (lock.locked) return PinResult.locked;
    final stored = await _getSetting(_kPinHash);
    if (stored == null) return PinResult.wrong;
    final ok = isValidPin(pin) && await _verify(pin, stored);
    if (ok) {
      lock.success();
      await _saveLockout(lock);
      return PinResult.ok;
    }
    lock.fail();
    await _saveLockout(lock);
    return lock.locked ? PinResult.locked : PinResult.wrong;
  }

  Future<String> _storePin(String pin) async {
    final code = RecoveryCode.generate(_random);
    final pinHash = await _hash(pin);
    final codeHash = await _hash(code);
    await _db.transaction(() async {
      await _setSetting(_kPinHash, pinHash);
      await _setSetting(_kRecoveryHash, codeHash);
    });
    return code;
  }

  void _requirePin(String pin) {
    if (!isValidPin(pin)) throw ArgumentError('Le PIN doit avoir 4 chiffres');
  }

  Future<PinLockout> _loadLockout() async {
    final raw = await _getSetting(_kLockout);
    if (raw != null) {
      try {
        final j = jsonDecode(raw);
        if (j is Map<String, Object?>) {
          return PinLockout.fromJson(j, now: _now);
        }
      } on FormatException {
        // Illisible : on repart d'un état neutre.
      }
    }
    return PinLockout(now: _now);
  }

  Future<void> _saveLockout(PinLockout lock) =>
      _setSetting(_kLockout, jsonEncode(lock.toJson()));

  // --- Réglages --------------------------------------------------------

  Future<String?> _getSetting(String key) async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _setSetting(String key, String value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  Future<void> _delSetting(String key) =>
      (_db.delete(_db.settings)..where((s) => s.key.equals(key))).go();
}
