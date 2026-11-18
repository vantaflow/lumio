# Backend

Le backend est un Worker Cloudflare (Hono, TypeScript) dans `backend/`. Il est
optionnel : l'application doit fonctionner sans lui. Il servira à la
synchronisation, à l'appairage et aux watch-parties ; aujourd'hui seuls les
comptes existent.

## Routes existantes

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/health` | `{ "ok": true }` |
| POST | `/auth/request` | `{email}` : génère un jeton à usage unique valable 15 minutes et l'envoie par e-mail. Répond 202 que le compte existe ou non. Limité par adresse (429 au-delà de 5 demandes par minute). |
| POST | `/auth/verify` | `{token}` : échange le jeton contre une session et un jeton de rafraîchissement (`expiresIn` 3600 s). Le jeton ne sert qu'une fois. |
| POST | `/auth/refresh` | `{refresh}` : rotation du jeton de rafraîchissement, nouvelle session. |
| GET | `/me` | Identifiant de l'utilisateur, avec `Authorization: Bearer <session>`. |

Les routes de synchronisation (`/sync`), d'appairage (`/pair`) et de salles
(`/room`) sont prévues et n'existent pas encore.

## Données

- D1 (`DB`) : tables `users`, `login_tokens`, `sessions` (voir
  `backend/migrations/0001_init.sql`). Les jetons sont stockés hachés
  (SHA-256).
- KV (`RATE`) : compteurs de limitation de débit.
- Durable Objects : pas encore déclarés.

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
4. Appliquer les migrations : `npx wrangler d1 migrations apply lumio --remote`.
5. Configurer l'envoi d'e-mail : écrire une implémentation de `EmailSender`
   (par exemple avec Cloudflare Email Service, après vérification du domaine
   d'envoi) et la passer à `createApp` dans `src/index.ts`. Sans cela, personne
   ne reçoit de jeton de connexion.
6. Déployer : `npx wrangler deploy`.

Ces étapes ne sont pas encore réalisées : aucun backend de production n'existe.
