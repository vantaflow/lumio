import { env } from 'cloudflare:workers';
import { beforeEach, describe, expect, it } from 'vitest';
import { createApp } from '../src/index';
import { PAIR_ALPHABET, generateCode } from '../src/pair';

let now = 1_800_000_000_000;
let app: ReturnType<typeof createApp>;
let ipN = 0;
let ip = '1.1.1.1';

const req = (path: string, init: RequestInit = {}) =>
  app.request(path, { ...init, headers: { 'CF-Connecting-IP': ip, ...(init.headers as object) } }, env);
const json = (b: unknown) => ({
  method: 'POST',
  body: JSON.stringify(b),
  headers: { 'content-type': 'application/json' },
});
const create = async () =>
  (await (await req('/pair', { method: 'POST' })).json()) as { code: string; pollToken: string; expiresIn: number };
const poll = (code: string, token: string) => req(`/pair/${code}`, { headers: { Authorization: `Bearer ${token}` } });

beforeEach(async () => {
  now = 1_800_000_000_000;
  ip = `10.0.0.${++ipN}`;
  app = createApp({ now: () => now });
  await env.DB.prepare('DELETE FROM pairings').run();
});

describe('appairage', () => {
  it('crée un code de 6 caractères sans 0/O/1/I/L', async () => {
    const s = await create();
    expect(s.code).toMatch(/^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$/);
    expect(s.expiresIn).toBe(300);
    expect(s.pollToken.length).toBeGreaterThan(30);
    for (let i = 0; i < 200; i++) expect(generateCode()).toMatch(/^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$/);
  });

  it('ne stocke que des hachages', async () => {
    const s = await create();
    await req(`/pair/${s.code}`, json({ payload: 'https://x.example/manifest.json' }));
    const rows = await env.DB.prepare('SELECT * FROM pairings').all<Record<string, unknown>>();
    expect(rows.results).toHaveLength(1);
    const dump = JSON.stringify(rows.results);
    expect(dump).not.toContain(s.code);
    expect(dump).not.toContain(s.pollToken);
    expect(rows.results[0].code_hash).toMatch(/^[0-9a-f]{64}$/);
  });

  it('payload posté, lu une seule fois, 2e lecture -> 410', async () => {
    const s = await create();
    expect((await poll(s.code, s.pollToken)).status).toBe(204);
    const post = await req(`/pair/${s.code}`, json({ payload: 'https://x.example/manifest.json' }));
    expect(post.status).toBe(204);
    const r = await poll(s.code, s.pollToken);
    expect(r.status).toBe(200);
    expect(await r.json()).toEqual({ payload: 'https://x.example/manifest.json' });
    expect((await poll(s.code, s.pollToken)).status).toBe(410);
    // Le contenu est effacé de la base après lecture.
    const row = await env.DB.prepare('SELECT payload FROM pairings').first<{ payload: string | null }>();
    expect(row!.payload).toBeNull();
  });

  it('le code est à usage unique côté téléphone', async () => {
    const s = await create();
    expect((await req(`/pair/${s.code}`, json({ payload: 'a' }))).status).toBe(204);
    expect((await req(`/pair/${s.code}`, json({ payload: 'b' }))).status).toBe(404);
    expect(await (await poll(s.code, s.pollToken)).json()).toEqual({ payload: 'a' });
    expect((await req(`/pair/${s.code}`, json({ payload: 'c' }))).status).toBe(404);
  });

  it('code expiré après 301 s -> 410 (télé) et 404 (téléphone)', async () => {
    const s = await create();
    now += 301_000;
    expect((await poll(s.code, s.pollToken)).status).toBe(410);
    expect((await req(`/pair/${s.code}`, json({ payload: 'a' }))).status).toBe(404);
  });

  it('payload de 9 Ko -> 413 ; 8 Ko accepté', async () => {
    const s = await create();
    expect((await req(`/pair/${s.code}`, json({ payload: 'a'.repeat(9 * 1024) }))).status).toBe(413);
    expect((await req(`/pair/${s.code}`, json({ payload: 'a'.repeat(8 * 1024) }))).status).toBe(204);
  });

  it('refuse un corps invalide (400)', async () => {
    const s = await create();
    expect((await req(`/pair/${s.code}`, json({ payload: 5 }))).status).toBe(400);
    expect((await req(`/pair/${s.code}`, { method: 'POST', body: 'x', headers: { 'content-type': 'application/json' } })).status).toBe(400);
  });

  it('seule la télé qui a créé le code peut lire (jeton)', async () => {
    const s = await create();
    await req(`/pair/${s.code}`, json({ payload: 'secret' }));
    expect((await req(`/pair/${s.code}`)).status).toBe(404);
    expect((await poll(s.code, 'faux')).status).toBe(404);
    expect((await poll(s.code, s.pollToken)).status).toBe(200);
  });

  it('code inconnu ou mal formé : même 404', async () => {
    const a = await req('/pair/ABCDEF', json({ payload: 'a' }));
    const b = await req('/pair/!!', json({ payload: 'a' }));
    expect(a.status).toBe(404);
    expect(b.status).toBe(404);
    expect(await a.text()).toBe(await b.text());
  });

  it('limite la création à 10 par minute et par IP', async () => {
    for (let i = 0; i < 10; i++) expect((await req('/pair', { method: 'POST' })).status).toBe(201);
    const r = await req('/pair', { method: 'POST' });
    expect(r.status).toBe(429);
    expect(r.headers.get('Retry-After')).toBeTruthy();
    ip = '9.9.9.9';
    expect((await req('/pair', { method: 'POST' })).status).toBe(201);
    now += 61_000;
    ip = `10.0.0.${ipN}`;
    expect((await req('/pair', { method: 'POST' })).status).toBe(201);
  });

  it('anti force brute : 30 recherches ratées par minute -> 429', async () => {
    const s = await create();
    const guess = (i: number) => `/pair/${PAIR_ALPHABET[i % 31]}${PAIR_ALPHABET[(i * 7) % 31]}AAAA`;
    for (let i = 0; i < 30; i++) expect((await req(guess(i), json({ payload: 'a' }))).status).toBe(404);
    expect((await req(guess(31), json({ payload: 'a' }))).status).toBe(429);
    // Même avec le bon code, la même IP reste bloquée ; une autre IP non.
    expect((await req(`/pair/${s.code}`, json({ payload: 'a' }))).status).toBe(429);
    ip = '8.8.8.8';
    expect((await req(`/pair/${s.code}`, json({ payload: 'a' }))).status).toBe(204);
  });

  it("l'interrogation normale toutes les 2 s n'est pas bloquée", async () => {
    const s = await create();
    for (let i = 0; i < 25; i++) expect((await poll(s.code, s.pollToken)).status).toBe(204);
  });
});

describe('page compagnon', () => {
  it('sert un formulaire sans ressource externe, CSP stricte', async () => {
    const r = await req('/p/abcdef');
    expect(r.status).toBe(200);
    expect(r.headers.get('content-security-policy')).toBe(
      "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
    );
    const html = await r.text();
    expect(html).toContain('action="/pair/ABCDEF"');
    expect(html).toContain('Envoyer');
    expect(html).not.toMatch(/<script|src=|https?:\/\//);
  });

  it('refuse un code mal formé sans reflet', async () => {
    const r = await req('/p/%3Cscript%3E');
    expect(r.status).toBe(404);
    expect(await r.text()).not.toContain('<script>alert');
  });

  it('formulaire : succès, puis expiré, sans reflet du contenu', async () => {
    const s = await create();
    const form = (v: string) => ({
      method: 'POST',
      body: new URLSearchParams({ payload: v }).toString(),
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
    });
    const ok = await req(`/pair/${s.code}`, form('<b>https://x.example/m.json</b>'));
    expect(ok.status).toBe(200);
    const html = await ok.text();
    expect(html).toContain('Envoyé');
    expect(html).not.toContain('x.example');
    expect(await (await poll(s.code, s.pollToken)).json()).toEqual({ payload: '<b>https://x.example/m.json</b>' });
    const again = await req(`/pair/${s.code}`, form('y'));
    expect(again.status).toBe(404);
    expect(await again.text()).toContain('expiré');
  });
});
