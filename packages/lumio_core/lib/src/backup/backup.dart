import 'dart:convert';

import '../addons/addon_url.dart';
import '../crypto/secret_box.dart';
import '../playback/title_settings.dart';
import '../profiles/content_rating.dart';
import '../sync/sync_models.dart';

/// Pourquoi un fichier de sauvegarde est refusé.
enum BackupFormatError {
  unknownFormat,
  unsupportedVersion,
  malformed,
  tooLarge,
  passphraseRequired,
}

/// Fichier de sauvegarde refusé ; [message] est lisible (français), l'interface
/// choisit son propre texte d'après [error].
class BackupFormatException implements Exception {
  const BackupFormatException(this.error);

  final BackupFormatError error;

  String get message => switch (error) {
    BackupFormatError.unknownFormat =>
      "Ce fichier n'est pas une sauvegarde Lumio.",
    BackupFormatError.unsupportedVersion =>
      'Cette sauvegarde vient d\'une version plus récente de Lumio.',
    BackupFormatError.malformed => 'Cette sauvegarde est illisible ou abîmée.',
    BackupFormatError.tooLarge => 'Cette sauvegarde est trop volumineuse.',
    BackupFormatError.passphraseRequired =>
      'Cette sauvegarde est chiffrée : une phrase secrète est nécessaire.',
  };

  @override
  String toString() => 'BackupFormatException($error)';
}

class BackupProfile {
  const BackupProfile({
    required this.id,
    required this.name,
    required this.isKid,
    required this.ageLimit,
  });

  final String id;
  final String name;
  final bool isKid;

  /// Index de `AgeLimit`.
  final int ageLimit;
}

class BackupLibraryItem {
  const BackupLibraryItem({
    required this.profileId,
    required this.itemId,
    required this.type,
    required this.meta,
    required this.addedAt,
    this.certification,
  });

  final String profileId;
  final String itemId;
  final String type;
  final Map<String, dynamic> meta;
  final int addedAt;
  final String? certification;
}

class BackupProgress {
  const BackupProgress({
    required this.profileId,
    required this.itemId,
    required this.metaId,
    required this.positionMs,
    required this.durationMs,
    required this.watched,
    required this.updatedAt,
    this.certification,
  });

  final String profileId;
  final String itemId;
  final String metaId;
  final int positionMs;
  final int durationMs;
  final bool watched;
  final int updatedAt;
  final String? certification;
}

class BackupTitleSettings {
  const BackupTitleSettings({
    required this.profileId,
    required this.metaId,
    required this.json,
  });

  final String profileId;
  final String metaId;
  final Map<String, Object?> json;
}

/// Addon d'une sauvegarde. [url] n'existe que dans un fichier chiffré : un
/// fichier ordinaire ne contient que l'identifiant et le nom.
class BackupAddon {
  const BackupAddon({required this.manifestId, required this.name, this.url});

  final String manifestId;
  final String name;
  final String? url;
}

/// Contenu d'une sauvegarde. Jamais de PIN, de verrou, de code de récupération,
/// de jeton ni de phrase secrète.
class BackupData {
  const BackupData({
    required this.createdAt,
    this.profiles = const [],
    this.library = const [],
    this.progress = const [],
    this.settings = const {},
    this.titleSettings = const [],
    this.addons = const [],
    this.skipped = 0,
  });

  final DateTime createdAt;
  final List<BackupProfile> profiles;
  final List<BackupLibraryItem> library;
  final List<BackupProgress> progress;

  /// Réglages de la liste blanche de la synchronisation, seulement.
  final Map<String, String> settings;
  final List<BackupTitleSettings> titleSettings;
  final List<BackupAddon> addons;

  /// À l'import : entrées invalides ignorées.
  final int skipped;
}

/// Sauvegarde locale : JSON versionné `{"format":"lumio-backup","version":1}`.
///
/// Sans secret par défaut. Les adresses d'addons ne sont écrites qu'avec
/// `includeSecrets`, et le fichier est alors chiffré ([SecretBox], phrase d'au
/// moins [minPassphraseLength] caractères) : elles ne sont jamais en clair.
abstract final class Backup {
  static const format = 'lumio-backup';
  static const version = 1;
  static const maxBytes = 10 * 1024 * 1024;
  static const minPassphraseLength = 12;

  /// Données associées du chiffrement : une sauvegarde ne s'ouvre pas comme un
  /// blob d'addons de la synchronisation, et réciproquement.
  static const aad = 'backup';

  static const maxProfiles = 6;
  static const maxLibrary = 20000;
  static const maxProgress = 50000;
  static const maxTitleSettings = 20000;
  static const maxSettings = 500;
  static const maxAddons = 200;

  static const _maxJson = SyncLimits.maxPayloadBytes;
  static const _maxNameLength = 40;
  static const _maxId = 200;
  static const _maxInt = 9007199254740991;
  static final _profileId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// Représentation JSON (en clair) ; avec [includeSecrets], les adresses
  /// d'addons y figurent : à ne jamais écrire telle quelle (voir [encode]).
  static Map<String, dynamic> export(
    BackupData d, {
    bool includeSecrets = false,
  }) => {
    'format': format,
    'version': version,
    'createdAt': d.createdAt.toUtc().toIso8601String(),
    'profiles': [
      for (final p in d.profiles)
        {'id': p.id, 'name': p.name, 'isKid': p.isKid, 'ageLimit': p.ageLimit},
    ],
    'library': [
      for (final i in d.library)
        {
          'profileId': i.profileId,
          'itemId': i.itemId,
          'type': i.type,
          'meta': cleanMeta(i.meta, withUrls: includeSecrets),
          'addedAt': i.addedAt,
          'certification': i.certification,
        },
    ],
    'progress': [
      for (final p in d.progress)
        {
          'profileId': p.profileId,
          'itemId': p.itemId,
          'metaId': p.metaId,
          'positionMs': p.positionMs,
          'durationMs': p.durationMs,
          'watched': p.watched,
          'updatedAt': p.updatedAt,
          'certification': p.certification,
        },
    ],
    'settings': {
      for (final e in d.settings.entries)
        if (isSyncableSettingKey(e.key) && e.value.length <= 4096)
          e.key: e.value,
    },
    'titleSettings': [
      for (final t in d.titleSettings)
        {'profileId': t.profileId, 'metaId': t.metaId, 'json': t.json},
    ],
    'addons': [
      for (final a in d.addons)
        {
          'manifestId': a.manifestId,
          'name': a.name,
          if (includeSecrets && a.url != null) 'url': a.url,
        },
    ],
  };

  /// Texte du fichier à écrire. Avec [includeSecrets] (ou une [passphrase]) le
  /// contenu est chiffré ; la phrase est alors obligatoire (≥ 12 caractères).
  static Future<String> encode(
    BackupData d, {
    bool includeSecrets = false,
    String? passphrase,
  }) async {
    final json = export(d, includeSecrets: includeSecrets);
    if (!includeSecrets && passphrase == null) return jsonEncode(json);
    if (passphrase == null || passphrase.runes.length < minPassphraseLength) {
      throw ArgumentError(
        'Une phrase secrète de $minPassphraseLength caractères au moins est '
        'obligatoire pour une sauvegarde chiffrée',
      );
    }
    final sealed = await SecretBox.seal(jsonEncode(json), passphrase, aad: aad);
    return jsonEncode({
      'format': format,
      'version': version,
      'encrypted': true,
      'data': sealed,
    });
  }

  /// Vrai si le texte est une enveloppe chiffrée (sans la déchiffrer).
  static bool isEncrypted(String text) {
    try {
      final j = jsonDecode(text);
      return j is Map && j['format'] == format && j['encrypted'] == true;
    } on FormatException {
      return false;
    }
  }

  /// Lit un fichier : taille, JSON, enveloppe chiffrée (phrase demandée), puis
  /// [import]. Lève [BackupFormatException] ou [WrongPassphraseException].
  static Future<BackupData> decode(
    List<int> bytes, {
    String? passphrase,
  }) async {
    if (bytes.length > maxBytes) {
      throw const BackupFormatException(BackupFormatError.tooLarge);
    }
    final Object? j;
    try {
      j = jsonDecode(utf8.decode(bytes));
    } on Object {
      throw const BackupFormatException(BackupFormatError.malformed);
    }
    if (j is! Map) {
      throw const BackupFormatException(BackupFormatError.malformed);
    }
    final json = Map<String, dynamic>.from(j);
    if (json['encrypted'] != true) return import(json);
    _checkHeader(json);
    final data = json['data'];
    if (data is! String) {
      throw const BackupFormatException(BackupFormatError.malformed);
    }
    if (passphrase == null) {
      throw const BackupFormatException(BackupFormatError.passphraseRequired);
    }
    final plain = await SecretBox.open(data, passphrase, aad: aad);
    if (plain.length > maxBytes) {
      throw const BackupFormatException(BackupFormatError.tooLarge);
    }
    final Object? inner;
    try {
      inner = jsonDecode(plain);
    } on Object {
      throw const BackupFormatException(BackupFormatError.malformed);
    }
    if (inner is! Map) {
      throw const BackupFormatException(BackupFormatError.malformed);
    }
    return import(Map<String, dynamic>.from(inner), allowAddonUrls: true);
  }

  static void _checkHeader(Map<String, dynamic> json) {
    if (json['format'] != format) {
      throw const BackupFormatException(BackupFormatError.unknownFormat);
    }
    final v = json['version'];
    if (v is! int) {
      throw const BackupFormatException(BackupFormatError.malformed);
    }
    if (v > version) {
      throw const BackupFormatException(BackupFormatError.unsupportedVersion);
    }
    if (v < 1) {
      throw const BackupFormatException(BackupFormatError.malformed);
    }
  }

  /// Valide strictement [json] (en clair). Les entrées invalides sont ignorées
  /// et comptées ([BackupData.skipped]) ; une structure erronée ou trop grosse
  /// refuse tout le fichier. Les adresses d'addons ne sont gardées que si
  /// [allowAddonUrls] (contenu déchiffré).
  static BackupData import(
    Map<String, dynamic> json, {
    bool allowAddonUrls = false,
    DateTime? now,
  }) {
    _checkHeader(json);
    // Une progression datée de plus d'un jour dans le futur l'emporterait pour
    // toujours : elle est ramenée à maintenant.
    final maxUpdated =
        (now ?? DateTime.now()).millisecondsSinceEpoch + 86400000;
    final clampTo = (now ?? DateTime.now()).millisecondsSinceEpoch;
    var skipped = 0;

    List<Map<String, dynamic>> list(String key, int cap) {
      final v = json[key];
      if (v == null) return const [];
      if (v is! List) {
        throw const BackupFormatException(BackupFormatError.malformed);
      }
      if (v.length > cap) {
        throw const BackupFormatException(BackupFormatError.tooLarge);
      }
      final out = <Map<String, dynamic>>[];
      for (final e in v) {
        if (e is Map) {
          out.add(Map<String, dynamic>.from(e));
        } else {
          skipped++;
        }
      }
      return out;
    }

    final profiles = <BackupProfile>[];
    for (final m in list('profiles', maxProfiles)) {
      final p = _profile(m);
      p == null ? skipped++ : profiles.add(p);
    }
    final library = <BackupLibraryItem>[];
    for (final m in list('library', maxLibrary)) {
      final i = _library(m, allowAddonUrls);
      i == null ? skipped++ : library.add(i);
    }
    final progress = <BackupProgress>[];
    for (final m in list('progress', maxProgress)) {
      final p = _progress(m, maxUpdated, clampTo);
      p == null ? skipped++ : progress.add(p);
    }
    final titleSettings = <BackupTitleSettings>[];
    for (final m in list('titleSettings', maxTitleSettings)) {
      final t = _titleSettings(m);
      t == null ? skipped++ : titleSettings.add(t);
    }
    final addons = <BackupAddon>[];
    for (final m in list('addons', maxAddons)) {
      final a = _addon(m, allowAddonUrls);
      a == null ? skipped++ : addons.add(a);
    }

    final settings = <String, String>{};
    final rawSettings = json['settings'];
    if (rawSettings != null) {
      if (rawSettings is! Map) {
        throw const BackupFormatException(BackupFormatError.malformed);
      }
      if (rawSettings.length > maxSettings) {
        throw const BackupFormatException(BackupFormatError.tooLarge);
      }
      for (final e in rawSettings.entries) {
        final k = e.key;
        final v = e.value;
        if (k is String &&
            isSyncableSettingKey(k) &&
            v is String &&
            v.length <= 4096) {
          settings[k] = v;
        } else {
          skipped++;
        }
      }
    }

    final created = json['createdAt'];
    return BackupData(
      createdAt:
          (created is String ? DateTime.tryParse(created) : null) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      profiles: profiles,
      library: library,
      progress: progress,
      settings: settings,
      titleSettings: titleSettings,
      addons: addons,
      skipped: skipped,
    );
  }

  /// Champs de `meta` écrits en clair.
  static const metaPlainFields = {
    'id',
    'type',
    'name',
    'releaseInfo',
    'certification',
    'sourceKind',
  };

  /// Reconstruit `meta` à partir d'une liste blanche (valeurs texte bornées).
  /// [withUrls] (contenu chiffré) ajoute l'affiche (http/https, avec hôte, sans
  /// identifiants) et l'addon d'origine : une affiche embarque souvent une clé.
  static Map<String, dynamic> cleanMeta(
    Map<dynamic, dynamic> raw, {
    required bool withUrls,
  }) {
    final out = <String, dynamic>{};
    for (final k in metaPlainFields) {
      final v = raw[k];
      if (v is String && v.length <= 500) out[k] = v;
    }
    if (withUrls) {
      final src = raw['sourceAddonId'];
      if (src is String && src.length <= 200) out['sourceAddonId'] = src;
      final poster = raw['poster'];
      if (poster is String && poster.length <= 2048) {
        final u = Uri.tryParse(poster);
        if (u != null &&
            (u.scheme == 'http' || u.scheme == 'https') &&
            u.host.isNotEmpty &&
            u.userInfo.isEmpty) {
          out['poster'] = poster;
        }
      }
    }
    return out;
  }

  // --- validation d'une entrée ---

  static String? _str(Object? v, int max, {bool allowEmpty = false}) {
    if (v is! String || v.length > max) return null;
    if (!allowEmpty && v.isEmpty) return null;
    return v;
  }

  static int _nat(Object? v) =>
      v is num && v.isFinite && v >= 0 && v <= _maxInt ? v.toInt() : 0;

  static bool _jsonFits(Object? v, [int max = _maxJson]) {
    try {
      return utf8.encode(jsonEncode(v)).length <= max;
    } on Object {
      return false;
    }
  }

  static BackupProfile? _profile(Map<String, dynamic> m) {
    final id = m['id'];
    if (id is! String || !_profileId.hasMatch(id)) return null;
    final rawName = m['name'];
    if (rawName is! String) return null;
    var name = rawName.trim();
    if (name.isEmpty) return null;
    if (name.length > _maxNameLength) name = name.substring(0, _maxNameLength);
    final isKid = m['isKid'] == true;
    final adult = AgeLimit.adult.index;
    final raw = m['ageLimit'];
    var age = raw is num ? raw.toInt().clamp(0, adult) : adult;
    // Un profil enfant n'a jamais la limite « adulte ».
    if (isKid && age == adult) age = AgeLimit.age12.index;
    return BackupProfile(id: id, name: name, isKid: isKid, ageLimit: age);
  }

  static BackupLibraryItem? _library(Map<String, dynamic> m, bool allowUrls) {
    final profileId = m['profileId'];
    final itemId = _str(m['itemId'], _maxId);
    final type = _str(m['type'], 64);
    if (profileId is! String ||
        !_profileId.hasMatch(profileId) ||
        itemId == null ||
        type == null) {
      return null;
    }
    final rawMeta = m['meta'];
    if (rawMeta is! Map) return null;
    // Reconstruit depuis une liste blanche : rien d'autre n'entre en base.
    final meta = cleanMeta(rawMeta, withUrls: allowUrls);
    final cert = m['certification'];
    return BackupLibraryItem(
      profileId: profileId,
      itemId: itemId,
      type: type,
      meta: meta,
      addedAt: _nat(m['addedAt']),
      certification: cert is String && cert.length <= 32 ? cert : null,
    );
  }

  static BackupProgress? _progress(
    Map<String, dynamic> m,
    int maxUpdated,
    int clampTo,
  ) {
    final profileId = m['profileId'];
    final itemId = _str(m['itemId'], _maxId);
    final updatedAt = m['updatedAt'];
    if (profileId is! String ||
        !_profileId.hasMatch(profileId) ||
        itemId == null ||
        updatedAt is! num ||
        !updatedAt.isFinite ||
        updatedAt < 0 ||
        updatedAt > _maxInt) {
      return null;
    }
    final metaId = _str(m['metaId'], _maxId, allowEmpty: true) ?? '';
    final cert = m['certification'];
    return BackupProgress(
      profileId: profileId,
      itemId: itemId,
      metaId: metaId,
      positionMs: _nat(m['positionMs']),
      durationMs: _nat(m['durationMs']),
      watched: m['watched'] == true,
      updatedAt: updatedAt > maxUpdated ? clampTo : updatedAt.toInt(),
      certification: cert is String && cert.length <= 32 ? cert : null,
    );
  }

  static BackupTitleSettings? _titleSettings(Map<String, dynamic> m) {
    final profileId = m['profileId'];
    final metaId = _str(m['metaId'], _maxId);
    final j = m['json'];
    if (profileId is! String ||
        !_profileId.hasMatch(profileId) ||
        metaId == null ||
        j is! Map ||
        !_jsonFits(j, 4096)) {
      return null;
    }
    try {
      // Types normalisés (une valeur de mauvais type n'entre jamais en base).
      final clean = TitleSettings.fromJson(
        Map<String, Object?>.from(j),
      ).toJson();
      return BackupTitleSettings(
        profileId: profileId,
        metaId: metaId,
        json: clean,
      );
    } on Object {
      return null;
    }
  }

  static BackupAddon? _addon(Map<String, dynamic> m, bool allowUrls) {
    final id = _str(m['manifestId'], 200);
    final name = _str(m['name'], 200);
    if (id == null || name == null) return null;
    String? url;
    final raw = m['url'];
    if (allowUrls && raw is String && raw.length <= 2048) {
      try {
        url = normalizeAddonUrl(raw).toString();
      } on FormatException {
        url = null;
      }
    }
    return BackupAddon(manifestId: id, name: name, url: url);
  }
}
