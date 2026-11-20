# Débit TorrServer : réglages et banc (2026-11-21)

## Constat
Lecture d'un torrent sur la box : 10 sources, environ 2 Mo/s, pour une ligne de 200 Mbit/s (~25 Mo/s).

## Banc
Le banc devait tourner sur la box. Avant tout lancement, la box affichait 143 Mo libres et un swap plein (477/478 Mo), avec Lumio en mémoire (RSS 322 Mo). Un second TorrServer l'aurait mise en difficulté. Décision : banc sur le Mac, même réseau, binaire officiel MatriX.150 darwin-arm64 (SHA-256 8baa838c…ee86, identique au condensé GitHub), rangé hors dépôt.

Ce banc mesure l'effet des réglages sur l'essaim, PAS la limite CPU/RAM de la box (32 bits, 120 à 215 % de CPU pendant le flux d'après le spike).

Torrent : Tears of Steel (571 Mo, licence libre), lecture complète par curl à pleine vitesse, cache disque 512 Mo, un seul réglage de plus par ligne.

| Config | Débit moteur à 10 / 20 / 30 s (Mo/s) | Pairs actifs (max) | Lu 571 Mo en | RSS moteur (Mo) | CPU % |
|---|---|---|---|---|---|
| A actuelle (envoi coupé, 25 conn., fenêtre ~96 Mo) | 55,6 / 21,5 / 0,8 | 17 | 32,3 s (17,7 Mo/s) | 72-78 | 45-47 |
| B envoi autorisé (plafond 3 Mo/s) | 10,1 / 23,4 / 22,1 | 21 | 33,2 s | 58-77 | 19-38 |
| C B + ConnectionsLimit 50 | 22,7 / 19,8 / 0,7 | 25 | 26,5 s (21,5 Mo/s) | 73-86 | 33-38 |
| D C + fenêtre ~205 Mo, préchargement 32 Mo | 4,5 / 22,2 / 21,6 | 28 | 39,5 s | 59-83 | 11-37 |

Le débit tombe à ~0 après 30-40 s : le cache de 512 Mo est plein, TorrServer ne télécharge que dans la fenêtre de lecture. Ce n'est pas un plafond.

## Lecture
- Sur le Mac, les quatre configurations donnent le même débit (17 à 22 Mo/s sur le flux, jusqu'à 55 Mo/s en pointe) : l'essaim n'est pas bridé par l'envoi coupé ni par la limite de 25 connexions. Les écarts entre A, B, C, D sont dans le bruit (un essai chacun, essaim variable).
- Les pistes 1 (envoi coupé) et 2 (25 connexions) ne sont donc PAS confirmées comme cause des 2 Mo/s. Je ne peux pas non plus les écarter pour un essaim moins bien fourni (10 sources) : l'envoi coupé nuit surtout quand peu de pairs acceptent un client qui ne rend rien.
- La limite la plus probable sur la box reste le CPU 32 bits (cryptographie, tables de pièces), le swap plein (RAM 2 Go, Lumio 322 Mo) et l'essaim choisi. À confirmer par un banc sur la box quand elle aura de la mémoire libre.
- Fenêtre plus grande (D) : aucun gain mesuré, pas retenue.

## Réglages retenus (torrServerSettings)
- `DisableUpload: false` toujours ; `UploadRateLimit` 2048 Kio/s sans ensemencement (plafond pendant la lecture, le torrent est retiré à l'arrêt, rien n'est partagé ensuite) ; avec ensemencement, limite de l'utilisateur (0 = illimité). Le sens du réglage « ensemencement » est conservé.
- `ConnectionsLimit: 50` (modéré pour 2 Go de RAM).
- Inchangés : 127.0.0.1, mot de passe, contrôle d'état, fenêtre ~96 Mo, préchargement ~16 Mo.
- Pas retenus : IPv6, UTP/TCP, port fixe, chiffrement forcé : non mesurés, aucun indice de gain.

## Ce que verra l'utilisateur
Le débit affiché monte au début puis retombe à celui du film quand le tampon est plein. C'est voulu.

## RAM de la box
Avant installation : libtorrserver.so RSS 42 Mo au repos (13 702), Lumio 324 Mo. Après installation : Lumio relancé, 54 Mo ; le moteur ne démarre qu'à la première lecture. Je n'ai pas lancé de lecture (Lumio non lancé, consigne). RSS sous charge à mesurer lors de la prochaine lecture : sur le Mac, la RSS du moteur monte de 58 à 86 Mo avec 50 connexions (contre 72-78 Mo avec 25), pas de saut notable. Swap de la box saturé avant et après (472-477 Mo).

## Autre correctif livré (commit séparé)
Échec « la lecture a échoué » (mpv recevait une liste M3U) : le flux est refusé si la réponse est du texte, et un fileIdx absent, hors liste ou non vidéo retombe sur la plus grosse vidéo. L'URL avait déjà `&play` et l'index 1-based ; la cause exacte sur la box n'est pas prouvée (pas de journal du moteur), la défense couvre les cas plausibles.
