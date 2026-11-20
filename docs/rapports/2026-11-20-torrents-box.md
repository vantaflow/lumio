# Torrents sur la box : métadonnées jamais reçues (2026-11-20)

## Symptôme
Sintel (08ada5a7...) : 32 à 58 pairs, aucune métadonnée, 100 à 200 octets/s. Transmission sur le même réseau : 16 Mb/s.

## Cause
Avec « Débit montant : Désactivé », `engineUploadLimit` passait 1 au moteur. `libtorrent_flutter` 1.7.5 transmet la valeur telle quelle à `upload_rate_limit` (octets/s). libtorrent limite tous les octets sortants, poignées de main et requêtes ut_metadata comprises : 68 octets de poignée à 1 octet/s dépassent largement le délai de 5 s du moteur, les pairs sont coupés avant d'envoyer les métadonnées. Les autres pistes ont été écartées à la lecture des sources natives : DHT, LSD, UPnP actifs, chiffrement « activé » (non forcé), écoute 0.0.0.0 et [::], connexions 500, aucun proxy ni coupe-circuit appliqué au moteur. Le moteur 1.7.5 n'active pas les alertes pairs, trackers et DHT (masque figé dans le code natif) : le diagnostic repose sur les mesures d'état journalisées par l'écran de debug (pairs, graines, débits, progression).

## Correctif
`minProtocolUploadBytes` = 256 Kio/s : plancher appliqué quand l'ensemencement est désactivé ou quand la limite choisie est plus basse (0 reste illimité si on ensemence). Libellé du réglage mis à jour. Tests : `app/test/cache_manager_test.dart` (groupe engineUploadLimit).

## Mesures sur la box (armv7, Sintel)
| | Avant | Après |
|---|---|---|
| Métadonnées | jamais (5 min) | 2 à 3 s (31 à 34 pairs) |
| Débit moteur | 100-200 o/s | 1,7 Mo/s les 10 premières secondes, puis 0,06 à 0,5 Mo/s |
| Débit lu 120 s (plancher 256 Kio/s) | - | 195 Ko/s moyen |
| Débit lu 300 s (essai intermédiaire à 32 Kio/s) | - | 141 Ko/s moyen, 79 pairs max |

## Non atteint
Débit soutenu >= 1 Mo/s pendant 5 min : non tenu. Après la salve initiale, le nombre de pairs oscille entre 1 et 70 et le débit retombe à 0,1-0,2 Mo/s, comme dans le spike 0.6 (rapport 2026-11-18-spike-0.6.md). Ce comportement vient de la lecture en flux native de libtorrent_flutter 1.7.5 (fenêtre de pièces ciblée, rotation des pairs), hors de portée sans changer de moteur ; la porte 1080p reste ouverte. Lecture dans Lumio avec un addon : non testée (aucun addon de flux sur la box), le build de debug suffit.
