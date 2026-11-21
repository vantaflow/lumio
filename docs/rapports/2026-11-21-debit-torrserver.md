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

## Banc sur la box (2026-11-21)

Box « 4K Google TV Box » (armeabi-v7a, 4 coeurs, 2 Go, Ethernet), binaire officiel MatriX.150 armv7 (SHA-256 vérifié, 852e15b8…e764), lancé en ligne de commande sur 127.0.0.1 depuis /data/local/tmp, Lumio arrêté (`force-stop`). Même torrent que le banc du Mac (Tears of Steel, 571 Mo), lecture complète du flux par `nc` depuis la box elle-même (aucun lien adb ni Mac dans la mesure). Cache disque 512 Mo, un réglage à la fois, stats moteur toutes les 10 s.

État de départ : 570 Mo disponibles, swap saturé (489/489 Mo, ZRAM), charge 1,1, CPU quasi au repos, Lumio 64 Mo une fois en veille. Après arrêt de Lumio : 575 Mo disponibles, swap toujours plein (le swap ne se vide pas de lui-même).

| Config | Lu 571 Mo en | Débit moteur par fenêtre de 10 s (Mo/s) | Pairs actifs (max) | RSS moteur (Mo) | CPU moteur % (de 400) |
|---|---|---|---|---|---|
| Lumio : envoi 2 Mo/s, 50 conn. (3 essais) | 66 / 70 / 70 s (8,2 Mo/s) | 11,3 à 11,8 en régime, pointe 14,1 | 27-30 | 61 → 84 | 85-290 |
| Anciens réglages : envoi coupé, 25 conn. (2 essais) | 71 / 65 s | 11,4 à 11,8 | 22-23 | 60 → 78 | 75-212 |
| 100 connexions | 64 s | 11,5 à 11,7 | 29 | 59 → 83 | 90-190 |
| Cache en RAM (UseDisk faux) | 61 s | 11,7 à 11,8 | 29 | 87 → 685 | 100-135 |
| Chiffrement forcé (ForceEncrypt) | 69 s | 11,4 à 14,7 | 28 | 59 → 85 | 100-200 |

Écriture flash : `dd` 512 Mo avec fsync dans /data/local/tmp : 18 Mo/s (relecture 123 Mo/s). Plus lent que le réseau, mais le cache n'écrit que ce que le réseau apporte et le débit moteur ne baisse pas pendant les écritures.

### Ce que disent les chiffres
- Toutes les configurations plafonnent au même débit, 11,6 à 11,8 Mo/s, soit environ 93 Mbit/s : exactement la charge utile d'un lien Ethernet 100 Mbit/s. Aucun réglage ne bouge ce plafond (écarts = bruit de l'essaim).
- Contre-épreuve hors torrent : un téléchargement HTTP simple Mac vers box sur le réseau local donne 176 Mo en 15 s, soit 11,7 Mo/s. Même plafond. Android annonce d'ailleurs `LinkDnBandwidth>=100000Kbps` pour eth0 (valeur par défaut, indice seulement). Le lien de la box (port Ethernet de la box, câble ou port du routeur) est donc à 100 Mbit/s, pas à 200 Mbit/s ou plus.
- Le CPU ne sature pas : le moteur consomme 1,5 à 2,9 coeurs sur 4, le système reste à 360 % d'inactivité. Le chiffrement forcé n'a aucun coût mesurable.
- Le cache en RAM est franchement mauvais sur cette box : 685 Mo de RSS, mémoire disponible à 63 Mo, kswapd à 50 % de CPU, 68 % de CPU système. Même débit réseau, mais la box est à la limite de l'OOM. Rejeté.
- 100 connexions : pas de gain (le nombre de pairs actifs plafonne à 29-30 : c'est l'essaim). Les 50 connexions actuelles suffisent.
- Le swap plein ne gêne pas le flux (aucun effet sur le débit) ; il pénalise les autres applications, pas ce banc.

### Dans Lumio (même torrent, addon de test servi par le Mac, installé puis supprimé)
La carte du lecteur affiche « Connexion aux sources… » puis, vers 20 s, « 5 sources · 1,1 Mo/s · 89 % téléchargé » : le film (12 min 14 s, environ 0,8 Mo/s de débit vidéo) est lu sans accroc, le débit retombe dès que la fenêtre de lecture est remplie (comportement attendu, voir plus haut). Le moteur de l'appli tournait à 15 % de CPU, 70 Mo de RSS. Captures dans le scratchpad de la session. L'addon de test a été supprimé depuis Réglages > Sources ; aucun addon de l'utilisateur touché.

### Conclusion
Le goulot est le lien réseau de la box (100 Mbit/s, soit un plafond pratique de 11,7 Mo/s), pas le CPU, pas la RAM, pas les réglages TorrServer. Les 2 Mo/s vus avec 10 sources ne viennent donc pas de la box : ils reflètent l'essaim (peu de pairs rapides) ou la fenêtre de lecture déjà pleine (la carte affiche le débit moteur du moment, qui tombe à ~1 Mo/s en lecture normale). Aucun réglage `torrServerSettings` n'est modifié. Pour dépasser 11,7 Mo/s il faudrait un lien gigabit (autre câble, autre port de routeur, ou box dont le port est gigabit) ; pour un film 1080p (< 1 Mo/s) le lien actuel est largement suffisant.
