import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio_core/lumio_core.dart';
import 'package:path_provider/path_provider.dart';

/// Cache du catalogue dans le dossier de support de l'application ; le
/// dossier n'est résolu qu'au premier accès.
class LazyFileCatalogStore implements CatalogCacheStore {
  FileCatalogCacheStore? _store;

  Future<CatalogCacheStore> _open() async {
    final dir = await getApplicationSupportDirectory();
    return _store ??= FileCatalogCacheStore(
      Directory('${dir.path}${Platform.pathSeparator}addon_catalog'),
    );
  }

  @override
  Future<CachedCatalogEntry?> read(String key) async {
    try {
      return await (await _open()).read(key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String data, DateTime at) async {
    try {
      await (await _open()).write(key, data, at);
    } catch (_) {}
  }
}

/// Catalogue d'addons : requêtes gardées (UrlGuard, hôtes privés refusés),
/// cache de 24 h, hors ligne, repli sur la collection officielle.
final addonCatalogServiceProvider = Provider<AddonCatalogService>(
  (ref) => AddonCatalogService(
    AddonCatalogSource(
      IoHttpFetcher(
        connectionFactory: guardedConnectionFactory(allowPrivate: false),
        redirectGuard: (u) => UrlGuard.check(u),
      ),
    ),
    LazyFileCatalogStore(),
  ),
);
