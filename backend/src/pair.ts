import { Hono, type Context } from 'hono';
import { randomToken, sha256Hex } from './crypto';
import { rateBlocked, rateLimit } from './rate';
import { PAIR_PAGE_CSP, pairPage, type PairPageState } from './pages/pair.html';
import type { AppEnv } from './types';

export const PAIR_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
export const PAIR_CODE_LENGTH = 6;
export const PAIR_TTL_SEC = 300;
export const PAIR_MAX_PAYLOAD_BYTES = 8 * 1024;
export const CREATE_LIMIT = 10; // créations par minute et par IP
export const FAIL_LIMIT = 30; // recherches ratées par minute et par IP
export const CODE_LIMIT = 60; // requêtes par minute et par code
const WINDOW_SEC = 60;

const CODE_RE = new RegExp(`^[${PAIR_ALPHABET}]{${PAIR_CODE_LENGTH}}$`);

/** Code aléatoire par échantillonnage avec rejet (aucun biais de modulo). */
export function generateCode(): string {
  const limit = 256 - (256 % PAIR_ALPHABET.length);
  let out = '';
  while (out.length < PAIR_CODE_LENGTH) {
    for (const b of crypto.getRandomValues(new Uint8Array(16))) {
      if (b < limit && out.length < PAIR_CODE_LENGTH) out += PAIR_ALPHABET[b % PAIR_ALPHABET.length];
    }
  }
  return out;
}

function clientIp(c: Context<AppEnv>): string {
  return c.req.header('CF-Connecting-IP') ?? 'unknown';
}

function timingSafeEqualHex(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function tooMany(c: Context<AppEnv>, retryAfterSec: number) {
  c.header('Retry-After', String(retryAfterSec));
  return c.json({ error: 'Trop de demandes, réessayez plus tard' }, 429);
}

/** Compte un échec de recherche pour cette IP (anti-force brute). */
async function recordFailure(c: Context<AppEnv>) {
  await rateLimit(c.env.RATE, `pairfail:${clientIp(c)}`, FAIL_LIMIT, WINDOW_SEC, c.var.deps.now());
}

const notFound = (c: Context<AppEnv>) => c.json({ error: 'Code inconnu ou expiré' }, 404);

export const pairRoutes = new Hono<AppEnv>();

pairRoutes.post('/', async (c) => {
  const { now } = c.var.deps;
  const rl = await rateLimit(c.env.RATE, `paircreate:${clientIp(c)}`, CREATE_LIMIT, WINDOW_SEC, now());
  if (!rl.allowed) return tooMany(c, rl.retryAfterSec);
  const nowSec = Math.floor(now() / 1000);
  // Ménage opportuniste des codes périmés depuis plus d'une heure.
  await c.env.DB.prepare('DELETE FROM pairings WHERE expires_at < ?').bind(nowSec - 3600).run();
  const pollToken = randomToken();
  const pollHash = await sha256Hex(pollToken);
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = generateCode();
    const res = await c.env.DB.prepare(
      'INSERT OR IGNORE INTO pairings (code_hash, poll_hash, expires_at) VALUES (?, ?, ?)',
    )
      .bind(await sha256Hex(code), pollHash, nowSec + PAIR_TTL_SEC)
      .run();
    if (res.meta.changes === 1) {
      c.header('Cache-Control', 'no-store');
      return c.json({ code, pollToken, expiresIn: PAIR_TTL_SEC }, 201);
    }
  }
  return c.json({ error: 'Erreur interne' }, 500);
});

/** Lit le corps (JSON ou formulaire) ; renvoie le texte ou un code d'erreur. */
async function readPayload(
  c: Context<AppEnv>,
): Promise<{ ok: true; payload: string; form: boolean } | { ok: false; status: 400 | 413; form: boolean }> {
  const type = (c.req.header('content-type') ?? '').toLowerCase();
  const form = type.startsWith('application/x-www-form-urlencoded');
  const declared = Number(c.req.header('content-length') ?? '0');
  // Un formulaire encode en %XX (jusqu'à 3x) : marge large avant lecture.
  if (declared > PAIR_MAX_PAYLOAD_BYTES * 4 + 1024) return { ok: false, status: 413, form };
  let raw: string;
  try {
    raw = new TextDecoder().decode(await c.req.arrayBuffer());
  } catch {
    return { ok: false, status: 400, form };
  }
  if (raw.length > PAIR_MAX_PAYLOAD_BYTES * 4 + 1024) return { ok: false, status: 413, form };
  let payload: unknown;
  if (form) {
    payload = new URLSearchParams(raw).get('payload');
  } else {
    try {
      payload = (JSON.parse(raw) as { payload?: unknown })?.payload;
    } catch {
      return { ok: false, status: 400, form };
    }
  }
  if (typeof payload !== 'string' || payload.trim() === '') return { ok: false, status: 400, form };
  if (new TextEncoder().encode(payload).length > PAIR_MAX_PAYLOAD_BYTES) {
    return { ok: false, status: 413, form };
  }
  return { ok: true, payload: payload.trim(), form };
}

function htmlResponse(c: Context<AppEnv>, code: string, state: PairPageState, status = 200) {
  return c.html(pairPage(code, state), status as 200, {
    'Content-Security-Policy': PAIR_PAGE_CSP,
    'Cache-Control': 'no-store',
    'Referrer-Policy': 'no-referrer',
    'X-Content-Type-Options': 'nosniff',
  });
}

pairRoutes.post('/:code', async (c) => {
  const { now } = c.var.deps;
  const code = c.req.param('code').toUpperCase();
  const body = await readPayload(c);
  const form = body.form;
  const fail = (status: 404 | 413 | 400) => {
    if (form) {
      const valid = CODE_RE.test(code);
      return htmlResponse(c, valid ? code : '------', status === 413 ? 'toolarge' : 'expired', status);
    }
    return status === 404
      ? notFound(c)
      : c.json({ error: status === 413 ? 'Contenu trop volumineux' : 'Contenu invalide' }, status);
  };

  const blocked = await rateBlocked(c.env.RATE, `pairfail:${clientIp(c)}`, FAIL_LIMIT, WINDOW_SEC, now());
  if (!blocked.allowed) return tooMany(c, blocked.retryAfterSec);
  if (!CODE_RE.test(code)) {
    await recordFailure(c);
    return fail(404);
  }
  const rl = await rateLimit(c.env.RATE, `pairpost:${code}`, 10, WINDOW_SEC, now());
  if (!rl.allowed) return tooMany(c, rl.retryAfterSec);
  if (!body.ok) return fail(body.status);

  const nowSec = Math.floor(now() / 1000);
  const res = await c.env.DB.prepare(
    'UPDATE pairings SET payload = ? WHERE code_hash = ? AND expires_at > ? AND payload IS NULL AND consumed = 0',
  )
    .bind(body.payload, await sha256Hex(code), nowSec)
    .run();
  if (res.meta.changes !== 1) {
    await recordFailure(c);
    return fail(404);
  }
  if (form) return htmlResponse(c, code, 'sent');
  return c.body(null, 204);
});

pairRoutes.get('/:code', async (c) => {
  const { now } = c.var.deps;
  const code = c.req.param('code').toUpperCase();
  c.header('Cache-Control', 'no-store');
  const blocked = await rateBlocked(c.env.RATE, `pairfail:${clientIp(c)}`, FAIL_LIMIT, WINDOW_SEC, now());
  if (!blocked.allowed) return tooMany(c, blocked.retryAfterSec);
  if (!CODE_RE.test(code)) {
    await recordFailure(c);
    return notFound(c);
  }
  const rl = await rateLimit(c.env.RATE, `pairget:${code}`, CODE_LIMIT, WINDOW_SEC, now());
  if (!rl.allowed) return tooMany(c, rl.retryAfterSec);

  const m = /^Bearer\s+(\S+)$/i.exec(c.req.header('Authorization') ?? '');
  const codeHash = await sha256Hex(code);
  const row = await c.env.DB.prepare(
    'SELECT poll_hash, expires_at, payload, consumed FROM pairings WHERE code_hash = ?',
  )
    .bind(codeHash)
    .first<{ poll_hash: string; expires_at: number; payload: string | null; consumed: number }>();
  // Jeton absent ou faux = même 404 qu'un code inconnu.
  const tokenHash = m ? await sha256Hex(m[1]) : '';
  if (!row || !m || !timingSafeEqualHex(row.poll_hash, tokenHash)) {
    await recordFailure(c);
    return notFound(c);
  }
  const nowSec = Math.floor(now() / 1000);
  if (row.consumed === 1 || row.expires_at <= nowSec) return c.json({ error: 'Code expiré ou utilisé' }, 410);
  if (row.payload === null) return c.body(null, 204);
  // Lecture unique : on efface le contenu et on marque le code consommé.
  const res = await c.env.DB.prepare(
    'UPDATE pairings SET consumed = 1, payload = NULL WHERE code_hash = ? AND consumed = 0 AND payload IS NOT NULL',
  )
    .bind(codeHash)
    .run();
  if (res.meta.changes !== 1) return c.json({ error: 'Code expiré ou utilisé' }, 410);
  return c.json({ payload: row.payload });
});

export const pairPageRoutes = new Hono<AppEnv>();

pairPageRoutes.get('/:code', async (c) => {
  const code = c.req.param('code').toUpperCase();
  if (!CODE_RE.test(code)) return htmlResponse(c, '------', 'expired', 404);
  return htmlResponse(c, code, 'form');
});
