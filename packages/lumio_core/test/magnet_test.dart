import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

void main() {
  test('magnet en minuscules', () {
    expect(magnetFromInfoHash('A' * 40), 'magnet:?xt=urn:btih:${'a' * 40}');
  });
  test('39 caractères refusés', () {
    expect(() => magnetFromInfoHash('a' * 39), throwsArgumentError);
  });
  test('isInfoHash', () {
    expect(isInfoHash('a' * 40), isTrue);
    expect(isInfoHash('A' * 40), isTrue);
    expect(isInfoHash('a' * 39), isFalse);
    expect(isInfoHash('g' * 40), isFalse);
  });
}
