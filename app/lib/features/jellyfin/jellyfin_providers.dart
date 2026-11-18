import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/jellyfin_repository.dart';
import 'package:lumio/features/settings/settings_providers.dart'
    show appVersionProvider;
import 'package:lumio/providers.dart';
import 'package:lumio_core/lumio_core.dart';

/// Accès HTTP des serveurs Jellyfin ; remplacé en test.
final jellyfinFetcherProvider = Provider<HttpFetcher>((ref) => IoHttpFetcher());

final jellyfinRepositoryProvider = Provider<JellyfinRepository>((ref) {
  final p = Platform.operatingSystem;
  return JellyfinRepository(
    ref.watch(secretStoreProvider),
    ref.watch(jellyfinFetcherProvider),
    version: ref.watch(appVersionProvider).value ?? '',
    platform: p.isEmpty ? 'Lumio' : '${p[0].toUpperCase()}${p.substring(1)}',
  );
});

/// Serveurs enregistrés ; chaque mutation recharge la liste.
final jellyfinServersProvider =
    AsyncNotifierProvider<JellyfinServersController, List<JellyfinServer>>(
      JellyfinServersController.new,
    );

class JellyfinServersController extends AsyncNotifier<List<JellyfinServer>> {
  JellyfinRepository get _repo => ref.read(jellyfinRepositoryProvider);

  /// Un trousseau illisible ne doit pas faire tomber l'accueil : pas de
  /// serveur, le reste de l'application fonctionne.
  @override
  Future<List<JellyfinServer>> build() async {
    try {
      return await _repo.list();
    } on Object {
      return const [];
    }
  }

  Future<JellyfinServer> add(
    Uri url,
    String user,
    String password, {
    bool confirmedInsecure = false,
  }) async {
    final s = await _repo.addServer(
      url,
      user,
      password,
      confirmedInsecure: confirmedInsecure,
    );
    state = AsyncData(await _repo.list());
    return s;
  }

  Future<void> remove(String serverId) async {
    await _repo.remove(serverId);
    state = AsyncData(await _repo.list());
  }
}

/// Rangée de l'accueil : une bibliothèque d'un serveur, ou une erreur.
class JellyfinRowData {
  const JellyfinRowData({
    required this.id,
    required this.title,
    required this.allowPrivate,
    this.items = const [],
    this.error,
  });

  /// `jf:<serveur>|<bibliothèque>` (ou `jf:<serveur>|error`).
  final String id;
  final String title;
  final bool allowPrivate;
  final List<MetaPreview> items;
  final Object? error;
}

/// Nombre d'éléments montrés par rangée sur l'accueil.
const jellyfinRowLimit = 20;

/// Une rangée par bibliothèque de chaque serveur. Un serveur en échec donne
/// une rangée d'erreur, sans gêner les autres.
final jellyfinRowsProvider = FutureProvider<List<JellyfinRowData>>((ref) async {
  final servers = await ref.watch(jellyfinServersProvider.future);
  final repo = ref.read(jellyfinRepositoryProvider);
  final out = <JellyfinRowData>[];
  for (final s in servers) {
    try {
      final c = await repo.client(s.id);
      if (c == null) throw const JellyfinAuthException(expired: true);
      for (final v in await c.views()) {
        final page = await c.items(v.id, limit: jellyfinRowLimit);
        out.add(
          JellyfinRowData(
            id: 'jf:${s.id}|${v.id}',
            title: '${v.name} · ${s.name}',
            allowPrivate: s.allowPrivate,
            items: [for (final it in page.items) repo.preview(s, c, it)],
          ),
        );
      }
    } on Object catch (e) {
      out.add(
        JellyfinRowData(
          id: 'jf:${s.id}|error',
          title: s.name,
          allowPrivate: s.allowPrivate,
          error: e,
        ),
      );
    }
  }
  return out;
});
