# Backend

Le backend est un Worker Cloudflare (Hono, TypeScript) dans `backend/`. Il est
optionnel : l'application doit fonctionner sans lui. Il sert aux
comptes, à la synchronisation, à l'appairage et aux watch-parties.

## Routes existantes

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/health` | `{ "ok": true }` |
| POST | `/auth/request` | `{email}` : génère un jeton à usage unique valable 15 minutes et l'envoie par e-mail. Répond 202 que le compte existe ou non. Limité par adresse (429 au-delà de 5 demandes par minute). |
| POST | `/auth/verify` | `{token}` : échange le jeton contre une session et un jeton de rafraîchissement (`expiresIn` 3600 s). Le jeton ne sert qu'une fois. |
| POST | `/auth/refresh` | `{refresh}` : rotation du jeton de rafraîchissement, nouvelle session. |
| GET | `/me` | Identifiant de l'utilisateur, avec `Authorization: Bearer <session>`. |

## Salles de watch-party (`/rooms`, `/room/{id}`)

Un Durable Object (`Room`, binding `ROOMS`, API d'hibernation) par salle.

- `POST /rooms` (session requise, 10 par heure et par utilisateur) renvoie
  `{roomId, inviteCode, expiresAt}` : identifiant de 128 bits, code de 8
  caractères (même alphabet que l'appairage, seul son hachage est stocké),
  expiration à 6 h.
- `GET /room/{id}?code=…` (WebSocket) : session **et** code requis, validés avant
  d'accepter. Le jeton de session ne passe jamais dans l'URL : en-tête
  `Sec-WebSocket-Protocol: lumio.v1, <jeton>`, ou à défaut premier message
  `{"type":"auth","token":"…"}` dans les 5 s (sinon fermeture 1008).
- 8 participants au plus (9e : 409). Codes invalides : 20 par minute et par IP,
  50 par salle (la salle est alors détruite).
- Messages `{type: state|join|leave|ping, positionMs, playing, sentAt}` seulement,
  1 Ko max, clés inconnues refusées ; 20 messages/s par client (1008 au-delà).
  Hôte seul en contrôle, sauf `POST /room/{id}/control {allControl}` (hôte).
- La salle se ferme quand elle se vide ou à l'expiration. Aucune URL, aucun
  flux ni titre ne circule : seul le `metaId` est annoncé aux invités.

Les routes de synchronisation (`/sync`) et d'appairage (`/pair`) sont décrites
plus haut.

## Données

- D1 (`DB`) : tables `users`, `login_tokens`, `sessions` (voir
  `backend/migrations/0001_init.sql`). Les jetons sont stockés hachés
  (SHA-256).
- KV (`RATE`) : compteurs de limitation de débit.
- Durable Objects : `Room` (binding `ROOMS`), une salle de watch-party par objet.

L'envoi d'e-mails passe par l'interface `EmailSender`. L'implémentation
actuelle (`LogEmailSender`) ne fait que journaliser un message masqué : aucun
e-mail réel n'est envoyé tant qu'un fournisseur n'est pas branché.

## Tests

```sh
cd backend && npm ci && npx vitest run
```

Les tests utilisent Miniflare (`@cloudflare/vitest-pool-workers`) et ne
nécessitent aucun compte Cloudflare.

## Déploiement (à faire par le mainteneur)

`wrangler.jsonc` contient des identifiants factices (`00000000-…`). Avant tout
déploiement :

1. Se connecter : `npx wrangler login`.
2. Créer la base : `npx wrangler d1 create lumio`, puis remplacer
   `database_id` dans `wrangler.jsonc`.
3. Créer le KV : `npx wrangler kv namespace create RATE`, puis remplacer `id`.
   Le Durable Object `Room` est déclaré dans `wrangler.jsonc` (migration
   `v1-rooms`) et créé au déploiement.
4. Appliquer les migrations : `npx wrangler d1 migrations apply lumio --remote`.
5. Configurer l'envoi d'e-mail : écrire une implémentation de `EmailSender`
   (par exemple avec Cloudflare Email Service, après vérification du domaine
   d'envoi) et la passer à `createApp` dans `src/index.ts`. Sans cela, personne
   ne reçoit de jeton de connexion.
6. Déployer : `npx wrangler deploy`.

Ces étapes ne sont pas encore réalisées : aucun backend de production n'existe.
