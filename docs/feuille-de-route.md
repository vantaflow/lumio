# Feuille de route

Source : le plan d'implémentation (`docs/superpowers/plans/2026-11-18-lumio.md`),
41 tâches (numérotées de 1 à 43 ; les tâches 32 et 33 ont été retirées). État : toutes les tâches sont terminées ; la validation sur appareil
(box Android TV, bureau, services réels) reste à faire, voir
[le rapport](rapports/2026-11-18-verification-finale.md).

## Phase 0 — Socle (terminée)

| Tâche | Story | État |
|---|---|---|
| 1. Monorepo, application Flutter, CI, garde-fous | 0.1 | fait |
| 2. Serveur d'addons simulé et corpus de manifests | 0.5 | fait |
| 3. Backend : comptes, jeton par e-mail, limitation de débit | 0.2 | fait |
| 4. Vérification des mises à jour et récupérateur HTTP sécurisé | 0.4 | fait |
| 5. Moteur de torrents, spike sur la box Android TV | 0.6 | fait (verdict GO avec réserves) |

## Phase 1 — MVP (terminée)

| Tâche | Story | État |
|---|---|---|
| 6. Manifest, client d'addons, garde d'URL | 1.1 cœur, 1.6 réseau | fait |
| 7. Agrégation des catalogues | 1.2 | fait |
| 8. Fiches fusionnées | 1.3 | fait |
| 9. Normalisation des flux (magnets, débrideurs via addons) | 1.4 | fait |
| 10. Sous-titres d'addons | 1.5 | fait |
| 11. Base locale, secrets, gestion des addons | 1.1 UI, 1.6 stockage | fait |
| 12. Lecteur plein écran et proxy HTTP local | 2.1 | fait |
| 13. Pistes, sous-titres, décalage, style | 2.2 | fait |
| 14. Progression, reprise, épisode suivant | 2.3, 2.5 | fait |
| 15. Ossature du focus D-pad | 3.5 | fait |
| 16. Profils et contrôle parental | 4.1 | fait |
| 17. Accueil | 3.1 | fait |
| 18. Recherche unifiée | 3.2 | fait |
| 19. Fiche, liste des flux, « Ma liste » | 1.3 UI, 1.4 UI, 3.4 | fait |
| 20. Réglages, gestion des addons, langues | 3.7 | fait |
| 21. Appairage mobile | 1.7 | fait |
| 22. Assistant de premier lancement | 3.0 | fait |
| 23. Navigation TV complète et accessibilité | 3.3 | fait |
| 24. Streaming de torrents de bout en bout | 1.8 | fait |
| 25. Cache disque, débit, ensemencement | 1.9 | fait |
| 26. Endurance et bout en bout sur la box | 3.6 | fait |

## Phase 2 — « En mieux » (terminée)

Synchronisation (27), chiffrement côté client des secrets (28), export et
import local (29), import depuis Stremio (30), santé des addons (34), tri, dédoublonnage et basculement automatique
des sources (35).

## Phase 3 — Extensions (terminée)

Dossiers locaux (36), Jellyfin (37), Trakt (38), Simkl (39), calendrier des
sorties (40), cast DLNA (41), watch-party (42), vérification finale sur la box
et documentation (43).

## Hors périmètre

iOS et tvOS, magasin d'addons, hébergement de contenu, addon préinstallé,
scraper de sources.

## Retiré le 2026-11-20 — option VPN

Le cycle « VPN WireGuard intégré » est annulé et l'option VPN (VPN requis,
coupe-circuit, avertissement IP) est retirée : les torrents fonctionnent
directement, sans réglage ni blocage. Un VPN reste possible au niveau du
système de l'appareil ou du routeur.
