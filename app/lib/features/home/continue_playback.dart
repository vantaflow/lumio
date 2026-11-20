import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/l10n/l10n.dart';
import 'package:lumio/features/settings/settings_providers.dart'
    show localeProvider;
import 'package:lumio/data/progress_repository.dart';
import 'package:lumio/data/jellyfin_repository.dart'
    show isJellyfinId, parseJellyfinId;
import 'package:lumio/data/local_library.dart' show LocalItemView, isLocalId;
import 'package:lumio/features/detail/detail_screen.dart';
import 'package:lumio/features/detail/playback_service.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/features/jellyfin/jellyfin_providers.dart';
import 'package:lumio/features/jellyfin/jellyfin_screen.dart';
import 'package:lumio/features/local/local_providers.dart';
import 'package:lumio/features/local/local_screen.dart';
import 'package:lumio/player/player_screen.dart';
import 'package:lumio/providers.dart';
import 'package:lumio_core/lumio_core.dart';

/// Ce que l'accueil affiche pour une entrée « Continuer ».
class ContinueInfo {
  const ContinueInfo({
    required this.title,
    this.subtitle,
    this.poster,
    this.allowPrivate = false,
  });

  final String title;
  final String? subtitle;
  final Uri? poster;

  /// L'affiche vient d'un serveur du réseau privé approuvé (Jellyfin).
  final bool allowPrivate;
}

/// Lecture en un clic d'une entrée « Continuer » à la bonne position.
abstract class ContinuePlayback {
  /// Titre à afficher (la progression ne porte que des identifiants).
  Future<ContinueInfo> describe(ProgressEntry entry);

  /// Image de fond « background » de l'addon (paysage, haute définition), ou
  /// null : le héros de l'accueil la préfère à l'affiche.
  Future<Uri?> backdrop(ProgressEntry entry);

  /// Lance (ou reprend) la lecture de [entry].
  Future<void> play(BuildContext context, ProgressEntry entry);
}

/// « SxEy » d'un épisode, `null` pour un film ou un épisode inconnu.
String? episodeLabel(Meta meta, String videoId) {
  for (final v in meta.videos) {
    if (v.id != videoId) continue;
    final s = v.season, e = v.episode;
    if (s == null || e == null) return v.title;
    return 'S${s}E$e';
  }
  return null;
}

/// Implémentation réelle : titre depuis `MetaService`, lecture au flux
/// préféré du profil, à la position enregistrée (le lecteur reprend seul).
class DefaultContinuePlayback implements ContinuePlayback {
  DefaultContinuePlayback(this._ref) {
    // Les fiches mises en cache dépendent des addons installés.
    _ref.listen(activeAddonsProvider, (_, _) => _metas.clear());
  }

  final Ref _ref;
  final Map<String, Future<Meta>> _metas = {};

  Future<Meta> _meta(ProgressEntry e) {
    final cached = _metas[e.metaId];
    if (cached != null) return cached;
    final f = _ref
        .read(playbackLauncherProvider)
        .loadMeta(
          MetaPreview(
            id: e.metaId,
            type: typeForVideo(e.metaId, e.videoId),
            name: e.metaId,
            sourceAddonId: '',
            certification: e.certification,
          ),
        );
    _metas[e.metaId] = f;
    // Un échec n'est pas gardé : la carte réessaiera.
    f.catchError((Object _) {
      _metas.remove(e.metaId);
      return Meta(id: e.metaId, type: 'movie', name: e.metaId);
    });
    return f;
  }

  /// Libellé « SxEy » d'après la saison et l'épisode mémorisés.
  static String? _storedEpisode(ProgressEntry e) {
    if (e.season != null && e.episode != null) {
      return 'S${e.season}E${e.episode}';
    }
    // Épisode ajouté à 0 s (suite d'un épisode vu) : ni saison ni épisode
    // mémorisés, mais l'identifiant de la vidéo les porte (`meta:S:E` ou
    // `meta:E`).
    final prefix = '${e.metaId}:';
    if (!e.videoId.startsWith(prefix)) return null;
    final rest = e.videoId.substring(prefix.length).split(':');
    final nums = [for (final r in rest) int.tryParse(r)];
    if (nums.any((n) => n == null)) return null;
    return switch (nums.length) {
      1 => 'E${nums[0]}',
      2 => 'S${nums[0]}E${nums[1]}',
      _ => null,
    };
  }

  String get _unknown =>
      lookupAppLocalizations(_ref.read(localeProvider)).unknownTitle;

  @override
  Future<ContinueInfo> describe(ProgressEntry entry) async {
    if (isLocalId(entry.metaId)) {
      final item = await _ref.read(localLibraryProvider).item(entry.metaId);
      return ContinueInfo(
        title: item?.displayTitle ?? entry.title ?? _unknown,
        subtitle: item?.episodeLabel,
      );
    }
    if (isJellyfinId(entry.metaId)) return _describeJellyfin(entry);
    // Titre et affiche mémorisés à la lecture : aucune requête.
    final stored = entry.title;
    if (stored != null && stored.isNotEmpty) {
      return ContinueInfo(
        title: stored,
        subtitle: _storedEpisode(entry),
        poster: Uri.tryParse(entry.poster ?? ''),
      );
    }
    // Ancienne ligne : requête meta ; jamais d'identifiant brut affiché.
    try {
      final meta = await _meta(entry);
      final name = meta.name.trim();
      final raw = name.isEmpty || name == entry.metaId;
      return ContinueInfo(
        title: raw ? _unknown : name,
        subtitle: episodeLabel(meta, entry.videoId),
        poster: meta.poster,
      );
    } catch (_) {
      return ContinueInfo(title: _unknown);
    }
  }

  Future<ContinueInfo> _describeJellyfin(ProgressEntry entry) async {
    final ids = parseJellyfinId(entry.metaId);
    if (ids == null) return ContinueInfo(title: entry.title ?? _unknown);
    final repo = _ref.read(jellyfinRepositoryProvider);
    final server = await repo.server(ids.serverId);
    final client = await repo.client(ids.serverId);
    if (server == null || client == null) {
      return ContinueInfo(title: entry.title ?? _unknown);
    }
    final it = await client.item(ids.itemId);
    return ContinueInfo(
      title: it.name,
      subtitle: it.seriesName,
      poster: it.imageTag == null
          ? null
          : client.imageUrl(it.id, tag: it.imageTag),
      allowPrivate: server.allowPrivate,
    );
  }

  @override
  Future<Uri?> backdrop(ProgressEntry entry) async {
    if (isLocalId(entry.metaId) || isJellyfinId(entry.metaId)) return null;
    try {
      return (await _meta(entry)).background;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> play(BuildContext context, ProgressEntry entry) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = context.l10n;
    void tell(String m) => messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
    if (isLocalId(entry.metaId)) {
      final library = _ref.read(localLibraryProvider);
      final item = await library.item(entry.metaId);
      if (!context.mounted) return;
      if (item == null) {
        tell(l.localFileMissing);
        return;
      }
      // Fichier local : jamais de certification, refusé aux profils enfants.
      await playLocalItem(
        context,
        library: library,
        item: item,
        profileId: _ref.read(currentProfileIdProvider),
        allowed: contentAllowed(_ref.read(currentProfileProvider), [
          entry.certification,
        ]),
        build: _ref.read(playerBuilderProvider),
      );
      return;
    }
    if (isJellyfinId(entry.metaId)) {
      final ids = parseJellyfinId(entry.metaId);
      if (ids == null) {
        tell(l.sheetUnavailable);
        return;
      }
      // La classification est relue sur le serveur à chaque lecture ;
      // `playJellyfinItem` refuse un profil enfant sans classification connue.
      await playJellyfinItem(
        context,
        repo: _ref.read(jellyfinRepositoryProvider),
        profile: _ref.read(currentProfileProvider),
        profileId: _ref.read(currentProfileIdProvider),
        build: _ref.read(playerBuilderProvider),
        serverId: ids.serverId,
        itemId: ids.itemId,
      );
      return;
    }
    final launcher = _ref.read(playbackLauncherProvider);
    final Meta meta;
    try {
      meta = await _meta(entry);
    } on Object {
      tell(l.sheetUnavailable);
      return;
    }
    if (!contentAllowed(_ref.read(currentProfileProvider), [
      meta.certification,
      entry.certification,
    ])) {
      tell(l.notAllowedForProfile);
      return;
    }
    final type = meta.type;
    final ranked = await launcher.resolveRanked(type, entry.videoId);
    if (!context.mounted) return;
    if (ranked.isEmpty) {
      tell(l.noSourceAvailable);
      return;
    }
    // Le flux regardé la dernière fois (même addon, même torrent ou même
    // lien) ; à défaut (addon supprimé, flux absent) le meilleur du classement
    // actuel, avec un message. Une ancienne entrée sans identité suit le
    // classement, sans message.
    final saved = findSavedStream(
      ranked,
      addonId: entry.streamAddonId,
      key: entry.streamKey,
    );
    final chosen = saved ?? ranked.first;
    final lost = saved == null && entry.streamKey != null;
    final exit = await launcher.play(
      context,
      meta: meta,
      videoId: entry.videoId,
      stream: chosen,
      fallbacks: [
        for (final s in ranked)
          if (!identical(s, chosen)) s,
      ].take(maxFallbacks).toList(),
      startNotice: lost ? l.resumeSourceGone : null,
    );
    // « Choisir une autre source » : la fiche s'ouvre sur la liste des flux.
    if (exit == PlayerExit.pickAnother && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetailScreen(
            preview: MetaPreview(
              id: meta.id,
              type: meta.type,
              name: meta.name,
              poster: meta.poster,
              releaseInfo: meta.releaseInfo,
              certification: meta.certification,
              sourceAddonId: '',
            ),
          ),
        ),
      );
    }
  }
}
