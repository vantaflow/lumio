import 'dart:async';
import 'dart:convert';

import '../../net/http_fetcher.dart';
import '../../net/url_guard.dart';
import 'catalog_models.dart';
import 'catalog_parser.dart';

/// Le site (ou la collection officielle) est injoignable ou répond mal :
/// réseau coupé, délai, statut d'erreur, réponse trop grosse. N'est PAS levée
/// pour un format inattendu (voir [CatalogParseException]).
class CatalogUnavailableException implements Exception {
  const CatalogUnavailableException([this.status]);

  /// Statut HTTP si le serveur a répondu.
  final int? status;

  @override
  String toString() =>
      'CatalogUnavailableException${status == null ? '' : ': HTTP $status'}';
}

/// Tri des pages de liste du site.
enum CatalogSort {
  popular('popular'),
  newest('new'),
  updated('updatedAt');

  const CatalogSort(this.param);
  final String param;
}

/// Catégories du site (noms exacts du paramètre `categories`).
class CatalogCategories {
  const CatalogCategories._();
  static const movies = 'movies';
  static const tvShows = 'tv shows';
  static const torrents = 'torrents';
  static const debrid = 'debrid support';
  static const httpStreams = 'http streams';
  static const usenet = 'usenet';
  static const subtitles = 'subtitles';
  static const anime = 'anime';
  static const metadata = 'metadata';
  static const tracking = 'tracking';
  static const asianDrama = 'asian drama';
  static const bollywood = 'bollywood';
  static const music = 'music';
  static const radios = 'radios';
  static const liveTv = 'live tv';
  static const misc = 'misc';
}

/// Requête d'une page de liste : catégories (union ; vide = toutes), tri, page.
class CatalogQuery {
  const CatalogQuery({
    this.categories = const [],
    this.sort = CatalogSort.popular,
    this.page = 1,
  });

  final List<String> categories;
  final CatalogSort sort;
  final int page;

  CatalogQuery withPage(int p) =>
      CatalogQuery(categories: categories, sort: sort, page: p);

  /// Clé de cache stable.
  String get key =>
      'list|${([...categories]..sort()).join(',')}|${sort.param}|$page';
}

/// Limiteur de débit : au plus une requête par [minInterval] (2 par seconde
/// par défaut). Horloge et attente injectables pour les tests.
class RateLimiter {
  RateLimiter({
    this.minInterval = const Duration(milliseconds: 500),
    DateTime Function()? now,
    Future<void> Function(Duration)? sleep,
  }) : _now = now ?? DateTime.now,
       _sleep = sleep ?? ((d) => Future<void>.delayed(d));

  final Duration minInterval;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _sleep;
  DateTime? _next;
  Future<void> _tail = Future.value();

  /// Attend son tour (les appels concurrents sont mis en file).
  Future<void> acquire() {
    final done = _tail.then((_) async {
      final t = _now();
      final next = _next;
      if (next != null && t.isBefore(next)) {
        await _sleep(next.difference(t));
      }
      _next = _now().add(minInterval);
    });
    _tail = done.catchError((_) {});
    return done;
  }
}

/// Récupère et analyse les pages de stremio-addons.net (pas d'API publique)
/// et la collection officielle de repli.
///
/// Toutes les requêtes passent par [HttpFetcher] avec [UrlGuard] (URL
/// initiale et redirections), taille et délai bornés, User-Agent générique.
/// Rien n'est téléchargé que la page demandée.
class AddonCatalogSource {
  AddonCatalogSource(
    this._fetcher, {
    Uri? site,
    Uri? collectionUrl,
    RateLimiter? limiter,
    this.timeout = const Duration(seconds: 10),
    this.maxPageBytes = 2 * 1024 * 1024,
    this.maxCollectionBytes = 2 * 1024 * 1024,
  }) : site = site ?? Uri.parse('https://stremio-addons.net'),
       collectionUrl =
           collectionUrl ??
           Uri.parse('https://api.strem.io/addonscollection.json'),
       _limiter = limiter ?? RateLimiter();

  final HttpFetcher _fetcher;
  final Uri site;
  final Uri collectionUrl;
  final RateLimiter _limiter;
  final Duration timeout;
  final int maxPageBytes;
  final int maxCollectionBytes;

  static const userAgent = 'Lumio';

  Future<CatalogPage> list(CatalogQuery q) async {
    final url = site.replace(
      path: '/addons',
      queryParameters: {
        'categories': q.categories,
        'sort': q.sort.param,
        if (q.page > 1) 'page': '${q.page}',
      },
    );
    return AddonCatalogParser.parseList(
      await _get(url, maxPageBytes),
      page: q.page,
    );
  }

  Future<CatalogDetail> detail(String slug) async {
    final url = site.replace(pathSegments: ['addons', slug]);
    return AddonCatalogParser.parseDetail(await _get(url, maxPageBytes), slug);
  }

  Future<CatalogPage> collection() async => AddonCatalogParser.parseCollection(
    await _get(collectionUrl, maxCollectionBytes),
  );

  Future<String> _get(Uri url, int maxBytes) async {
    await _limiter.acquire();
    final FetchResponse r;
    try {
      r = await _fetcher.get(
        url,
        headers: const {
          'user-agent': userAgent,
          'accept': 'text/html,application/json',
        },
        maxBytes: maxBytes,
        timeout: timeout,
        guard: UrlGuard.check,
      );
    } on UnsafeUrlException {
      rethrow;
    } catch (_) {
      throw const CatalogUnavailableException();
    }
    if (r.status != 200) throw CatalogUnavailableException(r.status);
    try {
      return utf8.decode(r.body);
    } on FormatException {
      throw const CatalogParseException('réponse non UTF-8');
    }
  }
}
