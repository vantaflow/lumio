# Torrents et confidentialité

## Fonctionnement du moteur

Lumio utilise **TorrServer** (MatriX.150, GPL-3.0, binaire officiel épinglé et
vérifié par SHA-256, voir [torrserver-provenance.md](torrserver-provenance.md))
derrière l'interface `TorrentEngine`. Le binaire est livré avec l'application
(`libtorrserver.so`) et lancé par elle comme processus séparé :

- `127.0.0.1` seulement (jamais « toutes les interfaces »), sur un port libre
  choisi à chaque lancement ;
- authentification HTTP obligatoire (`--httpauth`) avec un mot de passe
  aléatoire de 256 bits propre à chaque lancement, écrit dans le dossier privé
  de l'application ; un autre programme de l'appareil ne peut donc pas piloter
  le moteur ni lire le flux ;
- sortie du processus jetée : ni adresses de pairs ni mot de passe dans les
  journaux ;
- redémarré automatiquement s'il meurt (5 fois par minute au plus), arrêté deux
  minutes après le passage de l'application en arrière-plan et à sa fermeture ;
  un processus resté d'une session tuée est arrêté au lancement suivant.

Pour lire un flux de type torrent, l'application :
1. démarre le moteur (premier torrent seulement), après le contrôle du VPN ;
2. ajoute le magnet (ou l'infoHash converti en magnet) ;
3. attend un pair puis les métadonnées, choisit le fichier vidéo ;
4. donne au lecteur l'URL locale `http://127.0.0.1:<port>/stream?...` (plages
   d'octets, accès direct sans proxy : l'URL est produite par Lumio) ;
5. à l'arrêt, retire le torrent et son cache.

Mesures sur la box de référence (Android TV 32 bits, 2 Go) : voir
[le rapport d'intégration](rapports/2026-11-20-integration-torrserver.md)
(métadonnées 1,4 s, débit lu soutenu sur 5 minutes en Mo/s contre
0,1-0,5 Mo/s avec l'ancien moteur libtorrent).

## Exposition de l'adresse IP

BitTorrent est un protocole pair à pair : **votre adresse IP est visible des
autres pairs de l'essaim** et des trackers. Quiconque surveille l'essaim peut
voir que cette adresse y participe. Lumio ne masque pas votre IP.

Recommandation : utiliser un VPN de confiance au niveau de l'appareil ou du
routeur avant de lire des torrents. Lumio avertit à la première utilisation et,
avec « Exiger un VPN » :
- le processus TorrServer **ne démarre pas** si aucun VPN (ou pas le bon) n'est
  actif ;
- si le VPN tombe pendant la lecture, le torrent est retiré **et le processus
  est arrêté** (vérification toutes les 3 s) ;
- au prochain essai sans VPN, rien ne redémarre.

Ports : le serveur web de TorrServer n'écoute que sur 127.0.0.1. Comme tout
client BitTorrent, le moteur ouvre aussi un port d'écoute pour les pairs (TCP et
UDP, aléatoire, toutes interfaces) : c'est le protocole lui-même ; il ne donne
accès à aucune fonction de Lumio. UPnP est désactivé (Lumio ne demande pas
l'ouverture d'un port au routeur), de même que la découverte locale (LPD),
l'annonce Bonjour, DLNA et toute liste de trackers distante ; seuls les trackers
du magnet et une courte liste publique fixe (6 trackers UDP) sont contactés,
plus le DHT.

## Cache et limites

- Cache sur disque dans le dossier de cache de l'application, borné par le
  réglage « Cache » (défaut 1,5 Go sur TV, réduit selon l'espace libre) ;
  lecture anticipée d'environ 96 Mo, préchargement d'environ 16 Mo. Le cache
  d'un torrent est supprimé quand il est retiré (`RemoveCacheOnDrop`) ; les
  restes sont nettoyés au démarrage, et à la fermeture si « Vider le cache à la
  fermeture » est actif.
- Débit montant : « Désactivé » arrête tout envoi de données aux pairs
  (`DisableUpload`) ; sinon la limite choisie est transmise en Kio/s. (L'ancien
  plancher de 256 Kio/s, nécessaire à libtorrent, n'existe plus.)
- Sur une box à espace libre limité, un message « espace insuffisant » lisible
  est affiché avant tout contact avec des pairs.
- Le débit dépend de l'essaim.

## Légalité

Partager ou télécharger des œuvres protégées sans autorisation peut être
illégal dans votre pays. Voir [AVERTISSEMENT.md](AVERTISSEMENT.md).
