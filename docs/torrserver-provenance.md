# TorrServer : provenance et licence

Lumio embarque **TorrServer** (YouROK/TorrServer, https://github.com/YouROK/TorrServer) comme moteur de torrents, en remplacement de libtorrent_flutter.

- Version épinglée : `MatriX.150` (Go 1.25, moteur anacrolix/torrent 1.2.34).
- Licence : **GPL-3.0**, la même que Lumio. Le code source correspondant est publié par le projet sur la page de la release ; Lumio ne modifie pas le binaire.
- Provenance : assets officiels de la release GitHub `MatriX.150` (`TorrServer-android-arm7`, `TorrServer-android-arm64`), téléchargés par `scripts/fetch-torrserver.sh` puis vérifiés contre les condensés SHA-256 publiés par GitHub, épinglés dans `scripts/torrserver.pins`. Un binaire dont la somme diffère est refusé.
- Les binaires ne sont **pas** versionnés dans le dépôt (~125 Mo pour deux architectures) : ils sont placés dans `app/android/app/src/main/jniLibs/<abi>/libtorrserver.so` (ignoré par git) avant chaque build, en local et en CI (qui contrôle aussi les sommes avec `--verify`).
- Mettre à jour la version : changer `scripts/torrserver.pins` (version et condensés lus sur la page de la release), relancer le script, relire les changements d'API de `/settings` et `/torrents`, mettre à jour les tests de `torrserver_engine_test.dart`.
