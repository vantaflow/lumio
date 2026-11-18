import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:drift/drift.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/player/play_router.dart'
    show LocalFileSource, localVideoExtensions;
import 'package:lumio_core/lumio_core.dart' show MetaPreview, parseMediaName;
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

/// Profondeur maximale d'analyse sous un dossier accordé (le dossier = 0).
const maxScanDepth = 6;

/// Une analyse automatique n'est refaite qu'après ce délai.
const rescanInterval = Duration(hours: 6);

/// Source des éléments locaux dans les aperçus (`MetaPreview.sourceKind`).
const localSourceKind = 'local';

/// Préfixe des identifiants de titres locaux (progression, « Continuer »).
const localIdPrefix = 'local:';

bool isLocalId(String id) => id.startsWith(localIdPrefix);

/// Identifiant stable d'un fichier : `local:<sha1 du chemin>`.
String localItemId(String path) =>
    '$localIdPrefix${sha1.convert(utf8.encode(path))}';

/// Chemin de dossier normalisé (absolu, sans séparateur final).
String normalizeFolder(String path) => p.normalize(p.absolute(path.trim()));

/// Raison d'échec d'une analyse.
enum LocalScanFailure { missing, denied, other }

class LocalScanException implements Exception {
  const LocalScanException(this.failure);
  final LocalScanFailure failure;

  @override
  String toString() => 'LocalScanException: ${failure.name}';
}

/// Le dossier recoupe un dossier déjà accordé (contenu dans l'un, ou en
/// contenant un) : les mêmes fichiers seraient comptés deux fois.
class LocalFolderOverlapException implements Exception {
  const LocalFolderOverlapException();
}

/// Vidéo trouvée par l'analyse (types simples : passe d'un isolat à l'autre).
class ScannedFile {
  const ScannedFile({
    required this.path,
    required this.fileName,
    required this.title,
    required this.sizeBytes,
    required this.modifiedAt,
    this.year,
    this.season,
    this.episode,
  });

  final String path;
  final String fileName;
  final String title;
  final int? year, season, episode;
  final int sizeBytes;
  final int modifiedAt;
}

/// Plafonds d'une analyse : entrées visitées et durée.
const maxScanEntries = 50000;
const maxScanDuration = Duration(seconds: 60);

/// Résultat d'une analyse ; [truncated] : un plafond a été atteint, la liste
/// est partielle.
class ScanResult {
  const ScanResult(this.files, {this.truncated = false});
  final List<ScannedFile> files;
  final bool truncated;
}

/// Analyse récursive de [dir] (synchrone : à lancer hors du fil de l'interface,
/// voir [scanInIsolate]). Profondeur ≤ [maxDepth], dossiers et fichiers
/// cachés (`.nom`) ignorés. Les liens symboliques vers des dossiers ne sont
/// jamais suivis (ceux qui restent dans [dir] feraient des doublons, les
/// autres sortiraient du dossier accordé) ; un fichier lié n'est gardé que
/// si sa cible reste dans [dir]. Arrêt dès [maxEntries] entrées visitées ou
/// [maxDuration] écoulée : résultat partiel marqué `truncated`.
ScanResult scanLocalFolderResult(
  String dir, {
  int maxDepth = maxScanDepth,
  int maxEntries = maxScanEntries,
  Duration maxDuration = maxScanDuration,
}) {
  final rootDir = Directory(dir);
  if (!rootDir.existsSync()) {
    throw const LocalScanException(LocalScanFailure.missing);
  }
  final String realRoot;
  try {
    realRoot = rootDir.resolveSymbolicLinksSync();
  } on FileSystemException {
    throw const LocalScanException(LocalScanFailure.denied);
  }
  final clock = Stopwatch()..start();
  var visited = 0;
  var truncated = false;
  final seen = <String>{};
  final out = <ScannedFile>[];

  bool inside(String real) => real == realRoot || p.isWithin(realRoot, real);

  void walk(Directory d, int depth) {
    if (truncated) return;
    final String real;
    try {
      real = d.resolveSymbolicLinksSync();
    } on FileSystemException {
      return;
    }
    if (!inside(real) || !seen.add(real)) return;
    final List<FileSystemEntity> entries;
    try {
      entries = d.listSync(followLinks: false);
    } on FileSystemException {
      if (depth == 0) throw const LocalScanException(LocalScanFailure.denied);
      return; // sous-dossier illisible : ignoré
    }
    for (final e in entries) {
      if (++visited > maxEntries || clock.elapsed >= maxDuration) {
        truncated = true;
        return;
      }
      final name = p.basename(e.path);
      if (name.startsWith('.')) continue;
      FileSystemEntityType type;
      try {
        type = FileSystemEntity.typeSync(e.path); // suit les liens
      } on FileSystemException {
        continue;
      }
      if (type == FileSystemEntityType.directory) {
        if (e is Link) continue; // jamais suivi (doublon ou hors du dossier)
        if (depth < maxDepth) walk(Directory(e.path), depth + 1);
        if (truncated) return;
      } else if (type == FileSystemEntityType.file) {
        final ext = p.extension(name).replaceFirst('.', '').toLowerCase();
        if (!localVideoExtensions.contains(ext)) continue;
        if (e is Link) {
          try {
            if (!inside(File(e.path).resolveSymbolicLinksSync())) continue;
          } on FileSystemException {
            continue;
          }
        }
        try {
          final st = FileStat.statSync(e.path);
          final parsed = parseMediaName(name);
          out.add(
            ScannedFile(
              path: e.path,
              fileName: name,
              title: parsed.title,
              year: parsed.year,
              season: parsed.season,
              episode: parsed.episode,
              sizeBytes: st.size,
              modifiedAt: st.modified.millisecondsSinceEpoch,
            ),
          );
        } on FileSystemException {
          continue;
        }
      }
    }
  }

  walk(rootDir, 0);
  out.sort((a, b) => a.path.compareTo(b.path));
  return ScanResult(out, truncated: truncated);
}

/// Liste seule (voir [scanLocalFolderResult]).
List<ScannedFile> scanLocalFolder(String dir, {int maxDepth = maxScanDepth}) =>
    scanLocalFolderResult(dir, maxDepth: maxDepth).files;

/// [scanLocalFolderResult] dans un isolat : l'interface ne gèle pas.
Future<ScanResult> scanInIsolate(String dir) =>
    Isolate.run(() => scanLocalFolderResult(dir));

/// Dossier interdit à l'ajout : racine du système de fichiers, dossiers
/// système (`/proc`, `/sys`, `/dev`, `/etc`, `/System`, `/private/etc`,
/// `C:\`, dossier Windows…). [path] doit être absolu et normalisé.
bool isForbiddenFolder(String path, {p.Context? context}) {
  final ctx = context ?? p.context;
  final n = ctx.normalize(path);
  if (ctx.style == p.Style.windows) {
    if (RegExp(r'^[A-Za-z]:\\?$').hasMatch(n)) return true;
    final win = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    return ctx.equals(n, win) ||
        ctx.isWithin(win, n) ||
        ctx.equals(n, r'C:\Windows') ||
        ctx.isWithin(r'C:\Windows', n);
  }
  if (n == '/') return true;
  for (final r in const ['/proc', '/sys', '/dev', '/etc', '/System']) {
    if (n == r || ctx.isWithin(r, n)) return true;
  }
  return n == '/private' ||
      n == '/private/etc' ||
      ctx.isWithin('/private/etc', n);
}

/// Dossier refusé à l'ajout (non absolu, racine ou dossier système).
class LocalFolderForbiddenException implements Exception {
  const LocalFolderForbiddenException();
}

/// Permission de lecture des vidéos (Android ; ailleurs, toujours accordée).
abstract class StoragePermission {
  /// Demande l'accès si besoin ; faux si refusé.
  Future<bool> ensure();
}

/// `READ_MEDIA_VIDEO` (API 33+) ou `READ_EXTERNAL_STORAGE` (avant), via
/// `permission_handler`.
class SystemStoragePermission implements StoragePermission {
  @override
  Future<bool> ensure() async {
    if (!Platform.isAndroid) return true;
    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    final perm = sdk >= 33 ? Permission.videos : Permission.storage;
    final status = await perm.status;
    if (status.isGranted || status.isLimited) return true;
    final asked = await perm.request();
    return asked.isGranted || asked.isLimited;
  }
}

/// Dossiers locaux et leurs vidéos (SQLite) : ajout, analyse, correction
/// manuelle du titre.
class LocalLibrary {
  LocalLibrary(
    this._db, {
    Future<ScanResult> Function(String dir)? scanner,
    DateTime Function()? now,
  }) : _scanner = scanner ?? scanInIsolate,
       _now = now ?? DateTime.now;

  final AppDatabase _db;
  final Future<ScanResult> Function(String dir) _scanner;
  final DateTime Function() _now;
  final _running = <String, Future<int>>{};
  final _incomplete = <String>{};

  /// Vrai si la dernière analyse de [dir] a atteint un plafond (résultat
  /// partiel).
  bool isIncomplete(String dir) => _incomplete.contains(normalizeFolder(dir));

  Stream<List<LocalFolder>> watchFolders() => (_db.select(
    _db.localFolders,
  )..orderBy([(t) => OrderingTerm.asc(t.path)])).watch();

  Stream<List<LocalItem>> watchItems() =>
      (_db.select(_db.localItems)..orderBy([
            (t) => OrderingTerm.asc(t.title),
            (t) => OrderingTerm.asc(t.path),
          ]))
          .watch();

  Future<List<String>> grantedFolders() async => [
    for (final f in await _db.select(_db.localFolders).get()) f.path,
  ];

  Future<LocalItem?> item(String id) => (_db.select(
    _db.localItems,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Source de lecture d'un élément : [LocalFileSource] validé contre les
  /// dossiers accordés au moment du lancement.
  Future<LocalFileSource> sourceFor(LocalItem item) async =>
      LocalFileSource(path: item.path, grantedFolders: await grantedFolders());

  /// Accorde [path] puis l'analyse ; rend le nombre de vidéos trouvées. Si
  /// l'analyse échoue, le dossier n'est pas gardé.
  Future<int> addFolder(String path) async {
    final raw = path.trim();
    if (raw.isEmpty || !p.isAbsolute(raw)) {
      throw const LocalFolderForbiddenException();
    }
    final dir = normalizeFolder(raw);
    if (isForbiddenFolder(dir)) throw const LocalFolderForbiddenException();
    final real = _realOf(dir);
    if (real == null) throw const LocalScanException(LocalScanFailure.missing);
    if (isForbiddenFolder(real)) throw const LocalFolderForbiddenException();
    for (final existing in await grantedFolders()) {
      if (existing == dir) return scan(dir); // déjà accordé : simple analyse
      final other = _realOf(existing) ?? existing;
      if (_within(other, real) || _within(real, other)) {
        throw const LocalFolderOverlapException();
      }
    }
    await _db
        .into(_db.localFolders)
        .insert(
          LocalFoldersCompanion.insert(
            path: dir,
            addedAt: Value(_now().millisecondsSinceEpoch),
          ),
        );
    try {
      return await scan(dir);
    } on Object {
      await removeFolder(dir);
      rethrow;
    }
  }

  /// Chemin réel (liens résolus), `null` si le dossier n'existe pas.
  static String? _realOf(String dir) {
    try {
      return Directory(dir).resolveSymbolicLinksSync();
    } on FileSystemException {
      return null;
    }
  }

  /// Égalité ou inclusion de chemins réels ; la casse est ignorée sur macOS
  /// et Windows (volumes insensibles à la casse).
  static bool _within(String parent, String child) {
    final fold = Platform.isMacOS || Platform.isWindows;
    final a = fold ? parent.toLowerCase() : parent;
    final b = fold ? child.toLowerCase() : child;
    return a == b || p.isWithin(a, b);
  }

  /// Retire le dossier et ses éléments de Lumio (les fichiers ne sont pas
  /// touchés ; la progression est conservée).
  Future<void> removeFolder(String path) => _db.transaction(() async {
    await (_db.delete(
      _db.localItems,
    )..where((t) => t.folderPath.equals(path))).go();
    await (_db.delete(
      _db.localFolders,
    )..where((t) => t.path.equals(path))).go();
  });

  /// Analyse [dir] ; rend le nombre de vidéos. Les titres corrigés à la main
  /// sont conservés ; les fichiers disparus sont retirés. En cas d'échec
  /// ([LocalScanException]), l'état précédent est gardé. Deux analyses du
  /// même dossier en même temps n'en font qu'une.
  Future<int> scan(String dir) {
    final key = normalizeFolder(dir);
    return _running[key] ??= _scan(key).whenComplete(() {
      _running.remove(key);
    });
  }

  Future<int> _scan(String dir) async {
    final ScanResult result;
    try {
      result = await _scanner(dir);
    } on LocalScanException {
      rethrow;
    } on Object {
      throw const LocalScanException(LocalScanFailure.other);
    }
    final files = result.files;
    if (result.truncated) {
      _incomplete.add(dir);
    } else {
      _incomplete.remove(dir);
    }
    final stamp = _now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      final existing = {
        for (final r in await (_db.select(
          _db.localItems,
        )..where((t) => t.folderPath.equals(dir))).get())
          r.id: r,
      };
      final keep = <String>{};
      for (final f in files) {
        final id = localItemId(f.path);
        keep.add(id);
        final old = existing[id];
        await _db
            .into(_db.localItems)
            .insertOnConflictUpdate(
              LocalItemsCompanion(
                id: Value(id),
                folderPath: Value(dir),
                path: Value(f.path),
                fileName: Value(f.fileName),
                title: Value(f.title),
                titleOverride: Value(old?.titleOverride),
                year: Value(f.year),
                season: Value(f.season),
                episode: Value(f.episode),
                sizeBytes: Value(f.sizeBytes),
                modifiedAt: Value(f.modifiedAt),
                addedAt: Value(old?.addedAt ?? stamp),
              ),
            );
      }
      await (_db.delete(
        _db.localItems,
      )..where((t) => t.folderPath.equals(dir) & t.id.isNotIn(keep))).go();
      await (_db.update(_db.localFolders)..where((t) => t.path.equals(dir)))
          .write(LocalFoldersCompanion(lastScanAt: Value(stamp)));
    });
    return files.length;
  }

  /// Réanalyse les dossiers dont la dernière analyse date de plus de
  /// [rescanInterval] (tous si [force]). Les échecs sont ignorés : un disque
  /// absent ne doit pas gêner le démarrage.
  Future<void> rescanAll({bool force = false}) async {
    final limit = _now().subtract(rescanInterval).millisecondsSinceEpoch;
    for (final f in await _db.select(_db.localFolders).get()) {
      if (!force && f.lastScanAt > limit) continue;
      try {
        await scan(f.path);
      } on Object {
        // Dossier absent ou illisible : l'état précédent est gardé.
      }
    }
  }

  /// Corrige le titre de [id] ; vide ou `null` rétablit le titre détecté.
  Future<void> setTitle(String id, String? title) {
    final t = title?.trim();
    return (_db.update(_db.localItems)..where((r) => r.id.equals(id))).write(
      LocalItemsCompanion(
        titleOverride: Value(t == null || t.isEmpty ? null : t),
      ),
    );
  }
}

extension LocalItemView on LocalItem {
  /// Titre affiché : correction manuelle, sinon titre détecté.
  String get displayTitle {
    final o = titleOverride;
    return o == null || o.isEmpty ? title : o;
  }

  /// « S01E02 » pour un épisode reconnu.
  String? get episodeLabel {
    final s = season, e = episode;
    if (s == null || e == null) return null;
    String two(int n) => n.toString().padLeft(2, '0');
    return 'S${two(s)}E${two(e)}';
  }

  /// Aperçu pour l'accueil : pas d'affiche (carte-titre générée) ni de
  /// certification, donc masqué aux profils enfants (règle des certifications
  /// inconnues).
  MetaPreview toPreview() => MetaPreview(
    id: id,
    type: season != null ? 'series' : 'movie',
    name: episodeLabel == null ? displayTitle : '$displayTitle $episodeLabel',
    releaseInfo: year?.toString(),
    sourceAddonId: localSourceKind,
    sourceKind: localSourceKind,
  );
}
