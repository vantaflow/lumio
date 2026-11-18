import { env, runDurableObjectAlarm, runInDurableObject } from 'cloudflare:test';
import { beforeEach, describe, expect, it } from 'vitest';
import { createApp } from '../src/index';
import { parseClientMessage, type Room } from '../src/room';

let app: ReturnType<typeof createApp>;
let ipN = 0;
let ip = '1.1.1.1';

const req = (path: string, init: RequestInit = {}) =>
  app.request(path, { ...init, headers: { 'CF-Connecting-IP': ip, ...(init.headers as object) } }, env);

const roomStub = (id: string) =>
  (env.ROOMS as unknown as DurableObjectNamespace<Room>).get((env.ROOMS as unknown as DurableObjectNamespace<Room>).idFromName(id));

async function createRoom(body: unknown = {}) {
  const r = await req('/rooms', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  return { status: r.status, json: (await r.json()) as { roomId: string; inviteCode: string; hostKey: string; expiresAt: number } };
}

class Client {
  messages: any[] = [];
  closed: { code: number; reason: string } | null = null;
  private waiters: (() => void)[] = [];
  constructor(readonly ws: WebSocket) {
    ws.accept();
    ws.addEventListener('message', (e) => {
      this.messages.push(JSON.parse(e.data as string));
      this.wake();
    });
    ws.addEventListener('close', (e) => {
      this.closed = { code: e.code, reason: e.reason };
      this.wake();
    });
  }
  private wake() {
    for (const w of this.waiters.splice(0)) w();
  }
  async until(pred: () => boolean, ms = 3000) {
    const end = Date.now() + ms;
    while (!pred()) {
      if (Date.now() > end) throw new Error('délai dépassé');
      await new Promise<void>((res) => {
        this.waiters.push(res);
        setTimeout(res, 50);
      });
    }
  }
  async next(type: string) {
    await this.until(() => this.messages.some((m) => m.type === type));
    return this.messages.splice(this.messages.findIndex((m) => m.type === type), 1)[0];
  }
  send(o: unknown) {
    this.ws.send(typeof o === 'string' ? o : JSON.stringify(o));
  }
  async closedWith() {
    await this.until(() => this.closed !== null);
    return this.closed!;
  }
}

async function tryJoin(roomId: string, code: string, hostKey?: string | null) {
  const protocol = hostKey ? `lumio.v1, ${hostKey}` : 'lumio.v1';
  return req(`/room/${roomId}?code=${code}`, { headers: { Upgrade: 'websocket', 'Sec-WebSocket-Protocol': protocol } });
}

async function join(roomId: string, code: string, hostKey?: string) {
  const r = await tryJoin(roomId, code, hostKey);
  expect(r.status).toBe(101);
  const c = new Client(r.webSocket!);
  const hello = await c.next('hello');
  return { c, hello };
}

const st = (positionMs: number, playing: boolean) => ({ type: 'state', positionMs, playing, sentAt: Date.now() });

beforeEach(() => {
  ip = `10.1.0.${++ipN}`;
  app = createApp();
});

describe('création', () => {
  it('sans compte : id 128 bits, code à 8 caractères, clé d’hôte, expiration 6 h', async () => {
    const { status, json } = await createRoom({ metaId: 'tt0111161' });
    expect(status).toBe(201);
    expect(json.roomId).toMatch(/^[0-9a-f]{32}$/);
    expect(json.inviteCode).toMatch(/^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$/);
    expect(json.hostKey).toMatch(/^[0-9a-f]{32}$/);
    expect(json.expiresAt - Date.now()).toBeGreaterThan(5.9 * 3600 * 1000);
    expect(json.expiresAt - Date.now()).toBeLessThanOrEqual(6 * 3600 * 1000);
  });

  it('deux salles n’ont ni le même id, ni la même clé', async () => {
    const a = (await createRoom()).json;
    const b = (await createRoom()).json;
    expect(a.roomId).not.toBe(b.roomId);
    expect(a.hostKey).not.toBe(b.hostKey);
  });

  it('refuse un metaId invalide et ne stocke ni code ni clé en clair', async () => {
    expect((await createRoom({ metaId: 'x'.repeat(201) })).status).toBe(400);
    expect((await createRoom({ metaId: 42 })).status).toBe(400);
    const { json } = await createRoom();
    const stub = roomStub(json.roomId);
    const dump = await runInDurableObject(stub, async (_i, state) => JSON.stringify(await state.storage.get('meta')));
    expect(dump).not.toContain(json.inviteCode);
    expect(dump).not.toContain(json.hostKey);
  });

  it('limite les créations par IP', async () => {
    for (let i = 0; i < 10; i++) expect((await createRoom()).status).toBe(201);
    expect((await createRoom()).status).toBe(429);
    ip = `10.8.0.${++ipN}`; // une autre IP n’est pas touchée
    expect((await createRoom()).status).toBe(201);
  });
});

describe('connexion', () => {
  it('refuse sans WebSocket', async () => {
    const { json } = await createRoom();
    expect((await req(`/room/${json.roomId}?code=${json.inviteCode}`)).status).toBe(426);
  });

  it('refuse un mauvais code ou une salle inconnue avant d’accepter', async () => {
    const { json } = await createRoom();
    expect((await tryJoin(json.roomId, 'AAAAAAAA')).status).toBe(403);
    expect((await tryJoin(json.roomId, 'abc')).status).toBe(403);
    expect((await tryJoin('0'.repeat(32), json.inviteCode)).status).toBe(404);
    expect((await tryJoin('pas-un-id', json.inviteCode)).status).toBe(404);
  });

  it('bloque une IP après trop de codes invalides', async () => {
    const { json } = await createRoom();
    for (let i = 0; i < 20; i++) expect((await tryJoin(json.roomId, 'AAAAAAAA')).status).toBe(403);
    expect((await tryJoin(json.roomId, json.inviteCode)).status).toBe(429);
  });

  it('la clé de l’hôte n’est jamais lue dans l’URL', async () => {
    const { json } = await createRoom();
    const r = await req(`/room/${json.roomId}?code=${json.inviteCode}&hostKey=${json.hostKey}`, {
      headers: { Upgrade: 'websocket', 'Sec-WebSocket-Protocol': 'lumio.v1' },
    });
    expect(r.status).toBe(101);
    expect((await new Client(r.webSocket!).next('hello')).host).toBe(false); // simple invité
  });

  it('une mauvaise clé d’hôte donne un simple invité', async () => {
    const { json } = await createRoom();
    const r = await tryJoin(json.roomId, json.inviteCode, 'f'.repeat(32));
    expect(r.status).toBe(101);
    expect((await new Client(r.webSocket!).next('hello')).host).toBe(false);
  });

  it('la clé de l’hôte ouvre une connexion d’hôte', async () => {
    const { json } = await createRoom();
    const r = await tryJoin(json.roomId, json.inviteCode, json.hostKey);
    expect((await new Client(r.webSocket!).next('hello')).host).toBe(true);
  });
});

describe('diffusion', () => {
  it('relaie l’état de l’hôte aux autres seulement, avec le compte de participants', async () => {
    const { json } = await createRoom({ metaId: 'tt1' });
    const host = await join(json.roomId, json.inviteCode, json.hostKey);
    expect(host.hello.participants).toBe(1);
    expect(host.hello.metaId).toBe('tt1');
    const guest = await join(json.roomId, json.inviteCode);
    expect(guest.hello.participants).toBe(2);
    expect(guest.hello.host).toBe(false);
    expect((await host.c.next('join')).participants).toBe(2);

    host.c.send(st(5000, false));
    const got = await guest.c.next('state');
    expect(got).toMatchObject({ positionMs: 5000, playing: false });
    // L'émetteur ne reçoit pas son propre état (ping pour borner l'attente).
    host.c.send({ type: 'ping', sentAt: 1 });
    await host.c.next('pong');
    expect(host.c.messages.filter((m) => m.type === 'state')).toHaveLength(0);
  });

  it('ignore l’état d’un invité par défaut, l’accepte si l’hôte ouvre le contrôle', async () => {
    const { json } = await createRoom();
    const host = await join(json.roomId, json.inviteCode, json.hostKey);
    const guest = await join(json.roomId, json.inviteCode);
    guest.c.send(st(1000, true));
    guest.c.send({ type: 'ping', sentAt: 1 });
    await guest.c.next('pong');
    host.c.send({ type: 'ping', sentAt: 2 });
    await host.c.next('pong');
    expect(host.c.messages.filter((m) => m.type === 'state')).toHaveLength(0);

    const ctl = (key: string | null, v: boolean) =>
      req(`/room/${json.roomId}/control`, {
        method: 'POST',
        headers: { ...(key ? { Authorization: `Bearer ${key}` } : {}), 'content-type': 'application/json' },
        body: JSON.stringify({ allControl: v }),
      });
    expect((await ctl(null, true)).status).toBe(403);
    expect((await ctl('f'.repeat(32), true)).status).toBe(403);
    expect((await ctl(json.hostKey, true)).status).toBe(204);
    expect((await guest.c.next('control')).allControl).toBe(true);
    guest.c.send(st(2000, true));
    expect(await host.c.next('state')).toMatchObject({ positionMs: 2000, playing: true });
  });

  it('un retardataire reçoit la position courante (avance si lecture en cours)', async () => {
    const { json } = await createRoom();
    const host = await join(json.roomId, json.inviteCode, json.hostKey);
    host.c.send(st(10_000, true));
    host.c.send({ type: 'ping', sentAt: 1 });
    await host.c.next('pong');
    await new Promise((r) => setTimeout(r, 200));
    const late = await join(json.roomId, json.inviteCode);
    expect(late.hello.state.playing).toBe(true);
    expect(late.hello.state.positionMs).toBeGreaterThanOrEqual(10_150);
    expect(late.hello.state.positionMs).toBeLessThan(11_500);
  });

  it('9e participant refusé (409), place libérée au départ', async () => {
    const { json } = await createRoom();
    const clients = [await join(json.roomId, json.inviteCode, json.hostKey)];
    for (let i = 1; i < 8; i++) {
      clients.push(await join(json.roomId, json.inviteCode));
    }
    expect((await tryJoin(json.roomId, json.inviteCode)).status).toBe(409);
    clients[7].c.send({ type: 'leave', sentAt: 1 });
    expect((await clients[0].c.next('leave')).participants).toBe(7);
    expect((await tryJoin(json.roomId, json.inviteCode)).status).toBe(101);
  });

  it('la salle se ferme quand elle se vide', async () => {
    const { json } = await createRoom();
    const host = await join(json.roomId, json.inviteCode, json.hostKey);
    host.c.send({ type: 'leave', sentAt: 1 });
    await host.c.closedWith();
    expect((await tryJoin(json.roomId, json.inviteCode)).status).toBe(404);
  });

  it('la salle expirée est fermée par l’alarme', async () => {
    const { json } = await createRoom();
    const host = await join(json.roomId, json.inviteCode, json.hostKey);
    const stub = roomStub(json.roomId);
    await runInDurableObject(stub, async (_i, state) => {
      const m = (await state.storage.get('meta')) as { expiresAt: number };
      await state.storage.put('meta', { ...m, expiresAt: Date.now() - 1 });
    });
    await runInDurableObject(stub, (i: Room) => {
      (i as unknown as { meta: unknown }).meta = undefined;
    });
    await runDurableObjectAlarm(stub);
    expect((await host.c.closedWith()).code).toBe(1000);
    expect((await tryJoin(json.roomId, json.inviteCode)).status).toBe(404);
  });
});

describe('abus', () => {
  it('coupe un client au-delà de 20 messages par seconde (1008)', async () => {
    const { json } = await createRoom();
    const host = await join(json.roomId, json.inviteCode, json.hostKey);
    for (let i = 0; i < 40; i++) host.c.send({ type: 'ping', sentAt: i });
    expect((await host.c.closedWith()).code).toBe(1008);
  });

  it.each([
    ['json cassé', '{pas du json'],
    ['type inconnu', JSON.stringify({ type: 'chat', sentAt: 1 })],
    ['position négative', JSON.stringify({ type: 'state', positionMs: -1, playing: true, sentAt: 1 })],
    ['position non entière', JSON.stringify({ type: 'state', positionMs: 1.5, playing: true, sentAt: 1 })],
    ['playing absent', JSON.stringify({ type: 'state', positionMs: 1, sentAt: 1 })],
    ['clé supplémentaire (url)', JSON.stringify({ type: 'state', positionMs: 1, playing: true, sentAt: 1, url: 'http://x' })],
    ['tableau', '[]'],
  ])('ferme sur message invalide : %s', async (_n, payload) => {
    const { json } = await createRoom();
    const host = await join(json.roomId, json.inviteCode, json.hostKey);
    host.c.send(payload);
    expect((await host.c.closedWith()).code).toBe(1007);
  });

  it('ferme sur message trop gros (1009) et sur binaire (1003)', async () => {
    const { json } = await createRoom();
    const a = await join(json.roomId, json.inviteCode, json.hostKey);
    a.c.send(JSON.stringify({ type: 'ping', sentAt: 1, pad: 'x'.repeat(1100) }));
    expect((await a.c.closedWith()).code).toBe(1009);
    const { json: j2 } = await createRoom();
    const b = await join(j2.roomId, j2.inviteCode);
    b.c.ws.send(new Uint8Array([1, 2, 3]));
    expect((await b.c.closedWith()).code).toBe(1003);
  });
});

describe('correctifs round 1', () => {
  it('type de média : liste blanche, renvoyé dans hello', async () => {
    expect((await createRoom({ type: 'podcast' })).status).toBe(400);
    expect((await createRoom({ type: 5 })).status).toBe(400);
    const { json } = await createRoom({ metaId: 'tt1', type: 'series' });
    const host = await join(json.roomId, json.inviteCode, json.hostKey);
    expect(host.hello.mediaType).toBe('series');
    expect((await join(json.roomId, json.inviteCode)).hello.mediaType).toBe('series');
  });

  it('compteur d’échecs par salle : fenêtre glissante, pas de salle brûlée', async () => {
    const { json } = await createRoom();
    const stub = roomStub(json.roomId);
    const setFail = (failures: number, since: number) =>
      runInDurableObject(stub, async (i: Room) => {
        const m = (await (i as any).load()) as { failures: number; failuresSince: number };
        m.failures = failures;
        m.failuresSince = since;
      });
    // Fenêtre expirée : le compteur repart de zéro, la salle survit.
    await setFail(10_000, Date.now() - 11 * 60 * 1000);
    ip = `10.9.0.${++ipN}`;
    expect((await tryJoin(json.roomId, 'AAAAAAAA')).status).toBe(403);
    ip = `10.9.0.${++ipN}`;
    expect((await tryJoin(json.roomId, json.inviteCode)).status).toBe(101);
  });

  it('au plafond de la fenêtre courante, la salle est détruite', async () => {
    const { json } = await createRoom();
    await runInDurableObject(roomStub(json.roomId), async (i: Room) => {
      const m = (await (i as any).load()) as { failures: number; failuresSince: number };
      m.failures = 199;
      m.failuresSince = Date.now();
    });
    expect((await tryJoin(json.roomId, 'AAAAAAAA')).status).toBe(403);
    ip = `10.9.1.${++ipN}`;
    expect((await tryJoin(json.roomId, json.inviteCode)).status).toBe(404);
  });

  it('un invité sans droit reçoit control_denied une seule fois', async () => {
    const { json } = await createRoom();
    await join(json.roomId, json.inviteCode, json.hostKey);
    const guest = await join(json.roomId, json.inviteCode);
    guest.c.send(st(1000, true));
    guest.c.send(st(2000, true));
    guest.c.send({ type: 'ping', sentAt: 1 });
    await guest.c.next('pong');
    expect(guest.c.messages.filter((m) => m.type === 'control_denied')).toHaveLength(1);
  });

  it('un message après expiration ferme le socket', async () => {
    const { json } = await createRoom();
    const host = await join(json.roomId, json.inviteCode, json.hostKey);
    await runInDurableObject(roomStub(json.roomId), async (i: Room) => {
      const m = (await (i as any).load()) as { expiresAt: number };
      m.expiresAt = Date.now() - 1;
    });
    host.c.send({ type: 'ping', sentAt: 1 });
    expect((await host.c.closedWith()).code).toBe(1000);
  });
});

describe('parseClientMessage', () => {
  it('accepte les messages bien formés', () => {
    expect(parseClientMessage('{"type":"state","positionMs":10,"playing":true,"sentAt":5}')).not.toBeNull();
    expect(parseClientMessage('{"type":"ping","sentAt":5}')).not.toBeNull();
    expect(parseClientMessage('{"type":"leave","sentAt":5}')).not.toBeNull();
    expect(parseClientMessage('{"type":"join","positionMs":0,"playing":false,"sentAt":0}')).not.toBeNull();
  });
  it('refuse les bornes dépassées', () => {
    expect(parseClientMessage('{"type":"state","positionMs":999999999999,"playing":true,"sentAt":5}')).toBeNull();
    expect(parseClientMessage('{"type":"ping","sentAt":-1}')).toBeNull();
    expect(parseClientMessage('{"type":"ping","sentAt":"1"}')).toBeNull();
  });
});
