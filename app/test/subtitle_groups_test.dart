import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/player/subtitle_groups.dart';
import 'package:lumio_core/lumio_core.dart';

SubtitleItem s(String lang, int n) => SubtitleItem(
  id: '$lang$n',
  url: Uri.parse('https://x.example.org/$lang$n.srt'),
  lang: lang,
  addonId: 'a',
);

void main() {
  test('nom de langue en clair, pas de code brut', () {
    expect(languageDisplayName('sq', 'fr'), 'Albanais');
    expect(languageDisplayName('sq', 'en'), 'Albanian');
    expect(languageDisplayName('hr', 'fr'), 'Croate');
    expect(languageDisplayName('et', 'fr'), 'Estonien');
    expect(languageDisplayName('fr', 'fr'), 'Français');
    expect(languageDisplayName('und', 'fr'), 'Langue inconnue');
    expect(languageDisplayName('qq', 'fr'), 'QQ');
  });

  test("regroupe par langue, préférées d'abord, autres par nom", () {
    final items = [
      s('sq', 1),
      s('en', 1),
      s('en', 2),
      s('fr', 1),
      s('hr', 1),
      s('fr', 2),
      s('fr', 3),
    ];
    final g = groupSubtitles(items, preferred: ['fr', 'en'], locale: 'fr');
    expect([for (final x in g.preferred) x.lang], ['fr', 'en']);
    expect(g.preferred.first.items.length, 3);
    expect([for (final x in g.others) x.lang], ['sq', 'hr']);
    expect(g.others.first.name, 'Albanais');
  });

  test('langue préférée normalisée (fra, FR) et dédoublonnée', () {
    final g = groupSubtitles(
      [s('fr', 1)],
      preferred: ['fra', 'FR', 'off', null, 'en'],
      locale: 'fr',
    );
    expect([for (final x in g.preferred) x.lang], ['fr']);
  });

  test('plafond par langue : les premières seulement, la choisie incluse', () {
    final items = [for (var i = 1; i <= 9; i++) s('en', i)];
    final g = groupSubtitles(
      items,
      preferred: ['en'],
      locale: 'en',
      perLanguage: 5,
      selectedId: 'en8',
    );
    final ids = [for (final i in g.preferred.single.shown) i.id];
    expect(ids.length, 5);
    expect(ids, contains('en8'));
    expect(ids.take(4), ['en1', 'en2', 'en3', 'en4']);
    expect(g.preferred.single.hidden, 4);
  });

  test('sans préférence : tout est dans les autres langues', () {
    final g = groupSubtitles([s('de', 1)], preferred: const [], locale: 'fr');
    expect(g.preferred, isEmpty);
    expect(g.others.single.name, 'Allemand');
  });
}
