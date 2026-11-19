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

## Défauts constatés non corrigés
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
