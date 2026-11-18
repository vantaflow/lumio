/// Masque chemin, requête et identifiants d'une URL pour la journalisation.
///
/// Ne garde que le schéma, l'hôte et le port : les URL d'addons contiennent
/// souvent un jeton dans le chemin. Toute chaîne qui n'est pas une URL
/// absolue http(s) donne `***`.
String redactUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null ||
      !uri.hasScheme ||
      uri.host.isEmpty ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return '***';
  }
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port/***';
}
