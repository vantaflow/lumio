import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

void main() {
  test('retourne la valeur dans le TTL puis null après expiration', () {
    var now = DateTime(2026, 1, 1, 12);
    final c = TtlCache(ttl: const Duration(minutes: 30), now: () => now);
    c.put('k', [1, 2]);
    expect(c.get<List<int>>('k'), [1, 2]);
    now = now.add(const Duration(minutes: 29));
    expect(c.get<List<int>>('k'), isNotNull);
    now = now.add(const Duration(minutes: 2));
    expect(c.get<List<int>>('k'), isNull);
  });

  test('clé inconnue ou type différent donne null', () {
    final c = TtlCache();
    expect(c.get<String>('x'), isNull);
    c.put('x', 5);
    expect(c.get<String>('x'), isNull);
    expect(c.get<int>('x'), 5);
  });

  test('put remplace et relance le TTL', () {
    var now = DateTime(2026, 1, 1);
    final c = TtlCache(ttl: const Duration(minutes: 1), now: () => now);
    c.put('k', 'a');
    now = now.add(const Duration(seconds: 50));
    c.put('k', 'b');
    now = now.add(const Duration(seconds: 50));
    expect(c.get<String>('k'), 'b');
  });
}
