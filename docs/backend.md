# Serveur des salles de watch-party

`backend/` est un Worker Cloudflare (Hono, TypeScript) réduit au strict
nécessaire pour la watch-party. Il est optionnel : l'application fonctionne sans
lui (la watch-party est alors masquée). Il n'y a **aucun compte, aucune
synchronisation, aucun appairage** : une salle est anonyme.

## Routes

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/health` | `{ "ok": true }` |
| POST | `/rooms` | Crée une salle (10 par heure et par IP). Corps facultatif `{metaId, type}`. Renvoie `{roomId, inviteCode, hostKey, expiresAt}`. |
| GET | `/room/{id}?code=…` | WebSocket de la salle. |
| POST | `/room/{id}/control` | `{allControl}` ; `Authorization: Bearer <hostKey>` (hôte seulement). |

## Salles (`Room`, Durable Object, binding `ROOMS`)

- Identifiant de 128 bits, code d'invitation de 8 caractères (alphabet sans
  caractères ambigus), clé d'hôte de 128 bits. Seuls les hachages du code et de
  la clé sont stockés. Expiration à 6 h.
- Le lien d'invitation (`lumio://party?room=…&code=…`) contient l'identifiant et
  le code, jamais la clé de l'hôte. Celle-ci reste sur l'appareil qui a créé la
  salle et part dans l'en-tête `Sec-WebSocket-Protocol: lumio.v1, <clé>` (jamais
  dans l'URL) ; un invité n'envoie que le code. Chaque connexion est anonyme.
- 8 participants au plus (9e : 409). Codes invalides : 20 par minute et par IP,
  200 par fenêtre de 10 minutes pour une salle (elle est alors détruite).
- Messages `{type: state|join|leave|ping, positionMs, playing, sentAt}`
  seulement, 1 Ko max, clés inconnues refusées ; 20 messages/s par client
  (1008 au-delà). L'hôte seul contrôle, sauf `allControl`.
- La salle se ferme quand elle se vide ou à l'expiration. Aucune URL, aucun flux
  ni titre ne circule : seul le `metaId` est annoncé aux invités.

## Données

- KV (`RATE`) : compteurs de limitation de débit (clés hachées).
- Durable Objects : une salle par objet.

## Tests

```sh
cd backend && npm ci && npx vitest run && npm run typecheck
```

Les tests utilisent Miniflare (`@cloudflare/vitest-pool-workers`) et ne
nécessitent aucun compte Cloudflare.
