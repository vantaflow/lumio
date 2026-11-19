# Plan — catalogue d'addons (cycle 3)

1. Core, TDD : modèles + `AddonCatalogParser` (liste, fiche, collection officielle) sur fixtures réelles et cas cassés.
2. Core : `RateLimiter`, `AddonCatalogSource` (HttpFetcher gardé), cache fichier, `AddonCatalogService` (cache 24 h, hors ligne, repli, rafraîchissement).
3. App : providers (service, cache dans le dossier de support), `AddAddonScreen` (3 onglets), onglet Catalogue (puces, grille, installé, voir plus, repli), choix d'instance, « À configurer sur le téléphone » + QR, onglet Par lien (flux existant), onglet téléphone (emplacement).
4. Remplacer le dialogue par l'écran (points d'entrée), correctifs d'audit (icône « pen S », libellés selon types/ressources réels).
5. Rendu PNG vs maquettes TV16 et TV08, liste d'écarts, corrections, REFONTE.md.
6. `ia.sh test` + `ia.sh analyze` avant chaque commit ; pas de build Android.
