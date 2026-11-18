# Sécurité

Pour signaler une faille, voir [SECURITY.md](../SECURITY.md).

## Garde SSRF

Lumio contacte des URL fournies par l'utilisateur (addons) ou par des
addons. La garde d'URL (`UrlGuard`, existante) :
- n'accepte que `http` et `https` ;
- refuse `localhost`, les adresses de boucle, privées, de lien local et les
  notations d'hôte numériques ambiguës, sauf confirmation explicite
  (`allowPrivate`) ;
- est appliquée par le récupérateur HTTP lui-même, y compris à chaque
  redirection ;
- limite le nombre de redirections, la taille des réponses (5 Mo) et la durée.

Limite connue : une garde fondée sur l'hôte écrit dans l'URL ne couvre pas un
nom de domaine public qui résoudrait vers une adresse privée (rebinding DNS).

## URL d'addons : des secrets

L'URL d'un addon contient souvent une clé personnelle. Règles du projet :
- stockage prévu dans le stockage sécurisé du système, jamais en clair dans
  SQLite ;
- jamais dans les journaux : `redactUrl` ne conserve que le schéma et l'hôte ;
- jamais en clair sur le serveur de synchronisation.

## Chiffrement côté client (prévu)

Pour la synchronisation, les secrets seront chiffrés par le client (AES-GCM,
clé dérivée d'une phrase secrète) avant envoi ; le serveur ne les lira pas.
Cela n'est pas encore implémenté. Corollaire : une phrase secrète perdue ne
se récupère pas.

## Backend

- Jetons de connexion et de rafraîchissement stockés hachés (SHA-256), jeton de
  connexion à usage unique et expirant au bout de 15 minutes.
- Rotation du jeton de rafraîchissement à chaque usage.
- Limitation de débit des demandes de connexion.
- Réponse identique que le compte existe ou non ; adresses e-mail masquées dans
  les journaux.

## Dépendances

`scripts/check-licenses.sh` refuse les dépendances AGPL ou de licence inconnue.
