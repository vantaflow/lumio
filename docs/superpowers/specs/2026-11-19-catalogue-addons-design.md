# Lumio — catalogue d'addons intégré (cycle 3)

Demande utilisateur : « un catalogue d'addons intégré, le même que Stremio », source https://stremio-addons.net/ (torrents et débrideurs inclus, comme Stremio). Écran « Ajouter un addon » à trois onglets : Catalogue / Par lien / Depuis le téléphone (maquettes TV16, TV08, TV09).

## Faits établis sur la source
- Le site n'a pas d'API. Pages de liste : `/addons?categories=<c>&categories=<c2>&sort=popular|new|updatedAt&page=N` (10 fiches par page, `page=` à partir de 1). Les catégories sont des noms simples (`movies`, `tv shows`, `torrents`, `debrid support`, `http streams`, `usenet`, `subtitles`, `anime`, `metadata`, `tracking`, `asian drama`, `bollywood`, `music`, `radios`, `live tv`, `misc`) ; plusieurs `categories=` = union. Les adultes sont exclus par défaut (on n'envoie jamais le filtre « 18+ »).
- Une carte de liste = `<a class="block" href="/addons/<slug>">` avec logo (`<img src>`), nom (`<h3>`), description (`<p>`), étoiles (popularité) et version ; le total est `N<!-- --> results`.
- Une fiche contient, dans la charge Next.js (échappée), le tableau `"instances":[{… "manifest":{…"behaviorHints":{"configurable":…,"configurationRequired":…}}, "manifestUrl":"https://…/manifest.json", "stars":…}]` ; le nom, la description et le logo sont dans les balises `og:*`.
- Repli officiel : `https://api.strem.io/addonscollection.json` (liste de `{transportUrl, manifest}`).
- `robots.txt` n'interdit pas `/addons`.

## Approche
`AddonCatalogSource` (lumio_core) : requêtes GET via `HttpFetcher` + `UrlGuard` (garde sur l'URL initiale et les redirections, 2 Mio max, 8 s), User-Agent générique « Lumio », 2 requêtes par seconde au plus (limiteur à intervalle minimal). Seules les pages de liste affichées et les fiches ouvertes sont téléchargées. `AddonCatalogService` ajoute cache, repli et hors ligne.

## Parsing
Tolérant : expressions régulières sur le HTML et sur la charge Next.js dépliée (`\"` → `"`), aucune dépendance au CSS. Un résultat « sans carte mais avec N > 0 résultats », une fiche sans aucune URL de manifest valide ou une page sans marqueur connu lèvent `CatalogParseException` (typée) : le service bascule alors sur le repli. Textes décodés des entités HTML ; URL de logo et de manifest gardées seulement si http(s). Lien « configurer » = URL du manifest dont `manifest.json` est remplacé par `configure` (convention du protocole) quand `configurable` est vrai.

## Cache et hors ligne
Fichier JSON par requête (clé = catégories + tri + page) dans le dossier de support de l'application, TTL 24 h. Lecture : cache frais d'abord ; sinon réseau ; réseau en échec : cache périmé (« hors ligne », date affichée) ; sinon repli `addonscollection.json` ; sinon erreur. Rafraîchissement manuel : un bouton ignore le cache. Les fiches sont mises en cache de la même manière.

## Repli
Si le site est injoignable (hors ligne exclu, cache vide) ou si son format a changé (`CatalogParseException`), la liste vient de `addonscollection.json`, filtrée au mieux par type/ressource (films et séries, anime, sous-titres, métadonnées) ; les autres catégories affichent toute la collection. Un bandeau discret l'indique.

## Installation et sécurité
- Choix de l'instance (liste avec domaines si plusieurs), puis flux existant inchangé : aperçu du manifest, garde SSRF, confirmation réseau privé, stockage chiffré de l'URL dans `SecretStore`, doublons refusés.
- Addon « configuration requise » : pas d'installation directe ; message « À configurer sur le téléphone » avec QR (généré localement, `qr_flutter`) vers l'URL `/configure`. Le QR est celui de l'URL publique de l'addon, jamais d'une URL saisie par l'utilisateur.
- Aucun addon pré-installé ; aucune URL d'addon complète dans les journaux (`redactUrl`) ; aucune requête hors du site source et des manifests choisis ; logos chargés par `GuardedNetworkImage`.
- Badge « Installé » : nom identique (insensible à la casse) à un addon installé au niveau de la liste, URL exacte au niveau de la fiche.
- Libellés des cartes = types et ressources réels du manifest (une carte du catalogue ne montre que ce que la fiche déclare ; sinon aucune étiquette), et plus jamais « Films · Séries » pour un addon de sous-titres.

## Interface (TV)
`AddAddonScreen` plein écran : en-tête TvScreen (fil « Réglages › Sources », titre, trois onglets à droite). Catalogue (TV16) : puces de catégories (Populaires, Films et séries, Torrents, Débrideurs, Sous-titres, Anime, Métadonnées, Suivi, Plus… qui ouvre les autres catégories), grille de cartes 400×250 avec badge « Installé », note de bas de page, carte « Voir plus » pour la page suivante. Par lien (TV08) : champ, bouton Coller, carte d'aperçu avec Installer. Depuis le téléphone (TV09) : emplacement propre en attendant la page de la box. L'ancien dialogue disparaît ; `showAddAddonDialog` devient l'ouverture de l'écran (mêmes points d'entrée : accueil, réglages, onboarding, liens d'installation).

## Tests
Core : fixtures HTML réelles (liste films+séries, liste sous-titres, page 2, trois fiches dont une multi-instances), cas cassés, service (cache frais/périmé/hors ligne/repli/rafraîchissement), limiteur, garde réseau. App : widget (onglets, puces, grille, installé, configuration requise + QR, choix d'instance, repli), rendu PNG comparé aux maquettes.

## Installer et configurer depuis la TV (cycle d'émulateur)
Appui sur une carte : choix d'instance si besoin, puis fiche de l'addon (TV16) avec « Installer » (sauf configuration requise), « Configurer » (page de l'addon dans l'app, TV17) et « Ou configurer sur le téléphone » (QR, option secondaire). La note de bas d'écran du catalogue est supprimée ; la grille défile dans une zone découpée entre l'en-tête et le bas de l'écran (`TvScrollClip`, appliqué aussi à la recherche, aux réglages, à Jellyfin et aux dossiers locaux).
