final _hex40 = RegExp(r'^[0-9a-fA-F]{40}$');

/// Vrai si [s] est un infoHash nu (40 caractères hexadécimaux).
bool isInfoHash(String s) => _hex40.hasMatch(s);

/// Construit un lien magnet depuis un infoHash nu (40 caractères hexadécimaux).
String magnetFromInfoHash(String infoHash, {List<String> trackers = const []}) {
  if (!isInfoHash(infoHash)) {
    throw ArgumentError.value(
      infoHash,
      'infoHash',
      'attendu : 40 caractères hexadécimaux',
    );
  }
  final b = StringBuffer('magnet:?xt=urn:btih:${infoHash.toLowerCase()}');
  for (final t in trackers) {
    b.write('&tr=${Uri.encodeQueryComponent(t)}');
  }
  return b.toString();
}
