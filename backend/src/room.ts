import { DurableObject } from 'cloudflare:workers';
import { Hono, type Context } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { requireUser, userIdForSession } from './auth';
import { sha256Hex } from './crypto';
import { PAIR_ALPHABET, generateCode } from './pair';
import { rateBlocked, rateLimit } from './rate';
import type { AppEnv, Bindings } from './types';

export const ROOM_MAX_PARTICIPANTS = 8;
export const ROOM_TTL_MS = 6 * 3600 * 1000;
export const ROOM_CODE_LENGTH = 8;
export const ROOM_MAX_MESSAGE_BYTES = 1024;
export const ROOM_AUTH_TIMEOUT_MS = 5000;
export const ROOM_MSG_PER_SEC = 20;
export const ROOM_MAX_CODE_FAILURES = 200; // par fenêtre ; le plafond principal est par IP
export const ROOM_FAILURE_WINDOW_MS = 10 * 60 * 1000;
export const ROOM_TYPES = ['movie', 'series', 'channel', 'tv'] as const;
const LAST_PERSIST_MS = 1000;
export const ROOM_PROTOCOL = 'lumio.v1';
export const CREATE_LIMIT = 10; // salles par heure et par utilisateur
export const JOIN_FAIL_LIMIT = 20; // refus de code par minute et par IP
const MAX_POSITION_MS = 48 * 3600 * 1000;
const MAX_META_ID = 200;

const ID_RE = /^[0-9a-f]{32}$/;
const CODE_RE = new RegExp(`^[${PAIR_ALPHABET}]{${ROOM_CODE_LENGTH}}$`);

// --- Validation des messages (exportée pour les tests) ---------------------

export type ClientMessage =
  | { type: 'state' | 'join'; positionMs: number; playing: boolean; sentAt: number }
  | { type: 'ping' | 'leave'; sentAt: number; positionMs?: number; playing?: boolean };

/**
 * Valide un message client : objet JSON strict (aucune clé inconnue, donc
 * aucune URL ni titre ne peut transiter), types et bornes contrôlés.
 * Renvoie null si le message est refusé.
 */
export function parseClientMessage(raw: string): ClientMessage | null {
  if (new TextEncoder().encode(raw).length > ROOM_MAX_MESSAGE_BYTES) return null;
  let v: unknown;
  try {
    v = JSON.parse(raw);
  } catch {
    return null;
  }
  if (!v || typeof v !== 'object' || Array.isArray(v)) return null;
  const o = v as Record<string, unknown>;
  for (const k of Object.keys(o)) {
    if (k !== 'type' && k !== 'positionMs' && k !== 'playing' && k !== 'sentAt') return null;
  }
  const type = o.type;
  if (type !== 'state' && type !== 'join' && type !== 'ping' && type !== 'leave') return null;
  const sentAt = o.sentAt;
  if (typeof sentAt !== 'number' || !Number.isSafeInteger(sentAt) || sentAt < 0) return null;
  const needsState = type === 'state' || type === 'join';
  if (o.positionMs !== undefined || needsState) {
    const p = o.positionMs;
    if (typeof p !== 'number' || !Number.isSafeInteger(p) || p < 0 || p > MAX_POSITION_MS) return null;
  }
  if (o.playing !== undefined || needsState) {
    if (typeof o.playing !== 'boolean') return null;
  }
  return o as unknown as ClientMessage;
}

// --- Durable Object ---------------------------------------------------------

interface RoomMeta {
  hostId: string;
  codeHash: string;
  expiresAt: number;
  metaId: string | null;
  type: string | null;
  allControl: boolean;
  everJoined: boolean;
  failures: number;
  failuresSince: number;
  last: { positionMs: number; playing: boolean; at: number } | null;
}

interface Attachment {
  uid: string | null; // null : en attente du premier message d'authentification
  deadline: number; // échéance d'authentification (ms)
  tokens: number; // seau à jetons (limite de débit)
  ts: number;
  denied?: boolean; // control_denied déjà envoyé
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/**
 * Une salle de watch-party. Seuls position et état de lecture y transitent.
 * API d'hibernation : les sockets survivent à l'éviction de l'objet, l'état
 * par socket est dans l'attachement.
 */
export class Room extends DurableObject<Bindings> {
  /** Délai d'authentification par premier message (modifiable en test). */
  authTimeoutMs = ROOM_AUTH_TIMEOUT_MS;
  private meta: RoomMeta | null | undefined;
  private gone = new WeakSet<WebSocket>();
  private lastPersistedAt = 0;

  private async load(): Promise<RoomMeta | null> {
    if (this.meta === undefined) {
      const m = (await this.ctx.storage.get<RoomMeta>('meta')) ?? null;
      if (m) m.last = (await this.ctx.storage.get<RoomMeta['last']>('last')) ?? m.last;
      this.meta = m;
    }
    return this.meta;
  }

  private async save(m: RoomMeta) {
    this.meta = m;
    // `last` change à chaque message : clé séparée, écrite au plus 1 fois/s.
    const { last: _last, ...rest } = m;
    await this.ctx.storage.put('meta', { ...rest, last: null });
  }

  /** Appelé une seule fois par le Worker à la création. */
  async init(
    hostId: string,
    codeHash: string,
    expiresAt: number,
    metaId: string | null,
    type: string | null = null,
  ) {
    if (await this.load()) return;
    await this.save({
      hostId,
      codeHash,
      expiresAt,
      metaId,
      type,
      allControl: false,
      everJoined: false,
      failures: 0,
      failuresSince: 0,
      last: null,
    });
    await this.ctx.storage.setAlarm(expiresAt);
  }

  /** Bascule « Tout le monde peut contrôler » ; réservée à l'hôte. */
  async setControl(userId: string, allControl: boolean): Promise<'ok' | 'forbidden' | 'gone'> {
    const m = await this.load();
    if (!m || Date.now() >= m.expiresAt) return 'gone';
    if (m.hostId !== userId) return 'forbidden';
    m.allControl = allControl;
    await this.save(m);
    this.broadcast({ type: 'control', allControl }, null);
    return 'ok';
  }

  async fetch(request: Request): Promise<Response> {
    const m = await this.load();
    if (!m || Date.now() >= m.expiresAt) return Response.json({ error: 'Salle inconnue ou expirée' }, { status: 404 });
    if (request.headers.get('Upgrade')?.toLowerCase() !== 'websocket') {
      return Response.json({ error: 'WebSocket requis' }, { status: 426 });
    }
    const code = request.headers.get('x-room-code') ?? '';
    if (!timingSafeEqual(await sha256Hex(code), m.codeHash)) {
      const t = Date.now();
      if (t - m.failuresSince > ROOM_FAILURE_WINDOW_MS) {
        m.failuresSince = t;
        m.failures = 0;
      }
      m.failures += 1;
      if (m.failures >= ROOM_MAX_CODE_FAILURES) {
        await this.destroy(1008, 'Trop de codes invalides');
      } else {
        await this.save(m);
      }
      return Response.json({ error: 'Code d’invitation invalide' }, { status: 403 });
    }
    const open = this.openSockets();
    if (open.length >= ROOM_MAX_PARTICIPANTS) {
      return Response.json({ error: 'Salle pleine' }, { status: 409 });
    }
    const uid = request.headers.get('x-room-user') || null;
    const pair = new WebSocketPair();
    const [client, server] = [pair[0], pair[1]];
    const att: Attachment = {
      uid,
      deadline: Date.now() + this.authTimeoutMs,
      tokens: ROOM_MSG_PER_SEC,
      ts: Date.now(),
    };
    this.ctx.acceptWebSocket(server);
    server.serializeAttachment(att);
    if (uid) await this.onAuthenticated(server, uid);
    else await this.scheduleAlarm();
    const headers = new Headers();
    if (request.headers.get('x-room-protocol') === '1') headers.set('Sec-WebSocket-Protocol', ROOM_PROTOCOL);
    return new Response(null, { status: 101, webSocket: client, headers });
  }

  private openSockets(): WebSocket[] {
    return this.ctx.getWebSockets().filter((w) => w.readyState === 1 && !this.gone.has(w));
  }

  private participants(): number {
    return this.openSockets().filter((w) => (w.deserializeAttachment() as Attachment | null)?.uid).length;
  }

  private send(ws: WebSocket, msg: unknown) {
    try {
      ws.send(JSON.stringify(msg));
    } catch {
      // socket déjà fermé
    }
  }

  private broadcast(msg: unknown, except: WebSocket | null) {
    for (const w of this.openSockets()) {
      if (w === except) continue;
      if (!(w.deserializeAttachment() as Attachment | null)?.uid) continue;
      this.send(w, msg);
    }
  }

  private snapshot(m: RoomMeta, ws: WebSocket, uid: string) {
    let state: { positionMs: number; playing: boolean; sentAt: number } | null = null;
    if (m.last) {
      const age = Math.max(0, Date.now() - m.last.at);
      state = {
        positionMs: Math.min(MAX_POSITION_MS, m.last.positionMs + (m.last.playing ? age : 0)),
        playing: m.last.playing,
        sentAt: Date.now(),
      };
    }
    return {
      type: 'hello',
      participants: this.participants(),
      host: uid === m.hostId,
      allControl: m.allControl,
      metaId: m.metaId,
      mediaType: m.type,
      expiresAt: m.expiresAt,
      state,
    };
  }

  private async onAuthenticated(ws: WebSocket, uid: string) {
    const m = (await this.load())!;
    const att = ws.deserializeAttachment() as Attachment;
    ws.serializeAttachment({ ...att, uid });
    if (!m.everJoined) {
      m.everJoined = true;
      await this.save(m);
    }
    this.send(ws, this.snapshot(m, ws, uid));
    this.broadcast({ type: 'join', participants: this.participants() }, ws);
    await this.scheduleAlarm();
  }

  private async scheduleAlarm() {
    const m = await this.load();
    if (!m) return;
    let next = m.expiresAt;
    for (const w of this.openSockets()) {
      const a = w.deserializeAttachment() as Attachment | null;
      if (a && !a.uid) next = Math.min(next, a.deadline);
    }
    await this.ctx.storage.setAlarm(Math.max(next, Date.now() + 1));
  }

  async alarm() {
    const m = await this.load();
    if (!m) return;
    const now = Date.now();
    if (now >= m.expiresAt) {
      await this.destroy(1000, 'Salle expirée');
      return;
    }
    for (const w of this.openSockets()) {
      const a = w.deserializeAttachment() as Attachment | null;
      if (a && !a.uid && a.deadline <= now) await this.drop(w, 1008, 'Authentification requise');
    }
    await this.scheduleAlarm();
  }

  /** Ferme tout et efface la salle. */
  private async destroy(code: number, reason: string) {
    for (const w of this.ctx.getWebSockets()) {
      this.gone.add(w);
      try {
        w.close(code, reason);
      } catch {
        // déjà fermé
      }
    }
    this.meta = null;
    await this.ctx.storage.deleteAlarm();
    await this.ctx.storage.deleteAll();
  }

  /** Ferme un socket du côté serveur et traite son départ. */
  private async drop(ws: WebSocket, code: number, reason: string) {
    const wasKnown = !this.gone.has(ws);
    const uid = (ws.deserializeAttachment() as Attachment | null)?.uid;
    this.gone.add(ws);
    try {
      ws.close(code, reason);
    } catch {
      // déjà fermé
    }
    if (wasKnown) await this.afterDeparture(!!uid);
  }

  private async afterDeparture(wasAuthenticated: boolean) {
    const m = await this.load();
    if (!m) return;
    if (m.everJoined && this.openSockets().length === 0) {
      await this.destroy(1000, 'Salle vide');
      return;
    }
    if (wasAuthenticated) this.broadcast({ type: 'leave', participants: this.participants() }, null);
  }

  async webSocketClose(ws: WebSocket) {
    if (this.gone.has(ws)) return;
    const uid = (ws.deserializeAttachment() as Attachment | null)?.uid;
    this.gone.add(ws);
    try {
      ws.close(1000, 'bye');
    } catch {
      // déjà fermé
    }
    await this.afterDeparture(!!uid);
  }

  async webSocketError(ws: WebSocket) {
    await this.webSocketClose(ws);
  }

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer) {
    if (this.gone.has(ws)) return;
    const att = ws.deserializeAttachment() as Attachment | null;
    if (!att) return this.drop(ws, 1008, 'Session inconnue');
    if (typeof message !== 'string') return this.drop(ws, 1003, 'Texte uniquement');
    if (new TextEncoder().encode(message).length > ROOM_MAX_MESSAGE_BYTES) {
      return this.drop(ws, 1009, 'Message trop gros');
    }
    // Seau à jetons : 20 messages par seconde et par client.
    const now = Date.now();
    const tokens = Math.min(ROOM_MSG_PER_SEC, att.tokens + ((now - att.ts) / 1000) * ROOM_MSG_PER_SEC);
    if (tokens < 1) return this.drop(ws, 1008, 'Trop de messages');
    const next: Attachment = { ...att, tokens: tokens - 1, ts: now };
    ws.serializeAttachment(next);

    const m = await this.load();
    if (!m) return;
    if (now >= m.expiresAt) {
      await this.destroy(1000, 'Salle expirée');
      return;
    }

    if (!att.uid) {
      // Premier message : {"type":"auth","token":"…"} dans le délai imparti.
      let token = '';
      try {
        const v = JSON.parse(message) as { type?: unknown; token?: unknown };
        if (v.type === 'auth' && typeof v.token === 'string') token = v.token;
      } catch {
        // refusé ci-dessous
      }
      const uid = token && now <= att.deadline ? await userIdForSession(this.env.DB, token, Math.floor(now / 1000)) : null;
      if (!uid) return this.drop(ws, 1008, 'Authentification requise');
      await this.onAuthenticated(ws, uid);
      return;
    }

    const msg = parseClientMessage(message);
    if (!msg) return this.drop(ws, 1007, 'Message invalide');
    switch (msg.type) {
      case 'ping':
        this.send(ws, { type: 'pong', sentAt: msg.sentAt });
        return;
      case 'leave':
        await this.drop(ws, 1000, 'bye');
        return;
      case 'join':
        // Re-synchronisation à la demande : renvoie la position courante.
        this.send(ws, this.snapshot(m, ws, att.uid));
        return;
      case 'state': {
        // Seul l'hôte contrôle, sauf si « tout le monde peut contrôler ».
        if (att.uid !== m.hostId && !m.allControl) {
          if (!att.denied) {
            ws.serializeAttachment({ ...next, denied: true });
            this.send(ws, { type: 'control_denied' });
          }
          return;
        }
        m.last = { positionMs: msg.positionMs!, playing: msg.playing!, at: now };
        this.meta = m;
        if (now - this.lastPersistedAt >= LAST_PERSIST_MS) {
          this.lastPersistedAt = now;
          await this.ctx.storage.put('last', m.last);
        }
        this.broadcast(
          { type: 'state', positionMs: msg.positionMs, playing: msg.playing, sentAt: msg.sentAt },
          ws,
        );
        return;
      }
    }
  }
}

// --- Routes Worker ------------------------------------------------------------

function stub(c: Context<AppEnv>, roomId: string) {
  const ns = c.env.ROOMS as unknown as DurableObjectNamespace<Room>;
  return ns.get(ns.idFromName(roomId));
}

function clientIp(c: Context<AppEnv>): string {
  return c.req.header('CF-Connecting-IP') ?? 'unknown';
}

export const roomRoutes = new Hono<AppEnv>();

roomRoutes.post('/rooms', async (c) => {
  const userId = await requireUser(c);
  const { now } = c.var.deps;
  const rl = await rateLimit(c.env.RATE, `roomcreate:${userId}`, CREATE_LIMIT, 3600, now());
  if (!rl.allowed) {
    c.header('Retry-After', String(rl.retryAfterSec));
    return c.json({ error: 'Trop de demandes, réessayez plus tard' }, 429);
  }
  let metaId: string | null = null;
  let type: string | null = null;
  try {
    const body = (await c.req.json()) as { metaId?: unknown; type?: unknown };
    if (body && body.type !== undefined && body.type !== null) {
      if (typeof body.type !== 'string' || !(ROOM_TYPES as readonly string[]).includes(body.type)) {
        return c.json({ error: 'Type invalide' }, 400);
      }
      type = body.type;
    }
    if (body && body.metaId !== undefined && body.metaId !== null) {
      if (
        typeof body.metaId !== 'string' ||
        body.metaId.length === 0 ||
        body.metaId.length > MAX_META_ID ||
        // eslint-disable-next-line no-control-regex
        /[\u0000-\u001f\u007f]/.test(body.metaId)
      ) {
        return c.json({ error: 'Identifiant invalide' }, 400);
      }
      metaId = body.metaId;
    }
  } catch {
    // corps absent : salle sans titre associé
  }
  const roomId = [...crypto.getRandomValues(new Uint8Array(16))].map((b) => b.toString(16).padStart(2, '0')).join('');
  const inviteCode = generateCode(ROOM_CODE_LENGTH);
  const expiresAt = now() + ROOM_TTL_MS;
  await stub(c, roomId).init(userId, await sha256Hex(inviteCode), expiresAt, metaId, type);
  c.header('Cache-Control', 'no-store');
  return c.json({ roomId, inviteCode, expiresAt }, 201);
});

roomRoutes.get('/room/:id', async (c) => {
  if (c.req.header('Upgrade')?.toLowerCase() !== 'websocket') {
    return c.json({ error: 'WebSocket requis' }, 426);
  }
  const roomId = c.req.param('id');
  if (!ID_RE.test(roomId)) return c.json({ error: 'Salle inconnue ou expirée' }, 404);
  const { now } = c.var.deps;
  const blocked = await rateBlocked(c.env.RATE, `roomfail:${clientIp(c)}`, JOIN_FAIL_LIMIT, 60, now());
  if (!blocked.allowed) {
    c.header('Retry-After', String(blocked.retryAfterSec));
    return c.json({ error: 'Trop de demandes, réessayez plus tard' }, 429);
  }
  const fail = async (status: 400 | 403 | 404, error: string) => {
    await rateLimit(c.env.RATE, `roomfail:${clientIp(c)}`, JOIN_FAIL_LIMIT, 60, now());
    return c.json({ error }, status);
  };
  const code = (c.req.query('code') ?? '').toUpperCase();
  if (!CODE_RE.test(code)) return fail(403, 'Code d’invitation invalide');

  // Jeton de session : jamais dans l'URL. Sous-protocole « lumio.v1, <jeton> »,
  // ou à défaut premier message {"type":"auth"} dans les 5 s (voir Room).
  const offered = (c.req.header('Sec-WebSocket-Protocol') ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  const speaksV1 = offered.includes(ROOM_PROTOCOL);
  const token = offered.find((p) => p !== ROOM_PROTOCOL);
  let userId = '';
  if (token) {
    const uid = await userIdForSession(c.env.DB, token, Math.floor(now() / 1000));
    if (!uid) return c.json({ error: 'Session invalide ou expirée' }, 401);
    userId = uid;
  }
  const headers = new Headers({ Upgrade: 'websocket', 'x-room-code': code });
  if (userId) headers.set('x-room-user', userId);
  if (speaksV1) headers.set('x-room-protocol', '1');
  const res = await stub(c, roomId).fetch('https://room/join', { headers });
  if (res.status === 403) await rateLimit(c.env.RATE, `roomfail:${clientIp(c)}`, JOIN_FAIL_LIMIT, 60, now());
  return res;
});

roomRoutes.post('/room/:id/control', async (c) => {
  const userId = await requireUser(c);
  const roomId = c.req.param('id');
  if (!ID_RE.test(roomId)) return c.json({ error: 'Salle inconnue ou expirée' }, 404);
  let allControl: unknown;
  try {
    allControl = ((await c.req.json()) as { allControl?: unknown }).allControl;
  } catch {
    allControl = undefined;
  }
  if (typeof allControl !== 'boolean') throw new HTTPException(400, { message: 'Paramètre invalide' });
  const r = await stub(c, roomId).setControl(userId, allControl);
  if (r === 'gone') return c.json({ error: 'Salle inconnue ou expirée' }, 404);
  if (r === 'forbidden') return c.json({ error: 'Réservé à l’hôte' }, 403);
  return c.body(null, 204);
});
