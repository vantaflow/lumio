/// Normalise une URL saisie pour un addon afin d'éviter les doublons.
///
/// - schéma et hôte en minuscules, port par défaut retiré ;
/// - fragment retiré, barres finales retirées ;
/// - `/manifest.json` ajouté s'il manque.
///
/// Lève [FormatException] (message lisible) si l'entrée n'est pas une URL
/// http(s) absolue.
Uri normalizeAddonUrl(String input) {
  final raw = input.trim();
  final Uri parsed;
  try {
    parsed = Uri.parse(raw);
  } on FormatException {
    throw const FormatException('URL illisible');
  }
  if ((parsed.scheme != 'http' && parsed.scheme != 'https') ||
      parsed.host.isEmpty) {
    throw const FormatException('URL http(s) attendue');
  }
  var path = parsed.path;
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  if (!path.endsWith('/manifest.json')) path = '$path/manifest.json';

  final defaultPort = parsed.scheme == 'https' ? 443 : 80;
  return Uri(
    scheme: parsed.scheme.toLowerCase(),
    userInfo: parsed.userInfo,
    host: parsed.host.toLowerCase(),
    port: parsed.hasPort && parsed.port != defaultPort ? parsed.port : null,
    path: path,
    query: parsed.hasQuery && parsed.query.isNotEmpty ? parsed.query : null,
  );
}
