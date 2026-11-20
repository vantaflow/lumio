import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:lumio/data/db.dart';
import 'package:lumio_core/lumio_core.dart';

/// Progression de lecture d'un titre ou d'un épisode.
class ProgressEntry {
  const ProgressEntry({
    required this.profileId,
    required this.metaId,
    required this.videoId,
    required this.position,
    required this.duration,
    required this.watched,
    required this.updatedAt,
    this.certification,
    this.title,
    this.poster,
    this.mediaType,
    this.season,
    this.episode,
    this.streamAddonId,
    this.streamKey,
  });

  final String profileId;

  /// Titre ou série (`tt1`).
  final String metaId;

  /// Film (`tt1`) ou épisode (`tt1:1:2`).
  final String videoId;
  final Duration position;
  final Duration duration;
  final bool watched;
  final DateTime updatedAt;

  /// Certification d'âge du titre ; nulle si inconnue (masqué aux enfants).
  final String? certification;

  /// Titre, affiche, type, saison et épisode mémorisés à la lecture ; nuls
  /// pour une ancienne ligne.
  final String? title;
  final String? poster;
  final String? mediaType;
  final int? season;
  final int? episode;

  /// Flux regardé : identifiant de stockage de l'addon et identité non
  /// sensible du flux (voir `StreamItem.identityKey`) ; nuls pour une ancienne
  /// ligne (la reprise suit alors le classement).
  final String? streamAddonId;
  final String? streamKey;
}

/// Progression locale (SQLite) : reprise, « vu » et rangée « Continuer ».
class ProgressRepository {
  ProgressRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  static const continueLimit = 20;

  /// Enregistre la position. Si l'épisode devient « vu » et que
  /// [nextVideoId] est donné, l'épisode suivant est ajouté à 0 s (sans écraser
  /// une progression déjà entamée) pour apparaître dans « Continuer ».
  Future<void> save(
    String profileId,
    String metaId,
    String videoId,
    Duration pos,
    Duration dur, {
    String? nextVideoId,
    String? certification,
    String? title,
    String? poster,
    String? mediaType,
    int? season,
    int? episode,
    String? streamAddonId,
    String? streamKey,
  }) async {
    final stamp = _now().millisecondsSinceEpoch;
    final watched = ProgressRules.isWatched(pos, dur);
    await _db.transaction(() async {
      await _db
          .into(_db.progress)
          .insertOnConflictUpdate(
            ProgressCompanion.insert(
              profileId: Value(profileId),
              itemId: videoId,
              metaId: Value(metaId),
              positionMs: Value(pos.inMilliseconds),
              durationMs: Value(dur.inMilliseconds),
              watched: Value(watched),
              updatedAt: Value(stamp),
              certification: Value.absentIfNull(certification),
              title: Value.absentIfNull(_clean(title)),
              poster: Value.absentIfNull(_clean(poster)),
              mediaType: Value.absentIfNull(_clean(mediaType)),
              season: Value.absentIfNull(season),
              episode: Value.absentIfNull(episode),
              streamAddonId: Value.absentIfNull(_clean(streamAddonId)),
              streamKey: Value.absentIfNull(_clean(streamKey)),
            ),
          );
      if (!watched || nextVideoId == null) return;
      final existing =
          await (_db.select(_db.progress)..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.itemId.equals(nextVideoId),
              ))
              .getSingleOrNull();
      // Le suivant n'est créé que s'il n'a aucune ligne. Entamé : sa
      // progression est gardée et il passe devant (+1 ms) l'épisode qui vient
      // de finir. Déjà vu (revisionnage) : on n'y touche pas.
      if (existing != null) {
        if (!existing.watched) {
          await (_db.update(_db.progress)..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.itemId.equals(nextVideoId),
              ))
              .write(ProgressCompanion(updatedAt: Value(stamp + 1)));
        }
        return;
      }
      await _db
          .into(_db.progress)
          .insertOnConflictUpdate(
            ProgressCompanion.insert(
              profileId: Value(profileId),
              itemId: nextVideoId,
              metaId: Value(metaId),
              positionMs: const Value(0),
              durationMs: const Value(0),
              watched: const Value(false),
              updatedAt: Value(stamp + 1),
              certification: Value.absentIfNull(certification),
              title: Value.absentIfNull(_clean(title)),
              poster: Value.absentIfNull(_clean(poster)),
              mediaType: Value.absentIfNull(_clean(mediaType)),
            ),
          );
    });
  }

  static String? _clean(String? v) {
    final t = v?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  Future<ProgressEntry?> get(String profileId, String videoId) async {
    final row =
        await (_db.select(_db.progress)..where(
              (t) => t.profileId.equals(profileId) & t.itemId.equals(videoId),
            ))
            .getSingleOrNull();
    return row == null ? null : _entry(row);
  }

  /// Identifiants des épisodes (ou du film) vus du titre [metaId].
  Stream<Set<String>> watchWatched(String profileId, String metaId) {
    final q = _db.select(_db.progress)
      ..where(
        (t) =>
            t.profileId.equals(profileId) &
            t.metaId.equals(metaId) &
            t.watched.equals(true),
      );
    return q.watch().map((rows) => {for (final r in rows) r.itemId});
  }

  /// Rangée « Continuer » : une entrée par série (la plus récente), ni vue ni
  /// sous 2 %, de la plus récente à la plus ancienne, 20 au plus. Un épisode
  /// suivant ajouté à 0 s (durée inconnue) est conservé.
  Stream<List<ProgressEntry>> continueWatching(String profileId) {
    final q = _db.select(_db.progress)
      ..where((t) => t.profileId.equals(profileId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.updatedAt),
        (t) => OrderingTerm.desc(t.itemId),
      ]);
    return q.watch().map((rows) {
      final seen = <String>{};
      final out = <ProgressEntry>[];
      for (final r in rows) {
        final key = r.metaId.isEmpty ? r.itemId : r.metaId;
        if (!seen.add(key)) continue;
        if (r.watched) continue;
        final placeholder = r.durationMs == 0 && r.positionMs == 0;
        if (!placeholder &&
            ProgressRules.resumeAt(
                  Duration(milliseconds: r.positionMs),
                  Duration(milliseconds: r.durationMs),
                ) ==
                null) {
          continue;
        }
        out.add(_entry(r));
        if (out.length == continueLimit) break;
      }
      return out;
    });
  }

  ProgressEntry _entry(ProgressData r) => ProgressEntry(
    profileId: r.profileId,
    metaId: r.metaId.isEmpty ? r.itemId : r.metaId,
    videoId: r.itemId,
    position: Duration(milliseconds: r.positionMs),
    duration: Duration(milliseconds: r.durationMs),
    watched: r.watched,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt, isUtc: true),
    certification: r.certification,
    title: r.title,
    poster: r.poster,
    mediaType: r.mediaType,
    season: r.season,
    episode: r.episode,
    streamAddonId: r.streamAddonId,
    streamKey: r.streamKey,
  );
}

/// Écrit la progression pendant la lecture sans tempête d'écritures : une
/// écriture toutes les [interval] en lecture, et immédiatement (au plus une
/// par [minGap]) sur pause, fin de déplacement ou sortie.
class ProgressRecorder {
  ProgressRecorder({
    required this.save,
    this.interval = const Duration(seconds: 10),
    this.minGap = const Duration(seconds: 1),
    this.onError,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    // Pas d'écriture avant [interval] : le début de lecture (position encore
    // à 0 avant la reprise) n'écrase pas la progression existante.
    _last = _now();
  }

  /// Écriture effective (position, durée).
  final Future<void> Function(Duration pos, Duration dur) save;
  final Duration interval;
  final Duration minGap;

  /// Appelée une seule fois après [failuresBeforeNotice] échecs consécutifs.
  final void Function()? onError;
  static const failuresBeforeNotice = 3;
  int _failures = 0;
  bool _noticed = false;
  final DateTime Function() _now;

  DateTime? _last;

  /// À appeler à chaque mise à jour de position en lecture.
  void tick(Duration pos, Duration dur) {
    if (dur <= Duration.zero || pos <= Duration.zero) return;
    final last = _last;
    if (last != null && _now().difference(last) < interval) return;
    _write(pos, dur);
  }

  /// Pause, fin de déplacement ou sortie : écrit tout de suite, au plus une
  /// fois par [minGap] (sauf [force], pour la sortie).
  void flush(Duration pos, Duration dur, {bool force = false}) {
    if (dur <= Duration.zero || pos <= Duration.zero) return;
    final last = _last;
    if (!force && last != null && _now().difference(last) < minGap) return;
    _write(pos, dur);
  }

  void _write(Duration pos, Duration dur) {
    _last = _now();
    unawaited(
      save(pos, dur).then(
        (_) => _failures = 0,
        onError: (Object e) {
          // Pas d'URL ni de jeton ici : seulement le type de l'erreur.
          debugPrint('Progression non enregistrée (${e.runtimeType})');
          if (++_failures >= failuresBeforeNotice && !_noticed) {
            _noticed = true;
            onError?.call();
          }
        },
      ),
    );
  }
}
