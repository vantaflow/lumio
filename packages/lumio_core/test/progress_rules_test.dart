import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

void main() {
  const dur = Duration(minutes: 100);

  test('40 % : reprise à la position', () {
    const pos = Duration(minutes: 40);
    expect(ProgressRules.resumeAt(pos, dur), pos);
    expect(ProgressRules.isWatched(pos, dur), isFalse);
  });

  test('1 % : pas de reprise', () {
    expect(ProgressRules.resumeAt(const Duration(minutes: 1), dur), isNull);
  });

  test('95 % : vu, pas de reprise', () {
    const pos = Duration(minutes: 95);
    expect(ProgressRules.isWatched(pos, dur), isTrue);
    expect(ProgressRules.resumeAt(pos, dur), isNull);
  });

  test('bornes : 90 % vu, 2 % repris, durée inconnue neutre', () {
    expect(ProgressRules.isWatched(const Duration(minutes: 90), dur), isTrue);
    expect(
      ProgressRules.isWatched(const Duration(minutes: 90, seconds: -1), dur),
      isFalse,
    );
    expect(
      ProgressRules.resumeAt(const Duration(minutes: 2), dur),
      const Duration(minutes: 2),
    );
    expect(
      ProgressRules.isWatched(const Duration(minutes: 5), Duration.zero),
      isFalse,
    );
    expect(
      ProgressRules.resumeAt(const Duration(minutes: 5), Duration.zero),
      isNull,
    );
  });
}
