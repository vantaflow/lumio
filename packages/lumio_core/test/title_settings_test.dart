import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

void main() {
  test('les réglages d\'une série sont retrouvés pour un autre épisode', () {
    final s = InMemoryTitleSettingsStore();
    s.save('p', 'tt1:1:1', const TitleSettings(audioLang: 'fr'));
    expect(s.forTitle('p', 'tt1:1:2').audioLang, 'fr');
    expect(s.forTitle('p', 'tt1').audioLang, 'fr');
    expect(s.forTitle('p', 'tt2:1:1').audioLang, isNull);
    expect(s.forTitle('autre', 'tt1:1:2').audioLang, isNull);
  });

  test('le décalage +300 ms est persisté', () {
    final s = InMemoryTitleSettingsStore();
    s.save('p', 'tt9', const TitleSettings(subtitleDelayMs: 300));
    expect(s.forTitle('p', 'tt9').subtitleDelayMs, 300);
  });

  test('JSON aller-retour', () {
    const t = TitleSettings(
      audioLang: 'en',
      subtitleLang: 'off',
      subtitleDelayMs: -200,
      audioDelayMs: 50,
      aspect: 1.78,
    );
    final back = TitleSettings.fromJson(t.toJson());
    expect(back.toJson(), t.toJson());
    expect(const TitleSettings().subtitleDelayMs, 0);
  });

  test('clé de série', () {
    expect(titleSettingsKey('tt1:1:2'), 'tt1');
    expect(titleSettingsKey('tt1'), 'tt1');
  });
}
