import { env } from 'cloudflare:workers';
import { beforeEach, describe, expect, it } from 'vitest';
import { sha256Hex } from '../src/crypto';
import { createApp } from '../src/index';

let now = 1_800_000_000_000;
let app: ReturnType<typeof createApp>;

interface Item {
  kind: string;
  key: string;
  payload: unknown;
  version: number;
  deleted: number;
}

async function user(id: string, token: string) {
  const nowSec = Math.floor(now / 1000);
  await env.DB.batch([
    env.DB.prepare('INSERT INTO users (id, email, created_at) VALUES (?, ?, ?)').bind(id, `${id}@example.com`, nowSec),
    env.DB.prepare(
      'INSERT INTO sessions (id, user_id, refresh_hash, expires_at, refresh_expires_at) VALUES (?, ?, ?, ?, ?)',
    ).bind(await sha256Hex(token), id, await sha256Hex(`r-${token}`), nowSec + 3600, nowSec + 86400),
  ]);
  return { Authorization: `Bearer ${token}` };
}

const call = (path: string, init: RequestInit & { auth?: Record<string, string> } = {}) =>
  app.request(path, { ...init, headers: { ...init.auth, ...(init.headers as object) } }, env);
const post = (auth: Record<string, string>, items: unknown[], raw?: string) =>
  call('/sync', {
    method: 'POST',
    auth,
    body: raw ?? JSON.stringify({ items }),
    headers: { 'content-type': 'application/json' },
  });
const get = (auth: Record<string, string>, since = 0) => call(`/sync?since=${since}`, { auth });
const lib = (key: string, extra: object = {}) => ({ kind: 'library', key, payload: { name: key }, deleted: false, baseVersion: 0, ...extra });

let A: Record<string, string>;
let B: Record<string, string>;

beforeEach(async () => {
  now = 1_800_000_000_000 + Math.floor(Math.random() * 1e6) * 1000; // fenêtres de débit distinctes
  app = createApp({ now: () => now });
  await env.DB.batch([
    env.DB.prepare('DELETE FROM sync_items'),
    env.DB.prepare('DELETE FROM sync_state'),
    env.DB.prepare('DELETE FROM sessions'),
    env.DB.prepare('DELETE FROM login_tokens'),
    env.DB.prepare('DELETE FROM users'),
  ]);
  A = await user('ua', 'token-a');
  B = await user('ub', 'token-b');
});

describe('versions attribuées par le serveur', () => {
  it('deux envois successifs : versions 1 puis 2', async () => {
    expect(await (await post(A, [lib('p|tt1')])).json()).toEqual({ version: 1 });
    expect(await (await post(A, [lib('p|tt2')])).json()).toEqual({ version: 2 });
    const body = (await (await get(A, 0)).json()) as { items: Item[]; version: number; more: boolean };
    expect(body.version).toBe(2);
    expect(body.more).toBe(false);
    expect(body.items.map((i) => [i.key, i.version])).toEqual([['p|tt1', 1], ['p|tt2', 2]]);
  });

  it('envois concurrents : jamais deux fois la même version', async () => {
    const res = await Promise.all(Array.from({ length: 12 }, (_, i) => post(A, [lib(`p|c${i}`)])));
    const versions = (await Promise.all(res.map((r) => r.json()))).map((b) => (b as { version: number }).version);
    expect(new Set(versions).size).toBe(12);
    expect([...versions].sort((a, b) => a - b)).toEqual(Array.from({ length: 12 }, (_, i) => i + 1));
  });

  it("la version du client (baseVersion) ou son horloge n'influent pas", async () => {
    await post(A, [lib('p|tt1', { payload: { name: 'v1' }, baseVersion: 99 })]);
    await post(A, [lib('p|tt1', { payload: { name: 'v2' }, baseVersion: 0 })]);
    const body = (await (await get(A, 0)).json()) as { items: Item[] };
    expect(body.items).toEqual([{ kind: 'library', key: 'p|tt1', payload: { name: 'v2' }, version: 2, deleted: 0 }]);
  });

  it('since ne renvoie que les éléments plus récents', async () => {
    await post(A, [lib('p|a')]);
    await post(A, [lib('p|b')]);
    const body = (await (await get(A, 1)).json()) as { items: Item[]; version: number };
    expect(body.items.map((i) => i.key)).toEqual(['p|b']);
    expect(body.version).toBe(2);
  });

  it("l'isolement entre utilisateurs est total", async () => {
    await post(A, [lib('p|secret')]);
    const body = (await (await get(B, 0)).json()) as { items: Item[]; version: number };
    expect(body).toEqual({ items: [], version: 0, more: false });
  });
});

describe('pierres tombales', () => {
  it('une suppression est renvoyée avec deleted:1 et sans contenu', async () => {
    await post(A, [lib('p|tt1')]);
    await post(A, [{ kind: 'library', key: 'p|tt1', payload: { name: 'ne pas garder' }, deleted: true, baseVersion: 1 }]);
    const body = (await (await get(A, 1)).json()) as { items: Item[] };
    expect(body.items).toEqual([{ kind: 'library', key: 'p|tt1', payload: null, version: 2, deleted: 1 }]);
    const row = await env.DB.prepare('SELECT payload FROM sync_items').first<{ payload: string | null }>();
    expect(row!.payload).toBeNull();
  });
});

describe('progression', () => {
  const prog = (updatedAt: number, positionMs: number, extra: object = {}) => ({
    kind: 'progress',
    key: 'p|tt1',
    payload: { positionMs, updatedAt },
    deleted: false,
    ...extra,
  });

  it("une progression plus ancienne ne remplace pas la plus récente", async () => {
    await post(A, [prog(2000, 500)]);
    await post(A, [prog(1000, 100)]);
    const body = (await (await get(A, 0)).json()) as { items: Item[] };
    expect(body.items).toHaveLength(1);
    expect(body.items[0].payload).toEqual({ positionMs: 500, updatedAt: 2000 });
    expect(body.items[0].version).toBe(1);
  });

  it('une progression plus récente remplace (égalité comprise)', async () => {
    await post(A, [prog(1000, 100)]);
    await post(A, [prog(3000, 900)]);
    const body = (await (await get(A, 0)).json()) as { items: Item[] };
    expect(body.items[0].payload).toEqual({ positionMs: 900, updatedAt: 3000 });
    expect(body.items[0].version).toBe(2);
  });

  it('une progression sans updatedAt est refusée', async () => {
    const r = await post(A, [{ kind: 'progress', key: 'p|tt1', payload: { positionMs: 1 }, deleted: false }]);
    expect(r.status).toBe(400);
  });

  it("une suppression de progression sans horodatage l'emporte", async () => {
    await post(A, [prog(5000, 500)]);
    await post(A, [{ kind: 'progress', key: 'p|tt1', payload: null, deleted: true }]);
    const body = (await (await get(A, 0)).json()) as { items: Item[] };
    expect(body.items[0]).toMatchObject({ deleted: 1, payload: null, version: 2 });
  });

  it("une suppression datée d'avant une progression plus récente est ignorée", async () => {
    await post(A, [prog(5000, 500)]);
    await post(A, [{ kind: 'progress', key: 'p|tt1', payload: { updatedAt: 1000 }, deleted: true }]);
    const body = (await (await get(A, 0)).json()) as { items: Item[] };
    expect(body.items[0]).toMatchObject({ deleted: 0, version: 1 });
  });
});

describe('limites et validations', () => {
  it('pagination : 500 éléments au plus, more:true, sans couper une version', async () => {
    for (let b = 0; b < 3; b++) {
      await post(A, Array.from({ length: 300 }, (_, i) => lib(`p|b${b}-${i}`)));
    }
    const p1 = (await (await get(A, 0)).json()) as { items: Item[]; version: number; more: boolean };
    expect(p1.more).toBe(true);
    expect(p1.items.length).toBeLessThanOrEqual(500);
    expect(p1.items.length).toBe(300); // une version entière : 2e version incomplète écartée
    expect(p1.version).toBe(1);
    const p2 = (await (await get(A, p1.version)).json()) as { items: Item[]; version: number; more: boolean };
    expect(p2.more).toBe(true);
    expect(p2.items).toHaveLength(300);
    expect(p2.version).toBe(2);
    const p3 = (await (await get(A, p2.version)).json()) as { items: Item[]; version: number; more: boolean };
    expect(p3.more).toBe(false);
    expect(p3.items).toHaveLength(300);
    expect(p3.version).toBe(3);
  });

  it('au plus 500 éléments par envoi', async () => {
    expect((await post(A, Array.from({ length: 500 }, (_, i) => lib(`p|${i}`)))).status).toBe(200);
    expect((await post(A, Array.from({ length: 501 }, (_, i) => lib(`p|${i}`)))).status).toBe(413);
  });

  it('corps de plus de 256 Ko refusé', async () => {
    const big = JSON.stringify({ items: [], pad: 'x'.repeat(260 * 1024) });
    expect((await post(A, [], big)).status).toBe(413);
  });

  it('contenu de plus de 16 Ko refusé, 16 Ko accepté', async () => {
    const ok = { name: 'x'.repeat(16 * 1024 - 20) };
    expect((await post(A, [lib('p|ok', { payload: ok })])).status).toBe(200);
    const tooBig = { name: 'x'.repeat(16 * 1024) };
    expect((await post(A, [lib('p|big', { payload: tooBig })])).status).toBe(413);
  });

  it("un échec de validation n'écrit rien (ni version)", async () => {
    const r = await post(A, [lib('p|ok'), { kind: 'inconnu', key: 'x', payload: {}, deleted: false }]);
    expect(r.status).toBe(400);
    expect(await (await get(A, 0)).json()).toEqual({ items: [], version: 0, more: false });
  });

  it('refuse les formes invalides', async () => {
    for (const bad of [
      lib('p|x', { key: '' }),
      lib('p|x', { key: 'k'.repeat(257) }),
      lib('p|x', { payload: null }),
      lib('p|x', { payload: [1] }),
      lib('p|x', { deleted: 'oui' }),
      lib('p|x', { baseVersion: -1 }),
    ]) {
      expect((await post(A, [bad])).status).toBe(400);
    }
    expect((await post(A, [], '{pas du json')).status).toBe(400);
    expect((await call('/sync', { method: 'POST', auth: A, body: JSON.stringify({}) })).status).toBe(400);
    expect((await get(A, -1)).status).toBe(400);
    expect((await call('/sync?since=abc', { auth: A })).status).toBe(400);
  });

  it('refuse les réglages et champs de profil sensibles (PIN, verrou, récupération)', async () => {
    for (const key of ['parent_pin_hash', 'parent_recovery_hash', 'parent_lockout', 'active_profile', 'home_layout:']) {
      expect((await post(A, [{ kind: 'settings', key, payload: { value: 'x' }, deleted: false }])).status).toBe(400);
    }
    for (const key of ['ui_locale', 'home_layout:p1', 'stream_prefs:p1', 'subtitle_lang:default']) {
      expect((await post(A, [{ kind: 'settings', key, payload: { value: 'x' }, deleted: false }])).status).toBe(200);
    }
    const prof = (payload: object) => ({ kind: 'profiles', key: 'p1', payload, deleted: false });
    expect((await post(A, [prof({ name: 'Léa', isKid: true, ageLimit: 2 })])).status).toBe(200);
    expect((await post(A, [prof({ name: 'Léa', pinHash: 'pbkdf2$x' })])).status).toBe(400);
    expect((await post(A, [prof({ name: 'Léa', locked: true })])).status).toBe(400);
  });

  it('accepte le type addons (blob opaque) côté serveur', async () => {
    const r = await post(A, [{ kind: 'addons', key: 'default', payload: { blob: 'AAAA' }, deleted: false }]);
    expect(r.status).toBe(200);
  });

  it('exige une session valide', async () => {
    expect((await get({})).status).toBe(401);
    expect((await post({ Authorization: 'Bearer faux' }, [])).status).toBe(401);
  });

  it('limite le débit par utilisateur', async () => {
    let last = 200;
    for (let i = 0; i < 121; i++) last = (await get(A, 0)).status;
    expect(last).toBe(429);
    expect((await get(B, 0)).status).toBe(200);
  });
});

describe('DELETE /account', () => {
  it('efface tout puis la session est refusée', async () => {
    await post(A, [lib('p|1'), lib('p|2')]);
    await post(B, [lib('p|b')]);
    await env.DB.prepare('INSERT INTO login_tokens (token_hash, user_id, expires_at, used) VALUES (?, ?, ?, 0)')
      .bind('h1', 'ua', 9_999_999_999)
      .run();
    const r = await call('/account', { method: 'DELETE', auth: A });
    expect(r.status).toBe(204);
    expect((await get(A, 0)).status).toBe(401);
    expect((await call('/me', { auth: A })).status).toBe(401);
    const count = async (sql: string) => (await env.DB.prepare(sql).first<{ n: number }>())!.n;
    expect(await count("SELECT COUNT(*) n FROM sync_items WHERE user_id = 'ua'")).toBe(0);
    expect(await count("SELECT COUNT(*) n FROM sync_state WHERE user_id = 'ua'")).toBe(0);
    expect(await count("SELECT COUNT(*) n FROM sessions WHERE user_id = 'ua'")).toBe(0);
    expect(await count("SELECT COUNT(*) n FROM login_tokens WHERE user_id = 'ua'")).toBe(0);
    expect(await count("SELECT COUNT(*) n FROM users WHERE id = 'ua'")).toBe(0);
    // L'autre utilisateur n'est pas touché.
    const b = (await (await get(B, 0)).json()) as { items: Item[] };
    expect(b.items).toHaveLength(1);
  });

  it('exige une session', async () => {
    expect((await call('/account', { method: 'DELETE' })).status).toBe(401);
  });
});
