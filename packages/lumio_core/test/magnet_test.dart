import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

void main() {
  test('magnet en minuscules', () {
    expect(magnetFromInfoHash('A' * 40), 'magnet:?xt=urn:btih:${'a' * 40}');
  });
  test('39 caractères refusés', () {
    expect(() => magnetFromInfoHash('a' * 39), throwsArgumentError);
  });
}
