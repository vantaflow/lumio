import 'package:lumio_core/lumio_core.dart';
import 'package:test/test.dart';

void main() {
  group('UrlGuard.check', () {
    for (final u in [
      'ftp://addon.example/manifest.json',
      'file:///etc/passwd',
      'http://localhost/x',
      'http://foo.localhost/x',
      'http://127.0.0.1/x',
      'http://127.1.2.3/x',
      'http://10.0.0.5/x',
      'http://172.16.0.1/x',
      'http://172.31.255.1/x',
      'http://192.168.1.2/x',
      'http://169.254.169.254/latest',
      'http://0.0.0.0/x',
      'http://100.64.0.1/x',
      'http://[::1]/x',
      'http://[::]/x',
      'http://[fe80::1]/x',
      'http://[fd00::1]/x',
      'http://[::ffff:10.0.0.1]/x',
      'http://[::ffff:7f00:1]/x',
      'http://2130706433/x',
      'http://0x7f.0.0.1/x',
    ]) {
      test('refuse $u', () {
        expect(
          () => UrlGuard.check(Uri.parse(u)),
          throwsA(isA<UnsafeUrlException>()),
        );
      });
    }

    for (final u in [
      'https://addon.example',
      'http://addon.example:7000/manifest.json',
      'https://8.8.8.8/x',
      'http://172.32.0.1/x',
      'https://[2606:4700::1111]/x',
    ]) {
      test('accepte $u', () {
        expect(() => UrlGuard.check(Uri.parse(u)), returnsNormally);
      });
    }

    test('allowPrivate accepte le réseau privé mais pas un schéma ftp', () {
      expect(
        () =>
            UrlGuard.check(Uri.parse('http://192.168.1.2'), allowPrivate: true),
        returnsNormally,
      );
      expect(
        () =>
            UrlGuard.check(Uri.parse('ftp://192.168.1.2'), allowPrivate: true),
        throwsA(isA<UnsafeUrlException>()),
      );
    });
  });

  group('normalizeAddonUrl', () {
    final expected = Uri.parse('https://ex.com/abc/manifest.json');
    test('hôte en minuscules, barre finale retirée', () {
      expect(normalizeAddonUrl('HTTPS://Ex.com/abc/'), expected);
    });
    test('manifest.json déjà présent : même valeur', () {
      expect(normalizeAddonUrl('https://ex.com/abc/manifest.json'), expected);
    });
    test('sans chemin, fragment retiré, port par défaut retiré', () {
      expect(
        normalizeAddonUrl(' https://EX.com:443#frag '),
        Uri.parse('https://ex.com/manifest.json'),
      );
    });
    test('port non standard et requête conservés', () {
      expect(
        normalizeAddonUrl('http://ex.com:7000/a//?k=v'),
        Uri.parse('http://ex.com:7000/a/manifest.json?k=v'),
      );
    });
    test('entrée invalide : FormatException', () {
      expect(() => normalizeAddonUrl('pas une url'), throwsFormatException);
      expect(() => normalizeAddonUrl('ftp://ex.com'), throwsFormatException);
    });
  });
}
