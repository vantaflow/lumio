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
- jamais envoyées à un serveur (Lumio n'a pas de synchronisation).

## Chiffrement local

Les adresses d'addons restent dans le stockage sécurisé de l'appareil
(`SecretStore`), jamais en clair dans SQLite. Il n'y a plus de synchronisation :
rien n'est envoyé à un serveur. `SecretBox` ne sert plus qu'à chiffrer une
sauvegarde exportée avec les adresses.

- Format : `v1.<sel>.<nonce>.<texte chiffré + tag>` (base64url). Clé :
  PBKDF2-HMAC-SHA256, 210 000 itérations, sel aléatoire de 16 octets, 256 bits.
  Chiffrement : AES-256-GCM, nonce aléatoire de 12 octets. Les données
  associées (`backup`) identifient l'usage : un blob ne peut pas être rejoué
  sous un autre usage. Toute altération, ou une mauvaise phrase, donne la même
  erreur.
- La phrase (12 caractères au moins) est choisie à l'export et n'est jamais
  conservée. La dérivation s'exécute hors du fil d'interface. La phrase n'est
  pas normalisée en Unicode (NFC).

## Sauvegarde locale (export / import)

- Format `{"format":"lumio-backup","version":1}` : profils (nom, enfant, limite
  d'âge), ma liste, progression, réglages de la liste blanche de la sauvegarde,
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

## Serveur des salles de watch-party

- Aucun compte : salle anonyme protégée par un identifiant de 128 bits et un
  code de 8 caractères ; seuls leurs hachages sont stockés. La clé de l'hôte
  (128 bits) ne figure jamais dans le lien d'invitation ni dans une URL.
- Limitation de débit : créations par IP, codes invalides par IP et par salle
  (salle détruite au plafond), 20 messages par seconde et par client.
- Seuls position et état de lecture circulent ; aucune URL ni titre.

## Dépendances

`scripts/check-licenses.sh` refuse les dépendances AGPL ou de licence inconnue.
