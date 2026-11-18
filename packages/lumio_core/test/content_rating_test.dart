import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

void main() {
  test('exemples du cahier des charges', () {
    expect(ratingAllows('PG-13', AgeLimit.age12), isFalse);
    expect(ratingAllows('PG', AgeLimit.age12), isTrue);
    expect(ratingAllows(null, AgeLimit.age12), isFalse);
    expect(ratingAllows(null, AgeLimit.adult), isTrue);
  });

  test('cinéma américain', () {
    expect(ratingAllows('G', AgeLimit.all), isTrue);
    expect(ratingAllows('PG', AgeLimit.all), isFalse);
    expect(ratingAllows('PG', AgeLimit.age7), isTrue);
    expect(ratingAllows('PG-13', AgeLimit.age16), isTrue);
    expect(ratingAllows('R', AgeLimit.age16), isFalse);
    expect(ratingAllows('NC-17', AgeLimit.age16), isFalse);
    expect(ratingAllows('R', AgeLimit.adult), isTrue);
  });

  test('télévision américaine', () {
    expect(ratingAllows('TV-Y', AgeLimit.all), isTrue);
    expect(ratingAllows('TV-G', AgeLimit.all), isTrue);
    expect(ratingAllows('TV-Y7', AgeLimit.age7), isTrue);
    expect(ratingAllows('TV-Y7', AgeLimit.all), isFalse);
    expect(ratingAllows('TV-PG', AgeLimit.age12), isTrue);
    expect(ratingAllows('TV-PG', AgeLimit.age7), isFalse);
    expect(ratingAllows('TV-14', AgeLimit.age16), isTrue);
    expect(ratingAllows('TV-14', AgeLimit.age12), isFalse);
    expect(ratingAllows('TV-MA', AgeLimit.age16), isFalse);
  });

  test('France', () {
    expect(ratingAllows('-10', AgeLimit.age7), isFalse);
    expect(ratingAllows('-10', AgeLimit.age12), isTrue);
    expect(ratingAllows('-12', AgeLimit.age12), isTrue);
    expect(ratingAllows('-16', AgeLimit.age12), isFalse);
    expect(ratingAllows('-16', AgeLimit.age16), isTrue);
    expect(ratingAllows('-18', AgeLimit.age16), isFalse);
    expect(ratingAllows('FR-18', AgeLimit.adult), isTrue);
  });

  test('casse, espaces et certification inconnue', () {
    expect(ratingAllows(' pg ', AgeLimit.age7), isTrue);
    expect(ratingAllows('Not Rated', AgeLimit.age16), isFalse);
    expect(ratingAllows('', AgeLimit.all), isFalse);
    expect(ratingAllows('Not Rated', AgeLimit.adult), isTrue);
  });
}
