import 'package:lumio/l10n/app_localizations.dart';
import 'package:lumio/l10n/app_localizations_fr.dart';

/// Libellés des types de contenu et ressources du protocole (français par
/// défaut).
String contentTypeLabel(String type, [AppLocalizations? l]) {
  l ??= AppLocalizationsFr();
  return switch (type) {
    'movie' => l.typeMovie,
    'series' => l.typeSeries,
    'anime' => l.typeAnime,
    'other' => l.typeOther,
    _ => type,
  };
}

String resourceLabel(String name, [AppLocalizations? l]) {
  l ??= AppLocalizationsFr();
  return switch (name) {
    'catalog' => l.resCatalog,
    'meta' => l.resMeta,
    'stream' => l.resStream,
    'subtitles' => l.resSubtitles,
    'addon_catalog' => l.resAddonCatalog,
    _ => name,
  };
}
