import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lumio_core/lumio_core.dart';

/// Cache mémoire LRU des octets d'images (par URL), partagé par l'application.
class ImageBytesCache {
  ImageBytesCache({this.maxBytes = 48 * 1024 * 1024});

  final int maxBytes;
  final LinkedHashMap<String, Uint8List> _map = LinkedHashMap();
  int _size = 0;

  Uint8List? get(String key) {
    final v = _map.remove(key);
    if (v != null) _map[key] = v; // le plus récent à la fin
    return v;
  }

  void put(String key, Uint8List bytes) {
    final old = _map.remove(key);
    if (old != null) _size -= old.length;
    if (bytes.length > maxBytes) return;
    _map[key] = bytes;
    _size += bytes.length;
    while (_size > maxBytes && _map.isNotEmpty) {
      _size -= _map.remove(_map.keys.first)!.length;
    }
  }

  void clear() {
    _map.clear();
    _size = 0;
  }

  int get length => _map.length;
}

final ImageBytesCache sharedImageCache = ImageBytesCache();

/// Image réseau protégée : l'URL (et chaque redirection) passe par
/// [UrlGuard] — pas d'adresse privée sauf [allowPrivate] (addon approuvé) —,
/// taille bornée, octets mis en cache.
@immutable
class GuardedNetworkImage extends ImageProvider<GuardedNetworkImage> {
  const GuardedNetworkImage(
    this.url, {
    this.allowPrivate = false,
    this.fetcher,
    this.cache,
  });

  final Uri url;
  final bool allowPrivate;
  final HttpFetcher? fetcher;
  final ImageBytesCache? cache;

  static const maxImageBytes = 4 * 1024 * 1024;

  @override
  Future<GuardedNetworkImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    GuardedNetworkImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _load(key, decode),
    scale: 1,
    debugLabel: 'GuardedNetworkImage',
  );

  Future<ui.Codec> _load(
    GuardedNetworkImage key,
    ImageDecoderCallback decode,
  ) async {
    final cache = this.cache ?? sharedImageCache;
    final id = url.toString();
    var bytes = cache.get(id);
    if (bytes == null) {
      UrlGuard.check(url, allowPrivate: allowPrivate);
      final http =
          fetcher ??
          IoHttpFetcher(
            redirectGuard: (u) => UrlGuard.check(u, allowPrivate: allowPrivate),
          );
      final res = await http.get(
        url,
        maxBytes: maxImageBytes,
        timeout: const Duration(seconds: 8),
        guard: (u) => UrlGuard.check(u, allowPrivate: allowPrivate),
      );
      if (res.status != 200 || res.body.isEmpty) {
        throw StateError('image indisponible');
      }
      bytes = Uint8List.fromList(res.body);
      cache.put(id, bytes);
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is GuardedNetworkImage &&
      other.url == url &&
      other.allowPrivate == allowPrivate;

  @override
  int get hashCode => Object.hash(url, allowPrivate);
}
