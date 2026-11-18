import { Hono, type Context } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { randomToken, sha256Hex } from './crypto';
import { maskEmail } from './email';
import { rateLimit } from './rate';
import type { AppEnv } from './types';

export const LOGIN_TOKEN_TTL_SEC = 15 * 60;
export const SESSION_TTL_SEC = 3600;
export const REFRESH_TTL_SEC = 30 * 24 * 3600;
export const REQUEST_LIMIT = 5;
export const REQUEST_WINDOW_SEC = 60;

const EMAIL_RE = /^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$/;

async function readJson(c: Context<AppEnv>): Promise<Record<string, unknown>> {
  try {
    const v = await c.req.json();
    return v && typeof v === 'object' ? (v as Record<string, unknown>) : {};
  } catch {
    return {};
  }
}

async function openSession(c: Context<AppEnv>, userId: string) {
  const { now } = c.var.deps;
  const session = randomToken();
  const refresh = randomToken();
  const nowSec = Math.floor(now() / 1000);
  await c.env.DB.prepare(
    'INSERT INTO sessions (id, user_id, refresh_hash, expires_at, refresh_expires_at) VALUES (?, ?, ?, ?, ?)',
  )
    .bind(
      await sha256Hex(session),
      userId,
      await sha256Hex(refresh),
      nowSec + SESSION_TTL_SEC,
      nowSec + REFRESH_TTL_SEC,
    )
    .run();
  return { session, refresh, expiresIn: SESSION_TTL_SEC };
}

/**
 * Renvoie l'identifiant utilisateur d'après `Authorization: Bearer <session>`,
 * ou lève une 401. À réutiliser par chaque route protégée (/pair, /sync, /room).
 */
export async function requireUser(c: Context<AppEnv>): Promise<string> {
  const header = c.req.header('Authorization') ?? '';
  const m = /^Bearer\s+(\S+)$/i.exec(header);
  if (!m) throw new HTTPException(401, { message: 'Authentification requise' });
  const userId = await userIdForSession(c.env.DB, m[1], Math.floor(c.var.deps.now() / 1000));
  if (!userId) throw new HTTPException(401, { message: 'Session invalide ou expirée' });
  return userId;
}

/** Identifiant utilisateur d'un jeton de session valide, sinon null. */
export async function userIdForSession(
  db: D1Database,
  token: string,
  nowSec: number,
): Promise<string | null> {
  const row = await db
    .prepare('SELECT user_id FROM sessions WHERE id = ? AND expires_at > ?')
    .bind(await sha256Hex(token), nowSec)
    .first<{ user_id: string }>();
  return row?.user_id ?? null;
}

export const authRoutes = new Hono<AppEnv>();

authRoutes.post('/request', async (c) => {
  const body = await readJson(c);
  const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
  if (email.length > 254 || !EMAIL_RE.test(email)) {
    return c.json({ error: 'Adresse e-mail invalide' }, 400);
  }
  const { now, email: sender } = c.var.deps;
  const rl = await rateLimit(c.env.RATE, `auth:${email}`, REQUEST_LIMIT, REQUEST_WINDOW_SEC, now());
  if (!rl.allowed) {
    c.header('Retry-After', String(rl.retryAfterSec));
    return c.json({ error: 'Trop de demandes, réessayez plus tard' }, 429);
  }
  const nowSec = Math.floor(now() / 1000);
  await c.env.DB.prepare('INSERT OR IGNORE INTO users (id, email, created_at) VALUES (?, ?, ?)')
    .bind(crypto.randomUUID(), email, nowSec)
    .run();
  const user = await c.env.DB.prepare('SELECT id FROM users WHERE email = ?')
    .bind(email)
    .first<{ id: string }>();
  const token = randomToken();
  await c.env.DB.prepare(
    'INSERT INTO login_tokens (token_hash, user_id, expires_at, used) VALUES (?, ?, ?, 0)',
  )
    .bind(await sha256Hex(token), user!.id, nowSec + LOGIN_TOKEN_TTL_SEC)
    .run();
  try {
    await sender.send(
      email,
      'Votre lien de connexion Lumio',
      `Votre code de connexion Lumio (valable 15 minutes, à usage unique) :\n\n${token}\n\nSi vous n'êtes pas à l'origine de cette demande, ignorez ce message.`,
    );
  } catch {
    console.error(`[auth] échec d'envoi pour ${maskEmail(email)}`);
    return c.json({ error: "Envoi de l'e-mail impossible" }, 502);
  }
  // Réponse identique que le compte existe ou non (pas d'énumération).
  return c.body(null, 202);
});

authRoutes.post('/verify', async (c) => {
  const body = await readJson(c);
  const token = typeof body.token === 'string' ? body.token : '';
  if (!token) return c.json({ error: 'Jeton manquant' }, 400);
  const nowSec = Math.floor(c.var.deps.now() / 1000);
  const hash = await sha256Hex(token);
  // Consommation atomique : un jeton ne sert qu'une fois, même en concurrence.
  const res = await c.env.DB.prepare(
    'UPDATE login_tokens SET used = 1 WHERE token_hash = ? AND used = 0 AND expires_at > ?',
  )
    .bind(hash, nowSec)
    .run();
  if (res.meta.changes !== 1) return c.json({ error: 'Jeton invalide, expiré ou déjà utilisé' }, 401);
  const row = await c.env.DB.prepare('SELECT user_id FROM login_tokens WHERE token_hash = ?')
    .bind(hash)
    .first<{ user_id: string }>();
  return c.json(await openSession(c, row!.user_id));
});

authRoutes.post('/refresh', async (c) => {
  const body = await readJson(c);
  const refresh = typeof body.refresh === 'string' ? body.refresh : '';
  if (!refresh) return c.json({ error: 'Jeton manquant' }, 400);
  const nowSec = Math.floor(c.var.deps.now() / 1000);
  const oldHash = await sha256Hex(refresh);
  // Rotation : l'ancien jeton de rafraîchissement est supprimé atomiquement.
  const row = await c.env.DB.prepare(
    'DELETE FROM sessions WHERE refresh_hash = ? AND refresh_expires_at > ? RETURNING user_id',
  )
    .bind(oldHash, nowSec)
    .first<{ user_id: string }>();
  if (!row) return c.json({ error: 'Jeton de rafraîchissement invalide ou expiré' }, 401);
  return c.json(await openSession(c, row.user_id));
});
