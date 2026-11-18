final _hex40 = RegExp(r'^[0-9a-fA-F]{40}$');

/// Construit un lien magnet depuis un infoHash nu (40 caractères hexadécimaux).
String magnetFromInfoHash(String infoHash,
    {List<String> trackers = const []}) {
  if (!_hex40.hasMatch(infoHash)) {
    throw ArgumentError.value(
        infoHash, 'infoHash', 'attendu : 40 caractères hexadécimaux');
  }
  final b = StringBuffer('magnet:?xt=urn:btih:${infoHash.toLowerCase()}');
  for (final t in trackers) {
    b.write('&tr=${Uri.encodeQueryComponent(t)}');
  }
  return b.toString();
}
