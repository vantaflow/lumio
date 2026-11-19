import 'package:lumio_core/lumio_core.dart';

/// Noms de langues (français, anglais) par code ISO 639-1.
const _names = <String, (String, String)>{
  'fr': ('Français', 'French'),
  'en': ('Anglais', 'English'),
  'ar': ('Arabe', 'Arabic'),
  'es': ('Espagnol', 'Spanish'),
  'de': ('Allemand', 'German'),
  'it': ('Italien', 'Italian'),
  'pt': ('Portugais', 'Portuguese'),
  'nl': ('Néerlandais', 'Dutch'),
  'ru': ('Russe', 'Russian'),
  'tr': ('Turc', 'Turkish'),
  'ja': ('Japonais', 'Japanese'),
  'ko': ('Coréen', 'Korean'),
  'zh': ('Chinois', 'Chinese'),
  'pl': ('Polonais', 'Polish'),
  'he': ('Hébreu', 'Hebrew'),
  'fa': ('Persan', 'Persian'),
  'hi': ('Hindi', 'Hindi'),
  'sv': ('Suédois', 'Swedish'),
  'el': ('Grec', 'Greek'),
  'ro': ('Roumain', 'Romanian'),
  'sq': ('Albanais', 'Albanian'),
  'hr': ('Croate', 'Croatian'),
  'et': ('Estonien', 'Estonian'),
  'bg': ('Bulgare', 'Bulgarian'),
  'cs': ('Tchèque', 'Czech'),
  'da': ('Danois', 'Danish'),
  'fi': ('Finnois', 'Finnish'),
  'hu': ('Hongrois', 'Hungarian'),
  'id': ('Indonésien', 'Indonesian'),
  'no': ('Norvégien', 'Norwegian'),
  'sk': ('Slovaque', 'Slovak'),
  'sl': ('Slovène', 'Slovenian'),
  'sr': ('Serbe', 'Serbian'),
  'th': ('Thaï', 'Thai'),
  'uk': ('Ukrainien', 'Ukrainian'),
  'vi': ('Vietnamien', 'Vietnamese'),
  'ca': ('Catalan', 'Catalan'),
  'lt': ('Lituanien', 'Lithuanian'),
  'lv': ('Letton', 'Latvian'),
  'bs': ('Bosniaque', 'Bosnian'),
  'mk': ('Macédonien', 'Macedonian'),
  'ms': ('Malais', 'Malay'),
  'is': ('Islandais', 'Icelandic'),
  'bn': ('Bengali', 'Bengali'),
  'ta': ('Tamoul', 'Tamil'),
  'te': ('Télougou', 'Telugu'),
  'ur': ('Ourdou', 'Urdu'),
  'af': ('Afrikaans', 'Afrikaans'),
};

/// Nom d'une langue en clair (`sq` donne « Albanais ») ; un code inconnu est
/// affiché en majuscules, `und` en « Langue inconnue ».
String languageDisplayName(String code, String locale) {
  final fr = locale.startsWith('fr');
  if (code == 'und') return fr ? 'Langue inconnue' : 'Unknown language';
  final n = _names[normalizeLang(code)];
  if (n == null) return code.toUpperCase();
  return fr ? n.$1 : n.$2;
}

/// Sous-titres d'une même langue.
class SubtitleGroup {
  SubtitleGroup(this.lang, this.name, this.items, this.shown);
  final String lang;
  final String name;
  final List<SubtitleItem> items;

  /// Ceux que le panneau affiche (plafond par langue).
  final List<SubtitleItem> shown;

  int get hidden => items.length - shown.length;
}

class GroupedSubtitles {
  const GroupedSubtitles(this.preferred, this.others);

  /// Langues préférées (ordre donné) ; [others] : le reste par nom de langue.
  final List<SubtitleGroup> preferred;
  final List<SubtitleGroup> others;
}

/// Regroupe les sous-titres d'addons par langue. [preferred] : codes de
/// langue (réglage Lecture, langue de l'app), `off` et `null` ignorés.
/// [perLanguage] : plafond d'entrées affichées par langue (la ligne
/// [selectedId] est toujours affichée).
GroupedSubtitles groupSubtitles(
  List<SubtitleItem> items, {
  required List<String?> preferred,
  required String locale,
  int perLanguage = 5,
  String? selectedId,
}) {
  final byLang = <String, List<SubtitleItem>>{};
  for (final s in items) {
    byLang.putIfAbsent(normalizeLang(s.lang), () => []).add(s);
  }
  SubtitleGroup build(String lang) {
    final all = byLang[lang]!;
    final shown = all.take(perLanguage).toList();
    if (selectedId != null && !shown.any((s) => s.id == selectedId)) {
      for (final s in all) {
        if (s.id == selectedId) {
          shown[shown.length - 1] = s;
          break;
        }
      }
    }
    return SubtitleGroup(lang, languageDisplayName(lang, locale), all, shown);
  }

  final prefs = <String>[];
  for (final p in preferred) {
    if (p == null || p == 'off' || p.startsWith('idx:')) continue;
    final n = normalizeLang(p);
    if (byLang.containsKey(n) && !prefs.contains(n)) prefs.add(n);
  }
  final others =
      [
        for (final l in byLang.keys)
          if (!prefs.contains(l)) l,
      ]..sort(
        (a, b) => languageDisplayName(
          a,
          locale,
        ).compareTo(languageDisplayName(b, locale)),
      );
  return GroupedSubtitles(
    [for (final l in prefs) build(l)],
    [for (final l in others) build(l)],
  );
}
