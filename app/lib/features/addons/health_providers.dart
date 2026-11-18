import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/addon_health_service.dart';
import 'package:lumio/features/settings/settings_providers.dart';
import 'package:lumio/providers.dart';
import 'package:lumio_core/lumio_core.dart';

/// Mesures de santé des addons : mémoire + persistance locale ; purgées à
/// la désinstallation d'un addon (la liste installée fait foi).
final addonHealthServiceProvider = Provider<AddonHealthService>((ref) {
  final service = AddonHealthService(
    HealthTracker(),
    ref.watch(appSettingsStoreProvider),
  );
  ref.onDispose(() {
    service.dispose();
    service.tracker.dispose();
  });
  ref.listen(addonsProvider, (_, next) {
    final list = next.value;
    if (list != null) {
      unawaited(service.keepOnly({for (final a in list) a.id}));
    }
  }, fireImmediately: true);
  return service;
});

final healthTrackerProvider = Provider<HealthTracker>(
  (ref) => ref.watch(addonHealthServiceProvider).tracker,
);

/// Identifiant de STOCKAGE d'un addon à partir de son manifeste (adresse
/// installée), jamais de `manifest.id` déclaré par l'addon. `null` si
/// l'addon n'est pas (ou plus) installé.
final healthKeyProvider = Provider<String? Function(AddonManifest)>(
  (ref) => (m) {
    final list = ref.read(addonsProvider).value;
    if (list == null) return null;
    final url = m.transportUrl.toString();
    for (final a in list) {
      if (a.manifest?.transportUrl.toString() == url) return a.id;
    }
    return null;
  },
);

/// Enveloppe [client] pour qu'il enregistre la santé de chaque addon appelé.
AddonClient withHealth(Ref ref, AddonClient client) =>
    HealthRecordingAddonClient(
      client,
      ref.read(healthTrackerProvider),
      ref.read(healthKeyProvider),
    );

/// Mesures de tous les addons. N'émet que si ce qui s'affiche change
/// (verdict, médiane arrondie, taux en %) : pas de reconstruction à chaque
/// appel réseau.
final healthSnapshotProvider = StreamProvider<Map<String, AddonHealth>>((ref) {
  final t = ref.watch(healthTrackerProvider);
  final out = StreamController<Map<String, AddonHealth>>();
  String? last;
  String sig(String id, AddonHealth h) {
    final ms = h.median.inMilliseconds;
    final shown = ms < 1000 ? ms : (ms / 100).round() * 100;
    return '$id:${h.level.index}:$shown:${(h.successRate * 100).round()}:'
        '${h.samples > 0}';
  }

  void emit() {
    if (out.isClosed) return;
    final snap = {for (final id in t.ids) id: t.stats(id)};
    final key = ([
      for (final e in snap.entries) sig(e.key, e.value),
    ]..sort()).join('|');
    if (key == last) return;
    last = key;
    out.add(snap);
  }

  // Abonné avant la première émission : aucun changement n'est manqué.
  final sub = t.changes.listen((_) => emit());
  ref.onDispose(() {
    sub.cancel();
    out.close();
  });
  emit();
  return out.stream;
});
