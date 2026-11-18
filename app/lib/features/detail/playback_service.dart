import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/addon_repository.dart';
import 'package:lumio/data/stream_prefs.dart';
import 'package:lumio/features/addons/health_providers.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/player/player_screen.dart';
import 'package:lumio/providers.dart';
import 'package:lumio_core/lumio_core.dart' hide Video;
import 'package:lumio_core/lumio_core.dart' as core show Video;

/// Client qui choisit, pour CHAQUE addon, le niveau de confiance réseau
/// dérivé de l'URL installée (jamais de l'identifiant du manifeste). Un seul
/// client sert ainsi `MetaService`, `StreamService` et `SubtitleService`.
class RoutingAddonClient extends AddonClient {
  RoutingAddonClient({
    AddonClientFactory factory = defaultAddonClient,
    HealthTracker? health,
    String? Function(AddonManifest)? healthKey,
  }) : _factory = factory,
       _health = health,
       _healthKey = healthKey,
       super(const _NoFetcher());

  final AddonClientFactory _factory;
  final HealthTracker? _health;
  final String? Function(AddonManifest)? _healthKey;

  /// Client de cet addon ; s'il y a un suivi de santé, chaque appel y est
  /// enregistré sous l'identifiant de stockage de l'addon.
  AddonClient _for(AddonManifest a) {
    final client = _factory(allowPrivate: isPrivateAddress(a.transportUrl));
    final health = _health;
    final key = _healthKey;
    return health == null || key == null
        ? client
        : HealthRecordingAddonClient(client, health, key);
  }

  @override
  Future<Map<String, dynamic>?> rawMeta(
    AddonManifest a,
    String type,
    String id,
  ) => _for(a).rawMeta(a, type, id);

  @override
  Future<List<Map<String, dynamic>>> rawStreams(
    AddonManifest a,
    String type,
    String id,
  ) => _for(a).rawStreams(a, type, id);

  @override
  Future<List<Map<String, dynamic>>> rawSubtitles(
    AddonManifest a,
    String type,
    String id,
  ) => _for(a).rawSubtitles(a, type, id);
}

class _NoFetcher implements HttpFetcher {
  const _NoFetcher();

  @override
  Future<FetchResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    int maxBytes = 5 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 8),
    void Function(Uri target)? guard,
  }) => throw StateError('RoutingAddonClient ne fait aucun appel direct');
}

/// Client d'addons partagé par la fiche, les flux et les sous-titres.
final addonClientProvider = Provider<AddonClient>(
  (ref) => RoutingAddonClient(
    health: ref.watch(healthTrackerProvider),
    healthKey: ref.read(healthKeyProvider),
  ),
);

/// Addon actif, rattaché à son identifiant de STOCKAGE (unique).
class ActiveAddon {
  const ActiveAddon(
    this.storageId,
    this.manifest, {
    required this.allowPrivate,
  });

  final String storageId;
  final AddonManifest manifest;
  final bool allowPrivate;
}

final activeAddonsProvider = Provider<List<ActiveAddon>>((ref) {
  final list = ref.watch(addonsProvider).value ?? const <InstalledAddon>[];
  return [
    for (final a in list)
      if (a.enabled && !a.broken)
        ActiveAddon(
          a.id,
          a.manifest!,
          allowPrivate: isPrivateAddress(a.manifest!.transportUrl),
        ),
  ];
});

final metaServiceProvider = Provider<MetaService>(
  (ref) => MetaService(ref.watch(addonClientProvider)),
);

final streamPrefsStoreProvider = Provider<StreamPrefsStore>(
  (ref) => StreamPrefsStore(ref.watch(appDatabaseProvider)),
);

/// Préférences de flux du profil actif.
final streamPrefsProvider = FutureProvider<StreamPrefs>((ref) async {
  final id = ref.watch(currentProfileIdProvider);
  try {
    return await ref.watch(streamPrefsStoreProvider).load(id);
  } on Object {
    return const StreamPrefs();
  }
});

/// Habille l'écran du lecteur avant sa mise en route ; remplacé en test pour
/// observer les paramètres sans démarrer de moteur vidéo.
final playerBuilderProvider = Provider<Widget Function(PlayerScreen screen)>(
  (ref) =>
      (screen) => screen,
);

final playbackLauncherProvider = Provider<PlaybackLauncher>(
  (ref) => PlaybackLauncher(ref),
);

/// Type de contenu déduit d'une progression (qui ne garde que des
/// identifiants) : un épisode a un identifiant `<titre>:<saison>:<épisode>`.
String typeForVideo(String metaId, String videoId) =>
    videoId != metaId && videoId.startsWith('$metaId:') ? 'series' : 'movie';

/// Flux et sous-titres d'un titre, choix du flux préféré et ouverture du
/// lecteur : partagé par la fiche et la reprise en un clic de l'accueil.
class PlaybackLauncher {
  PlaybackLauncher(this._ref);

  final Ref _ref;

  /// Addons actifs, une fois la liste chargée depuis la base.
  Future<List<ActiveAddon>> _addons() async {
    try {
      await _ref.read(addonsProvider.future);
    } on Object {
      // Liste illisible : traitée comme vide.
    }
    return _ref.read(activeAddonsProvider);
  }

  Future<Meta> loadMeta(MetaPreview p) async {
    final addons = await _addons();
    return _ref.read(metaServiceProvider).load([
      for (final a in addons) a.manifest,
    ], p);
  }

  /// Flux de [id] : un groupe par addon, rattaché à l'identifiant de
  /// stockage (les `addonId` des flux sont réécrits : l'identifiant du
  /// manifeste, déclaré par l'addon, ne sert jamais à décider d'un accès).
  Stream<StreamGroup> loadStreams(String type, String id) {
    final service = StreamService(_ref.read(addonClientProvider));
    final out = StreamController<StreamGroup>();
    final subs = <StreamSubscription<StreamGroup>>[];
    var cancelled = false;
    out.onCancel = () {
      cancelled = true;
      for (final s in subs) {
        s.cancel();
      }
    };
    () async {
      final addons = await _addons();
      if (cancelled || out.isClosed) return;
      var pending = addons.length;
      if (pending == 0) {
        await out.close();
        return;
      }
      for (final a in addons) {
        subs.add(
          service
              .load([a.manifest], type, id)
              .listen(
                (g) {
                  if (out.isClosed) return;
                  out.add(
                    StreamGroup(
                      addonId: a.storageId,
                      error: g.error,
                      items: [
                        for (final s in g.items) retagStream(s, a.storageId),
                      ],
                    ),
                  );
                },
                onDone: () {
                  if (--pending == 0 && !out.isClosed) out.close();
                },
              ),
        );
      }
    }();
    return out.stream;
  }

  /// Sous-titres de [id], `addonId` réécrit en identifiant de stockage.
  Future<List<SubtitleItem>> loadSubtitles(String type, String id) async {
    final addons = await _addons();
    final service = SubtitleService(_ref.read(addonClientProvider));
    final lists = await Future.wait([
      for (final a in addons)
        service
            .load([a.manifest], type, id)
            .then(
              (l) => [
                for (final s in l)
                  SubtitleItem(
                    id: s.id,
                    url: s.url,
                    lang: s.lang,
                    addonId: a.storageId,
                  ),
              ],
            )
            .catchError((Object _) => const <SubtitleItem>[]),
    ]);
    final seen = <String>{};
    return [
      for (final l in lists)
        for (final s in l)
          if (seen.add(s.url.toString())) s,
    ];
  }

  /// Meilleur flux de [id] selon les préférences du profil ; `null` si aucun.
  /// Le classement des préférences (langue, qualité, lien direct avant torrent
  /// à égalité) décide seul : un torrent est lu comme un autre flux.
  Future<StreamItem?> resolvePreferred(String type, String id) async {
    final prefs = await _ref.read(streamPrefsProvider.future);
    final all = <StreamItem>[];
    await for (final g in loadStreams(type, id)) {
      all.addAll(g.items);
    }
    return preferredStream(all, prefs);
  }

  bool allowPrivateFor(String storageId) => _ref
      .read(activeAddonsProvider)
      .any((a) => a.storageId == storageId && a.allowPrivate);

  /// Ouvre le lecteur sur [stream] (déjà rattaché à un identifiant de
  /// stockage). Un flux torrent est préparé par le lecteur lui-même.
  Future<PlayerExit?> play(
    BuildContext context, {
    required Meta meta,
    required String videoId,
    required StreamItem stream,
  }) async {
    final navigator = Navigator.of(context);
    final profileId = _ref.read(currentProfileIdProvider);
    final subtitles = await loadSubtitles(
      meta.type,
      videoId,
    ).catchError((Object _) => const <SubtitleItem>[]);
    final screen = PlayerScreen(
      item: stream,
      allowPrivate: allowPrivateFor(stream.addonId),
      allowPrivateForAddon: allowPrivateFor,
      metaId: meta.id,
      profileId: profileId,
      videoId: videoId,
      meta: meta,
      subtitles: subtitles,
      resolveNext: (core.Video next) => resolvePreferred(meta.type, next.id),
    );
    final build = _ref.read(playerBuilderProvider);
    return navigator.push<PlayerExit>(
      MaterialPageRoute(builder: (_) => build(screen)),
    );
  }
}

/// Copie d'un flux avec un autre `addonId`.
StreamItem retagStream(StreamItem s, String addonId) => StreamItem(
  addonId: addonId,
  title: s.title,
  url: s.url,
  infoHash: s.infoHash,
  fileIdx: s.fileIdx,
  quality: s.quality,
  language: s.language,
  sizeBytes: s.sizeBytes,
  seeders: s.seeders,
  requestHeaders: s.requestHeaders,
  notWebReady: s.notWebReady,
  trackers: s.trackers,
);
