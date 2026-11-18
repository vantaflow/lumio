/// Normalise un texte pour la recherche : minuscules, sans accents latins,
/// sans diacritiques ni tatweel arabes, alif unifié (أ إ آ ٱ → ا),
/// ى → ي, ة → ه. Les chiffres sont conservés.
String foldText(String s) {
  final out = StringBuffer();
  for (final r in s.runes) {
    final mapped = _fold(r);
    if (mapped != null) out.write(mapped);
  }
  return out.toString();
}

String? _fold(int r) {
  // Tashkeel (064B-065F, 0670) et tatweel (0640) : supprimés.
  if ((r >= 0x064B && r <= 0x065F) || r == 0x0670 || r == 0x0640) return null;
  switch (r) {
    case 0x0623: // أ
    case 0x0625: // إ
    case 0x0622: // آ
    case 0x0671: // ٱ
      return 'ا';
    case 0x0649: // ى
      return 'ي';
    case 0x0629: // ة
      return 'ه';
  }
  if (r < 0x80) {
    if (r >= 0x41 && r <= 0x5A) return String.fromCharCode(r + 32);
    return String.fromCharCode(r);
  }
  // Combinaisons diacritiques (U+0300-036F) : supprimées.
  if (r >= 0x0300 && r <= 0x036F) return null;
  final lower = String.fromCharCode(r).toLowerCase();
  return _latin[lower] ?? lower;
}

const _latin = <String, String>{
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ā': 'a',
  'ă': 'a',
  'ą': 'a',
  'æ': 'ae',
  'ç': 'c',
  'ć': 'c',
  'č': 'c',
  'ď': 'd',
  'đ': 'd',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'ė': 'e',
  'ę': 'e',
  'ě': 'e',
  'ğ': 'g',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ī': 'i',
  'į': 'i',
  'ı': 'i',
  'ł': 'l',
  'ñ': 'n',
  'ń': 'n',
  'ň': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ø': 'o',
  'ō': 'o',
  'ő': 'o',
  'œ': 'oe',
  'ř': 'r',
  'ś': 's',
  'š': 's',
  'ş': 's',
  'ß': 'ss',
  'ť': 't',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ū': 'u',
  'ů': 'u',
  'ű': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ź': 'z',
  'ż': 'z',
  'ž': 'z',
};
