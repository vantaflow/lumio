import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumio/data/db.dart';
import 'package:lumio/data/local_library.dart';
import 'package:lumio/providers.dart';
import 'package:lumio_core/lumio_core.dart' show MetaPreview;

final localLibraryProvider = Provider<LocalLibrary>(
  (ref) => LocalLibrary(ref.watch(appDatabaseProvider)),
);

/// Permission de lecture des vidéos ; remplacée en test.
final storagePermissionProvider = Provider<StoragePermission>(
  (ref) => SystemStoragePermission(),
);

/// Sélecteur de dossier système.
abstract class FolderPicker {
  /// Chemin choisi, `null` si l'utilisateur annule. Lève une erreur si le
  /// sélecteur n'est pas disponible (ou ne donne pas de chemin utilisable).
  Future<String?> pick();
}

/// `file_selector` : sur Android, le sélecteur de documents (SAF) ; le plugin
/// ne rend un chemin que pour le stockage interne.
class SystemFolderPicker implements FolderPicker {
  @override
  Future<String?> pick() => getDirectoryPath();
}

final folderPickerProvider = Provider<FolderPicker>(
  (ref) => SystemFolderPicker(),
);

final localFoldersProvider = StreamProvider<List<LocalFolder>>(
  (ref) => ref.watch(localLibraryProvider).watchFolders(),
);

final localItemsProvider = StreamProvider<List<LocalItem>>(
  (ref) => ref.watch(localLibraryProvider).watchItems(),
);

/// Aperçus des vidéos locales pour l'accueil (sans certification : masqués
/// aux profils enfants par `visibleItems`).
final localPreviewsProvider = Provider<List<MetaPreview>>(
  (ref) => [
    for (final i in ref.watch(localItemsProvider).value ?? const <LocalItem>[])
      i.toPreview(),
  ],
);
