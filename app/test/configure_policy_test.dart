import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/features/addons/configure_policy.dart';

void main() {
  final start = Uri.parse('https://addon.example/abc/configure');
  ConfigureNav d(String u) =>
      decideConfigureNavigation(Uri.parse(u), start: start);

  test('page de l\'addon : autorisée', () {
    expect(d('https://addon.example/abc/configure'), isA<ConfigureAllow>());
    expect(d('https://ADDON.example/x?y=1'), isA<ConfigureAllow>());
  });

  test('stremio:// devient un lien d\'installation https', () {
    final r = d('stremio://addon.example/cfg/manifest.json');
    expect(r, isA<ConfigureInstall>());
    expect(
      (r as ConfigureInstall).manifest.toString(),
      'https://addon.example/cfg/manifest.json',
    );
  });

  test('lumio://install et manifest.json https sont captés', () {
    expect(
      d('lumio://install?url=https%3A%2F%2Fa.example%2Fm%2Fmanifest.json'),
      isA<ConfigureInstall>(),
    );
    expect(d('https://autre.example/z/manifest.json'), isA<ConfigureInstall>());
  });

  test('hôte étranger, http, identifiants : bloqués', () {
    expect(d('https://evil.example/'), isA<ConfigureBlock>());
    expect(d('http://addon.example/x'), isA<ConfigureBlock>());
    expect(d('https://u:p@addon.example/x'), isA<ConfigureBlock>());
  });

  test('schémas interdits : bloqués', () {
    for (final u in [
      'file:///sdcard/x',
      'javascript:alert(1)',
      'intent://x#Intent;end',
      'data:text/html,hi',
      'content://a/b',
      'about:blank',
      'stremio:///nohost',
    ]) {
      expect(d(u), isA<ConfigureBlock>(), reason: u);
    }
  });

  test('addon en http : ses pages http restent autorisées', () {
    final r = decideConfigureNavigation(
      Uri.parse('http://192.168.1.5:7000/configure'),
      start: Uri.parse('http://192.168.1.5:7000/configure'),
    );
    expect(r, isA<ConfigureAllow>());
  });
}
