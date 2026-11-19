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

/// Titre de rangée de catalogue présenté proprement (audit D5) : les addons
/// déclarent des noms bruts en anglais (« Popular », « Featured »), identiques
/// pour films et séries. Les noms usuels sont traduits et accompagnés du type ;
/// les autres sont affichés tels que déclarés, précédés du type.
String catalogRowTitle(String type, String name, [AppLocalizations? l]) {
  l ??= AppLocalizationsFr();
  final fr = l.localeName.startsWith('fr');
  final movie = type == 'movie';
  final series = type == 'series';
  final key = name.trim().toLowerCase();
  if (fr && (movie || series)) {
    final what = movie ? 'Films' : 'Séries';
    final the = movie ? 'Films' : 'Séries';
    return switch (key) {
      'popular' || 'populaire' || 'populaires' => '$the populaires',
      'featured' => '$the à la une',
      'top' => '$the les mieux notés',
      'trending' => '$the du moment',
      'new' || 'latest' => 'Nouveaux ${what.toLowerCase()}',
      _ => '$what · ${_capital(name)}',
    };
  }
  if (!fr && (movie || series)) {
    final what = movie ? 'movies' : 'series';
    return switch (key) {
      'popular' => 'Popular $what',
      'featured' => 'Featured $what',
      'top' => 'Top $what',
      'trending' => 'Trending $what',
      'new' || 'latest' => 'New $what',
      _ => '${_capital(name)} · $what',
    };
  }
  return name;
}

String _capital(String s) {
  final t = s.trim();
  return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}

/// Capacités d'un addon (« Catalogues · Flux · Sous-titres ») d'après son
/// manifeste : plus fiable que les types de contenu (un addon de sous-titres
/// déclare « film, série » mais ne propose ni catalogue ni flux).
String addonCapabilities(
  List<String> resourceNames,
  bool hasCatalogs,
  List<String> types, [
  AppLocalizations? l,
]) {
  l ??= AppLocalizationsFr();
  final parts = <String>[
    if (hasCatalogs) l.resCatalog,
    if (resourceNames.contains('stream')) l.resStream,
    if (resourceNames.contains('subtitles')) l.resSubtitles,
  ];
  if (parts.isEmpty) {
    return types.map((t) => contentTypeLabel(t, l!)).join(' · ');
  }
  return parts.join(' · ');
}
