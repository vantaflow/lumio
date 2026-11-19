import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

void main() {
  test('épisode S01E02, balises retirées', () {
    final p = parseMediaName('The.Show.S01E02.1080p.x265.mkv');
    expect(p.title, 'The Show');
    expect(p.season, 1);
    expect(p.episode, 2);
    expect(p.year, isNull);
  });

  test('année entre parenthèses', () {
    final p = parseMediaName('Film (2019).mp4');
    expect(p.title, 'Film');
    expect(p.year, 2019);
    expect(p.season, isNull);
  });

  test('année entre points et balises de qualité', () {
    final p = parseMediaName('Blade.Runner.2049.2017.2160p.4K.HDR.WEB-DL.mkv');
    expect(p.title, 'Blade Runner 2049');
    expect(p.year, 2017);
  });

  test('préfixe [Group] et balises MULTI/VOSTFR/FRENCH', () {
    final p = parseMediaName(
      '[Fansub] Mon_Anime - S02E10 - Titre 720p MULTI VOSTFR h264.mkv',
    );
    expect(p.title, 'Mon Anime');
    expect(p.season, 2);
    expect(p.episode, 10);
    expect(parseMediaName('[A][B] Film.FRENCH.BluRay.x264.avi').title, 'Film');
  });

  test('format 1x02', () {
    final p = parseMediaName('Serie 1x02 Pilote.avi');
    expect(p.title, 'Serie');
    expect(p.season, 1);
    expect(p.episode, 2);
  });

  test('nom illisible : titre = nom sans extension', () {
    expect(parseMediaName('1080p.mkv').title, '1080p');
    expect(parseMediaName('xyz_123.mp4').title, 'xyz 123');
    expect(parseMediaName('[Grp].mkv').title, '[Grp]');
    expect(parseMediaName('sans_extension').title, 'sans extension');
  });

  test('nom de fichier courant : points, année et qualité nettoyés', () {
    final p = parseMediaName('Big.Buck.Bunny.2008.1080p.mp4');
    expect(p.title, 'Big Buck Bunny');
    expect(p.year, 2008);
    final q = parseMediaName('big-buck-bunny-2008-720p.mkv');
    expect(q.title, 'big buck bunny');
    expect(q.year, 2008);
  });

  test('année en tête = partie du titre', () {
    final p = parseMediaName('2012.mp4');
    expect(p.title, '2012');
    expect(p.year, isNull);
    final q = parseMediaName('2001.A.Space.Odyssey.1968.1080p.mkv');
    expect(q.title, '2001 A Space Odyssey');
    expect(q.year, 1968);
  });

  test('casse conservée, accents et arabe', () {
    expect(parseMediaName('Amélie Poulain (2001).mkv').title, 'Amélie Poulain');
    expect(parseMediaName('فيلم (2010).mp4').title, 'فيلم');
  });
}
