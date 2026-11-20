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
