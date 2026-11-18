import 'dart:async';

import 'package:lumio_core/lumio_core.dart';

/// « Ma liste » : titres mis de côté par profil. Task 19 fournit
/// l'implémentation persistante ; l'accueil ne dépend que de cette interface.
abstract class LibraryRepository {
  Stream<List<MetaPreview>> watch(String profileId);
}

/// Implémentation mémoire (par défaut tant que la persistance n'existe pas).
class InMemoryLibraryRepository implements LibraryRepository {
  final Map<String, List<MetaPreview>> _items = {};
  final Map<String, StreamController<List<MetaPreview>>> _ctrl = {};

  List<MetaPreview> _of(String profileId) => _items[profileId] ?? const [];

  Future<void> add(String profileId, MetaPreview item) async {
    final list = [..._of(profileId)];
    if (list.any((m) => m.id == item.id)) return;
    _items[profileId] = [item, ...list];
    _ctrl[profileId]?.add(_of(profileId));
  }

  Future<void> remove(String profileId, String metaId) async {
    _items[profileId] = [
      for (final m in _of(profileId))
        if (m.id != metaId) m,
    ];
    _ctrl[profileId]?.add(_of(profileId));
  }

  @override
  Stream<List<MetaPreview>> watch(String profileId) {
    final c = _ctrl.putIfAbsent(
      profileId,
      () => StreamController<List<MetaPreview>>.broadcast(),
    );
    return Stream<List<MetaPreview>>.multi((m) {
      m.add(_of(profileId));
      final sub = c.stream.listen(m.add);
      m.onCancel = sub.cancel;
    });
  }
}
