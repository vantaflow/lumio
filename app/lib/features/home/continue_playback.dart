import 'package:flutter/material.dart';
import 'package:lumio/data/progress_repository.dart';

/// Ce que l'accueil affiche pour une entrée « Continuer ».
class ContinueInfo {
  const ContinueInfo({required this.title, this.subtitle, this.poster});

  final String title;
  final String? subtitle;
  final Uri? poster;
}

/// Lecture en un clic d'une entrée « Continuer » à la bonne position.
/// La résolution des flux appartient à Task 19, qui remplace
/// [StubContinuePlayback] via `continuePlaybackProvider`.
abstract class ContinuePlayback {
  /// Titre à afficher (la progression ne porte que des identifiants).
  Future<ContinueInfo> describe(ProgressEntry entry);

  /// Lance (ou reprend) la lecture de [entry].
  Future<void> play(BuildContext context, ProgressEntry entry);
}

class StubContinuePlayback implements ContinuePlayback {
  const StubContinuePlayback();

  @override
  Future<ContinueInfo> describe(ProgressEntry entry) async {
    final parts = entry.videoId.split(':');
    final episode = parts.length >= 3
        ? 'Saison ${parts[parts.length - 2]} · épisode ${parts.last}'
        : null;
    return ContinueInfo(title: entry.metaId, subtitle: episode);
  }

  @override
  Future<void> play(BuildContext context, ProgressEntry entry) async {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('La reprise de lecture arrive bientôt.')),
    );
  }
}
