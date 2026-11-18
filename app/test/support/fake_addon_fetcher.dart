import 'dart:convert';
import 'dart:io';

import 'package:lumio_core/lumio_core.dart';

/// Fetcher factice : renvoie des manifestes préparés par URL exacte ; toute
/// autre URL est injoignable. Compte les requêtes.
class FakeAddonFetcher implements HttpFetcher {
  FakeAddonFetcher([Map<String, Map<String, Object?>>? manifests])
    : manifests = manifests ?? {};

  final Map<String, Map<String, Object?>> manifests;
  final List<Uri> requested = [];

  @override
  Future<FetchResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) async {
    guard?.call(url);
    requested.add(url);
    final m = manifests[url.toString()];
    if (m == null) throw const SocketException('injoignable');
    return FetchResponse(status: 200, body: utf8.encode(jsonEncode(m)));
  }
}

Map<String, Object?> sampleManifest({
  String id = 'org.example.films',
  String name = 'Films libres',
  List<String> types = const ['movie', 'series'],
  String? logo,
}) => {
  'id': id,
  'version': '1.0.0',
  'name': name,
  'description': 'Un addon de test',
  'logo': ?logo,
  'types': types,
  'resources': ['catalog', 'meta', 'stream'],
  'catalogs': [
    {'type': 'movie', 'id': 'top', 'name': 'Populaires'},
  ],
};
