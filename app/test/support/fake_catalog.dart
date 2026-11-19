import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart' show Override;
import 'package:lumio/features/addons/catalog_providers.dart';
import 'package:lumio_core/lumio_core.dart';

/// Faux site de catalogue pour les tests de l'app : pages de liste et fiches
/// au format réel (voir packages/lumio_core/test/fixtures/addon_catalog).
class FakeCatalogSite implements HttpFetcher {
  FakeCatalogSite({
    this.cards = const [],
    this.details = const {},
    this.collectionJson,
    this.officialJson,
    this.offline = false,
    this.siteDown = false,
    this.pageSize = 10,
  });

  /// (slug, nom, description, étoiles, version) dans l'ordre d'affichage.
  List<(String, String, String, int, String)> cards;

  /// slug → instances (url, configurable, configurationRequired).
  Map<String, List<(String, bool, bool)>> details;
  String? collectionJson;

  /// Collection officielle de Stremio (`addonsofficialcollection.json`).
  String? officialJson;
  bool offline;

  /// Le site répond 503 (la collection officielle reste joignable).
  bool siteDown;
  int pageSize;
  final List<Uri> requests = [];

  static String cardHtml((String, String, String, int, String) c) =>
      '<a class="block" href="/addons/${c.$1}"><div><img src="https://img.example/${c.$1}.png"/>'
      '<h3 class="t">${c.$2}</h3><p class="d">${c.$3}</p>'
      '<svg class="lucide lucide-star size-3"></svg><span>${c.$4}</span>'
      '<span>v<!-- -->${c.$5}</span></div></a>';

  String listHtml(int page) {
    final from = (page - 1) * pageSize;
    final slice = cards.skip(from).take(pageSize).toList();
    final pages = (cards.length / pageSize).ceil().clamp(1, 1000);
    return '<p>${cards.length}<!-- --> results</p>'
        '${slice.map(cardHtml).join()}'
        '<span>$page<!-- --> of <!-- -->$pages</span>';
  }

  String detailHtml(String slug) {
    final inst = details[slug] ?? const [];
    final items = [
      for (final (i, d) in inst.indexed)
        '{"id":$i,"uuid":"u$i","manifest":{"behaviorHints":{"configurable":${d.$2},"configurationRequired":${d.$3}}},"manifestUrl":"${d.$1}","stars":1}',
    ].join(',');
    final json = '"instances":[$items]'.replaceAll('"', r'\"');
    return '<meta property="og:title" content="$slug"/><script>$json</script>';
  }

  @override
  Future<FetchResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) async {
    requests.add(url);
    if (offline) throw const SocketException('hors ligne');
    if (siteDown && url.host.contains('stremio-addons')) {
      return const FetchResponse(status: 503, body: []);
    }
    String body;
    if (url.path == '/addons') {
      body = listHtml(int.tryParse(url.queryParameters['page'] ?? '') ?? 1);
    } else if (url.path.startsWith('/addons/')) {
      body = detailHtml(url.pathSegments.last);
    } else if (url.path == '/addonsofficialcollection.json' &&
        officialJson != null) {
      body = officialJson!;
    } else if (url.path == '/addonscollection.json' && collectionJson != null) {
      body = collectionJson!;
    } else {
      return const FetchResponse(status: 404, body: []);
    }
    return FetchResponse(status: 200, body: utf8.encode(body));
  }
}

/// Remplace le service de catalogue par un faux site (cache en mémoire).
Override catalogOverride(FakeCatalogSite site, [CatalogCacheStore? store]) =>
    addonCatalogServiceProvider.overrideWithValue(
      AddonCatalogService(
        AddonCatalogSource(
          site,
          limiter: RateLimiter(minInterval: Duration.zero),
        ),
        store ?? MemoryCatalogCacheStore(),
      ),
    );
