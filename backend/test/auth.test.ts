import { env } from 'cloudflare:workers';
import { beforeEach, describe, expect, it } from 'vitest';
import { createApp } from '../src/index';
import { LogEmailSender, maskEmail } from '../src/email';

let now = 1_800_000_000_000;
let sender: LogEmailSender;
let app: ReturnType<typeof createApp>;

const post = (path: string, body: unknown) =>
  app.request(path, { method: 'POST', body: JSON.stringify(body), headers: { 'content-type': 'application/json' } }, env);

const tokenFromMail = () => /\n\n(\S+)\n\n/.exec(sender.last!.body)![1];

async function login(email: string) {
  expect((await post('/auth/request', { email })).status).toBe(202);
  const res = await post('/auth/verify', { token: tokenFromMail() });
  expect(res.status).toBe(200);
  return (await res.json()) as { session: string; refresh: string; expiresIn: number };
}

beforeEach(async () => {
  now = 1_800_000_000_000;
  sender = new LogEmailSender();
  app = createApp({ now: () => now, email: sender });
  await env.DB.batch([
    env.DB.prepare('DELETE FROM sessions'),
    env.DB.prepare('DELETE FROM login_tokens'),
    env.DB.prepare('DELETE FROM users'),
  ]);
});

describe('lien magique', () => {
  it('request puis verify ouvre une session', async () => {
    const s = await login('karim@example.com');
    expect(s.expiresIn).toBe(3600);
    const me = await app.request('/me', { headers: { Authorization: `Bearer ${s.session}` } }, env);
    expect(me.status).toBe(200);
  });

  it('ne stocke que le hachage du jeton', async () => {
    await post('/auth/request', { email: 'karim@example.com' });
    const token = tokenFromMail();
    const rows = await env.DB.prepare('SELECT token_hash FROM login_tokens').all<{ token_hash: string }>();
    expect(rows.results).toHaveLength(1);
    expect(rows.results[0].token_hash).not.toBe(token);
    expect(rows.results[0].token_hash).toMatch(/^[0-9a-f]{64}$/);
  });

  it('refuse un jeton rejoué', async () => {
    await post('/auth/request', { email: 'a@example.com' });
    const token = tokenFromMail();
    expect((await post('/auth/verify', { token })).status).toBe(200);
    expect((await post('/auth/verify', { token })).status).toBe(401);
  });

  it('refuse un jeton expiré (+16 min)', async () => {
    await post('/auth/request', { email: 'a@example.com' });
    now += 16 * 60 * 1000;
    expect((await post('/auth/verify', { token: tokenFromMail() })).status).toBe(401);
  });

  it('refuse un jeton inconnu et une adresse invalide', async () => {
    expect((await post('/auth/verify', { token: 'nope' })).status).toBe(401);
    expect((await post('/auth/request', { email: 'pas-un-email' })).status).toBe(400);
  });

  it('réutilise le même compte pour la même adresse (casse ignorée)', async () => {
    await login('Karim@Example.com');
    await login('karim@example.com');
    const n = await env.DB.prepare('SELECT COUNT(*) AS n FROM users').first<{ n: number }>();
    expect(n!.n).toBe(1);
  });
});

describe('limitation de débit', () => {
  it('la 6e demande en 60 s pour le même e-mail reçoit 429', async () => {
    for (let i = 0; i < 5; i++) {
      expect((await post('/auth/request', { email: 'rl@example.com' })).status).toBe(202);
    }
    const sixth = await post('/auth/request', { email: 'rl@example.com' });
    expect(sixth.status).toBe(429);
    expect(sixth.headers.get('Retry-After')).toBeTruthy();
    // un autre e-mail n'est pas affecté
    expect((await post('/auth/request', { email: 'autre@example.com' })).status).toBe(202);
  });

  it('la fenêtre suivante est de nouveau ouverte', async () => {
    for (let i = 0; i < 6; i++) await post('/auth/request', { email: 'rl@example.com' });
    now += 61_000;
    expect((await post('/auth/request', { email: 'rl@example.com' })).status).toBe(202);
  });
});

describe('limitation par IP et jetons trop longs', () => {
  it('la 21e demande par IP en une heure reçoit 429, même avec des e-mails différents', async () => {
    const req = (i: number) =>
      app.request(
        '/auth/request',
        {
          method: 'POST',
          body: JSON.stringify({ email: `ip${i}@example.com` }),
          headers: { 'content-type': 'application/json', 'cf-connecting-ip': '203.0.113.9' },
        },
        env,
      );
    for (let i = 0; i < 20; i++) expect((await req(i)).status).toBe(202);
    const res = await req(20);
    expect(res.status).toBe(429);
    expect(res.headers.get('Retry-After')).toBeTruthy();
  });

  it('refuse un jeton de plus de 512 caractères (verify et refresh)', async () => {
    const long = 'a'.repeat(513);
    expect((await post('/auth/verify', { token: long })).status).toBe(400);
    expect((await post('/auth/refresh', { refresh: long })).status).toBe(400);
  });
});

describe('session et rafraîchissement', () => {
  it('route protégée sans Bearer ou avec un faux jeton -> 401', async () => {
    expect((await app.request('/me', {}, env)).status).toBe(401);
    expect((await app.request('/me', { headers: { Authorization: 'Bearer faux' } }, env)).status).toBe(401);
  });

  it('la session expire après 3600 s', async () => {
    const s = await login('a@example.com');
    now += 3601 * 1000;
    expect((await app.request('/me', { headers: { Authorization: `Bearer ${s.session}` } }, env)).status).toBe(401);
  });

  it('refresh émet une nouvelle session et révoque l’ancienne (rotation)', async () => {
    const s = await login('a@example.com');
    now += 3601 * 1000;
    const res = await post('/auth/refresh', { refresh: s.refresh });
    expect(res.status).toBe(200);
    const n = (await res.json()) as { session: string; refresh: string };
    expect((await app.request('/me', { headers: { Authorization: `Bearer ${n.session}` } }, env)).status).toBe(200);
    expect((await post('/auth/refresh', { refresh: s.refresh })).status).toBe(401);
  });

  it('refresh expiré après 30 jours -> 401', async () => {
    const s = await login('a@example.com');
    now += 31 * 24 * 3600 * 1000;
    expect((await post('/auth/refresh', { refresh: s.refresh })).status).toBe(401);
  });
});

describe('e-mail', () => {
  it('masque l’adresse', () => {
    expect(maskEmail('karim@example.com')).toBe('k***@example.com');
  });
});
