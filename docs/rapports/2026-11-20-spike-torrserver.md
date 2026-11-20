# Spike : TorrServer contre libtorrent_flutter 1.7.5 sur la box (2026-11-20)

Code jetable, aucune modification de l'application. Box « 4K Google TV Box » (192.168.0.47), Android 14, armeabi-v7a, 2 Go, 4 coeurs.

## Binaire
- Release `MatriX.150` (2026-11-06), asset `TorrServer-android-arm7`, 61 Mo, SHA-256 `852e15b8d4739ac94ce0e046bba5c7a929b2ad75f980849cef10c668971ee764` (identique au condensé publié par GitHub). Go 1.25, moteur anacrolix/torrent 1.2.34. Licence GPL-3.0 (compatible avec Lumio). Fichier jamais exécuté sur le Mac.
- La release « Latest » est `Silo.2` (2026-11-14, 34 Mo) : réécriture avec une autre API (`/api/torrents`, `/api/stream`, configuration par `-c config.yaml`, mode « OPEN » sans mot de passe). Démarrée seulement pour inspection, non mesurée. Les mesures portent sur MatriX.150, à l'API stable et documentée (`POST /torrents` action add/get/drop/rem, `GET /stream?link=&index=&play`).
- Lancement : `./torrserver -p 8090 -d /data/local/tmp/ts-data`. Réglages par défaut du moteur : cache RAM 64 Mo, 25 connexions, DHT, PEX, UPnP, LPD actifs. Écoute web sur toutes les interfaces par défaut (`--ip 127.0.0.1` possible).

## Mesures (Sintel et Tears of Steel, magnets avec trackers publics, sans webseed)
Lecture : curl sur le Mac via `adb forward` (mesure donc aussi le lien Mac-box ; curl jette les données). Stats moteur toutes les 10 s.

| | libtorrent 1.7.5 (rapport du jour, même box) | TorrServer MatriX.150 |
|---|---|---|
| Métadonnées | 2-3 s | 1,1 à 1,7 s (4 essais) |
| Débit moteur (Sintel) | 1,7 Mo/s à 10 s, puis 0,06-0,5 Mo/s | 10,6 à 12,4 Mo/s à 10 s |
| Débit lu Sintel, fichier entier (129 Mo) | 0,14-0,2 Mo/s sur 120-300 s | 129 Mo en 15 s : 8,6 et 8,9 Mo/s (essais 1 et 2) |
| Débit lu Tears of Steel (571 Mo) | non mesuré | 571 Mo en 37 s : 15,3 Mo/s |
| Débit lu soutenu 300 s (Tears of Steel relu en boucle, 5 passes, cache 64 Mo) | non tenu (< 0,5 Mo/s) | 2 986 Mo en 300 s : 9,9 Mo/s moyen ; débit moteur 0,5 à 18,9 Mo/s, creux courts à 1,6-6 Mo/s |
| Pairs actifs / connus | 1-70, instable | 12-25 actifs (limite 25), 50-98 connus |
| RAM (VmRSS) | non relevée | 122-175 Mo (pic 242 Mo sur la première lecture de Tears of Steel, cache 64 Mo) |
| CPU (top, 4 coeurs = 400 %) | non relevé | 120-215 % pendant le flux |

Limites : un seul créneau horaire ; la même box et le même réseau le même jour, mais pas simultanément. Le libtorrent n'a pas été rejoué : aucun APK de debug n'était sur la box ni dans le dépôt, et en installer un par-dessus Lumio sortait du cadre (« ne touche pas à Lumio »). La comparaison s'appuie donc sur les mesures du rapport 2026-11-20-torrents-box.md ; le swarm varie, mais l'écart (20 à 60 fois) est trop grand pour s'expliquer par cela seul. À confirmer avec un build debug libtorrent rejoué juste avant. La lecture passe par adb (Mac) : le débit côté box seule est au moins aussi bon. Objectif 1080p (>= 1 Mo/s soutenu 5 min) : atteint avec une grande marge.

## Faisabilité d'intégration
- Livrer le binaire comme `libtorrserver.so` dans `jniLibs/armeabi-v7a` (et arm64) puis l'exécuter depuis `nativeLibraryDir` (exec autorisé sur Android 10+ pour ce chemin ; `android:extractNativeLibs="true"` requis). Coût : environ 61 Mo par ABI dans l'APK (MatriX) ; Silo est plus léger (34 Mo). Un filtre d'ABI est nécessaire.
- Démarrage/arrêt par l'app : lancement par `Process.start` depuis Dart ou un service Kotlin, arrêt par `POST /shutdown` ou SIGTERM ; vérification par `GET /echo`.
- Réseau local : `--ip 127.0.0.1 -p <port libre>` ; ajouter l'authentification (`--httpauth`) ou un port aléatoire, car par défaut tout est ouvert sur toutes les interfaces.
- Coupe-circuit VPN : le moteur propose `ProxyURL`/`ProxyMode` (SOCKS5, tracker ou pairs), à tester ; sinon la fuite hors VPN dépend de l'interdiction de connexion à l'OS. Non validé dans ce spike (pas de VPN testé).
- Cache : `CacheSize` réglable (64 Mo par défaut ; `UseDisk` possible), RAM mesurée 120-240 Mo sur une box de 2 Go.
- Interface Dart : implémenter `TorrentEngine` par HTTP (add, status via `/torrents`, flux via `/stream`) ; le flux HTTP à plages d'octets existe déjà côté TorrServer.

## Verdict : GO conditionnel pour remplacer libtorrent
Débit 20 à 60 fois supérieur, métadonnées plus rapides, flux stable 5 min. Effort estimé : 3 à 5 jours (adaptateur `TorrentEngine`, gestion du processus, jniLibs/ABI, sécurité locale, tests box et VPN).

Risques :
1. Binaire Go de 61 Mo (APK x2 si deux ABI) et 120-240 Mo de RAM, 120-215 % de CPU pendant la lecture sur 32 bits.
2. Mainteneur unique, deux lignes (MatriX stable, Silo nouvelle API) : épingler une version et un condensé.
3. Exécution d'un binaire externe : surface d'attaque locale (port ouvert), à fermer par 127.0.0.1 et authentification ; licence GPL-3.0 à mentionner.
4. Coupe-circuit VPN et fin de processus (kill par le système) non validés ; à tester avant bascule.
5. Comparaison libtorrent à rejouer dans les mêmes conditions avant la décision finale.

## Nettoyage
TorrServer arrêté ; `/data/local/tmp/torrserver` et `/data/local/tmp/ts-data` supprimés ; redirection `tcp:8090` retirée ; binaires du scratchpad supprimés. Lumio intact.
