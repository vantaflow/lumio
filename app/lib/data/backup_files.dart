import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:lumio_core/lumio_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Extension des fichiers de sauvegarde.
const backupExtension = '.lumio.json';

/// Fichier de sauvegarde choisi. [read] refuse un fichier de plus de
/// [Backup.maxBytes] avant de le lire.
class BackupFile {
  const BackupFile({
    required this.name,
    required this.length,
    required this.read,
  });

  final String name;
  final int length;
  final Future<List<int>> Function() read;
}

/// Entrées/sorties des sauvegardes (l'application seule touche aux fichiers).
abstract class BackupFiles {
  /// Vrai s'il existe un sélecteur de fichiers du système (faux sur Android
  /// TV : on liste alors [listLocal]).
  bool get hasPicker;

  /// Écrit [text] ; renvoie l'emplacement (nul si l'utilisateur annule).
  Future<String?> save(String suggestedName, String text);

  /// Choisit un fichier avec le sélecteur du système (nul si annulé).
  Future<BackupFile?> pick();

  /// Sauvegardes `*.lumio.json` du dossier de l'application, récentes d'abord ;
  /// avec [anyJson], tous les fichiers `.json` (exports d'un autre client).
  Future<List<BackupFile>> listLocal({bool anyJson = false});

  /// Dossier de l'application où `save` écrit sans sélecteur.
  Future<String> get directory;
}

/// Disque réel. Bureau : fenêtre « Enregistrer sous » / « Ouvrir ». Android :
/// l'export va dans le dossier de données externes de l'application
/// (`Android/data/<appli>/files`, visible depuis un gestionnaire de fichiers ou
/// adb), l'import utilise le sélecteur du système, sauf sur TV où il n'y en a
/// pas et où l'on choisit dans ce dossier.
class PlatformBackupFiles implements BackupFiles {
  PlatformBackupFiles({required this.tv});

  final bool tv;

  static bool get _desktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  @override
  bool get hasPicker => !tv;

  @override
  Future<String> get directory async {
    Directory? d;
    if (Platform.isAndroid) {
      try {
        d = await getExternalStorageDirectory();
      } on Object {
        d = null;
      }
    }
    d ??= await getApplicationDocumentsDirectory();
    return p.join(d.path, 'backups');
  }

  @override
  Future<String?> save(String suggestedName, String text) async {
    String path;
    if (_desktop) {
      final loc = await getSaveLocation(
        suggestedName: suggestedName,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Sauvegarde Lumio', extensions: ['json']),
        ],
      );
      if (loc == null) return null;
      path = loc.path;
    } else {
      final dir = Directory(await directory);
      await dir.create(recursive: true);
      path = p.join(dir.path, suggestedName);
    }
    // Écriture complète puis renommage : jamais de fichier à moitié écrit.
    final tmp = File('$path.part');
    try {
      await tmp.writeAsString(text, flush: true);
      await tmp.rename(path);
    } on Object {
      try {
        if (await tmp.exists()) await tmp.delete();
      } on Object {
        // Nettoyage au mieux.
      }
      rethrow;
    }
    return path;
  }

  @override
  Future<BackupFile?> pick() async {
    final f = await openFile(
      // Sur Android le filtre par extension écarterait des fichiers servis
      // sans type précis : on laisse tout choisir, la validation fait foi.
      acceptedTypeGroups: Platform.isAndroid
          ? const []
          : const [
              XTypeGroup(label: 'Sauvegarde Lumio', extensions: ['json']),
            ],
    );
    if (f == null) return null;
    return BackupFile(
      name: f.name,
      length: await f.length(),
      read: () async => f.readAsBytes(),
    );
  }

  @override
  Future<List<BackupFile>> listLocal({bool anyJson = false}) async {
    final dir = Directory(await directory);
    if (!await dir.exists()) return const [];
    final files = <(File, DateTime, int)>[];
    await for (final e in dir.list(followLinks: false)) {
      if (e is File &&
          (anyJson
              ? e.path.toLowerCase().endsWith('.json')
              : e.path.endsWith(backupExtension))) {
        final st = await e.stat();
        files.add((e, st.modified, st.size));
      }
    }
    files.sort((a, b) => b.$2.compareTo(a.$2));
    return [
      for (final (f, _, size) in files)
        BackupFile(
          name: p.basename(f.path),
          length: size,
          read: () => f.readAsBytes(),
        ),
    ];
  }
}

/// Nom proposé : `lumio-20261118-103042.lumio.json`.
String backupFileName(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'lumio-${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}${two(t.second)}$backupExtension';
}
