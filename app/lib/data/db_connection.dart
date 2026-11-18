import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Ouvre la base SQLite de l'application (fichier dans le dossier de données).
LazyDatabase openAppDatabase() => LazyDatabase(() async {
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  return NativeDatabase.createInBackground(File(p.join(dir.path, 'lumio.db')));
});
