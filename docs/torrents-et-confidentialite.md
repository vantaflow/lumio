# Torrents et confidentialité

## Fonctionnement du moteur

Lumio utilise libtorrent (via `libtorrent_flutter` 1.7.5) derrière l'interface
`TorrentEngine`. Pour lire un flux de type torrent, le moteur :
1. ajoute le magnet (ou l'infoHash converti en magnet) ;
2. récupère les métadonnées auprès des pairs ;
3. expose le fichier choisi sur une URL HTTP locale (`127.0.0.1`) acceptant
   les plages d'octets, que le lecteur consomme ;
4. donne la priorité aux pièces nécessaires à la lecture ;
5. à l'arrêt, supprime les données téléchargées.

Mesures du spike sur une box Android TV 32 bits (un seul essai, un torrent
libre de droits de 129 Mo) : métadonnées en 1,5 s, premier mégaoctet servi en
environ 6 s, débit moyen d'environ 3 Mbit/s, aucun plantage. Détails et
réserves dans [le rapport](rapports/2026-11-18-spike-0.6.md). Le streaming de
bout en bout avec un vrai lecteur n'est pas encore construit.

## Exposition de l'adresse IP

BitTorrent est un protocole pair à pair : **votre adresse IP est visible des
autres pairs de l'essaim** et des trackers. Quiconque surveille l'essaim peut
voir que cette adresse y participe. Lumio ne masque pas votre IP.

Recommandation : utiliser un VPN de confiance au niveau de l'appareil ou du
routeur avant de lire des torrents. Lumio prévoit un avertissement dans
l'interface et, selon la conception, l'arrêt du moteur si l'interface réseau
choisie disparaît (kill switch applicatif). Une liaison native à une interface
n'est pas possible avec la bibliothèque actuelle. Ces fonctions ne sont pas
encore construites.

## Cache et limites

- Cache glissant : un plafond (`maxCacheBytes`) est transmis au moteur ; sa
  valeur par défaut visée est de 1,5 Go sur TV. Son effet réel (éviction,
  borne disque) n'a pas encore été mesuré.
- Limites de débit montant et descendant et ensemencement : prévus et
  configurables, non encore exposés dans l'interface.
- Sur une box à espace libre limité, un message « espace insuffisant » lisible
  est prévu.
- Le débit varie fortement selon l'essaim ; le 1080p à haut débit n'est pas
  garanti sur une box 32 bits.

## Légalité

Partager ou télécharger des œuvres protégées sans autorisation peut être
illégal dans votre pays. Voir [AVERTISSEMENT.md](AVERTISSEMENT.md).
