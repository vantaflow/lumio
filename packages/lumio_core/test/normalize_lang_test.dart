import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'les codes à trois lettres d\'OpenSubtitles sont ramenés à ISO 639-1',
    () {
      const cases = {
        'alb': 'sq',
        'hrv': 'hr',
        'est': 'et',
        'bul': 'bg',
        'cze': 'cs',
        'ces': 'cs',
        'dan': 'da',
        'fin': 'fi',
        'hun': 'hu',
        'ind': 'id',
        'nor': 'no',
        'slv': 'sl',
        'srp': 'sr',
        'tha': 'th',
        'ukr': 'uk',
        'vie': 'vi',
        'cat': 'ca',
        'lit': 'lt',
        'lav': 'lv',
        'EL': 'el',
        'nl': 'nl',
      };
      for (final e in cases.entries) {
        expect(normalizeLang(e.key), e.value, reason: e.key);
      }
    },
  );

  test('un code inconnu reste tel quel', () {
    expect(normalizeLang('xyz'), 'xyz');
  });
}
