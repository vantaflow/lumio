import 'dart:async';
import 'dart:convert';

import 'package:lumio/data/app_settings.dart';
import 'package:lumio_core/lumio_core.dart';

/// Persistance locale des mesures de santé des addons : une ligne de
/// `settings` par identifiant de STOCKAGE (`addon_health:<id>`), écrite au
/// plus une fois toutes les [flushInterval] (les mesures arrivent à chaque
/// appel réseau). Absente de la liste blanche de la sauvegarde : les
/// mesures ne quittent jamais l'appareil.
class AddonHealthService {
  AddonHealthService(
    this.tracker,
    this._store, {
    this.flushInterval = const Duration(seconds: 30),
  }) {
    _sub = tracker.changes.listen(_onChange);
    ready = _hydrate();
  }

  static const keyPrefix = 'addon_health:';
  static String keyFor(String storageId) => '$keyPrefix$storageId';

  final HealthTracker tracker;
  final AppSettingsStore _store;
  final Duration flushInterval;

  /// Fin du chargement des mesures sauvegardées.
  late final Future<void> ready;

  late final StreamSubscription<String> _sub;
  final Set<String> _dirty = {};

  /// Identifiants ayant une ligne enregistrée.
  final Set<String> _stored = {};

  /// Addons installés connus ; `null` tant que la liste n'est pas chargée.
  Set<String>? _installed;
  bool _hydrating = false;
  bool _disposed = false;
  Timer? _timer;

  Future<void> _hydrate() async {
    try {
      final rows = await _store.readPrefix(keyPrefix);
      if (_disposed) return;
      _hydrating = true;
      try {
        for (final e in rows.entries) {
          final id = e.key.substring(keyPrefix.length);
          _stored.add(id);
          try {
            tracker.loadAddon(id, jsonDecode(e.value));
          } on FormatException {
            // Ligne illisible : ignorée, réécrite à la prochaine mesure.
          }
        }
      } finally {
        _hydrating = false;
      }
    } on Object {
      // Base illisible : les mesures repartent de zéro, sans bloquer l'appli.
    }
  }

  void _onChange(String id) {
    if (_hydrating || _disposed) return;
    _dirty.add(id);
    _timer ??= Timer(flushInterval, flush);
  }

  /// Écrit sans attendre les mesures modifiées.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    final ids = _dirty.toList();
    _dirty.clear();
    for (final id in ids) {
      if (_installed != null && !_installed!.contains(id)) continue;
      try {
        final json = tracker.toJsonFor(id);
        if (json == null) {
          if (_stored.remove(id)) await _store.delete(keyFor(id));
        } else {
          await _store.write(keyFor(id), jsonEncode(json));
          _stored.add(id);
        }
      } on Object {
        // Écriture manquée : les mesures restent en mémoire.
      }
    }
  }

  /// Efface les mesures d'un addon, en mémoire et sur disque.
  Future<void> reset(String storageId) async {
    await ready;
    tracker.reset(storageId);
    _dirty.add(storageId);
    await flush();
  }

  /// Oublie (mémoire et disque) tout addon absent de [installed].
  Future<void> keepOnly(Set<String> installed) async {
    await ready;
    if (_disposed) return;
    _installed = installed;
    for (final id in [...tracker.ids]) {
      if (!installed.contains(id)) tracker.remove(id);
    }
    _dirty.removeWhere((id) => !installed.contains(id));
    for (final id in _stored.where((i) => !installed.contains(i)).toList()) {
      _stored.remove(id);
      try {
        await _store.delete(keyFor(id));
      } on Object {
        // Sera retenté à la prochaine modification de la liste.
        _stored.add(id);
      }
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _sub.cancel();
  }
}
