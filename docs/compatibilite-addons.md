# Compatibilité avec les addons

Lumio implémente le protocole d'addons utilisé par l'écosystème Stremio. Cette
compatibilité est technique ; Lumio n'est pas affilié à Stremio.

État : le client d'addons (manifest, catalogues, fiches, flux, sous-titres),
la normalisation des flux, l'agrégation et l'interface sont écrits et testés.
La validation avec des addons réels sur appareil reste à faire.

## Principe

Un addon est un serveur HTTP(S) qui expose un `manifest.json` et répond à des
URL de la forme `{base}/{ressource}/{type}/{id}.json`. Lumio en interroge
plusieurs et agrège les réponses.

## Manifest

`{base}/manifest.json` décrit l'addon : `id`, `version`, `name`,
`description`, `logo`, `types`, `resources`, `catalogs`, `idPrefixes`.
`resources` peut contenir des chaînes ou des objets. Lumio valide le manifest
de façon stricte : refus d'un manifest sans `id`, trop volumineux (5 Mo
maximum) ou mal formé, avec un message lisible. L'URL saisie est normalisée
(ajout de `/manifest.json`, hôte en minuscules, barre finale retirée) pour
éviter les doublons.

## Ressources

| Ressource | Chemin | Rôle |
|---|---|---|
| catalog | `/catalog/{type}/{id}.json` | listes de titres |
| meta | `/meta/{type}/{id}.json` | fiche détaillée, épisodes |
| stream | `/stream/{type}/{id}.json` | sources de lecture |
| subtitles | `/subtitles/{type}/{id}.json` | sous-titres |

## Extras

Les catalogues acceptent des paramètres (`search`, `genre`, `skip`…) placés
dans le chemin : `/catalog/{type}/{id}/{clé=valeur&…}.json`, valeurs encodées.
Lumio construit ces URL pour la recherche et la pagination.

## Flux et behaviorHints

Un flux porte une `url` directe ou un `infoHash` (avec `fileIdx` optionnel).
`behaviorHints` peut indiquer des en-têtes de requête à imposer
(`proxyHeaders`) ou que le contenu n'est pas lisible tel quel (`notWebReady`).
Lumio prévoit d'en tenir compte via le proxy local. Les flux sans `url` ni
`infoHash` (par exemple `externalUrl`, `ytId`) seront ignorés.

## Magnets, infoHash et débrideurs

Un `infoHash` de 40 caractères hexadécimaux est converti en magnet puis lu par
le moteur de torrents intégré (fonction `magnetFromInfoHash`, existante).
Les débrideurs ne sont pas gérés par Lumio : ce sont des addons qui renvoient
directement une `url` HTTP(S) lisible. Lumio n'a aucune intégration propre
avec un débrideur.

## Ajouter un addon

Quand l'interface sera disponible : Réglages, Addons, coller l'URL du
manifest. Cette URL contient souvent une clé personnelle : traitez-la comme un
mot de passe (voir [securite.md](securite.md)). Lumio refuse les adresses
locales et privées sauf confirmation explicite.

## Ce que Lumio ne fait pas

- Aucun addon n'est fourni, préinstallé ni suggéré.
- Aucun scraper et aucune recherche de sources dans le client.
- Aucune liste d'addons ni magasin d'addons.
- Aucune garantie de compatibilité avec tous les addons existants : le
  protocole est implémenté d'après sa documentation publique.
