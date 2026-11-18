# Lumio — design

Maquettes (Claude Design) : https://claude.ai/artifact/GKZmDLAFWRfcPDSEjCZStJ
(privé tant qu'il n'est pas partagé). Jetons machine : `tokens.json` (source de `app/lib/ui/theme.dart`).

15 artboards : 11 TV 1920×1080 (onboarding x3, choix du profil + PIN, accueil, fiche + flux, lecteur, ajout d'addon, appairage QR, réglages/addons, recherche), 3 téléphone 390×844 (accueil, fiche, ajout), 1 bureau 1440×900 (accueil).

## Principes

1. **Sombre d'abord, calme, une seule lumière** : fond encre bleu-nuit, un accent ambre (la « lumière » de Lumio) et un secondaire turquoise. Aucun violet, aucune ressemblance avec Stremio (palette, mise en page, logo : anneau ambre + point turquoise).
2. **Le focus est le design TV** : anneau 4 dp ambre clair + mise à l'échelle, toujours visible à 3 m, jamais coupé.
3. **Ajouter un addon = un écran, un bouton** : coller/recevoir un lien, aperçu (logo, nom, types), « Installer ». Aucun addon proposé par défaut.
4. **La source est toujours visible** : badge (Direct, Torrent, Jellyfin, Local) sur chaque carte, flux groupés par addon avec santé.
5. **Lisible à distance** : texte TV ≥ 24, contraste ≥ 4,5:1 (vérifié : texte `#F3F5F7` sur `#0E1116` ≈ 17:1 ; muet `#A9B2BF` ≈ 8:1 ; `#1A1100` sur ambre ≈ 11:1), l'état n'est jamais porté par la couleur seule (texte « Bonne / Lente / Hors ligne »).
6. **Français partout**, mise en page prête pour l'arabe (RTL) : n'utiliser que des marges `start/end`.

## Jetons (voir `tokens.json`)

TV : le canevas logique est **1920×1080 dp** (mettre à l'échelle l'écran réel, ex. `FittedBox`/facteur de densité) ; sur ce canevas, 24 = taille de lecture minimale à 3 m.

### Couleurs

| Jeton | Sombre | Clair |
|---|---|---|
| bg | `#0E1116` | `#F7F5F0` |
| surface | `#161B22` | `#FFFFFF` |
| surfaceRaised | `#1F2630` | `#F1EEE7` |
| surfaceFocus | `#2A3340` | `#E4E0D5` |
| outline | `#3A4452` | `#B9B3A4` |
| text | `#F3F5F7` | `#14171C` |
| textMuted | `#A9B2BF` | `#4A5361` |
| accent | `#FFB84D` | `#A85500` |
| onAccent | `#1A1100` | `#FFFFFF` |
| secondary | `#4FD1C5` | `#00796B` |
| focusRing | `#FFE08A` | `#0B57D0` |
| success / warning / error | `#5BD68A` / `#FFB84D` / `#FF7A70` | `#1B7F44` / `#8A5A00` / `#B3261E` |

La TV est en sombre uniquement ; le clair est pour téléphone et bureau.

### Typographie

Titres **Bricolage Grotesque** 700, texte **Manrope** 400/600/700 (à embarquer en assets, pas de réseau).

| Style | TV | Téléphone / bureau |
|---|---|---|
| display | 72 | 32 |
| h1 | 64 | 28 |
| h2 | 44 | 20 |
| title | 34 | 18 |
| body | 30 | 16 |
| label | 28 | 14 |
| caption (minimum) | 24 | 12 |

### Espacement, rayons, mouvement

- Espacement : 4 / 8 / 16 / 24 / 40 / 64 ; marge d'écran TV 96.
- Rayons : 10 (badges) / 16 / 24 (cartes) / 32 (panneaux) / pilule (boutons).
- Anneau de focus : trait 4, écart 4, couleur `focusRing`, échelle 1,06 (cartes de rangée 1,08). Prévoir 12 de marge autour des rangées pour ne pas rogner.
- Mouvement : focus 120 ms, échelle de carte 160 ms, panneau 220 ms, écran 280 ms, commandes du lecteur masquées après 4 s. Option « réduire les animations » : tout à 0 ms.
- Cibles tactiles ≥ 48 ; boutons TV hauteur 88, lignes 96.

## Inventaire des composants

- **FocusableCard** : poster 300×170 (rangée) ou portrait 230×340 (recherche), badge de source en haut à gauche, barre de progression 8 dp en bas (Continuer), titre ≥ 26. États : repos, focus (anneau + échelle), pression, désactivé. Fournit un `Semantics` (titre + source).
- **TvRow** : titre h2/title à 96 de la marge, rangée défilante horizontale, marge de 12 verticale pour l'anneau, mémorise le dernier focus, recentre sur l'élément focalisé.
- **StateView** : `loading` (squelettes de cartes, pas de spinner plein écran), `empty` (illustration simple + une action, ex. « Ajouter un addon »), `error` (message clair + « Réessayer » focalisé par défaut).
- **Badges** : source (Direct, Torrent, Jellyfin, Local) sur fond encre 88 % ; qualité (1080p, 4K) sur `surfaceFocus`, meilleure qualité en ambre ; santé d'addon (point + mot : Bonne/Lente/Hors ligne).
- **Panneaux** : panneau latéral droit du lecteur (620 de large, pistes/sous-titres), boîte PIN (clavier numérique focalisable), panneau d'aperçu d'addon.
- **Boutons** : principal (ambre, texte `onAccent`), secondaire (`surfaceFocus`), destructif (texte `error`, confirmation obligatoire).
- **Clavier TV** : touches 76×84, ligne d'actions Espace/Effacer/123, bouton micro.
- **Barre de lecture** : piste 12 dp, poignée 32 dp, ±10 s, lecture/pause 128 dp, pistes, vitesse, suivant.

## Notes par écran (pour les tâches 11 à 23)

1. **Onboarding (stories 3.0)** : 3 étapes (langue → profil → sources), indicateur d'étape, « Plus tard » toujours possible à l'étape 3 ; focus initial sur la langue système. Étape 3 : 4 cartes (addon, liste TV, Jellyfin, dossier), aucune suggestion de contenu.
2. **Choix du profil + PIN (4.1)** : avatars 200 dp ; profil verrouillé = cadenas + « PIN » ; PIN à 4 chiffres, points de saisie, clavier focalisable, Retour annule. Profil enfant : mention du filtre d'âge.
3. **Accueil (3.1)** : barre haute (logo, onglets, profil) ; héros « Reprendre » ; rangées Continuer à regarder, Ma liste, puis catalogues des addons ; badge de source sur chaque carte ; D-pad : haut/bas change de rangée, mémoire du focus par rangée, Retour remonte à la barre haute. Cache chaud < 2 s : afficher les squelettes sinon.
4. **Fiche + flux (1.4)** : poster à gauche, flux à droite groupés par addon (titre d'addon + santé), ligne = qualité, langues, taille, seeders (vert ≥ 50, ambre sinon) + icône aimant (torrent) ou lien (direct). Action principale « Lecture auto · meilleure source ». Premier flux focalisé.
5. **Lecteur (2.1/2.2)** : commandes masquées après 4 s, OK les ré-affiche ; gauche/droite = ∓10 s hors barre ; panneau pistes à droite ; carte « Épisode suivant » avec compte à rebours 8 s, annulable.
6. **Ajout d'addon (1.1)** : champ + « Coller » ; raccourcis : QR depuis le téléphone, Partager Android, lien `stremio://` (ouvre cet écran avec le lien pré-rempli). Aperçu dès un manifeste valide (logo, nom, version, types) ; bouton unique **Installer** ; erreur en une phrase sous le champ ; message de prudence. Ne jamais afficher l'URL complète (clé) dans les journaux.
7. **Appairage QR (1.7)** : QR 544 dp sur fond clair (contraste), code court KR7-4PQ de secours, 3 étapes, état d'attente + expiration 10 min, « Nouveau code ».
8. **Réglages / addons (3.7)** : menu à gauche ; liste ordonnable (appui long + haut/bas), bascule activer, supprimer avec confirmation, santé (point + mot + latence + taux). Ordre = priorité des sources.
9. **Recherche (3.2)** : clavier à gauche, résultats à droite par type (Tout/Films/Séries), micro pour la dictée, résultats avec badge de source.
10. **Téléphone/bureau** : mêmes jetons, échelle réduite ; navigation basse (téléphone) ou latérale (bureau) ; l'ajout d'addon sur téléphone envoie aussi vers la TV appairée.

## Accessibilité

- Texte TV ≥ 24 ; contrastes ≥ 4,5:1 (3:1 pour les gros titres).
- Focus visible partout (anneau 4 dp), ordre de focus logique, aucun piège ; Retour ferme toujours le panneau ouvert.
- Libellés `Semantics` sur icônes (aimant, micro, pause) ; support TalkBack.
- Pas d'information portée par la couleur seule ; option « réduire les animations ».
