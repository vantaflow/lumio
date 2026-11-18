import 'dart:async';

import '../addons/addon_client.dart';
import '../addons/manifest.dart';
import '../addons/meta_preview.dart';
import 'text_normalize.dart';

/// Recherche unifiée : interroge en parallèle les catalogues qui déclarent
/// l'extra `search`, fusionne, dédoublonne par id et trie par pertinence.
class SearchService {
  /// [clientFor] fournit le client réseau d'un addon (le niveau de confiance
  /// réseau dépend de l'addon installé, pas de son manifeste).
  SearchService(this.clientFor, {this.timeout = const Duration(seconds: 8)});

  final AddonClient Function(AddonManifest addon) clientFor;

  /// Délai maximal par addon.
  final Duration timeout;

  /// Émet, à chaque réponse d'addon, la liste fusionnée courante. Requête
  /// vide : aucun appel, une seule liste vide. Un addon en échec est ignoré.
  /// L'annulation de l'abonnement abandonne les réponses en attente.
  Stream<List<MetaPreview>> search(List<AddonManifest> addons, String query) {
    final q = query.trim();
    if (q.isEmpty) return Stream.value(const []);
    final folded = foldText(q);
    final out = StreamController<List<MetaPreview>>();
    var cancelled = false;
    out.onCancel = () => cancelled = true;

    final perAddon = List<List<MetaPreview>>.filled(addons.length, const []);

    Future<void> one(int i) async {
      final a = addons[i];
      final searchable = [
        for (final c in a.catalogs)
          if (c.extra.any((e) => e.name == 'search')) c,
      ];
      if (searchable.isEmpty) return;
      final client = clientFor(a);
      final lists = await Future.wait([
        for (final c in searchable)
          _safe(() => client.catalog(a, c.type, c.id, extra: {'search': q})),
      ]);
      if (cancelled) return;
      perAddon[i] = [for (final l in lists) ...l];
      if (perAddon[i].isNotEmpty && !out.isClosed) {
        out.add(_merge(perAddon, folded));
      }
    }

    Future.wait([for (var i = 0; i < addons.length; i++) one(i)]).whenComplete(
      () {
        if (!out.isClosed) out.close();
      },
    );
    return out.stream;
  }

  Future<List<MetaPreview>> _safe(
    Future<List<MetaPreview>> Function() f,
  ) async {
    try {
      return await f().timeout(timeout);
    } on Object {
      return const [];
    }
  }

  static List<MetaPreview> _merge(
    List<List<MetaPreview>> perAddon,
    String folded,
  ) {
    final seen = <String>{};
    final scored = <(int, int, MetaPreview)>[];
    var order = 0;
    for (final list in perAddon) {
      for (final m in list) {
        if (!seen.add(m.id)) continue;
        scored.add((_score(foldText(m.name), folded), order++, m));
      }
    }
    scored.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    return [for (final s in scored) s.$3];
  }

  /// 0 = exact, 1 = préfixe, 2 = contient, 3 = autre.
  static int _score(String name, String q) {
    if (name == q) return 0;
    if (name.startsWith(q)) return 1;
    if (name.contains(q)) return 2;
    return 3;
  }
}
