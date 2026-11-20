# Vérification de Lumio sur la vraie box (2026-11-19)

Box : « 4K Google TV Box », Android 14, armeabi-v7a, 2 Go, sortie 3840×2160 avec surcharge 1920×1080, 192.168.0.47. APK release `--target-platform android-arm`. Contenu légal seulement (films Blender via l'addon de test servi par le Mac). Captures : `docs/captures/box/`.

## Ménage
- Profil de test « Enfant » supprimé. « Moi » n'était pas coché « Verrouiller par PIN » : il n'était verrouillé que par la règle « adulte + un profil enfant + un PIN ». Le PIN restait demandé (Réglages, changement de profil) alors qu'aucun profil n'en avait plus besoin.
- Correctif : `ProfileRepository.pruneOrphanPin()` supprime le PIN parent et son code de récupération (et le verrou d'essais) dès qu'aucun profil n'est enfant ou verrouillé ; appelé au démarrage et après chaque modification ou suppression de profil. Vérifié sur la box : lancement direct à l'accueil, Réglages › Profils › Gérer les profils sans PIN.
- Vitesse de lecture : « Vitesse 1× » (déjà normale).
- `/sdcard/Movies/bbb.mp4` supprimé par le coordinateur, dossier /sdcard/Movies retiré de Lumio (« bbb » a disparu de l'accueil, de Continuer et de Ma liste). Constat : un fichier disparu reste affiché jusqu'à la prochaine analyse (au plus 6 h, ou bouton d'analyse) ; l'analyse manuelle le retire.
- Titre d'un fichier local nommé `big-buck-bunny-2008-720p.mkv` (séparé par des tirets) nettoyé ; `Big.Buck.Bunny.2008.1080p.mp4` donne déjà « Big Buck Bunny » et l'année 2008 (tests ajoutés). « bbb.mp4 » reste « bbb » (rien à extraire).

## Lecteur : fluidité (mesures sur 60 s, même fichier : Cosmos Laundromat 1080p H.264 24 i/s via le proxy)
| Réglage | frame-drop-count (10 s → 60 s) | décodage |
|---|---|---|
| avant (media_kit par défaut) | 33 → 601 (≈ 11 images perdues par seconde) | `mediacodec-copy` |
| `hwdec=mediacodec` | 0 → 0 | `mediacodec` (zéro copie) |
| `hwdec=mediacodec,mediacodec-copy` (retenu, repli copie) | 0 → 0 | `mediacodec` |
Le décodage tenait déjà (decoder-frame-drop-count 0) : c'est la sortie (copie mémoire → texture) qui ne suivait pas. Correctif : `androidDefaultHwdec = 'mediacodec,mediacodec-copy'` dans la configuration du `VideoController` (Android uniquement).
- Premier affichage : H.264 1080p 6,7 à 7,3 s (la source archive.org via le proxy est lente, pas le décodeur) ; MP4 H.265 1080p 30 i/s : 1,15 s, 0 image perdue, décodeur `c2.amlogic.hevc.decoder`.
- Journal ajouté (sans adresse) : `LUMIO_PLAYER {"event":"first_frame"…}` et toutes les 10 s `stats` (codec, hwdec, images perdues) ; avertissements libmpv `mpv_log`.
- Réglages avancés sans nouvel APK : `Android/data/dev.lumio.app/files/mpv.conf` (liste blanche de clés, `log-level`, `hwdec`, `vo`, `demuxer-lavf-*`…), lu au démarrage.

## HEVC
- MP4 H.265 1080p : OK (voir plus haut). L'échec noté le 2026-11-18 (« La lecture a échoué ») ne se reproduit pas : H.265 passe directement en `mediacodec`.
- HLS HEVC / fMP4 (exemples Apple) : échec « Délai dépassé » reproduit. Causes trouvées par les journaux libmpv : (1) ffmpeg ouvre TOUTES les variantes du maître au démarrage (28 playlists, puis le premier segment de chacune) ; (2) le proxy refaisait DNS + TCP + TLS à chaque requête (client neuf par requête, ~1 s). Corrigés : `pruneHlsMaster` ne garde qu'une variante (la meilleure ≤ 1080 p, jamais Dolby Vision, sans images clés ; libmpv ne change pas de qualité en cours de lecture) ; le proxy réutilise ses connexions (un client par régime d'adresses privées). `demuxer=lavf` + `demuxer-lavf-format=hls` forcés pour les `.m3u8`. Reste : avec les sondes de ffmpeg réduites (`demuxer-lavf-probesize=500000`, `analyzeduration=1`) le premier affichage arrive à 30 s ; sans, la lecture dépasse le délai. La lenteur est dans la lecture initiale des segments (requêtes à plage de 1,7 Mo via le proxy), pas dans le décodeur. À poursuivre : mesurer le débit du proxy, réduire la sonde par défaut pour HLS, allonger le délai de démarrage pour HLS.

## Écrans (captures dans docs/captures/box/)
Vérifiés à l'écran : choix de profil, gestion des profils, éditeur de profil (P02) et confirmation (P09), accueil rempli, fiche et flux (direct et torrents), lecteur et panneau Pistes, recherche (vide, résultats, clavier arabe), Réglages (Général, Sources, Profils, Suivi, Sauvegarde), Dossiers locaux (rempli et vide), ajout par lien, Gérer depuis le téléphone, Calendrier vide, Suivi Trakt et code Trakt, pop-ups : alerte IP (P04), adresse locale, erreur de lecture (P10). Non revérifiés cette passe : Catalogue (puces, Officiels, Anime), Ma liste, Personnaliser, Lecture/Torrents et VPN en détail, Jellyfin vide, fiche locale, import, pop-ups P03/P05–P08, P11–P14.

## Résultats a à f
- a. Image réelle : OK, fluide après correctif (voir mesures).
- b. Sous-titres : le panneau liste « Désactivés », « Français · OpenSubtitles v3 », « Français · Films libres (test) », « Autres langues… » ; choix fait ; rendu à l'image non confirmé (les fichiers de sous-titres Blender suivent le film Sintel, pas les titres de test). Défaut : « Désactivés » par défaut malgré la langue préférée.
- c. HEVC : voir plus haut.
- d. Portail : http://192.168.0.47:8790 répond ; connexion par code, `/api/session`, `/api/addons` (Cinemeta, OpenSubtitles), `/api/catalog` (puces Officiels…Suivi), installation par lien depuis le Mac → confirmation « Adresse locale » sur la TV → aperçu → installation. Adresse et QR affichés = 192.168.0.47:8790. Non fait : régler un addon configurable, vue Chrome headless 390 px.
- e. Trakt : « Connecter Trakt » affiche le code et le QR ; annulé sans connexion.
- f. `input keyevent` (source clavier) : fonctionne sur la box (flèches, OK, Retour).

## Défauts trouvés et corrigés (commits sur feat/lumio)
1. PIN orphelin (voir Ménage). 2. Pastilles de limite d'âge collées (P02) : largeur naturelle, écart 16, test. 3. Badges crayon/cadenas des avatars sous l'anneau de focus : dessinés au-dessus, à cheval sur le bord, mis à l'échelle, test. 4. Champ de recherche : boîte dans la boîte (contours de thème), test. 5. Code Trakt sous le QR, test. 6. Carte « Gérer depuis le téléphone » affichait une adresse qui ne répondait pas (portail fermé) : « Appuyez sur OK », phrase « Laissez cet écran ouvert », README. 7. En-tête TvScreen : deux actions se partageaient la place et « Ajouter un dossier » était coupé, test. 8. Saccades du lecteur (mediacodec direct). 9. HLS : proxy sans connexions persistantes, maîtres à variantes multiples.

## Défauts constatés (passe 1) : état après la passe 2 ci-dessous
- Annuler l'alerte IP d'un torrent affiche « La lecture a échoué. Torrent non démarré » au lieu de revenir à la fiche.
- Panneau « Pistes et sous-titres » : le bouton « Fermer » est coupé en bas à 1080p.
- Les onglets « Films » et « Séries » ouvrent la recherche (invite vide) au lieu d'un catalogue.
- Le focus d'une flèche haute depuis le contenu atterrit sur l'onglet « Films » plutôt que sur l'onglet courant ; l'écran « Ajouter un addon » ouvert depuis la carte du téléphone garde le titre « Gérer depuis le téléphone ».
- Héros de l'accueil : affiche basse définition étirée et floutée (pixellisée).
- L'addon de test « Films libres (test) » est toujours installé dans Lumio sur la box (serveur arrêté) : à supprimer par Mes addons.

## Ce qui reste
Torrents 1080p, endurance 8 h, HLS fMP4 (voir plus haut). Demandes reçues en cours de passe et NON faites : sections Trakt du portail (maquette M05d publiée, code à faire), guides pas à pas dans l'interface TV et le portail (A à F) et page Aide ; la section Torrents et VPN du portail est abandonnée (VPN intégré prévu en cycle séparé).

## Tests
Cœur : 538 ; application : 783 ; `flutter analyze`, `dart format` propres.

## Passe 2 (2026-11-19, nuit)

La box (192.168.0.47) a quitté le réseau par intermittence pendant cette passe (ping sans réponse, port adb fermé pendant de longues périodes) : les vérifications sur la box sont notées une par une ci-dessous ; ce qui n'a pu être vu à l'écran est marqué « non revérifié sur la box ».

### Défauts de la passe 1 : corrigés (tests d'abord, 805 tests verts)
| Défaut | Correctif |
|---|---|
| Annuler l'alerte IP d'un torrent affichait « La lecture a échoué » | refus volontaire : le lecteur se ferme (retour à la fiche), aucun message d'échec (`torrent_privacy_test`) |
| Bouton « Fermer » du panneau Pistes coupé | « Fermer » sorti de la zone défilante : pied fixe du panneau (`tracks_panel_test`, 1920×1080) |
| Films et Séries ouvraient une recherche vide | pages `TypePageScreen` : rangées des catalogues des addons du type, comme l'accueil (`home_screen_test`) |
| Focus remonté sur « Films » | `RowTraversalPolicy.preferUp` : la flèche haute atterrit sur l'onglet courant (`row_traversal_test`) |
| Titre « Gérer depuis le téléphone » sur tous les onglets | le titre fourni ne vaut que pour l'onglet du téléphone (`phone_tab_test`) |
| Héros qui étire et floute une affiche basse définition | fond « background » de l'addon s'il existe (`ContinuePlayback.backdrop`), sinon affiche à sa taille d'origine (jamais agrandie) sur son reflet flou et assombri (`tv_hero_test`) |
| Clavier de recherche en flux de 8 colonnes | rangées réelles AZERTYUIOP / QSDFGHJKLM / WXCVBN / chiffres, touches de 55 ; arabe en rangées de 10 (`search_screen_test`) |
| « Désactivés » gardé malgré une langue préférée | `fallbackSubtitleLang` : première langue de flux, sinon langue de l'application, appliquée seule si un sous-titre existe et si l'audio n'est pas déjà dans cette langue (`tracks_panel_test`) |

### Guides pas à pas (maquettes G01 à G04 dans docs/design/maquettes/project)
- A : bouton **Aide** de l'écran « Ajouter un addon » (guide de l'onglet courant).
- B : encadré « Sur votre téléphone » en 5 étapes sur l'écran « Configurer depuis le portail » ; message TV « Demande reçue du téléphone ».
- C : portail, écran Régler (où trouver Copier le lien / Install / Copy link, appui long, clé chiffrée), rappel de confirmer sur la TV, phrase sur le remplacement dans Mes addons.
- E : Trakt, 4 étapes sur l'écran du code de la TV.
- F : page Aide (TV : Réglages › Général › Aide ; portail : lien Aide dans l'en-tête), 6 guides. Pas de guide VPN externe.

### Section Trakt du portail (maquette M05d)
Onglet **Trakt** : état, « Connecter Trakt » (le flux de code d'appareil tourne dans l'application sur la TV, le portail montre le code et un bouton vers https://trakt.tv/activate), mise à jour automatique toutes les 2,5 s pendant l'attente, « Déconnecter » avec confirmation. Routes `GET /api/trakt`, `POST /api/trakt/connect`, `POST /api/trakt/disconnect` (session, origine, CSRF) ; jamais de jeton ni de code d'appareil dans les réponses (tests `phone_server_test` et `tracking_test`). La section Torrents et VPN (M05e) n'est pas codée.

### Débit torrent
Le moteur de mesure (`LUMIO_DEBUG_TORRENT=1`) accepte maintenant `--dart-define=LUMIO_TORRENT_HASH=<infohash>` et `LUMIO_TORRENT_SECONDS=300` et journalise un débit toutes les 10 s (`window_10s`).

### État de la passe 2 : arrêt faute de box
La box est devenue injoignable (adb « device offline », ping sans réponse, fenêtres de connexion de 1 à 3 minutes seulement) : l'APK (build b12, 73 Mo) n'a pas pu être installé, malgré un envoi par morceaux. Conformément à la consigne, rien n'a été lancé de plus : ni débit torrent, ni endurance (non démarrée). L'addon de test local a été arrêté sur le Mac ; « Films libres (test) » est toujours installé dans Lumio sur la box (à supprimer par Mes addons).

Tout ce qui suit est donc **non revérifié sur la box** (tests verts sur le Mac : 805 application, 537 cœur ; CI verte sur main) :
- les 8 défauts corrigés ci-dessus (rendus Mac : clavier AZERTY et arabe, guide, page Aide, vérifiés par `render_tv_test` ; captures box à prendre) ;
- recherche : « rangée de boutons vides » signalée par l'utilisateur, NON trouvée (pas de capture possible) : le clavier de la maquette n'a plus de flux de touches ; à rechercher sur la box dans tous les états (vide, saisie, résultats, aucun résultat, arabe, 123) ;
- guides A, B, C, E, F sur la TV et le portail (Chrome 390 px) ; section Trakt du portail de bout en bout avec un vrai compte ;
- écrans de l'étape 4 : catalogue d'addons, Ma liste, Personnaliser, Jellyfin vide, fiche locale, import, pop-ups P03, P05–P08, P11–P14 ;
- test de débit torrent 1080p (≥ 1 Mo/s pendant 5 min) : build `--dart-define=LUMIO_DEBUG_TORRENT=1 --dart-define=LUMIO_TORRENT_HASH=<infohash d'un film Blender, ex. Tears of Steel> --dart-define=LUMIO_TORRENT_SECONDS=300`, journal `LUMIO_TORRENT` (`window_10s`, `read_continuous`) ;
- endurance : build `--dart-define=LUMIO_DEBUG_LOOP=1`, puis `LUMIO_BOX=192.168.0.47:5555 caffeinate -i nohup scripts/endurance.sh 8 > endurance.log 2>&1 &` ; suivi : `tail` du CSV docs/rapports/endurance-<date>.csv ; arrêt : `pkill -f endurance.sh` puis réinstaller le build normal.
