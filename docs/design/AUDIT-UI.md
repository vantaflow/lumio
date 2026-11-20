# Audit de l'interface Lumio (Android TV, box 192.168.0.45)

Audit du 2026-11-18, build installé `dev.lumio.app` 1.0.0, parcours à la télécommande (DPAD, OK, Retour) sur la vraie box. Aucun code modifié. Captures dans
`/private/tmp/claude-501/-Users-lilou-Projects/e461255e-a823-4897-a89e-939f551fb471/scratchpad/audit/` (notées `A/…` ci-dessous).
Maquettes existantes : `docs/design/maquettes/project/`. Maquettes créées par l'audit : TV40 à TV52 et P20 à P24 (voir section 4).

Contexte de test : addons Cinemeta et OpenSubtitles installés (aucun addon de flux, donc aucune source jouable). Profils créés : « Enfant » (enfant 12+, PIN parent 1234). Effet de bord à connaître : la création du premier PIN a verrouillé le profil existant « Moi » par ce PIN (badge « PIN » dans le sélecteur) ; à retirer via Gérer les profils si ce n'est pas voulu.

Note de mesure : sur la box, l'affichage se met à jour avec 3 à 5 secondes de retard (plusieurs captures montraient l'état précédent). Les constats ci-dessous ont été recoupés avec une seconde capture différée.

## 1. Carte de navigation

```
Accueil (rangées ; sans source : « Votre accueil attend ses sources »)
├─ Barre haute
│  ├─ Accueil → focus sur la barre / retour en haut (le défilement ne remonte pas, voir D8)
│  ├─ Films → écran Recherche pré-filtré « Films »   (pas de catalogue Films)
│  ├─ Séries → écran Recherche pré-filtré « Séries » (pas de catalogue Séries)
│  ├─ Recherche → Recherche (clavier a-z + puces Tout / Films / Séries)
│  │   └─ résultat → Fiche
│  ├─ Réglages → (PIN parent si profil enfant) Réglages
│  └─ Avatar → Menu de l'avatar (dialogue centré)
│      ├─ Gérer ma liste → Ma liste (vide : message)  → fiche
│      ├─ Calendrier → Calendrier des sorties (interrupteur « Me prévenir… » + message vide)
│      ├─ Personnaliser → Personnaliser l'accueil (Continuer à regarder / Ma liste : monter, descendre, Masquer)
│      └─ Changer de profil → (PIN parent si enfant) Qui regarde ? / Gérer les profils
├─ Accueil vide : Ajouter un addon → dialogue d'ajout ; Dossier local → Dossiers locaux (ajout) ; Serveur Jellyfin → dialogue Jellyfin
├─ Carte de rangée → Fiche
│  ├─ Lecture auto · meilleure source → Lecteur / « Aucun flux trouvé. Vérifiez vos addons. »
│  ├─ Ajouter à ma liste ⇄ Retirer de ma liste
│  ├─ Série : puces Saisons → cartes Épisodes → Sources
│  └─ Source → Lecteur (non atteint : aucun addon de flux)
└─ Réglages (liste plate)
   ├─ Addons → Addons (monter, descendre, retester, interrupteur, supprimer → confirmation ; Ajouter un addon → dialogue)
   ├─ Dossiers locaux → Dossiers locaux (Ajouter un dossier → permission système → sélecteur / chemin)
   ├─ Serveurs Jellyfin → Serveurs Jellyfin (Ajouter un serveur → dialogue)
   ├─ Suivi (Trakt, Simkl) → Suivi (« Non configuré »)
   ├─ Exporter mes données → dialogue « Inclure les adresses d'addons ? » → phrase secrète → fichier
   ├─ Importer une sauvegarde → sélecteur de fichier système
   ├─ Importer depuis un autre client → Import (2 champs JSON, Choisir un fichier, Importer)
   ├─ Langue de l'interface → sélecteur Français / English
   ├─ Langue audio / sous-titres / Qualité / Préférer les liens directs → sélecteurs
   ├─ Cache torrents / Débit montant / Vider le cache / Exiger un VPN / Interface VPN → sélecteurs
   ├─ Version (7 appuis → « Menu debug » → Spike torrent / Spike lecteur / Boucle d'endurance)
   └─ À propos → Licence GPL-3.0, crédits, Licences open source
Profils : Gérer les profils → Ajouter → éditeur (Nom, Profil enfant, Limite d'âge) → Choisissez un PIN → Confirmez le PIN → Code de récupération
```

Non rendus faute de configuration : Compte et synchro, Phrase secrète, Regarder ensemble (tous masqués sans service de synchro), code d'appareil Trakt (suivi non configuré), bandeau de mise à jour.

## 2. Inventaire des écrans, pop-ups et états visités

Légende maquette : « aucune » = pas de maquette avant l'audit ; les maquettes TV40 et suivantes sont celles créées par l'audit.

| # | Écran / pop-up / état | Capture | Maquette | Verdict |
|---|---|---|---|---|
| 1 | Accueil vide | A/02-home.png | TV13 | Conforme |
| 2 | Barre haute, focus | A/03-nav-focus.png | TV05 (barre) | Écart : pas de pastille ambre sur l'onglet actif, onglet actif en gris |
| 3 | Films / Séries (Recherche filtrée) | A/04-films.png, A/07-nav-series.png | aucune (pas de catalogue) | Écart de produit (D12) |
| 4 | Recherche, saisie vide | A/09-recherche.png | TV12 | Écart : clavier a-z (pas AZERTY), touche « Tout effacer » tronquée « Tou », pas d'espacement |
| 5 | Recherche, résultats | A/142-search-ok.png | TV12 | Écart : badge « addon » au lieu de Direct / Torrent / Jellyfin, pas de compteur « résultats » |
| 6 | Recherche, aucun résultat | A/131-search-results.png | TV46 | Maquette créée |
| 7 | Menu de l'avatar | A/13-avatar.png | TV43 | Maquette créée (le dialogue est centré, boutons de largeurs inégales) |
| 8 | Ma liste vide | A/14-maliste.png | TV20 (rempli), TV41 | Maquette créée |
| 9 | Calendrier vide | A/17-calendrier.png | TV21 (rempli), TV42 | Maquette créée |
| 10 | Personnaliser l'accueil | A/19-perso.png | TV22 | Écart fort : 2 lignes, texte nu, aucune rangée d'addon listée, pas de focus visible |
| 11 | Gérer les profils | A/21-profil.png, A/126-… | TV35 | Écart : pastille crayon sur l'initiale, pas de sous-titre « Adulte » |
| 12 | Qui regarde ? | A/127-picker.png, A/139.png | TV04 | Écart : cadenas sur l'initiale ; focus initial sur « Ajouter » |
| 13 | Éditeur de profil (+ clavier) | A/118-editor2.png, A/120.png | P02 | Écart : clavier Android masque le formulaire ; pas de choix d'avatar |
| 14 | Création du PIN, confirmation | A/122.png, A/123.png | P20 | Maquette créée |
| 15 | Code de récupération | A/125.png | P21 | Maquette créée |
| 16 | PIN pour Moi | A/140-pin-moi.png | P01 | Écart : « Effacer » / « Annuler » à 16 px |
| 17 | PIN parent, incorrect | A/132-picker2.png, A/133-pinwrong.png | P22 | Maquette créée ; défaut D3 |
| 18 | Accueil profil enfant sans contenu | A/128-pinwrong.png | TV45 | Maquette créée |
| 19 | Dialogue d'ajout d'addon (vide, clavier, aperçu) | A/23-edit.png, A/25-imehidden.png, A/27-ime.png | TV08 / TV09 / TV16 | Écart fort : dialogue simple, pas d'onglets Catalogue / Par lien / Depuis le téléphone |
| 20 | Accueil avec catalogues Cinemeta | A/36-home-loaded.png, A/51.png | TV05 | Écart fort (D5, D6) |
| 21 | Fiche film, aucun flux | A/38-fiche2.png, A/49-reg-addons.png | TV06, P11 | Écart : pas de fond / bandeau, bouton coupé |
| 22 | Fiche série (saisons, épisodes) | A/72.png | TV40 | Maquette créée |
| 23 | Addons (2 addons) | A/66.png, A/76.png | TV10 (onglet Sources) | Écart fort : liste plate, icônes de 24 px |
| 24 | Confirmation de suppression d'addon | A/81.png | P09 | Écart léger (anneau collé au texte) |
| 25 | Dossiers locaux vide | A/84-dossiers.png | TV30 | Maquette TV49 (vide + accès refusé) |
| 26 | Permission fichiers (système) | A/86.png | aucune (fenêtre Android) | Hors périmètre ; aucun retour dans Lumio après refus (D14) |
| 27 | Serveurs Jellyfin vide | A/94-jellyfin.png | TV28 (rempli), TV50 | Maquette créée |
| 28 | Suivi non configuré | A/96-suivi.png | TV25 (connecté), TV48 | Maquette créée |
| 29 | Export : « Inclure les adresses d'addons ? » | A/97-export.png | TV33 | Conforme au texte, boutons collés |
| 30 | Import d'une sauvegarde | A/98-import.png | P14 | Sélecteur système non capturé |
| 31 | Importer depuis un autre client | A/99-import-autre.png | TV32 | Écart : contenu centré 670 px, pas de « Retirer le fichier » |
| 32 | Sélecteurs d'option (langue, cache, VPN) | A/100-langue.png, A/101-cache.png, A/103-vpn.png | P13 | Écart : anneau qui déborde du panneau |
| 33 | Réglages (flux plat) | A/11-reglages.png, A/54-reg-d2.png, A/54-reg-d4.png, A/54-reg-d6.png | TV10 / TV14 / TV15 | Écart fort (D6) |
| 34 | Réglages › Général (langue, version) | A/54-reg-d6.png | TV47 | Maquette créée (le menu « Général » de TV10 n'avait pas de page) |
| 35 | À propos | A/104-apropos.png | TV34 | Écart : texte nu à gauche |
| 36 | Menu debug, Spike lecteur | A/109.png, A/110-debugmenu.png, A/111-spike.png | aucune | Écran de développement exposé (D13) |
| 37 | Lecteur (spike) | A/113-play.png … A/115-play-ctrl2.png | TV07 / P03 / P05 / P06 / P10 | Captures noires : la surface vidéo n'est pas capturée et aucun contrôle n'a pu être confirmé |
| 38 | Retour de la racine | A/01-back.png | aucune | Quitte l'application (D2) |

Visités : 38 entrées d'inventaire, 52 états distincts (vides, avec contenu, erreurs, dialogues et claviers compris).

Non atteints : onboarding (TV01 à TV03, exige l'effacement des données, interdit), Compte et synchro / Phrase secrète / Regarder ensemble (masqués sans service de synchro), code Trakt (suivi non configuré), flux par addon, lecteur réel (contrôles, pistes, épisode suivant, cast, chargement torrent, alerte IP, erreur de lecture : aucun addon de flux et pas de fichier local sur la box), Jellyfin connecté et fiche Jellyfin (aucun serveur), fiche locale, sélecteur de fichiers système, bandeau de mise à jour.

## 3. Défauts constatés, par gravité

### Bloquants

- **D1. Les touches fuient vers l'écran du dessous.** Après la fermeture d'un dialogue ou le retour d'un sous-écran (Addons après « Installer », Réglages après Dossiers locaux), aucun élément n'est focalisé et OK / flèches agissent sur l'accueil caché : une fiche s'ouvre toute seule par-dessus (A/72.png, A/91.png, A/93.png). Il faut appuyer sur Tab pour récupérer le focus.
- **D2. Retour quitte l'application.** Retour depuis « Gérer les profils » (ouvert depuis l'avatar) ou depuis la barre haute ramène à l'écran d'accueil Android (A/01-back.png, A/22-b.png), sans confirmation.
- **D3. PIN : après un code incorrect, le pavé est mort.** Le focus disparaît, les chiffres tapés au clavier sont ignorés (même le bon PIN, A/133 à A/135.png) ; seul Tab rend le focus (A/137.png). Le message « PIN incorrect » reste affiché.
- **D4. Le clavier Android s'ouvre tout seul sur les dialogues à champ** (Ajouter un addon, Nouveau profil) et masque le bas du formulaire (boutons Installer / Enregistrer, interrupteur enfant) ; avec la télécommande, la flèche bas ne sort pas du champ (A/23-edit.png, A/29.png, A/118-editor2.png).
- **D5. Accueil avec contenu : mise en page cassée.** Les rangées se chevauchent (le titre « Popular » est mordu par l'anneau de focus, A/46.png), la rangée précédente est réduite à une seule carte sous la barre (A/51.png, A/52.png), la page ne remonte pas quand on revient à la barre. Titres de rangées bruts en anglais, identiques pour films et séries (« Popular », « Popular », « Featured ») ; badge générique « addon » au lieu de Direct / Torrent / Jellyfin / Local.

### Majeurs

- **D6. Réglages ne ressemble pas aux maquettes.** Colonne unique de 860 px collée à gauche, sans marge d'écran, titre de section répété dans chaque ligne, dernière ligne coupée par le bas, titre qui chevauche la liste au défilement (A/54-reg-d2.png). Maquettes TV10 / TV14 / TV15 : rail de catégories à gauche et panneau à droite. Rien de « Profils et contrôle parental ».
- **D7. Écrans secondaires sans marge de sécurité TV.** Titre à 0 à 16 px du bord (Ma liste, Calendrier, Addons, Dossiers, Jellyfin, Suivi, Fiche), bouton d'en-tête à 4 px du haut (A/60.png, A/84-dossiers.png), ligne d'interrupteur pleine largeur sans marge (A/17-calendrier.png). Risque d'overscan sur téléviseur. Maquettes : marge 96.
- **D8. Dialogue d'ajout d'addon : mauvaise cible. (corrigé au cycle 3 : écran à trois onglets Catalogue / Par lien / Depuis le téléphone ; le dialogue est supprimé ; logo de repli = lettre de l'addon ; étiquettes = types et ressources réels)** Un petit dialogue avec champ + Coller + Installer ; ni onglets Catalogue / Par lien / Depuis le téléphone (TV08, TV09, TV16), ni page appairage (`showPairingScreen` n'est appelé nulle part, donc « Depuis le téléphone » est inatteignable). Icône d'addon cassée : le texte alternatif « pen S » déborde dans la pastille (OpenSubtitles, A/64.png). L'addon de sous-titres est étiqueté « Films · Séries » au lieu de « Sous-titres ».
- **D9. Fiche : bouton principal coupé.** « Lecture auto · meilleure source » passe sur deux lignes dans la pastille (A/38-fiche2.png) ; le focus initial n'est pas visible à l'arrivée ; pas de fond ni de bandeau comme TV06 ; synopsis et genres en anglais (données de l'addon, à traduire côté app si possible).
- **D10. Rendu lent sur la box.** Chaque transition met 3 à 5 s à s'afficher (captures périmées), ce qui fait croire que les boutons n'ont pas d'effet.
- **D11. Le menu de l'avatar est un dialogue centré** aux boutons de largeurs inégales ; l'anneau de focus est plus large que la pastille (A/13-avatar.png). Cible : TV43.

### Mineurs

- **D12. Films et Séries n'ouvrent pas un catalogue** mais la Recherche vide pré-filtrée.
- **D13. Menu debug accessible en production** (7 appuis sur « Version », A/109.png) avec « Spike torrent », « Spike lecteur » en anglais et lecteur de test sans contrôles (A/111-spike.png).
- **D14. Refus de la permission fichiers sans retour** : l'écran Dossiers reste identique, pas de message « Lumio a besoin d'accéder à vos vidéos… » (texte pourtant présent dans l'app).
- **D15. Touches du pavé PIN trop petites** : « Effacer » et « Annuler » à environ 16 px (< 24), « PIN oublié ? » sans état de focus visible (A/132-picker2.png). Le focus initial tombe parfois sur « Effacer ».
- **D16. Pastille crayon / cadenas posée sur l'initiale de l'avatar** (A/21-profil.png, A/127-picker.png) ; avatar de l'en-tête ambre alors que le profil « Enfant » est turquoise (A/128-pinwrong.png).
- **D17. Touche « Tout effacer » de la Recherche tronquée** (« Tou · ») et clavier a-z au lieu de l'AZERTY de TV12 (A/09-recherche.png).
- **D18. Sélecteurs d'option : l'anneau de focus déborde** du panneau (A/103-vpn.png) et le panneau recouvre la ligne d'origine.
- **D19. Suivi non configuré : message technique** (« identifiants de l'application … absents ») sans action ni explication pour l'utilisateur (A/96-suivi.png).
- **D20. « Changer de profil » avec un seul profil ouvre « Gérer les profils »** au lieu de « Qui regarde ? ».
- **D21. Personnaliser l'accueil** n'affiche que Continuer à regarder et Ma liste, pas les rangées d'addon, alors que TV22 en liste cinq (A/19-perso.png).
- **D22. Import d'une sauvegarde** : aucune réaction visible dans Lumio pendant l'ouverture du sélecteur système (A/98-import.png).

### Suivi des corrections

« Vérifié box » = constaté sur la box 192.168.0.45 après installation d'une version release ; « code + tests » = corrigé dans le code et couvert par les tests, pas revu sur la box dans ce passage.

| Défaut | Corrigé | Commit | Vérification |
|---|---|---|---|
| D1 touches qui fuient | oui | e9a3844 (FocusRescueObserver) | code + tests |
| D2 Retour quitte l'application | oui | e9a3844, ca2a5b6 (Retour depuis le sélecteur, `beforeSelect` enfin appelé) | vérifié box : Retour depuis « Qui regarde ? » ramène à l'accueil |
| D3 pavé PIN mort après erreur | oui | e9a3844 | code + tests |
| D4 clavier qui s'ouvre seul | oui | e9a3844 | vérifié box : éditeur de profil sans clavier à l'ouverture, clavier seulement après OK |
| D5 accueil : mise en page | oui (rangées) ; hero TV05 et états TV44/45/52 : non | e9a3844 | code + tests |
| D6 Réglages | oui, rail pleine hauteur, Général en premier, carte du profil, pied de rail, carte VPN, jauge du cache, métriques exactes TV10/14/15/47 ; reste : liste d'addons en ligne et cartes Dossiers/Jellyfin de TV10 | e9a3844, 9a1c5f1, ca2a5b6 | vérifié box (cmp-TV15, cmp-TV14, cmp-TV47) |
| D7 marges de sécurité | partiel (écrans refaits : Réglages, sélecteur, Recherche, Ma liste, Calendrier, Personnaliser, Addons, Fiche) ; Jellyfin, Dossiers, Suivi, Watch party, Import, Sauvegarde : non | e9a3844, 7b48b6a | |
| D8 ajout d'addon | non (cycle séparé) | | |
| D9 fiche | bouton sur une ligne : oui ; focus initial : oui ; fond/bandeau TV06 : non revu | 7b48b6a | vérifié box (fiche série) |
| D10 rendu lent | non | | |
| D11 menu avatar | oui (TV43) | 9a1c5f1 | code + tests |
| D12 Films/Séries | non | | |
| D13 menu debug | non | | |
| D14 permission fichiers | non | | |
| D15 touches PIN | oui (P01) | 7b48b6a | code + tests |
| D16 pastilles d'avatar | oui (TV04 : aucun badge ; TV35 : badges 60 dp aux coins) | ca2a5b6 | vérifié box (cmp-TV04, cmp-TV35) |
| D17 Recherche | oui | e9a3844 | code + tests |
| D18 sélecteurs d'option | oui (P13) | 7b48b6a | code + tests |
| D19 Suivi non configuré | non | | |
| D20 « Changer de profil » avec un seul profil | non revu | | |
| D21 Personnaliser | non | | |
| D22 import de sauvegarde | non | | |

## 4. Maquettes créées (docs/design/maquettes/project/)

Toutes en 1920×1080, mêmes jetons et même squelette que P09 / TV13 (`.dc.html`, bloc `data-dc-script` avec `$preview` 1920×1080, vrais `<button>`, SVG en trait avec `aria-hidden`, focus 4 px `#FFE08A`, texte ≥ 24 px). Libellés pris dans `app_fr.arb`. Rendu vérifié en headless (Chrome).

| Fichier | Contenu | Pourquoi |
|---|---|---|
| TV40-FicheSerie | Saisons, épisodes, sources par épisode, variantes « Aucun épisode… », « Spéciaux » | TV06 ne montre aucune série |
| TV41-MaListeVide | Ma liste vide + bouton Recherche | TV20 seulement rempli |
| TV42-CalendrierVide | Aucune série / aucune sortie dans 30 jours | TV21 seulement rempli |
| TV43-MenuAvatar | Menu sous l'avatar (4 entrées) | Aucun menu dans le design |
| TV44-AccueilEtats | Rangée en chargement (squelette) et rangée en échec + Réessayer, badges Direct / Torrent / Jellyfin / Local | États absents de TV05 |
| TV45-AccueilFiltre | « Aucun contenu adapté à ce profil » | Profil enfant sans contenu |
| TV46-RechercheEtats | « Aucun résultat », variantes vide / aucun addon | TV12 n'a que les résultats |
| TV47-ReglagesGeneral | Langue, Version, À propos, note menu debug | Entrée « Général » de TV10 sans page |
| TV48-SuiviNonConfigure | Trakt et Simkl « Non configuré » | TV25 seulement connecté |
| TV49-DossiersVide | Aucun dossier + refus d'accès aux fichiers | TV30 seulement rempli |
| TV50-JellyfinVide | Aucun serveur | TV28 seulement rempli |
| TV51-AddonsVide | Aucun addon + « Action impossible » ; variantes illisible / chargement | P09 montre seulement une liste |
| TV52-AccueilMiseAJour | Bandeau « Mise à jour disponible : version … » + Télécharger / Fermer | Bandeau sans maquette |
| P20-CreationPIN | Choisissez un PIN / Confirmez le PIN + « Les deux PIN ne correspondent pas » | P01 ne couvre que la saisie |
| P21-CodeRecuperation | Code de récupération + « J'ai noté le code » | Absent |
| P22-PINParent | PIN parent (réglages, changement de profil), état erreur, PIN oublié | Variante de P01 sans titre « PIN parent » |
| P23-SousTitresReglages | Pistes + taille, décalage, fond opaque | TV07 sans réglage de sous-titres |
| P24-ErreurFiche | « Impossible de charger la fiche. » + Réessayer | Absent |

Maquettes existantes non modifiées (aucun libellé faux relevé). Les maquettes TV08, TV09, TV16, M04 (ajout d'addon, catalogue) restent la cible : elles ne sont pas refaites ; l'écart est consigné en D8. `canvas.json` : 18 cadres ajoutés (3 par rangée, x 0 / 2040 / 4080, rangées de 1200 de pas à partir de y 21000), note « Audit · écrans ajoutés » en y 20700, aucun chevauchement.

## Défauts relevés sur l'émulateur (2026-11-19)
- Catalogue (TV16) : tuiles qui défilaient par-dessus l'en-tête et la note de bas — corrigé (zone découpée entre l'en-tête et le bas, anneau de focus conservé).
- Accueil vide : pas de focus initial au démarrage à froid ; après fermeture du menu avatar, le focus revient sur l'onglet Accueil — à corriger.
- Flèches d'un clavier (source keyboard) : testées avec `input keyevent DPAD_*` sur l'émulateur, elles déplacent bien le focus de Lumio (langue, accueil, catalogue) ; les raccourcis de l'application n'écartent aucune touche fléchée (`WidgetsApp.defaultShortcuts` + `ActivateIntent` pour OK). Un blocage ne se reproduit donc qu'avec des appuis très rapprochés ; à surveiller sur la box.
- Onboarding profil : le choix d'avatar de la maquette TV02 n'existe pas (le profil n'a pas d'avatar) — écart de conception, pas corrigé.

## Test global sur l'émulateur (2026-11-19, soir)
Compte rendu complet : `docs/rapports/2026-11-19-test-global-emulateur.md`.
- Portail web (ERR_EMPTY_RESPONSE dans un vrai navigateur) : la limite de 4 connexions par adresse bloquait les 6 connexions keep-alive d'un navigateur — corrigé (8 par adresse, 24 au total, éviction de la plus ancienne connexion de la même adresse, idleTimeout 5 s ; tests ajoutés).
- Accueil, « Continuer à regarder » : sans addon de métadonnées pour l'identifiant (ici seulement un addon de catalogue), la carte et le héros affichent l'identifiant brut (`tt0458339`) sans affiche. Cause : la progression ne mémorise ni titre ni affiche ; `ContinueController.describe` les redemande aux addons `meta`. Correctif proposé : stocker titre et affiche dans `Progress` (migration v12) — NON fait.
- Catalogue intégré : ni Cinemeta ni OpenSubtitles v3 (officiels) n'y figurent (source stremio-addons.net) ; l'onglet « Sous-titres » propose des clones tiers. Proposé : rangée « Essentiels » (collection officielle) — NON fait.
- Catalogue, onglet « Populaires » : le premier focus tombe sur Torrentio ; une confirmation distraite installe un addon de torrents. À réfléchir (focus initial sur la barre de puces).
- Portail, fiche « Configurer » : après l'envoi par le formulaire principal (et non par le bouton du panneau), le panneau reste ouvert et un second exemplaire de l'addon est installé au lieu de remplacer l'existant — NON corrigé.
- Réglages : la carte « Gérer depuis le téléphone » ouvre un écran titré « Ajouter un addon » — libellé à harmoniser.
- Dialogue « Choisir une instance » (Marvel) : terme technique pour le grand public — à reformuler.
- Lecteur : la première touche ne fait que réveiller les commandes ; sur l'émulateur l'image vidéo reste noire sur les captures (rendu logiciel de media_kit), seule la lecture (temps qui avance) est vérifiable.

### Passe 2 (2026-11-19, soir) : état
- Corrigé et vérifié sur l'émulateur : puce « Officiels » (collection officielle de Stremio, focus initial sur Cinemeta), titre et affiche mémorisés dans la progression (base v12, repli « Titre inconnu »), lecteur (commandes 6 s, flèche haut = Pistes), portail v2 (M05a/b/c : 2 onglets, Installer/Régler, écran Régler en 3 étapes, vocabulaire grand public), lien non affiché sur la TV, remplacement d'un addon du même hôte et du même identifiant, titre « Gérer depuis le téléphone », « serveur » à la place de « instance », une seule confirmation à l'installation depuis le catalogue.
- Restent : libellés indistincts dans « Pistes » et échec de lecture après le choix d'un sous-titre d'addon ; badge « Installé » qui chevauche un nom long ; « Titre inconnu » non rafraîchi à chaud après l'installation d'un addon meta ; « Changer les réglages » affiché pour tous les addons du portail ; titre du lecteur = nom du flux. Étapes F (réglages de sous-titres), H (reprise après force-stop, séries, fin de lecture), I (maintien de touche, série, Ma liste, recherche) non terminées : voir le compte rendu.

### Passe 4 (2026-11-19, soir)
- Corrigé : échec de lecture / sous-titre refusé. Cause = SRT d'addon débutant par une ligne vide + BOM (libmpv le refuse) ; blancs et BOM de tête retirés (a265d0c). L'erreur moteur de sous-titre n'interrompt plus la lecture (20e8e31, confirmé : Reprendre et lecture de Tenzing OK).
- Corrigé : Taille et Fond opaque des sous-titres n'agissaient pas (media_kit dessine le texte) ; style passé au rendu Flutter (617e09e). À revérifier à l'écran.
- Ouvert : la ligne choisie dans « Pistes » reste marquée même quand le moteur a refusé le fichier ; il faudrait n'afficher la sélection qu'après succès (et le message « sous-titre illisible » sur erreur moteur).
- Ouvert : avec OpenSubtitles v3, le panneau Pistes liste une centaine de sous-titres (codes à 3 lettres ALB, HRV, EST mélangés à des noms de langue, doublons numérotés) ; atteindre « Apparence » demande des dizaines de pressions bas. Proposer : regrouper par langue, langue préférée en tête, plafond (5 par langue), et « Apparence » en tête ou sur un onglet.
- Ouvert : le pas de la taille (100 %, 164 %) est peu parlant ; préférer S/M/L/XL nommés.

### Passe 6 (2026-11-19, soir)
- Corrigé et vérifié à l'écran : recherche (1re rangée de résultats entière, « droite » reste dans la rangée), focus de retour sur la carte d'origine, héros « REPRENDRE · S3E3 » à 0 s, appui long sur une carte de « Ma liste » (menu « Ouvrir la fiche » / « Retirer de ma liste »).
- Corrigé, tests verts, NON revérifié à l'écran : piste interne « fr · auto » masquée dans Pistes ; Retour ne part plus deux fois (la fiche ouverte depuis la recherche ramenait à l'accueil ; un Retour sur l'accueil proposait aussitôt « Quitter Lumio ? » ; au retour d'une fiche l'onglet « Accueil » prenait le focus).
- Anime : Anime Kitsu absent des puces « Officiels » et « Anime » du catalogue (installé par lien) ; catalogues Kitsu sur l'accueil, fiche et épisodes affichés ; flux de test pour `kitsu:` prêt (addon de test) ; lecture et reprise d'un épisode d'anime non jouées (émulateur instable).
- Ouvert : « Anime Kitsu » devrait figurer dans la puce « Anime » du catalogue (celle-ci ne propose que des addons de torrents) ; au démarrage à froid de l'émulateur l'écran « Set up Google TV » vole le focus (hors application).

### Passe 7 (2026-11-19, soir)
- Corrigé et vérifié à l'écran : puce « Anime » du catalogue (Anime Kitsu en tête, via la collection communautaire) ; piste « auto » absente de Pistes avec des sous-titres d'addon ; lecture, épisode suivant et reprise d'un épisode d'anime (« REPRENDRE · É4 », « Reprise à 0:18 ») ; un Retour = un retour (lecteur, fiche, accueil, « Quitter Lumio ? » au second niveau seulement) ; focus de retour sur la carte d'origine depuis l'accueil.
- Corrigé (test d'abord) et vérifié : lecteur, une flèche commandes visibles et focus sur la racine ne quitte plus le lecteur (le focus partait sur l'accueil resté dessous).
- Tests verts, NON revérifié à l'écran : Retour et focus d'origine depuis la recherche et depuis « Ma liste ».
- Ouvert : le lecteur masque les commandes avec un fondu et la première touche suivante ne fait que les réveiller (±10 s pour gauche/droite) ; acceptable, à confirmer sur une vraie télécommande.

### Passe 8 (2026-11-20, vraie box)
- Corrigé et vérifié à l'écran : cartes sans affiche (fond de surface + icône, c'était la « rangée de boutons vides » de la recherche), anneau de focus des touches du clavier (plus de chevauchement), focus initial de « Ma liste » et de « Personnaliser ».
- Corrigé, test vert, non revu à l'écran : focus initial de « Importer depuis un autre client ».
- Règle : l'anneau de focus (contour 4 + écart) ne doit pas toucher un voisin ; pour les éléments serrés, pas d'agrandissement et `ringGap: 0`. Test générique ajouté sur le clavier ; à étendre aux autres groupes serrés.
- Ouvert : focus perdu de la flèche gauche depuis l'onglet « Accueil » (4 appuis sans anneau visible) ; texte d'« Ajouter un dossier » tronqué (« saisissez le ch… ») ; « Actualiser » coupé à droite des puces du catalogue ; fiche : bouton « + Ma liste » coupé en bas à 1080p.

### Passe box du 2026-11-20 : 4 défauts restants
Box « 4K Google TV Box » (192.168.0.47, 1920 x 1080), build release installé par `install -r`, un seul build pour les 4 correctifs. Chaque défaut a d'abord un test rouge.
- **Flèche gauche depuis « Accueil » (barre haute)** : le focus partait dans le contenu (anneau absent de la barre). Corrigé : Gauche est absorbée sur « Accueil », le focus reste dessus. Test : `home_screen_test` « Gauche depuis Accueil garde le focus dessus ». Vérifié box : oui (`D1-accueil-gauche-reste-sur-accueil.png`).
- **Catalogue d'addons, « Actualiser » coupé** : les puces défilent maintenant dans leur propre fenêtre, « Actualiser » reste fixé à droite, entier, dans les marges de 96 dp ; anneau des puces d'extrémité non rogné (fenêtre débordante de 12 dp). Test : `add_addon_screen_test` « Actualiser reste entièrement visible ». Vérifié box : oui, « Actualiser » visible puis focalisé avec son anneau après avoir parcouru toutes les puces jusqu'à « Plus… » (`D2-catalogue-actualiser-visible.png`, `D2b-catalogue-actualiser-focus.png`).
- **Fiche série, « + Ma liste » coupé à 1080p** : les boutons sont épinglés en bas de la colonne gauche (marge de 12 dp autour pour l'anneau et l'échelle), affiche 240 x 360, titre 2 lignes, synopsis 4 lignes dans cette colonne. Marge de 12 dp aussi autour des boutons de la fiche film. Test : `detail_screen_test` « fiche série à 1080p ». Vérifié box : oui, les deux boutons entiers, anneau compris (`D3-fiche-serie-ma-liste-visible.png`).
- **Dossiers locaux, « Ajouter un dossier » tronqué** : l'en-tête réservait 2/5 de la largeur aux actions et les réduisait d'un bloc ; les actions gardent leur largeur naturelle (titre ellipsé, au moins 420 dp), réduites seulement au-delà de 1100 dp. Test : `local_screen_test` « Ajouter un dossier : libellé complet, ni coupé ni réduit ». Vérifié box : oui (`D4-dossiers-locaux-ajouter-complet.png`).
- Constats hors périmètre : sur la box, l'affichage met 5 à 10 s à se mettre à jour après une touche (captures périmées) ; le test `settings_screen_test` « vider le cache à la fermeture » échoue à cause de modifications non commitées d'une autre session (libellé `uploadOff` dans les .arb), sans lien avec ces correctifs.

