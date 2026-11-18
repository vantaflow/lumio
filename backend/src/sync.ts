import { Hono, type Context } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { requireUser } from './auth';
import { rateLimit } from './rate';
import type { AppEnv } from './types';

export const SYNC_KINDS = ['library', 'progress', 'settings', 'profiles', 'addons'] as const;
export const SYNC_PAGE_SIZE = 500;
export const SYNC_MAX_ITEMS = 500;
export const SYNC_MAX_BODY_BYTES = 256 * 1024;
export const SYNC_MAX_PAYLOAD_BYTES = 16 * 1024;
export const SYNC_MAX_KEY_LENGTH = 256;
export const SYNC_RATE_LIMIT = 120; // requêtes par minute et par utilisateur
const WINDOW_SEC = 60;

/** Réglages synchronisables : jamais de PIN, de verrou ni de code de récupération. */
const SETTINGS_KEY_RE = /^(ui_locale|(home_layout|stream_prefs|subtitle_lang):[A-Za-z0-9_-]{1,64})$/;
/** Un profil ne transporte que son nom, son statut enfant et sa limite d'âge. */
const PROFILE_FIELDS = new Set(['name', 'isKid', 'ageLimit']);

interface Incoming {
  kind: string;
  key: string;
  payload: string | null; // JSON sérialisé
  deleted: boolean;
}

class BadRequest extends HTTPException {
  constructor(message: string, status: 400 | 413 = 400) {
    super(status, { message });
  }
}

const isObject = (v: unknown): v is Record<string, unknown> =>
  !!v && typeof v === 'object' && !Array.isArray(v);

const byteLength = (s: string) => new TextEncoder().encode(s).length;

function parseItem(raw: unknown, index: number): Incoming {
  const at = `élément ${index}`;
  if (!isObject(raw)) throw new BadRequest(`${at} : objet attendu`);
  const { kind, key, payload, deleted, baseVersion } = raw;
  if (typeof kind !== 'string' || !(SYNC_KINDS as readonly string[]).includes(kind)) {
    throw new BadRequest(`${at} : type inconnu`);
  }
  if (typeof key !== 'string' || key.length < 1 || key.length > SYNC_MAX_KEY_LENGTH) {
    throw new BadRequest(`${at} : clé invalide`);
  }
  if (deleted !== undefined && deleted !== true && deleted !== false && deleted !== 0 && deleted !== 1) {
    throw new BadRequest(`${at} : « deleted » invalide`);
  }
  if (baseVersion !== undefined && !(Number.isInteger(baseVersion) && (baseVersion as number) >= 0)) {
    throw new BadRequest(`${at} : « baseVersion » invalide`);
  }
  const isDeleted = deleted === true || deleted === 1;
  if (kind === 'settings' && !SETTINGS_KEY_RE.test(key)) {
    throw new BadRequest(`${at} : réglage non synchronisable`);
  }
  if (isDeleted) {
    // La pierre tombale ne garde rien, sauf l'horodatage d'une progression
    // (pour qu'une progression plus ancienne ne la ressuscite pas).
    if (kind === 'progress' && isObject(payload) && typeof payload.updatedAt === 'number' && Number.isFinite(payload.updatedAt)) {
      return { kind, key, payload: JSON.stringify({ updatedAt: payload.updatedAt }), deleted: true };
    }
    return { kind, key, payload: null, deleted: true };
  }
  if (!isObject(payload)) throw new BadRequest(`${at} : contenu manquant`);
  if (kind === 'progress' && !(typeof payload.updatedAt === 'number' && Number.isFinite(payload.updatedAt))) {
    throw new BadRequest(`${at} : « updatedAt » manquant`);
  }
  if (kind === 'profiles' && Object.keys(payload).some((f) => !PROFILE_FIELDS.has(f))) {
    throw new BadRequest(`${at} : champ de profil non synchronisable`);
  }
  const text = JSON.stringify(payload);
  if (byteLength(text) > SYNC_MAX_PAYLOAD_BYTES) throw new BadRequest(`${at} : contenu trop volumineux`, 413);
  return { kind, key, payload: text, deleted: false };
}

async function readBody(c: Context<AppEnv>): Promise<unknown> {
  const declared = Number(c.req.header('content-length') ?? '0');
  if (declared > SYNC_MAX_BODY_BYTES) throw new BadRequest('Requête trop volumineuse', 413);
  let buf: ArrayBuffer;
  try {
    buf = await c.req.arrayBuffer();
  } catch {
    throw new BadRequest('Corps illisible');
  }
  if (buf.byteLength > SYNC_MAX_BODY_BYTES) throw new BadRequest('Requête trop volumineuse', 413);
  try {
    return JSON.parse(new TextDecoder().decode(buf));
  } catch {
    throw new BadRequest('JSON invalide');
  }
}

async function throttle(c: Context<AppEnv>, userId: string) {
  const rl = await rateLimit(c.env.RATE, `sync:${userId}`, SYNC_RATE_LIMIT, WINDOW_SEC, c.var.deps.now());
  if (!rl.allowed) {
    c.header('Retry-After', String(rl.retryAfterSec));
    throw new HTTPException(429, { message: 'Trop de demandes, réessayez plus tard' });
  }
}

const UPSERT = `INSERT INTO sync_items (user_id, kind, key, payload, version, deleted)
VALUES (?, ?, ?, ?, (SELECT version FROM sync_state WHERE user_id = ?), ?)
ON CONFLICT(user_id, kind, key) DO UPDATE SET
  payload = excluded.payload, version = excluded.version, deleted = excluded.deleted
WHERE excluded.kind <> 'progress'
  OR (excluded.deleted = 1 AND excluded.payload IS NULL)
  OR COALESCE(json_extract(excluded.payload, '$.updatedAt'), 0)
     >= COALESCE(json_extract(sync_items.payload, '$.updatedAt'), 0)`;

export const syncRoutes = new Hono<AppEnv>();

syncRoutes.get('/', async (c) => {
  const userId = await requireUser(c);
  await throttle(c, userId);
  const rawSince = c.req.query('since') ?? '0';
  if (!/^\d{1,15}$/.test(rawSince)) throw new BadRequest('« since » invalide');
  const since = Number(rawSince);
  const db = c.env.DB;
  // Le numéro courant est lu AVANT les éléments : une écriture concurrente a
  // forcément une version supérieure et sera servie à l'appel suivant.
  const state = await db
    .prepare('SELECT version FROM sync_state WHERE user_id = ?')
    .bind(userId)
    .first<{ version: number }>();
  const current = state?.version ?? 0;
  const rows = await db
    .prepare(
      `SELECT kind, key, payload, version, deleted FROM sync_items
       WHERE user_id = ? AND version > ? AND version <= ?
       ORDER BY version, kind, key LIMIT ?`,
    )
    .bind(userId, since, current, SYNC_PAGE_SIZE + 1)
    .all<{ kind: string; key: string; payload: string | null; version: number; deleted: number }>();
  let items = rows.results;
  let more = false;
  let version = current;
  if (items.length > SYNC_PAGE_SIZE) {
    // On ne coupe jamais au milieu d'une version : un envoi en porte au plus
    // SYNC_MAX_ITEMS, donc au moins deux versions figurent dans la page lue.
    const lastVersion = items[items.length - 1].version;
    items = items.filter((r) => r.version !== lastVersion);
    more = true;
    version = items[items.length - 1].version;
  }
  c.header('Cache-Control', 'no-store');
  return c.json({
    items: items.map((r) => ({
      kind: r.kind,
      key: r.key,
      payload: r.payload === null ? null : JSON.parse(r.payload),
      version: r.version,
      deleted: r.deleted,
    })),
    version,
    more,
  });
});

syncRoutes.post('/', async (c) => {
  const userId = await requireUser(c);
  await throttle(c, userId);
  const body = await readBody(c);
  const list = isObject(body) ? body.items : undefined;
  if (!Array.isArray(list)) throw new BadRequest('« items » attendu');
  if (list.length > SYNC_MAX_ITEMS) throw new BadRequest('Trop d’éléments', 413);
  const items = list.map(parseItem);
  const db = c.env.DB;
  if (items.length === 0) {
    const s = await db
      .prepare('SELECT version FROM sync_state WHERE user_id = ?')
      .bind(userId)
      .first<{ version: number }>();
    return c.json({ version: s?.version ?? 0 });
  }
  // Un seul lot D1 = une transaction : le compteur et les éléments avancent
  // ensemble, deux envois concurrents n'obtiennent jamais la même version.
  const results = await db.batch([
    db.prepare('INSERT OR IGNORE INTO sync_state (user_id, version) VALUES (?, 0)').bind(userId),
    db.prepare('UPDATE sync_state SET version = version + 1 WHERE user_id = ? RETURNING version').bind(userId),
    ...items.map((i) =>
      db.prepare(UPSERT).bind(userId, i.kind, i.key, i.payload, userId, i.deleted ? 1 : 0),
    ),
  ]);
  const version = (results[1].results[0] as { version: number }).version;
  return c.json({ version });
});

export const accountRoutes = new Hono<AppEnv>();

/** Efface le compte et tout ce qui s'y rattache ; la session devient invalide. */
accountRoutes.delete('/', async (c) => {
  const userId = await requireUser(c);
  const db = c.env.DB;
  // Les codes d'appairage (table `pairings`) ne sont rattachés à aucun
  // utilisateur : ils n'ont rien à effacer ici et expirent en 5 minutes.
  await db.batch([
    db.prepare('DELETE FROM sync_items WHERE user_id = ?').bind(userId),
    db.prepare('DELETE FROM sync_state WHERE user_id = ?').bind(userId),
    db.prepare('DELETE FROM login_tokens WHERE user_id = ?').bind(userId),
    db.prepare('DELETE FROM sessions WHERE user_id = ?').bind(userId),
    db.prepare('DELETE FROM users WHERE id = ?').bind(userId),
  ]);
  return c.body(null, 204);
});
