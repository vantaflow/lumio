import 'dart:convert';

/// Types d'éléments synchronisés. `addons` voyage sous la forme d'un unique
/// blob chiffré côté client (`addons/all`, voir `SecretBox`) : le serveur ne
/// voit jamais les adresses des addons.
abstract final class SyncKind {
  static const library = 'library';
  static const progress = 'progress';
  static const settings = 'settings';
  static const profiles = 'profiles';
  static const addons = 'addons';

  /// Types que le moteur envoie et applique.
  static const enabled = {library, progress, settings, profiles, addons};

  /// Clé de l'unique élément `addons`.
  static const addonsKey = 'all';
}

/// Un élément synchronisé. [version] est attribuée par le serveur (0 pour un
/// changement local pas encore envoyé) ; [payload] est nul pour une pierre
/// tombale ([deleted]).
class SyncItem {
  const SyncItem({
    required this.kind,
    required this.key,
    this.payload,
    this.version = 0,
    this.deleted = false,
  });

  final String kind;
  final String key;
  final Map<String, dynamic>? payload;
  final int version;
  final bool deleted;

  factory SyncItem.fromJson(Map<String, dynamic> j) {
    final p = j['payload'];
    final d = j['deleted'];
    return SyncItem(
      kind: j['kind'] as String,
      key: j['key'] as String,
      payload: p is Map ? Map<String, dynamic>.from(p) : null,
      version: (j['version'] as num?)?.toInt() ?? 0,
      deleted: d == true || d == 1,
    );
  }

  Map<String, dynamic> toPushJson() => {
    'kind': kind,
    'key': key,
    'payload': deleted ? null : payload,
    'deleted': deleted,
    'baseVersion': version,
  };

  @override
  String toString() => 'SyncItem($kind, $key, v$version, deleted: $deleted)';
}

/// Changement local en attente d'envoi. [seq] identifie l'état exact envoyé :
/// une modification survenue pendant l'envoi reçoit un autre [seq] et reste en
/// attente.
class PendingChange {
  const PendingChange(this.item, this.seq);

  final SyncItem item;
  final int seq;
}

/// Une page de réponse du serveur.
class SyncPage {
  const SyncPage({
    required this.items,
    required this.version,
    required this.more,
  });

  final List<SyncItem> items;
  final int version;
  final bool more;
}

/// Limites du protocole (identiques côté serveur).
abstract final class SyncLimits {
  static const maxItemsPerRequest = 500;
  static const maxBodyBytes = 256 * 1024;

  /// Marge sous les 256 Ko du serveur (enveloppe JSON, accents).
  static const targetBodyBytes = 200 * 1024;
  static const maxPayloadBytes = 16 * 1024;
  static const maxKeyLength = 256;
}

final _settingsKeyRe = RegExp(
  r'^(ui_locale|(home_layout|stream_prefs|subtitle_lang):[A-Za-z0-9_-]{1,64})$',
);

/// Réglages autorisés à voyager : disposition de l'accueil, préférences de
/// flux, langue de sous-titres et langue de l'interface. Tout le reste (PIN,
/// verrou, code de récupération, profil actif…) reste sur l'appareil.
bool isSyncableSettingKey(String key) => _settingsKeyRe.hasMatch(key);

/// Champs d'un profil qui peuvent voyager (jamais de données de PIN).
const syncableProfileFields = {'name', 'isKid', 'ageLimit'};

/// Vrai si [item] peut être envoyé : type activé, clé et contenu conformes.
/// Un élément refusé ici est abandonné plutôt que renvoyé indéfiniment.
bool isPushable(SyncItem item, {Set<String> kinds = SyncKind.enabled}) {
  if (!kinds.contains(item.kind)) return false;
  if (item.key.isEmpty || item.key.length > SyncLimits.maxKeyLength) {
    return false;
  }
  if (item.kind == SyncKind.settings && !isSyncableSettingKey(item.key)) {
    return false;
  }
  if (item.kind == SyncKind.addons && item.key != SyncKind.addonsKey) {
    return false;
  }
  if (item.deleted) return true;
  final p = item.payload;
  if (p == null) return false;
  if (item.kind == SyncKind.profiles &&
      p.keys.any((k) => !syncableProfileFields.contains(k))) {
    return false;
  }
  if (item.kind == SyncKind.progress && p['updatedAt'] is! num) return false;
  if (item.kind == SyncKind.addons && !isSealedAddonsPayload(p)) return false;
  return utf8.encode(jsonEncode(p)).length <= SyncLimits.maxPayloadBytes;
}

/// Contenu d'un élément `addons` : un seul champ `blob`, texte chiffré au
/// format `v1.…` (jamais de liste d'adresses en clair).
bool isSealedAddonsPayload(Map<String, dynamic> p) =>
    p.length == 1 &&
    p['blob'] is String &&
    (p['blob'] as String).startsWith('v1.');
