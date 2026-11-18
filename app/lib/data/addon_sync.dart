import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio_core/lumio_core.dart';

typedef SealFn = Future<String> Function(String plaintext, String passphrase);

/// Empreinte d'une phrase pour un sel local (jamais la phrase elle-même).
typedef FingerprintFn = Future<String> Function(String phrase, List<int> salt);
typedef OpenFn = Future<String> Function(String sealed, String passphrase);

/// Clés du `SecretStore` propres à la synchronisation des addons.
abstract final class AddonSyncSecretKeys {
  /// Phrase secrète de synchronisation (jamais envoyée au serveur).
  static const passphrase = 'sync.passphrase';

  /// Addons du blob distant pas encore installés ici (adresse locale à
  /// confirmer, échec réseau…) : ils sont gardés dans le blob renvoyé pour ne
  /// pas disparaître des autres appareils. Les adresses sont des secrets.
  static const carry = 'sync.addons_carry';

  /// Empreinte de la dernière phrase saisie et son sel local : survivent à
  /// l'oubli de la phrase, pour reconnaître la même phrase ressaisie.
  static const fingerprint = 'sync.addons_fp';
  static const fingerprintSalt = 'sync.addons_fpsalt';
}

/// Longueur minimale de la phrase secrète.
const minPassphraseLength = 12;

enum AddonSyncStatus {
  /// Pas de phrase secrète : les addons ne sont pas synchronisés.
  noPassphrase,

  /// Phrase saisie, en attente du premier échange avec le serveur.
  waiting,

  /// Les addons se synchronisent.
  ready,

  /// La phrase ne déchiffre pas le blob du serveur : rien n'est touché.
  wrongPassphrase,

  /// Trop d'addons pour un élément synchronisé (16 Ko).
  tooLarge,

  /// Réinitialisation demandée, suppression du blob distant en attente.
  resetting,

  /// Un autre appareil a réinitialisé la synchronisation des addons : la
  /// phrase locale est oubliée, rien n'est envoyé avant une nouvelle saisie.
  phraseReset,
}

/// Un addon reçu dont l'adresse désigne le réseau local : il attend la
/// confirmation de l'utilisateur sur cet appareil.
class PendingPrivateAddon {
  const PendingPrivateAddon(this.hash, this.label);

  /// Empreinte de l'adresse (clé stable, jamais l'adresse elle-même).
  final String hash;

  /// Adresse masquée (`redactUrl`).
  final String label;
}

class AddonSyncState {
  const AddonSyncState(
    this.status, {
    this.pendingPrivate = const [],
    this.failed = 0,
  });
  final AddonSyncStatus status;
  final List<PendingPrivateAddon> pendingPrivate;

  /// Addons reçus pas encore installables (réseau, manifeste) : nouvel essai
  /// automatique.
  final int failed;
}

/// Résultat d'un traitement du blob reçu.
class AddonProcessResult {
  const AddonProcessResult({this.needsPush = false, this.changedLocal = false});
  final bool needsPush;
  final bool changedLocal;
}

/// Synchronisation des addons : un seul élément `addons/all`, chiffré côté
/// client par `SecretBox` avec la phrase secrète de l'utilisateur. Le serveur
/// ne reçoit jamais d'adresse en clair ni la phrase.
///
/// Réception : l'élément distant est mis de côté tel quel (`recordRemote`),
/// puis déchiffré et appliqué par [process] ; les installations passent par
/// [AddonRepository.install] (UrlGuard, manifeste), jamais autrement, et une
/// adresse locale n'est jamais autorisée sans confirmation.
///
/// Garde-fous :
///  * rien n'est envoyé tant que le blob distant n'a pas été lu avec la
///    phrase courante (`addons_ready`), pour ne jamais écraser les addons
///    d'un autre appareil par une liste locale vide ou incomplète ;
///  * un addon n'est supprimé localement que s'il venait du dernier blob
///    traité (`addons_origin`) : un addon ajouté ici n'est jamais touché ;
///  * une mauvaise phrase laisse les addons locaux intacts.
class AddonSync {
  AddonSync(
    this._db,
    this._secrets,
    this._repo, {
    SealFn? seal,
    OpenFn? open,
    FingerprintFn? fingerprint,
    DateTime Function()? now,
    this.retryDelay = const Duration(minutes: 5),
  }) : _seal = seal ?? ((t, p) => SecretBox.seal(t, p)),
       _open = open ?? ((t, p) => SecretBox.open(t, p)),
       _fingerprint = fingerprint ?? _defaultFingerprint,
       _now = now ?? DateTime.now;

  final AppDatabase _db;
  final SecretStore _secrets;
  final AddonRepository _repo;
  final SealFn _seal;
  final OpenFn _open;
  final FingerprintFn _fingerprint;
  final DateTime Function() _now;
  final Duration retryDelay;

  /// Au plus 11 000 octets de clair : base64 + enveloppe tiennent sous 16 Ko.
  static const _maxPlainBytes = 11000;
  static const _maxEntries = 200;

  /// Au-delà de 2^53 un entier n'est plus exact : blob illisible.
  static const _maxGen = 9007199254740992;
  static const _maxUrlLength = 2048;

  static const _kPulled = 'addons_pulled';
  static const _kReady = 'addons_ready';
  static const _kRemote = 'addons_remote';
  static const _kRemoteNew = 'addons_remote_new';
  static const _kOrigin = 'addons_origin';
  static const _kSnapshot = 'addons_snapshot';
  static const _kStatus = 'addons_status';
  static const _kTooLarge = 'addons_toolarge';
  static const _kReset = 'addons_reset';
  static const _kRetryAt = 'addons_retry_at';
  static const _kGen = 'addons_gen';
  static const _kDevice = 'addons_device';
  static const _kRemoved = 'addons_removed';
  static const _kChanging = 'addons_changing';

  /// Les suppressions explicites sont gardées 90 jours, 100 au plus, et
  /// identifiées par un préfixe de 16 caractères de l'empreinte.
  static const _tombstoneMaxAge = Duration(days: 90);
  static const _tombstoneMax = 100;
  static const _tombstoneHashLength = 16;

  // --- sync_meta ---------------------------------------------------------

  Future<String?> _get(String key) async {
    final r = await _db
        .customSelect(
          'SELECT value FROM sync_meta WHERE key = ?',
          variables: [Variable.withString(key)],
        )
        .getSingleOrNull();
    return r?.read<String>('value');
  }

  Future<void> _set(String key, String value) => _db.customStatement(
    'INSERT OR REPLACE INTO sync_meta (key, value) VALUES (?, ?)',
    [key, value],
  );

  Future<void> _del(String key) =>
      _db.customStatement('DELETE FROM sync_meta WHERE key = ?', [key]);

  Future<void> _enqueue() async {
    await _db.customStatement(
      "DELETE FROM sync_outbox WHERE kind = 'addons' AND key = 'all'",
    );
    await _db.customStatement(
      "INSERT INTO sync_outbox (kind, key) VALUES ('addons', 'all')",
    );
  }

  Future<bool> _queued() async =>
      (await _db
              .customSelect(
                "SELECT 1 FROM sync_outbox WHERE kind = 'addons' AND key = 'all'",
              )
              .get())
          .isNotEmpty;

  // Les opérations qui modifient l'état s'exécutent l'une après l'autre.
  Future<void> _tail = Future.value();
  Future<T> _locked<T>(Future<T> Function() op) {
    final c = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        c.complete(await op());
      } on Object catch (e, st) {
        c.completeError(e, st);
      }
    });
    return c.future;
  }

  // --- phrase secrète ----------------------------------------------------

  Future<String?> passphrase() => _secrets.read(AddonSyncSecretKeys.passphrase);

  /// Enregistre la phrase de cet appareil (« rejoindre » : le blob du serveur
  /// doit s'ouvrir avec elle, ou ne pas exister). Lève [ArgumentError] si
  /// elle est trop courte.
  Future<AddonProcessResult> setPassphrase(String phrase) => _locked(() async {
    _checkLength(phrase);
    // La même phrase ressaisie (après oubli, réinitialisation distante…)
    // garde génération, origine et suppressions : un ancien blob rejoué reste
    // ignoré. Seule une phrase réellement nouvelle ouvre une nouvelle époque
    // (les blobs de l'autre phrase ne s'ouvrent de toute façon pas).
    final fp = await _fingerprintOf(phrase);
    final known = await _secrets.read(AddonSyncSecretKeys.fingerprint);
    if (known != null && known != fp) {
      await _del(_kGen);
      await _del(_kOrigin);
      await _del(_kRemoved);
    }
    await _secrets.write(AddonSyncSecretKeys.fingerprint, fp);
    await _secrets.write(AddonSyncSecretKeys.passphrase, phrase);
    await _del(_kChanging);
    await _del(_kReset);
    await _del(_kReady);
    await _del(_kStatus);
    await _del(_kTooLarge);
    await _set(_kRemoteNew, '1');
    return _process();
  });

  /// Change la phrase : les addons sont rechiffrés et renvoyés. Réservé à un
  /// appareil dont la phrase courante a déjà ouvert le blob.
  Future<void> changePassphrase(String phrase) => _locked(() async {
    _checkLength(phrase);
    if (await _get(_kReady) != '1') {
      throw StateError('phrase courante non validée');
    }
    await _secrets.write(AddonSyncSecretKeys.passphrase, phrase);
    await _secrets.write(
      AddonSyncSecretKeys.fingerprint,
      await _fingerprintOf(phrase),
    );
    // Jusqu'à l'envoi, un blob de l'ancienne phrase qui arrive ne bloque pas
    // le nouvel envoi.
    await _set(_kChanging, '1');
    await _del(_kStatus);
    await _del(_kTooLarge);
    await _enqueue();
  });

  /// Phrase perdue : le blob distant est supprimé (pierre tombale) à la
  /// prochaine synchronisation ; les addons de cet appareil sont conservés
  /// et pourront être renvoyés avec une nouvelle phrase.
  Future<void> requestReset() => _locked(() async {
    await _secrets.delete(AddonSyncSecretKeys.passphrase);
    await _del(_kReady);
    await _del(_kStatus);
    await _del(_kTooLarge);
    await _del(_kRemoteNew);
    await _del(_kChanging);
    await _set(_kReset, '1');
    await _enqueue();
  });

  Future<String> _fingerprintOf(String phrase) async {
    var raw = await _secrets.read(AddonSyncSecretKeys.fingerprintSalt);
    if (raw == null) {
      final r = Random.secure();
      raw = base64Url.encode([for (var i = 0; i < 16; i++) r.nextInt(256)]);
      await _secrets.write(AddonSyncSecretKeys.fingerprintSalt, raw);
    }
    return _fingerprint(phrase, base64Url.decode(raw));
  }

  static Future<String> _defaultFingerprint(String phrase, List<int> salt) =>
      Isolate.run(() async {
        final key = await SecretBox.pbkdf2(utf8.encode(phrase), [
          ...utf8.encode('lumio-fp'),
          ...salt,
        ], SecretBox.iterations);
        return base64Url.encode(key);
      });

  void _checkLength(String phrase) {
    if (phrase.runes.length < minPassphraseLength) {
      throw ArgumentError('phrase trop courte');
    }
  }

  /// Déconnexion : la phrase et les addons en attente quittent l'appareil
  /// (les addons installés restent).
  Future<void> forget() => _locked(() async {
    await _secrets.delete(AddonSyncSecretKeys.passphrase);
    await _secrets.delete(AddonSyncSecretKeys.carry);
  });

  // --- envoi -------------------------------------------------------------

  /// Contenu de `addons/all` à envoyer, ou nul s'il ne doit pas l'être
  /// maintenant (pas de phrase, blob distant pas encore lu, trop gros).
  Future<SyncItem?> snapshot(int seq) => _locked(() async {
    if (await _get(_kReset) == '1') {
      return const SyncItem(
        kind: SyncKind.addons,
        key: SyncKind.addonsKey,
        deleted: true,
      );
    }
    final pass = await passphrase();
    if (pass == null || await _get(_kReady) != '1') return null;
    if (await _get(_kTooLarge) == '$seq') return null;
    final entries = await _entries();
    final gen = await _gen() + 1;
    if (gen > _maxGen) return null; // compteur épuisé : plus d'envoi
    final device = await _deviceId();
    var removed = await _removedFor(entries);
    String build() => jsonEncode({
      'v': 1,
      'gen': gen,
      'device': device,
      'entries': [for (final e in entries) e.toJson()],
      'removed': [
        for (final t in removed) {'h': t.hash, 't': t.at},
      ],
    });
    var plain = build();
    // Les plus anciennes suppressions cèdent la place avant de déclarer le
    // blob trop gros.
    while (utf8.encode(plain).length > _maxPlainBytes && removed.isNotEmpty) {
      removed = removed.sublist(0, removed.length - 1);
      plain = build();
    }
    if (utf8.encode(plain).length > _maxPlainBytes) {
      return _tooLarge(seq);
    }
    await _set(_kRemoved, jsonEncode([for (final t in removed) t.toJson()]));
    final sealed = await _seal(plain, pass);
    final payload = {'blob': sealed};
    if (utf8.encode(jsonEncode(payload)).length > SyncLimits.maxPayloadBytes) {
      return _tooLarge(seq);
    }
    final hashes = {
      for (final e in entries)
        if (e.hash != null) e.hash!,
    };
    await _set(
      _kSnapshot,
      jsonEncode({
        'seq': seq,
        'gen': gen,
        'hashes': hashes.toList(),
        'blob': sealed,
      }),
    );
    return SyncItem(
      kind: SyncKind.addons,
      key: SyncKind.addonsKey,
      payload: payload,
    );
  });

  Future<SyncItem?> _tooLarge(int seq) async {
    await _set(_kTooLarge, '$seq');
    await _set(_kStatus, 'toolarge');
    return null;
  }

  /// L'élément envoyé pour [seq] est parti : ses adresses deviennent
  /// l'« origine » (ce qui peut être supprimé si un autre appareil l'enlève).
  Future<void> acknowledged(int seq, {required bool deleted}) =>
      _locked(() async {
        if (deleted) {
          if (await _get(_kReset) == '1') {
            await _del(_kReset);
            await _del(_kRemote);
            await _del(_kRemoteNew);
            await _del(_kOrigin);
            await _del(_kReady);
            await _del(_kStatus);
            await _del(_kChanging);
            await _secrets.delete(AddonSyncSecretKeys.carry);
          }
          return;
        }
        final raw = await _get(_kSnapshot);
        if (raw == null) return;
        try {
          final j = jsonDecode(raw) as Map;
          if (j['seq'] == seq) {
            await _set(_kOrigin, jsonEncode(j['hashes']));
            final g = j['gen'];
            if (g is int && g > await _gen()) await _set(_kGen, '$g');
            await _del(_kChanging);
            if (await _get(_kStatus) == 'toolarge') await _del(_kStatus);
          }
        } on Object {
          // Origine inconnue : aucune suppression distante ne sera appliquée.
        }
      });

  // --- réception ---------------------------------------------------------

  /// Met de côté l'élément `addons/all` reçu (rien n'est déchiffré ici).
  Future<void> recordRemote(SyncItem i) async {
    if (i.kind != SyncKind.addons || i.key != SyncKind.addonsKey) return;
    if (i.deleted) {
      await _set(_kRemote, jsonEncode({'deleted': true}));
    } else {
      final p = i.payload;
      final blob = p?['blob'];
      if (p == null ||
          !isSealedAddonsPayload(p) ||
          (blob as String).length > 2 * SyncLimits.maxPayloadBytes) {
        return;
      }
      await _set(_kRemote, jsonEncode({'deleted': false, 'blob': blob}));
      // Notre propre envoi qui revient : rien à déchiffrer ni à appliquer.
      if (await _lastPushedBlob() == blob) return;
    }
    await _set(_kRemoteNew, '1');
  }

  Future<String?> _lastPushedBlob() async {
    final raw = await _get(_kSnapshot);
    if (raw == null) return null;
    try {
      final b = (jsonDecode(raw) as Map)['blob'];
      return b is String ? b : null;
    } on Object {
      return null;
    }
  }

  /// Un tirage complet a eu lieu : l'absence de blob distant est fiable.
  Future<void> markPulled() => _set(_kPulled, '1');

  Future<AddonProcessResult> process() => _locked(_process);

  Future<AddonProcessResult> _process() async {
    if (await _get(_kReset) == '1') return const AddonProcessResult();
    final pass = await passphrase();
    if (pass == null || await _get(_kPulled) != '1') {
      return const AddonProcessResult();
    }
    final ready = await _get(_kReady) == '1';
    final fresh = await _get(_kRemoteNew) == '1';
    if (ready && !fresh) return _retryCarry();

    // Contenu distant : aucun / pierre tombale / blob.
    _Plain? remote; // nul = pas de blob
    final rawRemote = await _get(_kRemote);
    Map<String, Object?>? r;
    if (rawRemote != null) {
      try {
        final d = jsonDecode(rawRemote);
        if (d is Map<String, Object?>) r = d;
      } on FormatException {
        r = null;
      }
    }
    if (r != null && r['deleted'] == true && ready) {
      // Un autre appareil a réinitialisé : ce n'est pas à nous de renvoyer
      // nos addons avec une phrase qui n'a plus cours. Phrase oubliée, plus
      // aucun envoi avant une nouvelle saisie.
      await _secrets.delete(AddonSyncSecretKeys.passphrase);
      await _del(_kReady);
      await _del(_kRemoteNew);
      await _del(_kChanging);
      await _set(_kStatus, 'reset');
      return const AddonProcessResult();
    }
    if (r != null && r['deleted'] != true && r['blob'] is String) {
      try {
        final plain = await _open(r['blob']! as String, pass);
        remote = _parsePlain(plain);
      } on WrongPassphraseException {
        await _del(_kRemoteNew);
        if (await _get(_kChanging) == '1') {
          // Blob de l'ancienne phrase arrivé pendant le changement : sans
          // effet, le nouvel envoi (déjà en file) le remplacera.
          return AddonProcessResult(needsPush: await _queued());
        }
        await _del(_kReady);
        await _set(_kStatus, 'wrong');
        return const AddonProcessResult();
      }
      if (remote == null) {
        // Déchiffré mais illisible : on n'y touche pas (ni suppression ni envoi).
        await _del(_kRemoteNew);
        await _del(_kReady);
        await _set(_kStatus, 'wrong');
        return const AddonProcessResult();
      }
    }
    await _set(_kReady, '1');
    await _del(_kRemoteNew);
    if (await _get(_kStatus) == 'wrong') await _del(_kStatus);

    if (remote != null) {
      final stored = await _gen();
      final mine = await _deviceId();
      if (remote.gen < stored ||
          (remote.gen == stored && remote.device == mine)) {
        // Blob plus ancien (rejeu, appareil en retard) ou le nôtre qui
        // revient : rien n'est appliqué, surtout aucune suppression. Un blob
        // plus ancien que notre état est remplacé par un envoi à jour.
        if (remote.gen < stored) await _enqueue();
        return AddonProcessResult(needsPush: await _queued());
      }
      if (remote.gen > stored) await _set(_kGen, '${remote.gen}');
    }

    final changed = await _merge(remote);
    return AddonProcessResult(
      needsPush: await _queued(),
      changedLocal: changed,
    );
  }

  /// Applique [remote] (nul = aucun blob) aux addons locaux. Un addon n'est
  /// supprimé que par une suppression explicite du blob, jamais parce qu'il
  /// y manque.
  Future<bool> _merge(_Plain? remote) async {
    var changed = false;
    final entries = remote?.entries ?? const <_Entry>[];
    final byHash = {for (final e in entries) e.hash!: e};
    final origin = await _origin();
    final gone = {
      for (final t in remote?.removed ?? const <_Tombstone>[]) t.hash,
    };

    // 1. Supprimés ailleurs, explicitement : seulement ceux qui venaient du
    // blob.
    if (gone.isNotEmpty) {
      for (final row in await _rows()) {
        if (origin.contains(row.urlHash) &&
            !byHash.containsKey(row.urlHash) &&
            gone.contains(_short(row.urlHash))) {
          await _repo.remove(row.id);
          changed = true;
        }
      }
    }
    if (remote != null) {
      // Les suppressions connues suivent, sans ce qui est de nouveau présent.
      final merged = <String, _Tombstone>{
        for (final t in await _loadRemoved()) t.hash: t,
      };
      for (final t in remote.removed) {
        final old = merged[t.hash];
        if (old == null || old.at < t.at) merged[t.hash] = t;
      }
      for (final h in byHash.keys) {
        merged.remove(_short(h));
      }
      await _set(
        _kRemoved,
        jsonEncode([for (final t in _prune(merged.values)) t.toJson()]),
      );
    }

    // 2. Activation des addons déjà présents.
    for (final row in await _rows()) {
      final e = byHash[row.urlHash];
      if (e != null && e.enabled != row.enabled) {
        await _repo.setEnabled(row.id, e.enabled);
        changed = true;
      }
    }

    // 3. Installation des manquants, par le chemin normal.
    final have = {for (final row in await _rows()) row.urlHash};
    final missing = [
      for (final e in entries)
        if (!have.contains(e.hash)) e,
    ]..sort((a, b) => a.position.compareTo(b.position));
    final carry = <_Carry>[];
    for (final e in missing) {
      final res = await _tryInstall(e);
      if (res == null) {
        changed = true;
      } else {
        carry.add(res);
      }
    }
    await _saveCarry(carry);
    if (carry.any((c) => c.kind == _CarryKind.failed)) {
      await _set(_kRetryAt, '${_now().add(retryDelay).millisecondsSinceEpoch}');
    } else {
      await _del(_kRetryAt);
    }

    // 4. Même ordre relatif que le blob pour les addons venus de lui.
    if (remote != null && await _reorder(byHash)) changed = true;

    // 5. Ce qui n'est que local doit être envoyé.
    await _set(_kOrigin, jsonEncode(byHash.keys.toList()));
    final after = await _rows();
    if (after.any((r) => !byHash.containsKey(r.urlHash))) await _enqueue();
    return changed;
  }

  /// Installe [e] ; renvoie nul en cas de succès (ou d'addon déjà présent),
  /// sinon l'entrée à garder.
  Future<_Carry?> _tryInstall(_Entry e, {bool allowPrivate = false}) async {
    try {
      final a = await _repo.install(e.url, allowPrivate: allowPrivate);
      if (!e.enabled) await _repo.setEnabled(a.id, false);
      return null;
    } on DuplicateAddonException {
      return null;
    } on PrivateAddressException {
      return _Carry(e, _CarryKind.private);
    } on AddonException catch (x) {
      final permanent =
          x.code == AddonErrorCode.invalidAddress ||
          x.code == AddonErrorCode.addressRefused;
      return _Carry(e, permanent ? _CarryKind.refused : _CarryKind.failed);
    } on Object {
      return _Carry(e, _CarryKind.failed);
    }
  }

  Future<bool> _reorder(Map<String, _Entry> byHash) async {
    final rows = await _rows();
    final synced = [
      for (final r in rows)
        if (byHash.containsKey(r.urlHash)) r,
    ];
    if (synced.length < 2) return false;
    final wanted = [...synced]
      ..sort((a, b) {
        final c = byHash[a.urlHash]!.position.compareTo(
          byHash[b.urlHash]!.position,
        );
        return c != 0 ? c : a.urlHash.compareTo(b.urlHash);
      });
    if (List.generate(
      synced.length,
      (i) => synced[i].id == wanted[i].id,
    ).every((b) => b)) {
      return false;
    }
    final ids = [for (final r in rows) r.id];
    final slots = [
      for (var i = 0; i < rows.length; i++)
        if (byHash.containsKey(rows[i].urlHash)) i,
    ];
    for (var k = 0; k < slots.length; k++) {
      ids[slots[k]] = wanted[k].id;
    }
    await _repo.reorder(ids);
    return true;
  }

  /// Nouvel essai (au plus toutes les [retryDelay]) des addons en échec.
  Future<AddonProcessResult> _retryCarry() async {
    final carry = await _loadCarry();
    if (!carry.any((c) => c.kind == _CarryKind.failed)) {
      return const AddonProcessResult();
    }
    final at = int.tryParse(await _get(_kRetryAt) ?? '') ?? 0;
    if (_now().millisecondsSinceEpoch < at) return const AddonProcessResult();
    var changed = false;
    final next = <_Carry>[];
    for (final c in carry) {
      if (c.kind != _CarryKind.failed) {
        next.add(c);
        continue;
      }
      final res = await _tryInstall(c.entry);
      if (res == null) {
        changed = true;
      } else {
        next.add(res);
      }
    }
    await _saveCarry(next);
    if (next.any((c) => c.kind == _CarryKind.failed)) {
      await _set(_kRetryAt, '${_now().add(retryDelay).millisecondsSinceEpoch}');
    } else {
      await _del(_kRetryAt);
    }
    return AddonProcessResult(
      needsPush: await _queued(),
      changedLocal: changed,
    );
  }

  // --- confirmation des adresses locales ---------------------------------

  /// L'utilisateur confirme l'addon [hash] (adresse locale) : installé avec
  /// `allowPrivate`, par le chemin normal. Renvoie vrai si c'est fait.
  Future<bool> installPending(String hash) => _locked(() async {
    final carry = await _loadCarry();
    final target = carry
        .where((c) => c.kind == _CarryKind.private && c.entry.hash == hash)
        .firstOrNull;
    if (target == null) return false;
    final res = await _tryInstall(target.entry, allowPrivate: true);
    final next = [
      for (final c in carry)
        if (!identical(c, target)) c,
      ?res,
    ];
    await _saveCarry(next);
    return res == null;
  });

  /// L'utilisateur renonce à l'addon [hash] : il ne sera plus renvoyé.
  Future<void> dismissPending(String hash) => _locked(() async {
    final carry = await _loadCarry();
    final next = [
      for (final c in carry)
        if (!(c.kind == _CarryKind.private && c.entry.hash == hash)) c,
    ];
    if (next.length == carry.length) return;
    await _saveCarry(next);
    if (await _get(_kReady) == '1') await _enqueue();
  });

  // --- état --------------------------------------------------------------

  Future<AddonSyncState> state() async {
    if (await _get(_kReset) == '1') {
      return const AddonSyncState(AddonSyncStatus.resetting);
    }
    if (await passphrase() == null) {
      return AddonSyncState(
        await _get(_kStatus) == 'reset'
            ? AddonSyncStatus.phraseReset
            : AddonSyncStatus.noPassphrase,
      );
    }
    final carry = await _loadCarry();
    final pending = [
      for (final c in carry)
        if (c.kind == _CarryKind.private)
          PendingPrivateAddon(c.entry.hash!, redactUrl(c.entry.url)),
    ];
    final failed = carry.where((c) => c.kind == _CarryKind.failed).length;
    final status = await _get(_kStatus);
    final s = status == 'wrong'
        ? AddonSyncStatus.wrongPassphrase
        : status == 'toolarge'
        ? AddonSyncStatus.tooLarge
        : await _get(_kReady) == '1'
        ? AddonSyncStatus.ready
        : AddonSyncStatus.waiting;
    return AddonSyncState(s, pendingPrivate: pending, failed: failed);
  }

  // --- génération, appareil, suppressions -------------------------------

  Future<int> _gen() async => int.tryParse(await _get(_kGen) ?? '') ?? 0;

  Future<String> _deviceId() async {
    var id = await _get(_kDevice);
    if (id == null) {
      final r = Random.secure();
      id = [
        for (var i = 0; i < 8; i++)
          r.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ].join();
      await _set(_kDevice, id);
    }
    return id;
  }

  String _short(String hash) => hash.length > _tombstoneHashLength
      ? hash.substring(0, _tombstoneHashLength)
      : hash;

  Future<List<_Tombstone>> _loadRemoved() async {
    final raw = await _get(_kRemoved);
    if (raw == null) return [];
    try {
      return [for (final j in jsonDecode(raw) as List) ?_Tombstone.fromJson(j)];
    } on Object {
      return [];
    }
  }

  /// Plus récentes d'abord, 90 jours et 100 au plus.
  List<_Tombstone> _prune(Iterable<_Tombstone> all) {
    final limit =
        _now().subtract(_tombstoneMaxAge).millisecondsSinceEpoch ~/ 1000;
    final out = [
      for (final t in all)
        if (t.at >= limit) t,
    ]..sort((a, b) => b.at.compareTo(a.at));
    return out.length > _tombstoneMax ? out.sublist(0, _tombstoneMax) : out;
  }

  /// Suppressions à publier : celles déjà connues, plus les addons venus du
  /// dernier blob qui ne sont plus là (supprimés ici), sans ceux qui sont
  /// de nouveau présents.
  Future<List<_Tombstone>> _removedFor(List<_Entry> entries) async {
    final present = {for (final e in entries) _short(e.hash!)};
    final now = _now().millisecondsSinceEpoch ~/ 1000;
    final all = <String, _Tombstone>{
      for (final t in await _loadRemoved()) t.hash: t,
    };
    for (final h in await _origin()) {
      final k = _short(h);
      if (!present.contains(k)) all.putIfAbsent(k, () => _Tombstone(k, now));
    }
    for (final k in present) {
      all.remove(k);
    }
    return _prune(all.values);
  }

  // --- données locales ---------------------------------------------------

  Future<List<Addon>> _rows() =>
      (_db.select(_db.addons)
            ..where((a) => a.profileScope.equals(_repo.profileScope))
            ..orderBy([(a) => OrderingTerm.asc(a.position)]))
          .get();

  Future<Set<String>> _origin() async {
    final raw = await _get(_kOrigin);
    if (raw == null) return {};
    try {
      return {...(jsonDecode(raw) as List).whereType<String>()};
    } on Object {
      return {};
    }
  }

  /// Addons locaux (adresse relue du SecretStore) puis ceux en attente.
  Future<List<_Entry>> _entries() async {
    final out = <_Entry>[];
    var pos = 0;
    for (final row in await _rows()) {
      final raw = await _secrets.read(row.secretKey);
      if (raw == null) continue;
      try {
        final j = jsonDecode(raw);
        if (j is! Map || j['url'] is! String) continue;
        final logo = j['logo'];
        out.add(
          _Entry(
            j['url'] as String,
            logo is String ? logo : null,
            row.enabled,
            pos++,
            row.urlHash,
          ),
        );
      } on FormatException {
        continue;
      }
    }
    final have = {for (final e in out) e.hash};
    for (final c in await _loadCarry()) {
      if (have.contains(c.entry.hash)) continue;
      out.add(c.entry.withPosition(pos++));
    }
    return out;
  }

  /// Contenu d'un blob déchiffré ; nul s'il n'a pas la forme prévue.
  _Plain? _parsePlain(String plain) {
    final Object? j;
    try {
      j = jsonDecode(plain);
    } on FormatException {
      return null;
    }
    if (j is! Map || j['v'] != 1) return null;
    final gen = j['gen'];
    final device = j['device'];
    final list = j['entries'];
    final rem = j['removed'];
    if (gen is! int ||
        gen < 0 ||
        gen > _maxGen ||
        device is! String ||
        device.length > 64 ||
        list is! List ||
        list.length > _maxEntries ||
        rem is! List ||
        rem.length > 1000) {
      return null;
    }
    final out = <_Entry>[];
    final seen = <String>{};
    for (var i = 0; i < list.length; i++) {
      final e = _Entry.fromJson(list[i], i);
      if (e == null) continue;
      if (seen.add(e.hash!)) out.add(e);
    }
    return _Plain(gen, device, out, [
      for (final t in rem) ?_Tombstone.fromJson(t),
    ]);
  }

  Future<List<_Carry>> _loadCarry() async {
    final raw = await _secrets.read(AddonSyncSecretKeys.carry);
    if (raw == null) return [];
    try {
      final j = jsonDecode(raw);
      if (j is! List) return [];
      return [for (final e in j) ?_Carry.fromJson(e)];
    } on FormatException {
      return [];
    }
  }

  Future<void> _saveCarry(List<_Carry> carry) async {
    if (carry.isEmpty) {
      await _secrets.delete(AddonSyncSecretKeys.carry);
    } else {
      await _secrets.write(
        AddonSyncSecretKeys.carry,
        jsonEncode([for (final c in carry) c.toJson()]),
      );
    }
  }
}

class _Plain {
  _Plain(this.gen, this.device, this.entries, this.removed);
  final int gen;
  final String device;
  final List<_Entry> entries;
  final List<_Tombstone> removed;
}

/// Suppression explicite : préfixe d'empreinte et date (secondes).
class _Tombstone {
  _Tombstone(this.hash, this.at);
  final String hash;
  final int at;

  Map<String, Object?> toJson() => {'h': hash, 't': at};

  static _Tombstone? fromJson(Object? j) {
    if (j is! Map) return null;
    final h = j['h'];
    final t = j['t'];
    if (h is! String || h.isEmpty || h.length > 64 || t is! num) return null;
    return _Tombstone(h, t.toInt());
  }
}

class _Entry {
  _Entry(this.url, this.logo, this.enabled, this.position, this.hash);

  final String url;
  final String? logo;
  final bool enabled;
  final int position;
  final String? hash;

  _Entry withPosition(int p) => _Entry(url, logo, enabled, p, hash);

  Map<String, Object?> toJson() => {
    'url': url,
    'logo': logo,
    'enabled': enabled,
    'position': position,
  };

  /// Entrée d'un blob (contenu non fiable même déchiffré) ; nulle si l'adresse
  /// n'est pas une adresse d'addon valide.
  static _Entry? fromJson(Object? j, int index) {
    if (j is! Map) return null;
    final url = j['url'];
    if (url is! String || url.isEmpty || url.length > AddonSync._maxUrlLength) {
      return null;
    }
    final String hash;
    try {
      hash = AddonRepository.urlHashOf(url);
    } on FormatException {
      return null;
    }
    final logo = j['logo'];
    final pos = j['position'];
    return _Entry(
      url,
      logo is String && logo.length <= AddonSync._maxUrlLength ? logo : null,
      j['enabled'] != false,
      pos is num ? pos.toInt() : index,
      hash,
    );
  }
}

enum _CarryKind { private, failed, refused }

class _Carry {
  _Carry(this.entry, this.kind);
  final _Entry entry;
  final _CarryKind kind;

  Map<String, Object?> toJson() => {...entry.toJson(), 'kind': kind.name};

  static _Carry? fromJson(Object? j) {
    final e = _Entry.fromJson(j, 0);
    if (e == null || j is! Map) return null;
    final kind = _CarryKind.values.where((k) => k.name == j['kind']);
    return _Carry(e, kind.isEmpty ? _CarryKind.failed : kind.first);
  }
}
