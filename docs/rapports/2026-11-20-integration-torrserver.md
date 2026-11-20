# Intégration de TorrServer (MatriX.150) à la place de libtorrent (2026-11-20)

Suite du spike (`2026-11-20-spike-torrserver.md`). Plan : `docs/superpowers/plans/2026-11-20-torrserver.md`.

## Ce qui a été fait
- **Binaires** : téléchargés, non commités. `scripts/fetch-torrserver.sh` récupère `MatriX.150` (arm7 et arm64) depuis la release officielle YouROK/TorrServer, vérifie le SHA-256 épinglé (`scripts/torrserver.pins`, identique aux condensés publiés par GitHub) et les place dans `jniLibs/<abi>/libtorrserver.so` (ignoré par git). Raison : ~125 Mo pour deux ABI, et chaque changement de version alourdirait l'historique pour toujours. La CI met en cache, télécharge et contrôle (`--verify`). Provenance et licence GPL-3.0 : `docs/torrserver-provenance.md`.
- **Processus** (`TorrServerManager`, Kotlin, canal `dev.lumio.app/torrserver`) : lancé depuis `nativeLibraryDir` (`extractNativeLibs`), `--ip 127.0.0.1`, port libre, dossier privé `filesDir/torrserver`, `--httpauth` avec mot de passe aléatoire de 256 bits par lancement, sortie jetée. Relance automatique (5 par minute au plus), arrêt 2 min après l'arrière-plan et à la fermeture, ancien processus tué au démarrage (fichier pid).
- **Adaptateur** `TorrServerEngine` (HTTP : `/torrents` add/get/rem/drop/list, `/settings`, `/stream`) : mêmes contrats que `TorrentEngine` (index de fichier 0-based, chemins complets, pairs/graines/débits/tampon, relance et ré-ajout si le moteur meurt). Réglages : cache disque borné par « Cache », `DisableUpload` sans ensemencement, limites en Kio/s, DHT actif, UPnP/LPD/Bonjour/DLNA/liste de trackers distante coupés, 6 trackers UDP publics fixes (sans eux : métadonnées 4 s au lieu de 1,4 s). Le flux local passe en direct (`trustedLocal`), sans LocalProxy ; les identifiants sont dans l'URL (jamais journalisée).
- **VPN** : le coupe-circuit existant est conservé ; en plus, VPN exigé absent au démarrage = le processus ne démarre pas (et est arrêté s'il tournait) ; VPN tombé en lecture = torrent retiré et processus arrêté (`TorrentPlayback.shutdown`).
- **Retrait de libtorrent_flutter** : dépendance, adaptateur, plancher d'envoi de 256 Kio/s et son test supprimés ; crédits mis à jour. Écran de debug torrent adapté (relecture en boucle, URL sans mot de passe). `TorrentEngine.clearCache()` ajouté.
- Le build d'une seule architecture n'embarque que le binaire de celle-ci.

## Mesures sur la box (4K Google TV Box, armeabi-v7a, 2 Go)
| | libtorrent 1.7.5 (rapport torrents-box) | TorrServer dans Lumio |
|---|---|---|
| Démarrage du moteur (1er torrent) | n/a | ~4-5 s (dont ~3,6 s d'écriture des réglages la toute première fois ; aux lancements suivants les réglages sont déjà là) |
| Métadonnées Sintel | 2-3 s | 1,2-1,5 s (réglages de l'appli, banc direct) ; 4,1-4,6 s mesuré dans l'appli avant ajout des trackers publics |
| Débit lu Sintel (129 Mo) | 0,14-0,2 Mo/s | 6,1-9,4 Mo/s |
| Débit lu 300 s (Tears of Steel relu en boucle) | < 0,5 Mo/s | **2 215 Mo en 300 s : 7,37 Mo/s** (1,0 à 14,1 Mo/s par fenêtre de 10 s, 4 à 25 pairs) |
| RAM du processus moteur | n/a | 74-81 Mo (cache disque ; 122-242 Mo avec cache RAM dans le spike) |
| CPU pendant le flux | n/a | ~35 % d'un coeur (top, instantané) |
| Taille APK android-arm | 72,9 Mo | 54,3 Mo (77,2 Mo si les deux binaires sont embarqués) |

Ports (/proc/net, uid de l'appli) : web 127.0.0.1:port, écouteur interne de TorrServer 127.0.0.1:port ; port BitTorrent aléatoire 0.0.0.0 TCP+UDP (pairs entrants). Ce dernier existait déjà avec libtorrent ; il est inhérent au protocole et ne donne accès à aucune fonction de l'appli. Il n'a pas pu être restreint (`--torrentaddr` lie aussi les connexions sortantes). Arrêt propre : le processus disparaît à la fin d'une session de debug, 2 min après l'arrière-plan (vu à 100 s présent, 130 s absent), et avec `am force-stop` (aucun orphelin).

## Lecture réelle dans Lumio
Addon de test minimal sur le Mac (Sintel, hash 08ada5a7...), installé par `lumio://install?url=...` (adresse du Mac 192.168.0.205 ; le `stremio://` est converti en https et refusé), puis **supprimé de Lumio** et arrêté. Constaté : alerte IP, carte P05 (14 sources, 3,3 Mo/s), lecture à l'image, durée 14:48, entrée « Continuer à regarder » avec temps restant. Captures TS01 à TS03.
Non vérifié : reprise à la position depuis le même flux (le bouton « Reprendre » a choisi une autre source, un Sintel de Torrentio à 0 graine, déjà installé par l'utilisateur sur la box) ; VPN réel (aucun VPN sur la box : couvert par les tests unitaires). Restes sur la box : Sintel dans « Continuer à regarder » ; un ajout/retrait accidentel de Sintel dans « Ma liste » a été annulé.

## Tests
Nouveaux : `torrserver_engine_test.dart` (22, contre un faux TorrServer HTTP : réglages, index, flux authentifié, statut, relance après mort, réglages inchangés sans `set`), arrêt du moteur dans `torrent_privacy_test.dart`. Suite complète verte, analyze et format propres.

## Reste / réserves
- Premier torrent de la session : ~5 s de démarrage avant les métadonnées.
- Pas de binaire x86_64 (émulateur) : le moteur y échoue proprement.
- Dépend d'un mainteneur unique : version et sommes épinglées, mise à jour manuelle.

## Correctif : « Reprendre » relançait un autre flux (2026-11-20)
- Cause racine : la table `progress` (v12) ne gardait que titre, affiche, type, saison, épisode et position ; aucune identité du flux. `DefaultContinuePlayback.play` relançait donc toujours `ranked.first` (meilleur du classement), ici le Sintel de Torrentio à 0 graine.
- Correctif : migration v13 (colonnes `stream_addon_id` = identifiant de stockage opaque de l'addon, `stream_key` = `t:<infoHash>:<fileIdx>` ou `u:<SHA-256 de l'URL normalisée>`, jamais l'URL). Le lecteur écrit l'identité du flux réellement lu (repli et « autre source » compris, et chaque épisode enchaîné). La reprise retrouve ce flux dans le classement actuel (`findSavedStream` : même addon, sinon même source chez un autre addon) ; sinon meilleur flux, à la position enregistrée, avec le message « Source d'origine indisponible : lecture depuis la meilleure source. ». Une ancienne entrée sans identité suit le classement, sans message.
- Position : le démarrage (`start`) est transmis au lecteur après la préparation du torrent (test ajouté : torrent repris à 16 min).
- Tests ajoutés : `stream_identity_test` (core), `saved_stream_test`, migration v12 vers v13, `progress_repository_test`, 4 cas de reprise dans `detail_screen_test` (même torrent, même lien, flux disparu, ancienne entrée), 2 cas lecteur dans `next_episode_overlay_test` (identité enregistrée, torrent repris à la position).
- Non vérifié sur la box : voir le rapport de session (la box est devenue injoignable en cours de scénario, l'addon de test n'a pas pu être retiré de Lumio).

## Diagnostic du blocage à 0 Ko/s (2026-11-20, soirée)
Box 4K Google TV (adb sur 192.168.0.48), appli de c7f174f, TorrServer MatriX.150.

**Constaté sur l'état laissé par l'après-midi** (appli jamais fermée) : écran « La lecture a échoué. Délai dépassé » ; processus `libtorrserver.so` vivant (écoute web + interne en boucle locale), `/echo` répond, réseau de la box sain (ping 29 ms), disque 53 % utilisé ; mémoire très tendue (swap plein : 489 448 / 489 472 Ko, ~240 Mo libres). « Réessayer » (5 pressions, 3 attentes de 25 s) : aucun changement d'écran, aucun journal `LUMIO_PLAYER` de préparation de torrent. Une relecture complète depuis la fiche échoue en quelques secondes avec, côté mpv : « Reading plaintext playlist », « Failed to create file cache », « No video or audio streams selected » : mpv a reçu un corps texte (réponse d'erreur du moteur) au lieu d'un flux vidéo. Le mot de passe du moteur n'est lisible que par l'appli (non debuggable, pas de root) : l'API authentifiée n'a pas pu être interrogée.

**Après `am force-stop` + relance** (nouveau processus, nouveau mot de passe, ancien moteur tué) : tout fonctionne. Cosmos Laundromat (torrent) 1,4 Mo/s, 57 % ; Sintel : repli automatique de la source Torrentio (0 graine) vers la source de test, lecture à l'image (h264, décodage matériel mediacodec, 0 image perdue), 4 sources, 100 % téléchargé.

**Conclusion** : le défaut n'est pas dans le réseau, ni dans le disque, ni dans le moteur au repos : c'est un état périmé d'un processus longue durée (moteur vivant mais plus d'accord avec l'adaptateur : mot de passe/port périmé, torrent fantôme ou moteur dégradé sous pression mémoire ; la réponse texte vue par mpv va dans le sens d'un 401/404 du moteur), que « Réessayer » ne répare pas parce qu'il rejoue la même session. Cause exacte non isolée.

**Reproduction par coupure Wi-Fi : tentée, non concluante, et dangereuse.** Coupure programmée côté box (`svc wifi disable; sleep 25; svc wifi enable`, lancée avant la coupure) pendant la lecture de Sintel : après la remise, la box n'est plus joignable par adb (port 5555 fermé sur tout 192.168.0.x, hormis un autre appareil qui n'est pas la box), alors que la commande de remise a dû s'exécuter. C'est très probablement ce qui s'était déjà produit l'après-midi : la box perd adb à la moindre bascule Wi-Fi/DHCP. Conséquence : la vérification du scénario « Reprendre » (tâche 3), le message de repli et le retrait de l'addon de test de Lumio n'ont pas pu être faits.

**Aucun code modifié** (aucun défaut prouvé : pas de test rouge possible sans la cause). Pistes à tester à la prochaine session sur la box (une fois adb rétabli, par exemple via l'écran de la box > Options pour les développeurs) :
1. Ajouter à l'adaptateur un contrôle d'état avant chaque `prepare` (`/echo` + requête authentifiée de liste) et une relance du moteur si l'authentification est refusée ; journaliser (sans URL ni pair) le code HTTP du moteur.
2. Faire que « Réessayer » sur un torrent relance le moteur (`stopEngine` puis `ready`) au lieu de rejouer la session.
3. Surveiller la mémoire : swap plein sur la box de 2 Go pendant les lectures.

## Causes plausibles confirmées par le code (2026-11-20, nuit)
Lecture de `TorrServerManager.kt`, `torrserver_engine.dart`, `torrent_playback.dart`, `player_screen.dart` :
1. **Désaccord silencieux Dart / processus** : `_call` ne relançait le moteur que sur `SocketException` et `TimeoutException`. Une réponse 401 (identifiants périmés après une relance native ou un nouveau lancement) ou 404 (torrent perdu à la relance du processus : `save_to_db: false`) devenait une simple `HttpException`, jamais récupérée. `/echo` (sans authentification) répondait, donc le moteur paraissait sain.
2. **Aucun contrôle d'état avant `prepare`** : `ready()` mémorise l'initialisation une fois pour toutes ; ni `add` ni `stream` ne vérifiaient que le moteur acceptait encore nos identifiants et connaissait encore nos torrents.
3. **URL de flux jamais vérifiée** : `stream()` fabriquait l'URL sans interroger le moteur ; une réponse non 2xx (corps texte) allait telle quelle à mpv (« Reading plaintext playlist »).
4. **« Réessayer »** : le lecteur refait bien une préparation (`_openTorrent`), mais celle-ci repassait par le même moteur sans contrôle : elle échouait pour la même raison (cause 1 à 3), d'où l'absence d'effet visible. Le gestionnaire natif, lui, ne diverge pas de lui-même (même port et mot de passe à la relance du processus, plafond de 5 relances par minute) : aucun changement Kotlin nécessaire.

La cause exacte de l'état périmé sur la box (relance native sous pression mémoire, bascule Wi-Fi) reste non observée, mais tous les chemins ci-dessus sont maintenant couverts.

## Correctif (2026-11-20, nuit) : à vérifier sur la box
Dans `TorrServerEngine` (garanties conservées : 127.0.0.1 seulement, mot de passe jamais journalisé ni dans un message d'erreur, coupe-circuit VPN inchangé, plafond de relance natif inchangé) :
- **Contrôle d'état authentifié** (`POST /torrents list`) avant chaque `add` et chaque `stream` ; en cas de connexion refusée, de délai dépassé, de connexion coupée ou de 401/403 : relance réelle (arrêt du processus, nouveau `start` natif donc nouvelles coordonnées, nouveaux réglages) puis ré-ajout des torrents connus.
- **Torrent absent côté moteur** (absent de la liste, ou 404 sur `get`) : ré-ajout transparent depuis le magnet mémorisé.
- **Aucune URL non vérifiée pour mpv** : `stream()` sonde l'URL (GET d'un octet, 4 s) ; 401 relance le moteur, 404 rajoute le torrent, un second échec lève `TorrServerStreamException` (code HTTP seul) qui s'affiche comme « Le torrent n'a pas pu démarrer ». Un moteur qui n'a pas encore répondu après 4 s (préchargement) n'est pas une erreur.
- **« Réessayer »** : repart d'une préparation complète, qui passe maintenant par le contrôle d'état et relance le moteur si besoin (test de non-régression ajouté).
- **Changement de réseau** : aucune dépendance ajoutée ; le contrôle d'état avant chaque préparation suffit.

Tests ajoutés (écrits d'abord, 5 rouges confirmés) : `torrserver_engine_test.dart` (mot de passe périmé, torrent fantôme via `files` et `stream`, 401 sur `stream`, non 2xx, mot de passe absent des erreurs, moteur arrêté avant `add`) et `torrent_privacy_test.dart` (Réessayer après échec du moteur).

**À vérifier sur la box** : plusieurs heures dans un même processus + bascule Wi-Fi, puis lecture d'un torrent sans `am force-stop` ; la sonde GET d'un octet sur `/stream` du vrai MatriX.150 (comportement non observé hors faux serveur) ; mémoire (swap plein) toujours à surveiller.

## Vérification « Reprendre » : non faite
Le scénario Reprendre (même flux, même position, message de repli) n'a pas pu être exécuté sur la box (injoignable). Les tests automatisés du correctif (voir plus haut) restent la seule vérification. À refaire : lecture ~1 min de Sintel via l'addon de test, sortie, « Reprendre » depuis l'accueil, puis désactivation de l'addon et nouveau « Reprendre » pour le message de repli. L'entrée Sintel actuelle de « Continuer à regarder » est ancienne (sans identité) : elle suit le classement.
Restes sur la box : addon « Test Sintel » toujours installé (adresse du Mac périmée, serveur du Mac arrêté), à supprimer dans Réglages > Sources ; Sintel dans « Continuer à regarder » (un ajout accidentel à « Ma liste » a été annulé).
