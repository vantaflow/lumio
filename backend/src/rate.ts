import { sha256Hex } from './crypto';

export interface RateResult {
  allowed: boolean;
  remaining: number;
  retryAfterSec: number;
}

/**
 * Limiteur à fenêtre fixe sur KV. `key` est haché avant stockage (pas d'e-mail
 * en clair dans KV). `now` (ms) est injectable pour les tests. Le compteur KV
 * n'est pas atomique : sous forte concurrence la limite peut être dépassée de
 * peu, ce qui est acceptable pour de l'anti-abus.
 */
export async function rateLimit(
  kv: KVNamespace,
  key: string,
  limit: number,
  windowSec: number,
  now: number = Date.now(),
): Promise<RateResult> {
  const windowIndex = Math.floor(now / 1000 / windowSec);
  const storeKey = `rl:${await sha256Hex(key)}:${windowIndex}`;
  const count = Number((await kv.get(storeKey)) ?? '0');
  const retryAfterSec = Math.max(1, (windowIndex + 1) * windowSec - Math.floor(now / 1000));
  if (count >= limit) return { allowed: false, remaining: 0, retryAfterSec };
  // KV impose un TTL minimal de 60 s.
  await kv.put(storeKey, String(count + 1), { expirationTtl: Math.max(60, windowSec * 2) });
  return { allowed: true, remaining: limit - count - 1, retryAfterSec };
}

/**
 * Lecture seule : vrai si `key` a déjà atteint `limit` dans la fenêtre courante
 * (sans incrémenter). Sert aux compteurs d'échecs alimentés par `rateLimit`.
 */
export async function rateBlocked(
  kv: KVNamespace,
  key: string,
  limit: number,
  windowSec: number,
  now: number = Date.now(),
): Promise<RateResult> {
  const windowIndex = Math.floor(now / 1000 / windowSec);
  const storeKey = `rl:${await sha256Hex(key)}:${windowIndex}`;
  const count = Number((await kv.get(storeKey)) ?? '0');
  const retryAfterSec = Math.max(1, (windowIndex + 1) * windowSec - Math.floor(now / 1000));
  return { allowed: count < limit, remaining: Math.max(0, limit - count), retryAfterSec };
}
