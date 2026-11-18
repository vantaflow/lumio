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

## Chiffrement côté client

Les adresses d'addons sont synchronisées sous la forme d'un seul élément
`addons/all`, chiffré par le client avant l'envoi : le serveur ne voit qu'un
texte opaque et ne reçoit jamais la phrase secrète.

- Format : `v1.<sel>.<nonce>.<texte chiffré + tag>` (base64url). Clé :
  PBKDF2-HMAC-SHA256, 210 000 itérations, sel aléatoire de 16 octets, 256 bits.
  Chiffrement : AES-256-GCM, nonce aléatoire de 12 octets. Les données
  associées sont le type d'élément (`addons`) : un blob ne peut pas être
  rejoué sous un autre type. Toute altération, ou une mauvaise phrase, donne
  la même erreur.
- La phrase (12 caractères au moins) est saisie une fois par appareil, reste
  dans le stockage sécurisé de l'appareil et sert à synchroniser sans
  intervention. La dérivation s'exécute hors du fil d'interface. La phrase
  n'est pas normalisée en Unicode (NFC) : aucun paquet maintenu n'est
  disponible hors ligne, deux claviers produisant des formes différentes d'un
  même accent donneraient des clés différentes.
- Rien n'est envoyé tant que le blob du serveur n'a pas été lu avec la phrase
  courante : un nouvel appareil n'écrase jamais les addons existants. Avec une
  mauvaise phrase, les addons locaux ne sont pas modifiés.
- À la réception, les addons manquants sont installés par le chemin normal
  (garde d'URL, récupération du manifeste). Une adresse du réseau local n'est
  jamais autorisée automatiquement : elle attend la confirmation de
  l'utilisateur. Le clair chiffré porte un numéro de génération croissant, un
  identifiant d'appareil et la liste des suppressions explicites (90 jours,
  100 au plus) : un blob de génération plus ancienne (rejeu du serveur,
  appareil en retard) est ignoré et remplacé par un envoi à jour. Un addon
  n'est retiré localement que par une suppression explicite et seulement s'il
  venait du dernier blob ; son absence d'un blob ne supprime jamais rien, et
  un addon ajouté sur l'appareil n'est jamais touché.
- Phrase perdue : « Réinitialiser » supprime le blob distant (pierre
  tombale) ; les addons doivent être réajoutés ou renvoyés depuis un appareil
  qui les a encore, le reste des données reste disponible. Une phrase perdue
  ne se récupère pas.
- La génération la plus élevée vue, l'origine et les suppressions survivent à
  l'oubli de la phrase (réinitialisation venue d'un autre appareil, oubli
  seul) ; la déconnexion du compte les efface avec les métadonnées de
  synchronisation, et la suppression du compte efface aussi l'empreinte et son
  sel. Une empreinte de la phrase (PBKDF2 avec un sel local) permet de
  reconnaître la même phrase ressaisie : elle garde alors ces repères et un
  ancien blob rejoué reste ignoré ; seule une phrase réellement nouvelle ouvre
  une nouvelle époque. Une génération au-delà de 2^53 rend le blob illisible.
- Limites de confiance : un appareil tout neuf (aucun repère) fait confiance
  au premier blob qu'il reçoit ; deux envois de même génération par deux
  appareils se départagent par le dernier arrivé, sans suppression.
- Limite : environ 11 Ko de clair (une quarantaine d'addons) ; au-delà, un
  message l'indique et rien n'est envoyé. En cas de modifications simultanées
  sur deux appareils, la dernière envoyée l'emporte (comme pour les autres
  éléments).

## Sauvegarde locale (export / import)

- Format `{"format":"lumio-backup","version":1}` : profils (nom, enfant, limite
  d'âge), ma liste, progression, réglages de la liste blanche de la synchro,
  réglages par titre, noms des addons. Jamais de PIN, de verrou, de code de
  récupération, de jeton ni de phrase secrète.
- Par défaut le fichier ne contient aucune adresse d'addon. Avec l'option
  explicite « Inclure les adresses », le fichier entier est chiffré
  (`SecretBox`, phrase de 12 caractères au moins choisie à l'export, données
  associées `backup`) : une adresse n'est jamais écrite en clair sur le disque.
- Import strict : format et version vérifiés (version future refusée), 10 Mo au
  maximum, bornes par champ, réglages revalidés par la liste blanche. Fusion :
  rien n'est supprimé ; les profils déjà présents ne sont pas modifiés (une
  sauvegarde ne lève pas les limites d'un profil enfant) ; la progression la
  plus récente l'emporte. Un profil enfant sans PIN parent sur l'appareil reste
  inutilisable tant que le PIN n'est pas créé.
- Les adresses d'un fichier chiffré passent par l'installation normale
  (validation, garde SSRF) ; une adresse locale attend une confirmation.
- Android : l'export va dans `Android/data/<appli>/files/backups` ; sur TV
  (pas de sélecteur de fichiers) l'import liste les `*.lumio.json` de ce
  dossier.

## Backend

- Jetons de connexion et de rafraîchissement stockés hachés (SHA-256), jeton de
  connexion à usage unique et expirant au bout de 15 minutes.
- Rotation du jeton de rafraîchissement à chaque usage.
- Limitation de débit des demandes de connexion.
- Réponse identique que le compte existe ou non ; adresses e-mail masquées dans
  les journaux.

## Dépendances

`scripts/check-licenses.sh` refuse les dépendances AGPL ou de licence inconnue.
