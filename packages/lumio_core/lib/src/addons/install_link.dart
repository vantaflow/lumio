import 'addon_url.dart';

const _maxLinkLength = 2048;

final _candidate = RegExp(
  r'(?:https?|stremio|lumio)://[^\s<>"]+',
  caseSensitive: false,
);

/// Extrait l'URL https d'un manifest d'addon depuis un lien d'installation ou
/// un texte contenant un tel lien. Renvoie null si rien d'exploitable.
///
/// Formes acceptées : `stremio://hôte/chemin/manifest.json` (converti en
/// https), `lumio://install?url=<url encodée>` (seul paramètre : `url`,
/// http(s) ou stremio), http(s) brut (normalisé par [normalizeAddonUrl]).
/// Tout autre schéma est refusé ; longueur maximale 2 048 caractères.
Uri? parseInstallLink(String input) {
  final text = input.trim();
  if (text.isEmpty || text.length > _maxLinkLength) return null;
  final match = _candidate.firstMatch(text);
  if (match == null) return null;
  var raw = match.group(0)!;
  // Ponctuation de phrase collée à la fin du lien.
  raw = raw.replaceFirst(RegExp(r'[.,;:!?)\]}]+$'), '');
  return _parse(raw, allowLumio: true);
}

Uri? _parse(String raw, {required bool allowLumio}) {
  if (raw.length > _maxLinkLength) return null;
  final Uri uri;
  try {
    uri = Uri.parse(raw);
  } on FormatException {
    return null;
  }
  switch (uri.scheme.toLowerCase()) {
    case 'lumio':
      if (!allowLumio || uri.host.toLowerCase() != 'install') return null;
      final params = uri.queryParametersAll;
      if (params.length != 1) return null;
      final values = params['url'];
      if (values == null || values.length != 1) return null;
      return _parse(values.single, allowLumio: false);
    case 'stremio':
      if (uri.host.isEmpty) return null;
      return _normalize(
        raw.replaceFirst(RegExp('^stremio', caseSensitive: false), 'https'),
      );
    case 'http':
    case 'https':
      return _normalize(raw);
    default:
      return null;
  }
}

Uri? _normalize(String raw) {
  try {
    final u = normalizeAddonUrl(raw);
    // Identifiants dans l'URL (u:p@hôte) : refusés (hôte trompeur).
    if (u.userInfo.isNotEmpty) return null;
    return u;
  } on FormatException {
    return null;
  }
}

/// Vrai si [text] ressemble à un lien d'addon : on ne propose que ceux-là
/// depuis le presse-papiers (jamais d'URL quelconque).
bool isPlausibleInstallLink(String? text) {
  final t = text?.trim();
  if (t == null || t.isEmpty || t.length > _maxLinkLength) return false;
  final lower = t.toLowerCase();
  final plausible =
      lower.startsWith('stremio://') ||
      lower.startsWith('lumio://install') ||
      lower.endsWith('manifest.json');
  return plausible && parseInstallLink(t) != null;
}
