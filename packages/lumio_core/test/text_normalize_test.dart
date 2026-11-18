import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

void main() {
  test('accents latins et casse', () {
    expect(foldText('Élève'), 'eleve');
    expect(foldText('ÇA Va À Œuvre'), 'ca va a oeuvre');
    expect(foldText('Amélie 2001'), 'amelie 2001');
  });

  test('tashkeel et tatweel arabes', () {
    expect(foldText('الْكِتَاب'), foldText('الكتاب'));
    expect(foldText('كتـــاب'), 'كتاب');
  });

  test('alif, ya et ta marbuta', () {
    expect(foldText('أحمد'), foldText('احمد'));
    expect(foldText('إسلام آمن ٱبن'), 'اسلام امن ابن');
    expect(foldText('مدينة'), 'مدينه');
    expect(foldText('موسى'), 'موسي');
  });

  test('chaîne vide et chiffres conservés', () {
    expect(foldText(''), '');
    expect(foldText('Se7en'), 'se7en');
  });
}
