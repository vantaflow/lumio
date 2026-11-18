# Endurance et bout en bout sur la box (Task 26, story 3.6)

Date : 2026-11-18. État : scripts, mode debug et tests hors box livrés ; **la mesure sur la box n'a pas été faite** (box 192.168.0.43 injoignable, décision actée). Les scripts sont éprouvés hors ligne avec un `adb` factice ; il reste à lancer une commande quand la box répond.

## Ce qui est livré

- `scripts/endurance.sh <heures> [--dry-run]` : relevé toutes les 5 min (`LUMIO_ENDURANCE_INTERVAL`) de la PSS totale (`dumpsys meminfo dev.lumio.app`), de la présence du processus (`pidof`) et du dernier battement `LUMIO_PLAYER` / `LUMIO_TORRENT` du logcat ; CSV dans `docs/rapports/endurance-<date>.csv`.
- Mode `--dart-define=LUMIO_DEBUG_LOOP=1` (aussi dans Réglages > Menu debug, « Boucle d'endurance ») : lit Big Buck Bunny (fichier direct, relu en boucle) pendant 10 min, puis Sintel par la voie torrent (`TorrentPlayback`) pendant 10 min, indéfiniment. Durée d'une phase : `--dart-define=LUMIO_LOOP_MINUTES=N`. Battement toutes les 30 s : `LUMIO_PLAYER {"event":"tick","phase":"direct","state":"playing","pos_s":..}` (idem `LUMIO_TORRENT` pendant la phase torrent). Aucune URL dans le journal.
- `scripts/test-endurance.sh` (CI, job `scripts`) : dry-run avec `scripts/testing/fake-adb.sh` pour les cas stable, ancien format meminfo, fuite, plantage, lecture figée, usage, box injoignable.

## Procédure (à exécuter quand la box est joignable)

1. `adb connect 192.168.0.43:5555` ; `bash scripts/disk-guard.sh`.
2. Build, installation et démarrage avec la boucle :
   `LUMIO_BUILD_ARGS="--dart-define=LUMIO_DEBUG_LOOP=1" bash scripts/box-smoke.sh`
   (attend `LUMIO_READY` ; l'application démarre directement dans la boucle).
3. Lancer le relevé détaché, 8 h :
   - Mac : `caffeinate -i nohup bash scripts/endurance.sh 8 > /tmp/endurance.log 2>&1 &` (la veille du Mac couperait la connexion adb).
   - Linux : `setsid nohup bash scripts/endurance.sh 8 > endurance.log 2>&1 &`.
   Variables : `LUMIO_BOX` (défaut `192.168.0.43:5555`), `LUMIO_ADB`, `LUMIO_ENDURANCE_INTERVAL` (s).
4. Pendant la nuit : rien à faire. Le journal `endurance.log` affiche le verdict à la fin ; code de sortie 0 = OK, 1 = échec, 2 = box injoignable (3 relevés de suite).
5. Lecture du CSV : colonnes `timestamp,elapsed_s,pss_kb,alive,pid,state,stuck_count`.
   - `pss_kb` : PSS totale en Ko ; tracer `elapsed_s` en abscisse pour la courbe mémoire (tableur, ou `awk -F, 'NR>1{print $2,$3}'` vers gnuplot).
   - `alive` : 1 vivante ; une ligne `dead` termine le relevé (échec).
   - `state` : dernier état du lecteur (`playing`, `buffering`, `failed`…) ; `none` si aucun battement trouvé.
   - `stuck_count` : relevés consécutifs hors `playing`.
6. Copier la section « Résultats » ci-dessous et joindre le CSV.

## Critères d'acceptation

- Aucun plantage : l'application reste vivante pendant 8 h (`alive = 1`, aucune ligne `dead`).
- PSS : la moyenne de la dernière heure ne dépasse pas de plus de 30 % celle de la première heure (`LUMIO_PSS_MAX_GROWTH`).
- Aucune lecture figée : jamais 3 relevés consécutifs (15 min) dont l'état n'est pas `playing`.
- Complément manuel au réveil : fermer l'application et vérifier que le cache torrent est vide (`adb shell ls <cache>/lumio_torrents`), puis un tour des écrans principaux à la télécommande.

## Limites connues

- Les phases torrent dépendent du réseau et des sources publiques ; une phase torrent sans pair apparaît comme `error` (journalisée) puis la boucle continue ; ce cas ne fait pas échouer le relevé si l'état redevient `playing` avant 15 min.
- La PSS de la première heure contient le démarrage (JIT, caches) : la comparaison est volontairement sévère.

## Résultats : à exécuter quand la box est joignable

| Mesure | Valeur |
| --- | --- |
| Date, version testée | à mesurer |
| Durée effective | à mesurer |
| PSS 1re heure (Ko) | à mesurer |
| PSS dernière heure (Ko) | à mesurer |
| Croissance (%) | à mesurer |
| Plantages | à mesurer |
| Lectures figées | à mesurer |
| Cache torrent vidé à la fermeture | à mesurer |
| Verdict | à mesurer |

## Preuves hors box

`bash scripts/test-endurance.sh` : stable (code 0), fuite +114 % (code 1), plantage au relevé 10 (code 1), lecture figée (code 1), box injoignable et usage (code 2). Boucle de l'application : `app/test/loop_scheduler_test.dart` (planificateur avec horloge factice).
