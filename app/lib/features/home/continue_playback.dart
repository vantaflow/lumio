import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/progress_repository.dart';
import 'package:lumio/features/detail/detail_screen.dart';
import 'package:lumio/features/detail/playback_service.dart';
import 'package:lumio/features/home/home_providers.dart';
import 'package:lumio/player/player_screen.dart';
import 'package:lumio/providers.dart';
import 'package:lumio_core/lumio_core.dart';

/// Ce que l'accueil affiche pour une entrée « Continuer ».
class ContinueInfo {
  const ContinueInfo({required this.title, this.subtitle, this.poster});

  final String title;
  final String? subtitle;
  final Uri? poster;
}

/// Lecture en un clic d'une entrée « Continuer » à la bonne position.
abstract class ContinuePlayback {
  /// Titre à afficher (la progression ne porte que des identifiants).
  Future<ContinueInfo> describe(ProgressEntry entry);

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
  DefaultContinuePlayback(this._ref);

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

  @override
  Future<ContinueInfo> describe(ProgressEntry entry) async {
    final meta = await _meta(entry);
    return ContinueInfo(
      title: meta.name,
      subtitle: episodeLabel(meta, entry.videoId),
      poster: meta.poster,
    );
  }

  @override
  Future<void> play(BuildContext context, ProgressEntry entry) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    void tell(String m) => messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
    final launcher = _ref.read(playbackLauncherProvider);
    final Meta meta;
    try {
      meta = await _meta(entry);
    } on Object {
      tell('Fiche indisponible. Réessayez.');
      return;
    }
    if (!profileAllows(
      _ref.read(currentProfileProvider),
      meta.certification ?? entry.certification,
    )) {
      tell('Ce contenu n\'est pas autorisé pour ce profil.');
      return;
    }
    final type = meta.type;
    final stream = await launcher.resolvePreferred(type, entry.videoId);
    if (!context.mounted) return;
    if (stream == null) {
      tell('Aucune source disponible. Vérifiez vos addons.');
      return;
    }
    final exit = await launcher.play(
      context,
      meta: meta,
      videoId: entry.videoId,
      stream: stream,
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
