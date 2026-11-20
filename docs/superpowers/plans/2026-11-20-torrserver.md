# Plan : remplacer libtorrent_flutter par TorrServer (MatriX.150)

Décision validée après le spike (docs/rapports/2026-11-20-spike-torrserver.md) : débit lu 9,9 Mo/s contre 0,1-0,5 Mo/s.

## Choix
- **Binaires non commités** (~125 Mo pour 2 ABI, historique git alourdi à chaque changement de version) : `scripts/fetch-torrserver.sh` les télécharge depuis la release GitHub officielle, vérifie le SHA-256 épinglé dans `scripts/torrserver.pins` et les place dans `jniLibs/<abi>/libtorrserver.so` (ignoré par git). Cache `~/.cache/lumio-torrserver`. La CI met le cache en place et lance le script avant le build.
- **Processus** : Kotlin (`TorrServerManager`) lance `libtorrserver.so` depuis `nativeLibraryDir` (`extractNativeLibs=true`), `--ip 127.0.0.1 --port <libre> --httpauth`, mot de passe aléatoire par lancement écrit dans `accs.db` du dossier privé (`filesDir/torrserver`). Canal `dev.lumio.app/torrserver` : `start` (idempotent, renvoie port + identifiants), `stop`, `alive`. Redémarrage automatique s'il meurt ; arrêt 2 min après le passage en arrière-plan et à la destruction ; processus orphelin tué au démarrage (fichier pid).
- **Adaptateur Dart** `TorrServerEngine` (HTTP : `/torrents` add/get/rem, `/settings`, `/stream`, `/shutdown`) derrière `TorrentEngine`. Réglages : cache disque borné par « Cache », DisableUpload si pas d'ensemencement, limites en Kio/s, DHT actif, UPnP/LPD/Bonjour/DLNA/liste de trackers distante coupés.
- **VPN** : coupe-circuit existant + arrêt du processus (`TorrentPlayback.shutdown`) quand le VPN exigé manque ou tombe.

## Étapes (TDD, commit par étape)
1. Binaires + script + pins + CI + licence/provenance.
2. `TorrServerEngine` + faux TorrServer HTTP de test (tests d'abord).
3. Côté Android : Kotlin, manifeste, canal Dart (`TorrServerProcess`).
4. Câblage : providers, VPN, écran de debug ; retrait de libtorrent_flutter ; tests mis à jour.
5. Vérification sur la box (mesures, netstat, lecture réelle avec addon de test jetable).
6. Docs, rapport, captures.
