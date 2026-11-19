# Test fonctionnel global sur l'émulateur TV (2026-11-19)

Émulateur Google TV Android 14 (x86, traduction ARM, 1920x1080), APK release android-arm, fenêtre scrcpy sous les yeux de l'utilisateur. Contenu légal uniquement. Passe INCOMPLÈTE (contexte épuisé) : ce qui est fait et ce qui reste est indiqué étape par étape.

## Addon de test (jamais embarqué)
`~/lumio-build/test-addon` sur la machine IA (port 7012) : `./run.sh start | stop | status`. Manifest « Films libres (test) » : catalogue de 5 films Blender (Sintel, Big Buck Bunny, Tears of Steel, Elephants Dream, Cosmos Laundromat), ressources catalog, meta, stream, subtitles, types movie et series, préfixe `tt`. Pour TOUT identifiant `tt…` (film, ou série avec saison:épisode) il renvoie un flux https de test « Flux de test (contenu libre) » (MP4 Blender, archive.org / download.blender.org) et deux sous-titres libres (Sintel EN/FR, durian.blender.org). Installé par « Par lien » (http://10.0.2.2:7012/manifest.json) : la confirmation « Adresse locale » apparaît bien.

## Résultats par étape
| Étape | Résultat |
|---|---|
| A. Premier lancement, onboarding (langue, profil, sources) | OK. Accueil atteint ; « 1 addon installé » affiché à l'étape 3. |
| B. Catalogue intégré, badge, installation directe | Partiel : installation directe de Marvel depuis le catalogue OK (dialogue « Choisir une instance », fiche, puis aperçu « Par lien », puis Installer : deux confirmations). Cinemeta et OpenSubtitles v3 absents du catalogue (défaut consigné). Badge « Installé » vu sur le portail. |
| C. Paramétrage | OK de bout en bout, deux côtés (voir ci-dessous). |
| D. Fonctionnement : catalogues, fiche, flux | OK : rangées de l'addon de test et de Marvel sur l'accueil ; fiche d'un titre Marvel (Captain America) avec le flux de test du bon groupe (« ADDON · Films libres (test) · Santé : bonne », « Direct »). Fiche pauvre (pas de synopsis) quand aucun addon meta n'existe. |
| E. Lecture | OK sur le fond : démarrage, temps qui avance (durée 14:48), ±10 s, barre, commandes. L'image est noire sur les captures de l'émulateur (rendu logiciel) : non vérifiable ici. Panneau Pistes : non atteint (la première touche ne fait que réveiller les commandes, qui se masquent en 3 s). |
| F. Sous-titres | NON FAIT (à tester sur la vraie box). |
| G. Favoris | NON FAIT. |
| H. Reprise | Partiel : le titre apparaît dans « Continuer à regarder » avec barre et bouton « Reprendre », « Reprise à 1:06 » proposé au 2e lancement. DÉFAUT : affiche et titre remplacés par l'identifiant brut `tt0458339`. Force-stop et fin de lecture : NON FAIT. |
| I. Surveillance | Pas de plantage ni FATAL. Erreurs « Failed to decode image » dans logcat (une affiche non décodable, sans effet visible). Émulateur très lent (images jusqu'à 20 s au démarrage) : les captures retardent sur les touches. |

## C. Paramétrage : avis
Parcours testé dans la vraie fenêtre Chrome (portail) et sur la TV : TV, Réglages, « Gérer depuis le téléphone » (adresse et code à 6 chiffres) ; portail : connexion, catalogue, fiche, « Configurer » ouvre la page /configure de l'addon (Torrentio, uniquement pour tester le formulaire, jamais pour lire ; retiré ensuite), l'onglet donne le lien produit (bouton INSTALL, lien stremio://), retour sur le portail, collage, « Envoyer à la TV », « En attente de confirmation sur la TV… », aperçu sur la TV, Installer, bandeau vert « Installé ». Environ 9 étapes dont 3 changements d'écran : c'est long mais chaque étape est guidée et la sécurité (confirmation sur la TV) est préservée. Points de confusion : (1) le panneau « Configurer » reste ouvert après l'envoi et le formulaire principal ajoute un doublon au lieu de remplacer ; (2) deux boutons « Envoyer à la TV » sur la même page ; (3) la TV affiche le lien brut tronqué ; (4) la carte de la TV s'appelle « Gérer depuis le téléphone » mais ouvre « Ajouter un addon ». Piste de simplification : fermer le panneau et vider le champ après succès, remplacer automatiquement un addon de même hôte, un seul bouton d'envoi. Une reconfiguration de Marvel (3 catalogues sur 6, lien construit comme la page le ferait) envoyée avec `replaces` a bien remplacé l'addon.

## Défauts et corrections
1. Portail inaccessible depuis un navigateur (ERR_EMPTY_RESPONSE) : limite de 4 connexions par adresse. CORRIGÉ (commit 5dd9052) : 8 par adresse, 24 au total, la plus ancienne connexion de la même adresse est fermée pour servir la nouvelle, idleTimeout 5 s, protection contre les connexions lentes conservée ; tests : 6 connexions keep-alive puis une 7e servie, éviction de la plus ancienne ; spec mise à jour. Revérifié sur l'émulateur : 8 requêtes parallèles = 8 x 200, puis une 9e = 200.
2. « Continuer » affiche l'identifiant brut. Cause trouvée (progression sans titre ni affiche), correctif décrit dans AUDIT-UI, NON fait.
3. Autres défauts de présentation : voir `docs/design/AUDIT-UI.md`, section « Test global sur l'émulateur ».

Note de conduite : pendant le test, un addon Torrentio a été installé sur l'émulateur (confirmations de la TV partagées avec le test du portail de l'utilisateur) ; il a été supprimé à chaque fois et n'a servi à aucune lecture.

## Limites et reste à faire
Sous-titres (F), favoris (G), reprise après force-stop et fin de lecture (H), séries multi-saisons, « épisode suivant », anime, plusieurs films récents/anciens issus de Cinemeta (non installé : pas de catalogue grand public sans lui), défilement en rafales. Ne se vérifie que sur la vraie box : image vidéo, fluidité, sous-titres rendus sur l'image, HEVC.


## Passe 2 (même soirée) : correctifs et étapes jouées
Correctifs livrés (commit « catalogue Officiels, titre mémorisé, lecteur 6 s, portail v2 (M05) »), revérifiés sur l'émulateur avec un APK release neuf :

| Point | Correctif | Vérifié sur l'émulateur |
|---|---|---|
| 1a | Puce « Officiels » en premier (https://api.strem.io/addonsofficialcollection.json, « Local Files » 127.0.0.1 écarté), fusionnée sans doublon avec les Populaires, cache 24 h et garde réseau partagés ; rien n'est pré-installé. Tests : 4 (core) + 1 (écran). | Oui : Cinemeta et OpenSubtitles v3 installés depuis le catalogue ; badge « Installé ». |
| 1b | Base v12 : titre, affiche, type, saison, épisode dans `progress` ; repli meta pour les anciennes lignes ; jamais d'identifiant brut (« Titre inconnu »). Tests : migration v11 vers v12 sur base réaliste, dépôt, 3 pour `describe`. | Oui : ancienne ligne tt0458339 = « Titre inconnu » sans addon meta, puis « Captain America: The First Avenger » avec affiche après Cinemeta ; Tenzing (nouvelle lecture) = titre + affiche, « 7 min restantes ». |
| 1c | Commandes 6 s ; flèche haut (commandes masquées) = affiche et focalise « Pistes » ; flèche bas = commandes ; gauche/droite déplacent déjà de 10 s en réveillant. | Oui : haut puis OK ouvre « Pistes et sous-titres » ; commandes masquées après 6 s. |
| 1d | Portail v2 (maquettes M05a/b/c) : 2 onglets, cartes avec un seul bouton Installer/Régler, écran Régler en 3 étapes, « Mes addons » avec états en mots, vocabulaire grand public, un seul bouton d'envoi ; la TV n'affiche plus le lien (nom + « Serveur : domaine ») ; même hôte + même id = remplacement avec note, rang conservé ; « Gérer depuis le téléphone » titre l'écran ; « instance » devient « serveur » ; une seule confirmation (fiche seulement si réglage requis). | Oui, dans la fenêtre Chrome (390 px émulés) : captures Ajouter, lien, Mes addons, Régler ; remplacement de « Films libres (test) » via un lien du même hôte : 1 seul exemplaire, même rang. |
| 1e | Focus initial = première carte (Cinemeta). | Oui. |

### Étapes
| Étape | Résultat |
|---|---|
| F. Sous-titres | PARTIEL. Le panneau Pistes est atteint (flèche haut) et liste les sous-titres des addons (OpenSubtitles v3 + addon de test), mais les libellés « Addon · en » sont indistincts (une trentaine d'entrées, doublons). Choix d'un sous-titre : l'écran « La lecture a échoué. » est apparu et l'émulateur, très lent, a ensuite mal répondu aux touches (BACK a fini par ramener à la fiche) ; cause non établie (aucune trace utile dans logcat ; hypothèse : erreur du moteur à l'ajout du fichier traitée comme fatale après le premier affichage). NON résolu. Réglages taille/décalage/fond et langue préférée : NON joués. |
| G. Ma liste | OK : ajout depuis la fiche de Tenzing (bouton devenu « Retirer de ma liste »), présence dans la rangée « Ma liste » de l'accueil et dans le héros. Retrait et ajout depuis l'accueil : non joués. |
| H. Reprise | PARTIEL : lecture de Tenzing 45 s puis retour, « Continuer » = titre + affiche + barre. Force-stop puis relance : « Captain America » (ancienne ligne) conservé avec titre et affiche. Reprise de Tenzing après force-stop, série (épisode suivant), fin de lecture : NON joués (l'émulateur emulator-5580 a disparu du tunnel pendant la relance ; consigne : ne pas le redémarrer). |
| I. Défilement | PARTIEL : 8 pressions bas d'affilée sur l'accueil rempli (Cinemeta + addon de test, ~12 rangées) sans à-coup ni plantage ; pas de FATAL ni d'exception Flutter dans logcat (seuls les « Failed to decode image » connus). Maintien `--longpress`, fiche série multi-saisons, Ma liste, recherche : NON joués. |
| Titres variés (2 films récents, 1 ancien, 1 série, 1 anime) | NON joués : seuls Tenzing (2026) et Captain America (2011) ont été ouverts. |

### Défauts restants
1. Sous-titres : libellés indistincts dans « Pistes » ; échec de lecture après choix d'un sous-titre d'addon (à reproduire sur la vraie box).
2. Après installation d'un addon de métadonnées, une carte « Continuer » déjà affichée garde « Titre inconnu » jusqu'au prochain démarrage.
3. Carte du catalogue : le badge « Installé » chevauche un nom long (« OpenSubtitles v3 »).
4. Portail : « Changer les réglages » s'affiche aussi pour un addon sans page de réglage (message « pas de page de réglage » au clic).
5. Fiche de lecture : le titre du lecteur est le nom du flux (« Flux de test (contenu libre) ») et non celui du film.


## Passe 3 : correctifs (code livré, vérification sur émulateur INTERROMPUE)
L'émulateur emulator-5580 a disparu d'adb (`adb devices` vide) juste après l'installation de l'APK corrigé ; conformément à la consigne il n'a pas été relancé. Étapes F, G, H, I et titres variés : NON JOUÉES dans cette passe.

Correctifs (tests verts : core 531, app 741, analyze et format propres) :
- a. Cause établie par lecture de media_kit 1.2.6 : tout message d'erreur libmpv de préfixe cplayer, stream, file, vd ou ad est relayé comme erreur du lecteur ; un refus d'ajout de sous-titre (« Can not open external file ») faisait donc passer le lecteur en « La lecture a échoué ». Correctif : `isIgnorableEngineError` (sous-titres) ignoré, plus journal `LUMIO_PLAYER {"event":"engine_error"}` sans adresse. À confirmer sur émulateur (le correctif n'a pas pu être revérifié ; une relecture « Reprendre » de Tenzing échouait aussi juste avant, cause non établie faute de journal).
- b. Libellés « Langue · Addon [n°] » (SubtitleItem.addonName).
- c. « Continuer » et héros se redécrivent quand les addons changent.
- d. Badge « Installé » placé sur la ligne de méta, plus de chevauchement.
- e. Portail : `configurable` (behaviorHints) ; bouton masqué seulement si le manifeste dit non (inconnu = affiché).
- f. Titre du lecteur = film ou « Série · SxEy » ; sous-titre = source, qualité, langue.


## Passe 4 : cause de « La lecture a échoué », sous-titres, émulateur perdu de nouveau
Émulateur 127.0.0.1:5601, APK de 20e8e31. En cours de passe l'appareil est passé « offline » puis a disparu d'adb ; conformément à la consigne il n'a pas été relancé (ni reconnect). Tout ce qui suit a été vérifié AVANT la perte ; le reste n'est pas joué.

### Échec de lecture : cause et correctif
- Rejoué avec le journal `LUMIO_PLAYER` : « Reprendre » de Captain America (reprise à ~3:50 sur 14:48, temps cohérent avec « 11 min restantes ») et lecture de Tenzing (0:20 sur 12:14) démarrent et avancent : plus d'écran « La lecture a échoué » (correctif 20e8e31 confirmé). Ni la reprise à une position, ni le proxy, ni l'expiration d'URL ne sont en cause.
- Le journal montre bien l'événement `engine_error` (« Can not open external file <url> », opened=true), maintenant ignoré. Avant 20e8e31 il faisait passer le lecteur en échec.
- Vraie cause de l'erreur moteur : le sous-titre français de l'addon de test (sintel_fr.srt) commence par un retour à la ligne puis un BOM UTF-8 (octets 0A EF BB BF 31…). `decodeSubtitleBytes` ne retirait le BOM qu'en tête absolue ; libmpv ne reconnaît pas un SRT qui ne commence pas par son premier numéro et refuse le fichier. Le sous-titre anglais (ASCII) passait. Constaté : choix « English · Films libres (test) » = texte affiché (« We're almost done. Shhh… », « Get him, Scales! Come on! », « Yeah! Come on! ») ; choix « Français » = `engine_error`, rien d'affiché alors que le panneau marquait la ligne comme choisie.
- Correctif (a265d0c), en TDD (rouge puis vert, core 532 tests) : après décodage, retrait des blancs et BOM de tête (UTF-8 et UTF-16).
- Second défaut découvert : les réglages Taille et Fond opaque ne changeaient rien à l'écran (taille 164 % et fond opaque réglés, texte inchangé). media_kit dessine lui-même le texte (SubtitleView Flutter) ; seul `sub-delay` agit via libmpv. Correctif (617e09e) : `SubtitleStyle.viewConfiguration()` (taille 32 x rapport, fond noir plein ou ombre) passé à `Video(subtitleViewConfiguration)`, mis à jour à chaud. Test unitaire ajouté ; app 743 tests verts, analyze et format propres. NON revérifié à l'écran (APK construit, émulateur perdu).

### Étapes
| Étape | Résultat |
|---|---|
| F | Sous-titre d'addon (anglais) affiché à l'écran : OK. Panneau : libellés « Langue · Addon n° » lisibles (« English · Films libres (test) », « English · OpenSubtitles v3 1… 9 »), réglages Taille (±, 164 %), Décalage (+0,4 s), Fond opaque (bascule) manipulables au clavier. Langue préférée : le français a été sélectionné automatiquement au démarrage (fallback sur le sous-titre d'addon de même langue), mais le fichier était refusé (cause ci-dessus). Taille et fond : sans effet à l'écran avant 617e09e (à revérifier). OpenSubtitles : liste d'une centaine d'entrées, voir AUDIT-UI. |
| G | NON joué dans cette passe (retrait depuis la fiche : bouton « Retirer de ma liste » présent sur la fiche de Tenzing, rangée « Ma liste » présente sur l'accueil). |
| H | Partiel : reprise à la bonne position (Captain America 3:59/14:48 pour « 11 min restantes ») OK. Série multi-saisons, « Continuer » sur le bon épisode, « Épisode suivant », fin de lecture : NON joués. |
| I | NON joué (rafales, `--longpress`). Aucun FATAL dans logcat sur la partie jouée. |
| Titres variés | Films : Captain America (2011, ancien) et Tenzing (2026). Série multi-saisons et anime : NON joués ; Cinemeta est installé (rangée « MCU Chronologically Order » vue sur l'accueil), mais aucun catalogue anime n'est présent. |

### Reste à faire (prochaine passe, nouvel émulateur)
APK de 617e09e déjà construit sur la machine IA (`~/lumio-build/src/app/build/app/outputs/flutter-apk/app-release.apk`). À jouer : F (français appliqué, taille et fond visibles), G, H série, I, anime.


## Passe 5 : sous-titres regroupés, vérifications (émulateur 127.0.0.1:5601)
- Étape 1 (APK de 617e09e) : sous-titre français de l'addon de test affiché à l'écran (« C'est bientôt fini. Chut… / Bonne nuit, Scales. ») : BOM corrigé confirmé. La taille et le fond opaque n'ont pas pu être revérifiés avec l'ancien panneau (Apparence en bas d'une liste de 100 lignes) ; à voir avec le nouveau panneau (étape 2).
- Étape 2 (ce lot, ce255e8) : panneau Pistes réorganisé : Audio, Apparence (Taille en mots Petite / Normale / Grande / Très grande, Décalage, Fond opaque), puis Sous-titres. Les sous-titres d'addons sont regroupés par langue (noms en clair : Albanais, Croate, Estonien… via `languageDisplayName` ; codes à 3 lettres d'OpenSubtitles ramenés à ISO 639-1 dans `normalizeLang`), langues préférées (sous-titre mémorisé du titre, réglage Lecture, langue de l'app) en tête, 5 entrées par langue au maximum (la ligne choisie reste visible), puis « Autres langues… » (bascule, le focus ne bouge pas) qui déplie les autres langues sous un titre chacune. Un fichier refusé par le moteur (erreur libmpv de fichier externe dans les 1,5 s) n'est plus marqué « choisi », n'est pas mémorisé et affiche « Sous-titre illisible ». Tests : core 534, app 750, analyze et format propres.
- Arrêt de l'émulateur : à 13:25:59 juste après `adb install -r` de l'APK de ce lot, emu-keeper.log note « arrêt de l'émulateur, code 0 » (pas de SIGKILL), relance 13:26:05.
- Étape 2 vérifiée à l'écran (APK de ce2 55e8, panneau Pistes) : Apparence juste sous Audio (une touche bas depuis l'audio), « Très grande » affiché en mots et mémorisé, sous-titre français affiché en grand ; sous-titres : Désactivés, piste interne « fr · auto », « Français · Films libres (test) » (choisi, ambre), « Français · OpenSubtitles v3 1 à 4 », puis « Autres langues… » ; déplié : « Allemand » en titre puis les entrées, triées par nom de langue, bouton devenu « Masquer les autres langues » (le focus reste dessus). Ligne « fr · auto » : piste interne créée par le moteur pour le fichier chargé (doublon de la ligne choisie, à masquer plus tard).
- Étape 3 (G, Ma liste) : retrait depuis la fiche (Tenzing, Big Buck Bunny : « Retirer de ma liste » puis « + Ma liste » ), depuis le héros (bouton du héros, bascule « Retirer de ma liste » / « + Ma liste »), et la rangée « Ma liste » disparaît de l'accueil quand elle se vide. Il n'existe pas d'action de retrait directement sur la carte d'une rangée (aucun appui long défini) : le retrait passe par la fiche ou le héros.
- Défaut trouvé : bas depuis « Continuer à regarder » (2e carte) sautait la rangée « Ma liste » (une seule carte, colonne 0) pour atterrir dans « Films libres » ; au retour de la fiche le focus tombait sur l'onglet Accueil. Correctif a4afab9 : `RowTraversalPolicy` (haut/bas = rangée voisine, carte la plus proche horizontalement), 4 tests.
- Arrêts de l'émulateur : emu-keeper.log note « code 0 » (sortie propre, jamais 137) à 13:25:59, 13:30:07, 13:32:21, 13:32:53, 13:34:00 ; l'émulateur redémarre à froid chaque fois (≈ 1 min), les données de l'application sont conservées. Cause non établie : un arrêt propre venant de l'extérieur du gardien (probablement un SIGTERM envoyé par un autre processus de la machine).
- Étape 4 (H, série) : « Stranger Things » (Cinemeta, 5 saisons + Spéciaux) trouvée par la recherche (« strangerthings » saisi par `adb shell input text`), fiche avec Saisons 1 à 5 et Spéciaux, épisodes S3E1..E4 ; lecture de S3E2 par la source de l'addon de test : titre du lecteur « Stranger Things · S3E2 », bouton « Suivant » présent, durée 12:10 ; retour : le héros affiche « REPRENDRE · S3E2 · 11 min restantes » et la carte « Stranger Things » est en tête de « Continuer à regarder » : OK. Fin de lecture d'un film (Tenzing, avance rapide par KEYCODE_MEDIA_FAST_FORWARD, +10 s par appui, jusqu'à 12:14 sur 12:14) : le lecteur s'arrête sur l'icône lecture ; vérification du retrait de « Continuer » interrompue par un arrêt de l'émulateur (13:39:47, code 0).
- Défauts : (1) depuis l'onglet « Séries », bas saute les boutons du héros et va sur la carte « Continuer » la plus proche (la politique par rangées ne couvre pas la barre d'onglets) ; (2) recherche : la première rangée de résultats est à demi masquée sous l'en-tête quand on y revient (le défilement ne ramène pas la carte focalisée entièrement dans la zone visible) et droite depuis la 1re carte saute sur la puce « Séries ».
