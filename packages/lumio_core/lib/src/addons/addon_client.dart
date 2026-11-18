import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../net/http_fetcher.dart';
import '../net/url_guard.dart';
import 'manifest.dart';
import 'meta_preview.dart';

/// Délai dépassé : est à la fois un [AddonException] (message FR) et un
/// [TimeoutException].
class AddonTimeoutException extends AddonException implements TimeoutException {
  const AddonTimeoutException({this.duration})
    : super(
        'Délai dépassé : l\'addon ne répond pas',
        code: AddonErrorCode.timeout,
      );

  @override
  final Duration? duration;
}

/// Client du protocole d'addons : manifeste, catalogues, meta, flux, sous-titres.
///
/// Chaque URL est vérifiée par [UrlGuard] avant l'envoi. Pour que les
/// redirections le soient aussi, construire le fetcher réseau avec
/// `IoHttpFetcher(redirectGuard: (u) => UrlGuard.check(u))`.
/// Les messages d'erreur ne contiennent jamais l'URL (jetons dans le chemin).
class AddonClient {
  AddonClient(
    this._fetcher, {
    this.timeout = const Duration(seconds: 8),
    this.retries = 1,
    this.maxBytes = 5 * 1024 * 1024,
    this.allowPrivate = false,
    this.retryDelay = const Duration(milliseconds: 250),
  });

  final HttpFetcher _fetcher;
  final Duration timeout;
  final int retries;
  final int maxBytes;
  final bool allowPrivate;
  final Duration retryDelay;

  /// Au-delà de cette taille, le JSON est décodé dans un isolate.
  static const isolateThreshold = 256 * 1024;

  Future<AddonManifest> fetchManifest(Uri url) async {
    final Object? json;
    try {
      json = await _getJson(
        url,
        (m, {cause, code = AddonErrorCode.other, status}) =>
            ManifestException(m, cause: cause, code: code, status: status),
        isManifest: true,
      );
    } on _NotFound {
      throw const ManifestException(
        'Addon introuvable (HTTP 404)',
        code: AddonErrorCode.notFound,
      );
    }
    return AddonManifest.fromJson(json, url);
  }

  Future<List<MetaPreview>> catalog(
    AddonManifest a,
    String type,
    String id, {
    Map<String, String> extra = const {},
  }) async {
    final json = await _resource(a, 'catalog', type, id, extra: extra);
    final metas = json is Map ? json['metas'] : null;
    if (metas is! List) return const [];
    return [
      for (final m in metas)
        ?MetaPreview.tryParse(m, sourceAddonId: a.id, fallbackType: type),
    ];
  }

  Future<Map<String, dynamic>?> rawMeta(
    AddonManifest a,
    String type,
    String id,
  ) async {
    final json = await _resource(a, 'meta', type, id, notFoundIsEmpty: true);
    final meta = json is Map ? json['meta'] : null;
    if (meta is! Map || meta.isEmpty) return null;
    return Map<String, dynamic>.from(meta);
  }

  Future<List<Map<String, dynamic>>> rawStreams(
    AddonManifest a,
    String type,
    String id,
  ) => _list(a, 'stream', 'streams', type, id);

  Future<List<Map<String, dynamic>>> rawSubtitles(
    AddonManifest a,
    String type,
    String id,
  ) => _list(a, 'subtitles', 'subtitles', type, id);

  Future<List<Map<String, dynamic>>> _list(
    AddonManifest a,
    String resource,
    String key,
    String type,
    String id,
  ) async {
    final json = await _resource(a, resource, type, id, notFoundIsEmpty: true);
    final list = json is Map ? json[key] : null;
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  Future<Object?> _resource(
    AddonManifest a,
    String resource,
    String type,
    String id, {
    Map<String, String> extra = const {},
    bool notFoundIsEmpty = false,
  }) async {
    final url = resourceUrl(a, resource, type, id, extra: extra);
    try {
      return await _getJson(
        url,
        (m, {cause, code = AddonErrorCode.other, status}) =>
            AddonException(m, cause: cause, code: code, status: status),
      );
    } on _NotFound {
      if (notFoundIsEmpty) return null;
      throw const AddonException(
        'Ressource introuvable (HTTP 404)',
        code: AddonErrorCode.notFound,
      );
    }
  }

  /// Construit l'URL d'une ressource du protocole.
  static Uri resourceUrl(
    AddonManifest a,
    String resource,
    String type,
    String id, {
    Map<String, String> extra = const {},
  }) {
    final base = a.baseUrl.toString();
    final extras = extra.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
    final tail = extras.isEmpty ? '' : '/$extras';
    return Uri.parse('$base/$resource/${_seg(type)}/${_seg(id)}$tail.json');
  }

  // Les identifiants du protocole contiennent des ':' (tt123:1:2) laissés
  // tels quels par convention.
  static String _seg(String s) => Uri.encodeComponent(s).replaceAll('%3A', ':');

  Future<Object?> _getJson(
    Uri url,
    AddonException Function(
      String, {
      Object? cause,
      AddonErrorCode code,
      int? status,
    })
    fail, {
    bool isManifest = false,
  }) async {
    try {
      UrlGuard.check(url, allowPrivate: allowPrivate);
    } on UnsafeUrlException catch (e) {
      throw fail(
        'Adresse refusée : ${e.reason}',
        cause: e,
        code: AddonErrorCode.addressRefused,
      );
    }

    FetchResponse res;
    for (var attempt = 0; ; attempt++) {
      try {
        res = await _fetcher.get(
          url,
          headers: const {'accept': 'application/json'},
          maxBytes: maxBytes,
          timeout: timeout,
          guard: (u) => UrlGuard.check(u, allowPrivate: allowPrivate),
        );
      } on TimeoutException catch (e) {
        if (attempt < retries) {
          await _pause();
          continue;
        }
        throw _timeout(fail, e, isManifest);
      } on ResponseTooLargeException catch (e) {
        throw fail(
          'Réponse trop volumineuse (plus de ${maxBytes ~/ (1024 * 1024)} Mo)',
          code: AddonErrorCode.tooLarge,
          cause: e,
        );
      } on UnsafeUrlException catch (e) {
        throw fail(
          'Adresse refusée : ${e.reason}',
          cause: e,
          code: AddonErrorCode.addressRefused,
        );
      } on InsecureRedirectException catch (e) {
        throw fail(
          'Redirection refusée (non sécurisée)',
          cause: e,
          code: AddonErrorCode.redirect,
        );
      } on InvalidRedirectException catch (e) {
        throw fail(
          'Redirection invalide',
          cause: e,
          code: AddonErrorCode.redirect,
        );
      } on TooManyRedirectsException catch (e) {
        throw fail(
          'Trop de redirections',
          cause: e,
          code: AddonErrorCode.redirect,
        );
      } on HandshakeException catch (e) {
        throw fail(
          'Connexion sécurisée impossible (certificat refusé)',
          cause: e,
          code: AddonErrorCode.tlsFailed,
        );
      } on SocketException catch (e) {
        throw fail(
          'Addon injoignable',
          cause: e,
          code: AddonErrorCode.unreachable,
        );
      } on HttpException catch (e) {
        throw fail(
          'Addon injoignable',
          cause: e,
          code: AddonErrorCode.unreachable,
        );
      }

      final s = res.status;
      if (s >= 500 && attempt < retries) {
        await _pause();
        continue;
      }
      if (s == 404) throw const _NotFound();
      if (s >= 500) {
        throw fail(
          'Addon en erreur (HTTP $s)',
          code: AddonErrorCode.serverError,
          status: s,
        );
      }
      if (s < 200 || s >= 300) {
        throw fail(
          'Réponse refusée par l\'addon (HTTP $s)',
          code: AddonErrorCode.refused,
          status: s,
        );
      }
      break;
    }

    if (res.body.length > maxBytes) {
      throw fail(
        'Réponse trop volumineuse (plus de ${maxBytes ~/ (1024 * 1024)} Mo)',
        code: AddonErrorCode.tooLarge,
      );
    }
    try {
      return await _decode(res.body);
    } on FormatException catch (e) {
      throw fail(
        'Réponse invalide : ce n\'est pas du JSON valide',
        cause: e,
        code: AddonErrorCode.invalidJson,
      );
    }
  }

  AddonException _timeout(
    AddonException Function(
      String, {
      Object? cause,
      AddonErrorCode code,
      int? status,
    })
    fail,
    TimeoutException e,
    bool isManifest,
  ) {
    final ex = AddonTimeoutException(duration: timeout);
    // fetchManifest doit lever une ManifestException : on garde le message FR.
    return isManifest
        ? ManifestException(ex.message, cause: ex, code: AddonErrorCode.timeout)
        : ex;
  }

  Future<void> _pause() => retryDelay > Duration.zero
      ? Future<void>.delayed(retryDelay)
      : Future.value();

  static Future<Object?> _decode(List<int> body) {
    if (body.length > isolateThreshold) {
      return Isolate.run(() => _decodeSync(body));
    }
    return Future.value(_decodeSync(body));
  }

  static Object? _decodeSync(List<int> body) => jsonDecode(utf8.decode(body));
}

class _NotFound implements Exception {
  const _NotFound();
}
