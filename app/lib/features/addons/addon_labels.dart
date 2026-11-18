/// Libellés français des types de contenu et ressources du protocole.
String contentTypeLabel(String type) => switch (type) {
  'movie' => 'Films',
  'series' => 'Séries',
  'anime' => 'Animes',
  'other' => 'Autres',
  _ => type,
};

String resourceLabel(String name) => switch (name) {
  'catalog' => 'Catalogues',
  'meta' => 'Fiches',
  'stream' => 'Flux',
  'subtitles' => 'Sous-titres',
  'addon_catalog' => 'Addons',
  _ => name,
};
