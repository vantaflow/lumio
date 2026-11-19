// Écrit la page du téléphone (avec des données de démonstration) pour la
// rendre dans Chrome à 390 px et la comparer à M04. Inactif sauf avec
// LUMIO_RENDER_DIR=<dossier>.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/features/phone/lan_address.dart';
import 'package:lumio/features/phone/phone_add.dart';
import 'package:lumio/features/phone/phone_server.dart';

void main() {
  e2e();
  final dir = Platform.environment['LUMIO_RENDER_DIR'];
  test('page téléphone : fichiers de rendu', skip: dir == null, () {
    final out = Directory('$dir/phone')..createSync(recursive: true);
    Directory('${out.path}/fonts').createSync(recursive: true);
    for (final f in const [
      'Manrope-Variable.ttf',
      'BricolageGrotesque-Variable.ttf',
    ]) {
      File('assets/fonts/$f').copySync('${out.path}/fonts/$f');
    }
    File('${out.path}/app.css').writeAsStringSync(
      phoneCss
          .replaceAll('/fonts/manrope.ttf', 'fonts/Manrope-Variable.ttf')
          .replaceAll(
            '/fonts/bricolage.ttf',
            'fonts/BricolageGrotesque-Variable.ttf',
          ),
    );
    File('${out.path}/app.js').writeAsStringSync(phoneJs);
    File('${out.path}/demo.js').writeAsStringSync('''
window.fetch = function (p) {
  var json = function (s, o) { return Promise.resolve({ status: s, headers: { get: function () { return null; } }, text: function () { return Promise.resolve(JSON.stringify(o)); } }); };
  if (p === '/api/session') return json(200, { csrf: 'x' });
  if (p === '/api/addons') return json(200, { addons: [
    { id: 'a', name: 'Source Alpha', types: ['movie'], health: 'reliable', enabled: true, position: 0 },
    { id: 'b', name: 'Direct Plus', types: ['movie'], health: 'slow', enabled: true, position: 1 }] });
  return json(404, {});
};
''');
    for (final lang in const ['fr', 'en']) {
      File('${out.path}/index-$lang.html').writeAsStringSync(
        phoneIndexHtml(lang)
            .replaceFirst('href="/app.css"', 'href="app.css"')
            .replaceFirst(
              'src="/app.js"',
              'src="demo.js"></script><script src="app.js"',
            ),
      );
    }
  });
}

class _B implements PhoneBackend {
  var items = [
    const PhoneAddonView(
      id: 'a',
      name: 'Source Alpha',
      types: ['movie', 'series'],
      health: 'reliable',
      enabled: true,
      position: 0,
    ),
    const PhoneAddonView(
      id: 'b',
      name: 'Direct Plus',
      types: ['movie'],
      health: 'slow',
      enabled: true,
      position: 1,
    ),
  ];
  @override
  Future<List<PhoneAddonView>> addons() async => items;
  @override
  Future<PhoneCatalogPage> catalog({
    required String lang,
    String? chip,
    String? more,
    int page = 1,
    bool refresh = false,
  }) async => const PhoneCatalogPage(
    chips: [],
    more: [],
    chip: 'popular',
    cards: [],
    hasMore: false,
    page: 1,
  );
  @override
  Future<PhoneCatalogChoice?> catalogChoice(String slug) async => null;
  @override
  Future<Uri?> reconfigureUrl(String id) async => null;

  @override
  Future<void> move(String id, int delta) async {}
  @override
  Future<void> setEnabled(String id, bool on) async {}
  @override
  Future<void> remove(String id) async {}
}

/// Page réelle dans un vrai Chrome face au vrai serveur : le fragment `#c=`
/// ouvre la session (cookie + CSRF) et la liste s'affiche. Inactif sans
/// LUMIO_CHROME (chemin de Chrome).
void e2e() {
  final chrome = Platform.environment['LUMIO_CHROME'];
  test(
    'page téléphone : Chrome réel contre le serveur réel',
    skip: chrome == null,
    () async {
      final server = PhoneServer(
        backend: _B(),
        adds: PhoneAddCoordinator(),
        lan: _L(),
        lang: 'fr',
        preferredPort: 0,
      );
      await server.start();
      final url = server.state.value.url;
      final ok = await Process.run(chrome!, [
        '--headless=new',
        '--disable-gpu',
        '--virtual-time-budget=6000',
        '--dump-dom',
        url,
      ]);
      final dom = ok.stdout as String;
      expect(dom, contains('Source Alpha'));
      expect(dom, contains('Direct Plus'));
      expect(dom, contains('Bonne santé'));
      // Mauvais code : la page reste sur la saisie du code.
      final bad = await Process.run(chrome, [
        '--headless=new',
        '--disable-gpu',
        '--virtual-time-budget=6000',
        '--dump-dom',
        'http://${server.state.value.address}/#c=${server.state.value.code == '123456' ? '654321' : '123456'}',
      ]);
      expect(bad.stdout as String, contains('Code incorrect'));
      expect(bad.stdout as String, isNot(contains('Source Alpha')));
      await server.stop();
      server.dispose();
    },
  );
}

class _L implements LanAddressSource {
  @override
  Future<InternetAddress?> current() async => InternetAddress.loopbackIPv4;
}
