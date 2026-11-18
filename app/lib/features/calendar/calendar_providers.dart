import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/app_settings.dart';
import 'package:lumio/features/calendar/release_notifier.dart';
import 'package:lumio/features/detail/playback_service.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/features/settings/settings_providers.dart';
import 'package:lumio/providers.dart';
import 'package:lumio_core/lumio_core.dart';

/// Séries chargées en parallèle au plus (les addons sont ménagés).
const calendarConcurrency = 4;

/// Durée de validité d'une fiche gardée pour le calendrier.
const calendarMetaTtl = Duration(hours: 1);

/// Fiches déjà chargées (seulement celles qui ont des épisodes : un échec ou
/// une réponse vide est retenté à la prochaine ouverture).
final calendarMetaCacheProvider =
    Provider<Map<String, ({DateTime at, Meta meta})>>((ref) => {});

/// Calendrier du profil actif : les prochaines sorties et les aperçus des
/// séries de « Ma liste » (pour ouvrir leur fiche).
@immutable
class CalendarData {
  const CalendarData({required this.entries, required this.previews});

  final List<CalendarEntry> entries;

  /// Aperçu de chaque série affichée, par identifiant de fiche.
  final Map<String, MetaPreview> previews;

  bool get hasSeries => previews.isNotEmpty;
}

/// Applique [fn] à [items] avec au plus [limit] appels simultanés, dans
/// l'ordre ; le résultat garde l'ordre d'entrée.
Future<List<R>> mapLimited<T, R>(
  List<T> items,
  int limit,
  Future<R> Function(T item) fn,
) async {
  final out = List<R?>.filled(items.length, null);
  var next = 0;
  Future<void> worker() async {
    while (next < items.length) {
      final i = next++;
      out[i] = await fn(items[i]);
    }
  }

  await Future.wait([
    for (var w = 0; w < limit && w < items.length; w++) worker(),
  ]);
  return [for (final r in out) r as R];
}

final calendarProvider = FutureProvider.autoDispose<CalendarData>((ref) async {
  final profile = ref.watch(currentProfileProvider);
  final library = await ref.watch(libraryProvider.future);
  final series = [
    for (final p in visibleItems(library, profile))
      if (p.type == 'series' && p.sourceKind == 'addon') p,
  ];
  final cache = ref.read(calendarMetaCacheProvider);
  final launcher = ref.read(playbackLauncherProvider);
  final now = DateTime.now();

  Future<Meta?> load(MetaPreview p) async {
    final key = '${p.sourceAddonId}|${p.id}';
    final hit = cache[key];
    if (hit != null && now.difference(hit.at) < calendarMetaTtl) {
      return hit.meta;
    }
    try {
      final meta = await launcher.loadMeta(p);
      if (meta.videos.isNotEmpty) cache[key] = (at: now, meta: meta);
      return meta;
    } on Object {
      // Une série en échec n'empêche pas les autres : « date inconnue ».
      return Meta(id: p.id, type: p.type, name: p.name);
    }
  }

  final metas = await mapLimited(series, calendarConcurrency, load);
  final shown = <MetaPreview>[];
  final shownMetas = <Meta>[];
  for (var i = 0; i < series.length; i++) {
    final m = metas[i];
    if (m == null) continue;
    if (!contentAllowed(profile, [series[i].certification, m.certification])) {
      continue;
    }
    shown.add(series[i]);
    shownMetas.add(m);
  }
  return CalendarData(
    entries: upcoming(shownMetas, now),
    previews: {for (final p in shown) p.id: p},
  );
});

/// Réglage « Me prévenir des nouveaux épisodes » du profil actif :
/// désactivé par défaut.
final notifyReleasesProvider =
    AsyncNotifierProvider<NotifyReleasesController, bool>(
      NotifyReleasesController.new,
    );

class NotifyReleasesController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final id = ref.watch(currentProfileIdProvider);
    try {
      return await ref
              .read(appSettingsStoreProvider)
              .read(AppSettingsStore.notifyReleasesKey(id)) ==
          '1';
    } on Object {
      return false;
    }
  }

  /// Active ou désactive. L'autorisation n'est demandée qu'à l'activation ;
  /// refusée, le réglage reste désactivé et la méthode renvoie `false`.
  /// Les notifications sont reprogrammées ou annulées par
  /// `releaseSyncProvider`.
  Future<bool> set(bool value) async {
    final id = ref.read(currentProfileIdProvider);
    if (value && !await ref.read(releaseNotifierProvider).requestPermission()) {
      state = const AsyncData(false);
      return false;
    }
    state = AsyncData(value);
    await ref
        .read(appSettingsStoreProvider)
        .write(AppSettingsStore.notifyReleasesKey(id), value ? '1' : '0');
    return true;
  }
}
