# Captures réelles de la box (Google TV 4K, Android 14, armeabi-v7a, 1920×1080)

## Version 1.0.0 (2026-11-20)

Lumio 1.0.0 installé sur la vraie box, prises par `adb exec-out screencap`
(couleurs réduites pour tenir sous ~350 Ko). Elles remplacent les captures
antérieures qui montraient l'ancienne rubrique « Torrents et VPN » (retirée) ;
ces dernières ont été supprimées.

| Écran | Capture |
|---|---|
| Accueil (Reprendre, Continuer à regarder, Ma liste) | `v1-accueil.png` |
| Accueil, rangées de catalogues | `v1-accueil-rangees.png` |
| Fiche avec sources (flux disponibles par addon) | `v1-fiche-sources.png` |
| Lecteur (contenu libre) | `v1-lecteur.png` (reprise de `TV07-lecteur-commandes.png`, même écran) |
| Recherche | `v1-recherche.png` |
| Réglages : Sources | `v1-reglages-sources.png` |
| Réglages : Torrents (cache, limite d'envoi, sans VPN) | `v1-reglages-torrents.png` |
| Réglages : Sauvegarde et import | `v1-reglages-sauvegarde.png` |
| Gérer depuis le téléphone (QR, adresse du réseau local, code) | `v1-portail-telephone.png` |
| Catalogue d'addons | `v1-catalogue-addons.png` |

## Historique des passes précédentes

Prises par `adb exec-out screencap` sur Lumio installé sur la vraie box, le 2026-11-19 (couleurs réduites pour tenir sous ~500 Ko).

| Écran | Capture | Maquette | Remarques |
|---|---|---|---|
| Accueil rempli | `TV05-accueil-rempli.png`, `TV05-accueil-hero.png` | TV05 | rangées Cinemeta, « Continuer », « Ma liste » ; héros : affiche basse définition étirée (flou pixellisé) |
| Fiche film, flux directs et torrents | `TV06-fiche-film.png`, `TV06-fiche-flux-direct.png`, `TV06-fiche-flux-torrents.png` | TV06 | |
| Lecteur | `TV07-lecteur-commandes.png`, `TV07-lecteur-image-reelle-1080p.png`, `TV07-lecteur-hevc-1080p.png` | TV07 | image réelle H.264 et H.265 1080p, 0 image perdue en `mediacodec` direct |
| Ajouter un addon, par lien | `TV08-ajout-addon-par-lien.png` | TV08 | aperçu de l'addon de test |
| Gérer depuis le téléphone | `TV09-gerer-depuis-telephone.png` | TV09 | adresse 192.168.0.47:8790, QR et code |
| Recherche | `TV12-recherche-vide.png`, `TV12-recherche-resultats.png`, `TV12-recherche-clavier-arabe.png` | TV12 | contour interne du champ corrigé |
| Suivi Trakt et code d'appareil | `TV26-code-trakt.png` | TV25, TV26 | le cadre du code passait sous le QR (corrigé) |
| Dossiers locaux | `TV30-dossiers-locaux.png`, `TV30-dossiers-locaux-vide.png`, `D4-dossiers-locaux-ajouter-complet.png` | TV30 | bouton « Ajouter un d… » coupé (corrigé ; libellé complet revérifié le 2026-11-20) |
| Gestion des profils | `TV35-gestion-profils.png`, `TV35-qui-regarde-gestion.png` | TV35 | badge crayon au-dessus de l'anneau |
| Calendrier vide | `TV42-calendrier-vide.png` | TV42 | |
| Éditeur de profil | `P02-editeur-profil-adulte.png`, `P02-editeur-profil-pastilles.png` | P02 | pastilles d'âge séparées |
| Adresse locale | `P04b-adresse-locale.png` | P04 | confirmation d'installation depuis le portail |
| Confirmation | `P09-confirmation-suppression-profil.png` | P09 | |
| Erreur de lecture | `P10-erreur-lecture.png` | P10 | |
| Barre haute : Gauche sur Accueil | `D1-accueil-gauche-reste-sur-accueil.png` | TV05 | le focus reste sur « Accueil » (passe du 2026-11-20) |
| Catalogue d'addons : Actualiser | `D2-catalogue-actualiser-visible.png`, `D2b-catalogue-actualiser-focus.png` | TV16 | puces défilantes, « Actualiser » fixe et entier, anneau visible |
| Fiche série : boutons | `D3-fiche-serie-ma-liste-visible.png` | TV40 | « + Ma liste » entier à 1080p, anneau compris |

## Passe 3 (2026-11-20, box 192.168.0.47, build 7a94a09 puis correctifs)

| Écran | Capture | Maquette | Remarques |
|---|---|---|---|
| Recherche, états | `TV12-recherche-vide-box2.png`, `TV12-recherche-resultats-ten.png`, `TV12-recherche-cartes-sans-affiche.png`, `TV12-recherche-chiffres-aucun-resultat.png`, `TV12-recherche-clavier-arabe-box2.png` | TV12 | cartes sans affiche = fond de surface + icône (corrigé) ; anneau des touches sans chevauchement (corrigé) |
| Catalogue d'addons, aperçu, fiche à régler | `TV16-catalogue-addons.png`, `TV08-apercu-addon-catalogue.png`, `TV16-fiche-addon-a-regler.png`, `P13-choisir-serveur.png` | TV16, P13 | |
| Guides | `G01-aide-ajouter-addon.png`, `G02-encadre-sur-votre-telephone.png`, `G04-page-aide-reglages.png`, `G04-aide-guide-ajouter-addon.png` | G01, G02, G04 | bouton Aide, encadré 5 étapes, page Aide |
| Téléphone | `TV09-onglet-depuis-telephone.png`, `TV09b-telephone-connecte.png` | TV09 | |
| Portail à 390 px (Chrome headless) | `portail390-M05a-ajouter.png`, `portail390-M05b-regler-avec-aides.png`, `portail390-M05c-mes-addons.png`, `portail390-M05d-trakt-non-connecte.png`, `portail390-M05d-trakt-code.png`, `portail390-G03-aide.png` | M05a à M05d, G03 | Trakt : code affiché, annulé en quittant l'écran du téléphone |
| Ma liste, Personnaliser | `TV20-ma-liste-focus-initial.png`, `TV22-personnaliser-focus-initial.png`, `P13-menu-carte-ma-liste.png` | TV20, TV22 | aucun focus à l'ouverture (corrigé, build suivant) |
| Menu avatar, Calendrier | `TV43-menu-avatar.png`, `TV21-calendrier-date-inconnue.png` | TV43, TV21 | |
| Jellyfin vide, ajout, dossiers | `TV31-jellyfin-vide.png`, `P07-ajout-jellyfin.png`, `P08-ajout-dossier-choix.png` | TV31, P07, P08 | |
| Addons, suppression | `P13-menu-addon.png`, `P09-confirmation-suppression-addon.png` | P13, P09 | addon de test supprimé |
| Réglages divers | `TV33b-import-autre-client-sans-focus.png`, `P13-selecteur-langue.png` | TV25, TV33, P13 | import : aucun focus (corrigé, non revu à l'écran) |

## Intégration de TorrServer (2026-11-20)
- `TS02-carte-chargement-torrserver.png` : carte de chargement P05 pendant le flux (14 sources, 3,3 Mo/s, tampon).
- `TS03-lecture-sintel-torrserver.png` : lecture de Sintel (torrent légal) dans le lecteur de Lumio, servie par TorrServer.
- `TS04-lecture-echouee-delai-depasse.png` : état figé trouvé sur la box (« Délai dépassé : la source ne répond pas », « Réessayer » sans effet) après une longue session, avant de relancer l'appli.
- `TS05-lecture-sintel-repli-apres-relance.png` : même torrent, appli relancée (`am force-stop`) : repli automatique jusqu'à la source de test, lecture à 4:34, 4 sources, 100 % téléchargé.
- `TS06` à `TS09` (soir du 2026-11-20, box en Ethernet) : lecture de Sintel jusqu'à 11:11, accueil « Reprendre · 3 min restantes », reprise du même flux (« 3 sources · 8 % » = torrent de l'addon de test, pas celui de Torrentio) à 11:19 puis image à 11:40 (215 Ko/s, essaim lent ce soir).
- `TS10-lecture-echouee-essaim-vide.png` : « Délai dépassé » après une touche pressée pendant le chargement ; l'écran n'avait aucun focus (« Réessayer » ne réagissait à rien). Cause trouvée et corrigée (voir le rapport).
- `TS11-echec-reessayer-focus-apres-correctif.png` : même scénario avec le correctif : « Réessayer » porte l'anneau de focus ; Entrée relance une préparation complète.
