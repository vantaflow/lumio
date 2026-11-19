import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/secret_store.dart';
import 'package:lumio_core/lumio_core.dart';

/// Cette URL normalisée est déjà installée.
class DuplicateAddonException extends AddonException {
  const DuplicateAddonException()
    : super('Cet addon est déjà installé', code: AddonErrorCode.duplicate);
}

/// L'adresse désigne l'appareil ou le réseau local : l'installation demande
/// une confirmation explicite (`allowPrivate: true`).
class PrivateAddressException extends AddonException {
  const PrivateAddressException({super.cause})
    : super(
        'Cette adresse pointe vers votre réseau local',
        code: AddonErrorCode.privateAddress,
      );
}

/// Addon installé. L'URL n'y figure pas : voir [AddonRepository.urlOf].
///
/// [manifest] est nul si l'addon est [broken] (manifeste illisible ou secret
/// manquant) : l'utilisateur peut alors seulement le supprimer.
/// `manifest.transportUrl` vient du `SecretStore` ; ne jamais l'afficher ni le
/// journaliser (utiliser `redactUrl`).
class InstalledAddon {
  const InstalledAddon({
    required this.id,
    required this.manifest,
    required this.position,
    required this.enabled,
    this.logo,
  });

  final String id;
  final AddonManifest? manifest;
  final int position;
  final bool enabled;

  /// Logo (URL stockée dans le SecretStore, jamais dans SQLite).
  final Uri? logo;

  bool get broken => manifest == null;
  String get name => manifest?.name ?? id;
}

typedef AddonClientFactory = AddonClient Function({required bool allowPrivate});

AddonClient defaultAddonClient({required bool allowPrivate}) => AddonClient(
  IoHttpFetcher(
    connectionFactory: guardedConnectionFactory(allowPrivate: allowPrivate),
    redirectGuard: (u) => UrlGuard.check(u, allowPrivate: allowPrivate),
  ),
  allowPrivate: allowPrivate,
);

/// Installation et gestion des addons (stories 1.1 et 1.6).
class AddonRepository {
  AddonRepository(
    this._db,
    this._secrets, {
    AddonClientFactory clientFactory = defaultAddonClient,
    this.profileScope = 'default',
  }) : _clientFactory = clientFactory;

  final AppDatabase _db;
  final SecretStore _secrets;
  final AddonClientFactory _clientFactory;
  final String profileScope;

  static String secretKeyFor(String id) => 'addon_url:$id';

  /// Récupère et valide le manifeste sans rien enregistrer (aperçu).
  ///
  /// Lève [PrivateAddressException] si l'adresse est locale et
  /// [allowPrivate] faux, [AddonException] sinon (message français).
  Future<AddonManifest> preview(
    String rawUrl, {
    bool allowPrivate = false,
  }) async {
    final url = _normalize(rawUrl);
    _guard(url, allowPrivate);
    return _clientFactory(allowPrivate: allowPrivate).fetchManifest(url);
  }

  Future<InstalledAddon> install(
    String rawUrl, {
    bool allowPrivate = false,
  }) async {
    final url = _normalize(rawUrl);
    final hash = _hash(url);
    if (await _hashExists(hash)) throw const DuplicateAddonException();
    _guard(url, allowPrivate);
    final manifest = await _clientFactory(
      allowPrivate: allowPrivate,
    ).fetchManifest(url);

    return _db.transaction(() async {
      // Revérifie après l'attente réseau (installation concurrente).
      if (await _hashExists(hash)) throw const DuplicateAddonException();
      final id = await _freeId(manifest.id, hash);
      final maxPos = _db.addons.position.max();
      final row = await (_db.selectOnly(
        _db.addons,
      )..addColumns([maxPos])).getSingle();
      final position = (row.read(maxPos) ?? -1) + 1;
      final secretKey = secretKeyFor(id);
      await _db
          .into(_db.addons)
          .insert(
            AddonsCompanion.insert(
              id: id,
              profileScope: Value(profileScope),
              position: position,
              manifestJson: jsonEncode(manifestToJson(manifest)),
              secretKey: secretKey,
              urlHash: hash,
            ),
          );
      try {
        await _secrets.write(
          secretKey,
          jsonEncode({
            'url': url.toString(),
            'logo': manifest.logo?.toString(),
          }),
        );
      } catch (_) {
        // L'exception annule la transaction (pas de ligne orpheline) ; on
        // nettoie aussi une écriture partielle du secret.
        try {
          await _secrets.delete(secretKey);
        } catch (_) {}
        rethrow;
      }
      return InstalledAddon(
        id: id,
        manifest: manifest,
        position: position,
        enabled: true,
        logo: manifest.logo,
      );
    });
  }

  /// Addons installés, par priorité. [enabledOnly] écarte les addons
  /// désactivés : c'est la liste à utiliser pour toute requête réseau.
  Future<List<InstalledAddon>> list({bool enabledOnly = false}) async {
    final rows =
        await (_db.select(_db.addons)
              ..where(
                (a) =>
                    a.profileScope.equals(profileScope) &
                    (enabledOnly
                        ? a.enabled.equals(true)
                        : const Constant(true)),
              )
              ..orderBy([(a) => OrderingTerm.asc(a.position)]))
            .get();
    final out = <InstalledAddon>[];
    for (final r in rows) {
      out.add(await _toInstalled(r));
    }
    return out;
  }

  /// URL (secrète) d'un addon installé, pour construire des requêtes.
  Future<Uri> urlOf(String id) async {
    final url = (await _readSecret(secretKeyFor(id)))?.url;
    if (url == null) {
      throw const AddonException(
        'URL de l\'addon introuvable',
        code: AddonErrorCode.notFound,
      );
    }
    return url;
  }

  /// Addon déjà installé qui est le MÊME addon que [manifest] (même hôte et
  /// même identifiant de manifest) mais avec une autre adresse (réglages
  /// différents) : l'installer en plus créerait un doublon. `null` sinon.
  Future<InstalledAddon?> findSameAddon(
    String rawUrl,
    AddonManifest manifest,
  ) async {
    final url = _normalize(rawUrl);
    for (final a in await list()) {
      final m = a.manifest;
      if (m == null || m.id != manifest.id) continue;
      final Uri other;
      try {
        other = await urlOf(a.id);
      } on AddonException {
        continue;
      }
      if (other.host == url.host && other.port == url.port) return a;
    }
    return null;
  }

  /// Installe [rawUrl] à la place de l'addon [oldId] (même rang dans la
  /// liste) ; l'ancien n'est retiré qu'une fois le nouveau installé.
  Future<InstalledAddon> installReplacing(
    String rawUrl,
    String oldId, {
    bool allowPrivate = false,
  }) async {
    final before = [for (final a in await list()) a.id];
    final added = await install(rawUrl, allowPrivate: allowPrivate);
    final order = [
      for (final id in before)
        if (id == oldId) added.id else id,
    ];
    await remove(oldId);
    await reorder(order);
    return added;
  }

  /// Vrai si cette adresse (normalisée) est déjà installée.
  Future<bool> isInstalled(String rawUrl) =>
      _hashExists(_hash(_normalize(rawUrl)));

  /// Supprime d'abord le secret : en cas d'échec ensuite, la ligne reste
  /// (visible, `broken`) et la suppression peut être relancée ; jamais de
  /// secret orphelin.
  Future<void> remove(String id) async {
    await _secrets.delete(secretKeyFor(id));
    await (_db.delete(_db.addons)..where((a) => a.id.equals(id))).go();
  }

  /// Applique l'ordre de [ids] (premier = priorité maximale). Les addons non
  /// cités gardent leur ordre relatif, après ceux cités.
  Future<void> reorder(List<String> ids) async {
    await _db.transaction(() async {
      final current = await list();
      final rest = [
        for (final a in current)
          if (!ids.contains(a.id)) a.id,
      ];
      final known = current.map((a) => a.id).toSet();
      final order = [
        for (final id in ids)
          if (known.contains(id)) id,
        ...rest,
      ];
      for (var i = 0; i < order.length; i++) {
        await (_db.update(_db.addons)..where((a) => a.id.equals(order[i])))
            .write(AddonsCompanion(position: Value(i)));
      }
    });
  }

  Future<void> setEnabled(String id, bool on) => (_db.update(
    _db.addons,
  )..where((a) => a.id.equals(id))).write(AddonsCompanion(enabled: Value(on)));

  // --- interne ---

  Uri _normalize(String rawUrl) {
    try {
      return normalizeAddonUrl(rawUrl);
    } on FormatException catch (e) {
      throw AddonException(
        'Adresse invalide : ${e.message}',
        cause: e,
        code: AddonErrorCode.invalidAddress,
      );
    }
  }

  void _guard(Uri url, bool allowPrivate) {
    try {
      UrlGuard.check(url, allowPrivate: allowPrivate);
    } on UnsafeUrlException catch (e) {
      if (e.code == UnsafeUrlReason.privateAddress) {
        throw PrivateAddressException(cause: e);
      }
      throw AddonException(
        'Adresse refusée : ${e.reason}',
        cause: e,
        code: AddonErrorCode.addressRefused,
      );
    }
  }

  /// Empreinte d'une adresse (normalisée) : sert à reconnaître le même addon
  /// d'un appareil à l'autre. Lève [FormatException] si l'adresse est invalide.
  static String urlHashOf(String rawUrl) => _hash(normalizeAddonUrl(rawUrl));

  static String _hash(Uri normalized) =>
      sha256.convert(utf8.encode(normalized.toString())).toString();

  Future<bool> _hashExists(String hash) async {
    final row =
        await (_db.select(_db.addons)
              ..where(
                (a) =>
                    a.profileScope.equals(profileScope) &
                    a.urlHash.equals(hash),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  Future<String> _freeId(String manifestId, String hash) async {
    final taken = await (_db.select(
      _db.addons,
    )..where((a) => a.id.equals(manifestId))).getSingleOrNull();
    return taken == null ? manifestId : '$manifestId#${hash.substring(0, 8)}';
  }

  Future<({Uri url, Uri? logo})?> _readSecret(String key) async {
    final raw = await _secrets.read(key);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return null;
      final url = Uri.tryParse('${j['url']}');
      if (url == null || !url.hasScheme || url.host.isEmpty) return null;
      final logoRaw = j['logo'];
      return (url: url, logo: logoRaw is String ? Uri.tryParse(logoRaw) : null);
    } on FormatException {
      return null;
    }
  }

  Future<InstalledAddon> _toInstalled(Addon r) async {
    InstalledAddon broken() => InstalledAddon(
      id: r.id,
      manifest: null,
      position: r.position,
      enabled: r.enabled,
    );
    final secret = await _readSecret(r.secretKey);
    if (secret == null) return broken();
    try {
      final json = jsonDecode(r.manifestJson);
      if (json is Map && secret.logo != null) {
        json['logo'] = secret.logo.toString();
      }
      return InstalledAddon(
        id: r.id,
        manifest: AddonManifest.fromJson(json, secret.url),
        position: r.position,
        enabled: r.enabled,
        logo: secret.logo,
      );
    } on FormatException {
      return broken();
    } on ManifestException {
      return broken();
    }
  }

  /// Sérialisation du manifeste SANS `transportUrl` ni `logo` (URL secrètes,
  /// stockées dans le SecretStore).
  static Map<String, Object?> manifestToJson(AddonManifest m) => {
    'id': m.id,
    'version': m.version,
    'name': m.name,
    'description': ?m.description,
    'types': m.types,
    'resources': [
      for (final r in m.resources)
        {'name': r.name, 'types': ?r.types, 'idPrefixes': ?r.idPrefixes},
    ],
    'catalogs': [
      for (final c in m.catalogs)
        {
          'type': c.type,
          'id': c.id,
          'name': c.name,
          'extra': [
            for (final e in c.extra)
              {
                'name': e.name,
                'isRequired': e.isRequired,
                'options': ?e.options,
              },
          ],
        },
    ],
    'idPrefixes': ?m.idPrefixes,
  };
}
