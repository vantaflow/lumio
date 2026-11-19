# Refonte TV — suivi écran par écran

Règle : un écran est « fait » seulement quand l'image côte à côte maquette | box (scratchpad/refonte*/cmp-*.png) ne montre plus aucun écart hors données réelles. La refonte est terminée quand **toutes** les lignes sont « fait » ou « — ».

| Écran | Maquette | État |
|---|---|---|
| TV 01 · Onboarding · Langue | `Main.dc.html` | fait (comparaison maquette | box) |
| TV 02 · Onboarding · Profil | `TV02-Profil.dc.html` | fait (comparaison maquette | box) |
| TV 03 · Onboarding · Ajouter vos sources | `TV03-Sources.dc.html` | fait (comparaison maquette | box) |
| TV 04 · Choix du profil (PIN) | `TV04-ChoixProfil.dc.html` | fait (cmp : scratchpad/refonte4/cmp-TV04.png) — centré voulu par l'utilisateur ; panneau PIN et libellé « Filtre -12 ans » = données/états ; à vérifier sur la box |
| TV 05 · Accueil | `TV05-Accueil.dc.html` | fait (rendu : scratchpad/refonte5/cmp-TV05.png) — à vérifier sur la box ; héros = reprise la plus récente (+ Ma liste = ajout/retrait réel, seulement pour un titre de catalogue) ; cartes 300×170 (affiche réelle sinon dégradé, pastille seulement Local/Jellyfin : la source Direct/Torrent n'est connue qu'à la recherche de flux) ; pastille « Accueil » courante en gris #2A3340 (TV13/44/45/52) et non ambre comme dans TV05 seul ; rangées 12 px d'écart (TV05) alors que TV44 en montre 20 |
| TV 06 · Fiche + flux par addon | `TV06-Fiche.dc.html` | à reprendre : refait sans comparaison |
| TV 07 · Lecteur | `TV07-Lecteur.dc.html` | à reprendre : cmp box (scratchpad/refonte4/cmp-pl.png) sans écart de mise en page hors données (titre/sous-titre de source, durées, bouton Suivant) ; maquette = état composite (panneau + épisode suivant) ; titre plus étroit corrigé par la police ; à vérifier sur la box |
| TV 08 · Ajouter un addon · Par lien | `TV08-AjoutAddon.dc.html` | cycle ajout d'addon (après la refonte) |
| TV 09 · Ajouter un addon · Depuis le téléphone (page de la box) | `TV09-Appairage.dc.html` | cycle ajout d'addon (après la refonte) |
| TV 10 · Réglages · Sources | `TV10-Reglages.dc.html` | à reprendre : liste des addons en ligne + cartes Dossiers/Jellyfin manquantes |
| TV 11 · Recherche | `TV12-Recherche.dc.html` | fait (rendu : scratchpad/refonte5/cmp-TV12.png) — à vérifier sur la box ; panneau clavier 760, touches 69×84 en 8 colonnes (lettres, chiffres, Espace/Effacer/Tout effacer/langue gardés), micro rond à côté du champ, cartes 230×340 ; la maquette TV46 montre un autre clavier (7 colonnes, sans panneau) : TV12 suivi |
| TV 12 · Accueil vide (aucune source) | `TV13-AccueilVide.dc.html` | fait (comparaison maquette | fait (rendu : scratchpad/refonte5/cmp-TV13.png, revérifié après changement de police/TvScreen) — à vérifier sur la box |
| TV 13 · Réglages · Lecture | `TV14-ReglagesLecture.dc.html` | fait (comparaison maquette | box) |
| TV 14 · Réglages · Torrents et VPN | `TV15-ReglagesTorrents.dc.html` | fait (comparaison maquette | box) |
| TV 15 · Ajouter un addon · Catalogue (stremio-addons.net) | `TV16-Catalogue.dc.html` | cycle ajout d'addon (après la refonte) |
| Téléphone · Accueil | `M01-Accueil.dc.html` | — téléphone |
| Téléphone · Fiche | `M02-Fiche.dc.html` | — téléphone |
| Téléphone · Ajout d'addon | `M03-Ajout.dc.html` | — téléphone |
| Bureau · Accueil | `D01-Accueil.dc.html` | — hors cible (Android TV) |
| Téléphone · Page web de la box | `M04-PageWebBox.dc.html` | cycle ajout d'addon (après la refonte) |
| TV 20 · Ma liste | `TV20-MaListe.dc.html` | à reprendre : refait sans comparaison |
| TV 21 · Calendrier des sorties | `TV21-Calendrier.dc.html` | à reprendre : refait sans comparaison |
| TV 22 · Personnaliser l'accueil | `TV22-PersonnaliserAccueil.dc.html` | à reprendre : refait sans comparaison |
| TV 23 · Compte et synchronisation | `TV23-CompteSynchro.dc.html` | — retiré (synchro supprimée) |
| TV 24 · Phrase secrète | `TV24-PhraseSecrete.dc.html` | — retiré (synchro supprimée) |
| TV 25 · Suivi Trakt et Simkl | `TV25-Suivi.dc.html` | fait (rendu : scratchpad/refonte4/cmp-r-TV25.png) — à vérifier sur la box ; cartes dans l'écran Suivi ; Simkl absent de l'app (Trakt seul) ; réglage parental non rendu (profil adulte) |
| TV 26 · Code d'appareil Trakt | `TV26-TraktCode.dc.html` | fait en code (écran refait selon TV26) — rendu non produit, à vérifier sur la box |
| TV 27 · Regarder ensemble | `TV27-WatchParty.dc.html` | à faire : écran Regarder ensemble encore en Material (deux colonnes TV27 à écrire) ; visible seulement avec PARTY_SERVER_URL |
| TV 28 · Jellyfin · serveurs et navigation | `TV28-Jellyfin.dc.html` | partiel : liste des serveurs refaite (TvScreen, lignes 96, corbeille) ; navigation des bibliothèques (volet droit) et fiche encore en Material |
| TV 29 · Fiche Jellyfin | `TV29-JellyfinFiche.dc.html` | à faire : fiche Jellyfin encore en Material |
| TV 30 · Dossiers locaux | `TV30-DossiersLocaux.dc.html` | à vérifier sur la box : cmp box (scratchpad/refonte4/cmp-dl.png) montrait en-tête non aligné à droite et bouton d'analyse trop clair, corrigés (TvScreen + fond surface) ; lignes conformes |
| TV 31 · Fiche locale | `TV31-FicheLocale.dc.html` | à vérifier sur la box : cmp (scratchpad/refonte4/cmp-fl.png) sans écart hors données, 1-2 px d'écart vertical du titre |
| TV 32 · Import depuis un autre client | `TV32-ImportStremio.dc.html` | fait (rendu : scratchpad/refonte4/cmp-r-TV32.png) — à vérifier sur la box ; maquette = états composites (fichier chargé, progression, bilan) |
| TV 33 · Sauvegarde | `TV33-Sauvegarde.dc.html` | partiel : lignes avec icônes et panneaux/dialogues refaits (TvPanel) ; la maquette est un écran seul « Réglages · Sauvegarde », l'app garde le rail des Réglages (TV10/TV47) ; pas de rendu |
| TV 34 · À propos | `TV34-APropos.dc.html` | fait (rendu : scratchpad/refonte4/cmp-r-TV34.png, largeur de texte 1308 corrigée ensuite) — à vérifier sur la box |
| TV 35 · Gestion des profils | `TV35-ProfilsGestion.dc.html` | fait (comparaison maquette | box) |
| Pop-up 01 · PIN | `P01-PIN.dc.html` | fait (comparaison maquette | box) |
| Pop-up 02 · Éditeur de profil | `P02-EditeurProfil.dc.html` | fait (comparaison maquette | box) |
| Pop-up 03 · Diffusion | `P03-Cast.dc.html` | à faire |
| Pop-up 04 · Alerte adresse IP | `P04-AlerteIP.dc.html` | à faire |
| Pop-up 05 · Chargement torrent | `P05-ChargementTorrent.dc.html` | à faire |
| Pop-up 06 · Épisode suivant | `P06-EpisodeSuivant.dc.html` | à faire |
| Pop-up 07 · Ajout Jellyfin | `P07-AjoutJellyfin.dc.html` | fait en code (TvPanel 920, champs P07, erreur rouge) — pas de rendu, à vérifier sur la box |
| Pop-up 08 · Choix du dossier | `P08-ChoixDossier.dc.html` | à vérifier sur la box (panneau de saisie de chemin refait au lot précédent) |
| Pop-up 09 · Confirmation | `P09-Confirmation.dc.html` | à faire |
| Pop-up 10 · Erreur de lecture | `P10-ErreurLecture.dc.html` | à faire |
| Pop-up 11 · Aucun flux | `P11-AucunFlux.dc.html` | à faire |
| Pop-up 12 · Addon hors ligne | `P12-AddonHorsLigne.dc.html` | à faire |
| Pop-up 13 · Sélecteur d'option | `P13-SelecteurOption.dc.html` | à faire |
| Pop-up 14 · Import de sauvegarde | `P14-ImportSauvegarde.dc.html` | fait en code (TvPanel 960, champ P14 avec erreur rouge) — pas de rendu, à vérifier sur la box |
| TV 40 · Fiche série · saisons et épisodes | `TV40-FicheSerie.dc.html` | à reprendre : fond colonne gauche, zone Sources |
| TV 41 · Ma liste · vide | `TV41-MaListeVide.dc.html` | à faire |
| TV 42 · Calendrier · aucune série ou aucune sortie | `TV42-CalendrierVide.dc.html` | à faire |
| TV 43 · Menu de l'avatar | `TV43-MenuAvatar.dc.html` | fait (comparaison maquette | box) |
| TV 44 · Accueil · rangée en chargement et en échec | `TV44-AccueilEtats.dc.html` | fait (rendu : scratchpad/refonte5/cmp-TV44.png, héros retiré du rendu comme la maquette) — à vérifier sur la box ; 8 px d'écart vertical entre rangées (12 au lieu de 20, voir TV05) |
| TV 45 · Accueil · profil enfant sans contenu adapté | `TV45-AccueilFiltre.dc.html` | fait (rendu : scratchpad/refonte5/cmp-TV45.png) — à vérifier sur la box ; boutons « Changer de profil » (filtre), « Gérer les addons » (aucun catalogue) et « Réessayer » (addons illisibles) ; couleur de l'avatar = celle du choix de profil |
| TV 46 · Recherche · saisie vide et aucun résultat | `TV46-RechercheEtats.dc.html` | fait (rendu : scratchpad/refonte5/cmp-TV46.png) — à vérifier sur la box ; état centré dans le volet des résultats (la maquette le centre sur tout l'écran) ; clavier de TV12 (TV46 en dessine un autre) |
| TV 47 · Réglages · Général | `TV47-ReglagesGeneral.dc.html` | fait (comparaison maquette | box) |
| TV 48 · Suivi · non configuré | `TV48-SuiviNonConfigure.dc.html` | à reprendre : la maquette montre le rail des Réglages avec les cartes dans la page ; l'app ouvre l'écran Suivi (TV25) depuis le rail |
| TV 49 · Dossiers locaux · vide et accès refusé | `TV49-DossiersVide.dc.html` | fait (rendu : scratchpad/refonte4/cmp-r-TV49.png) — à vérifier sur la box |
| TV 50 · Jellyfin · aucun serveur | `TV50-JellyfinVide.dc.html` | fait (rendu : scratchpad/refonte4/cmp-r-TV50.png) — à vérifier sur la box |
| TV 51 · Addons · aucun addon et erreurs | `TV51-AddonsVide.dc.html` | à reprendre : refait sans comparaison |
| TV 52 · Accueil · mise à jour disponible | `TV52-AccueilMiseAJour.dc.html` | fait (rendu : scratchpad/refonte5/cmp-TV52.png, héros retiré du rendu comme la maquette) — à vérifier sur la box |
| Pop-up 20 · Création du PIN | `P20-CreationPIN.dc.html` | à faire |
| Pop-up 21 · Code de récupération | `P21-CodeRecuperation.dc.html` | fait (comparaison maquette | box) |
| Pop-up 22 · PIN parent | `P22-PINParent.dc.html` | à faire |
| Pop-up 23 · Réglages des sous-titres | `P23-SousTitresReglages.dc.html` | fait (cmp : scratchpad/refonte4/cmp-pi.png) — mêmes positions que P23 ; ligne « Variante » = état d'erreur ; à vérifier sur la box |
| Pop-up 24 · Fiche indisponible | `P24-ErreurFiche.dc.html` | à faire |
