import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Catégorie du rail des réglages qui contient la ligne `setting:<id>`.
const settingsRailOf = {
  'addons': 'sources',
  'localFolders': 'sources',
  'jellyfin': 'sources',
  'quality': 'playback',
  'preferDirect': 'playback',
  'audio': 'playback',
  'subtitles': 'playback',
  'cache': 'torrents',
  'upload': 'torrents',
  'clearCache': 'torrents',
  'profiles': 'profiles',
  'tracking': 'tracking',
  'party': 'party',
  'backupExport': 'backup',
  'backupImport': 'backup',
  'otherImport': 'backup',
  'locale': 'general',
  'version': 'general',
  'debug': 'general',
  'about': 'general',
};

/// Affiche la page des réglages qui contient la ligne [id] (clic sur le rail).
Future<void> openSettingsPageFor(
  WidgetTester tester,
  String id,
  Future<void> Function() settle,
) async {
  final cat = settingsRailOf[id];
  if (cat == null) return;
  final rail = find.byKey(ValueKey('rail:$cat'));
  if (rail.evaluate().isEmpty) return;
  await tester.tap(rail);
  await settle();
}
