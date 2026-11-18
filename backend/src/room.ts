import { DurableObject } from 'cloudflare:workers';
import { Hono, type Context } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { sha256Hex } from './crypto';
import { rateBlocked, rateLimit } from './rate';
import type { AppEnv, Bindings } from './types';

export const ROOM_MAX_PARTICIPANTS = 8;
export const ROOM_TTL_MS = 6 * 3600 * 1000;
export const ROOM_CODE_LENGTH = 8;
export const ROOM_MAX_MESSAGE_BYTES = 1024;
export const ROOM_MSG_PER_SEC = 20;
export const ROOM_MAX_CODE_FAILURES = 200; // par fenêtre ; le plafond principal est par IP
export const ROOM_FAILURE_WINDOW_MS = 10 * 60 * 1000;
export const ROOM_TYPES = ['movie', 'series', 'channel', 'tv'] as const;
const LAST_PERSIST_MS = 1000;
export const ROOM_PROTOCOL = 'lumio.v1';
export const CREATE_LIMIT = 10; // salles par heure et par IP
export const JOIN_FAIL_LIMIT = 20; // refus de code par minute et par IP
const MAX_POSITION_MS = 48 * 3600 * 1000;
const MAX_META_ID = 200;

/** Alphabet sans caractères ambigus (ni 0/O, ni 1/I/L). */
export const ROOM_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/** Code aléatoire par échantillonnage avec rejet (aucun biais de modulo). */
export function generateCode(length: number = ROOM_CODE_LENGTH): string {
  const limit = 256 - (256 % ROOM_ALPHABET.length);
  let out = '';
  while (out.length < length) {
    for (const b of crypto.getRandomValues(new Uint8Array(16))) {
      if (b < limit && out.length < length) out += ROOM_ALPHABET[b % ROOM_ALPHABET.length];
    }
  }
  return out;
}

/** Clé secrète de l'hôte : 128 bits aléatoires, en hexadécimal. */
export function generateHostKey(): string {
  return [...crypto.getRandomValues(new Uint8Array(16))].map((b) => b.toString(16).padStart(2, '0')).join('');
}

const ID_RE = /^[0-9a-f]{32}$/;
const CODE_RE = new RegExp(`^[${ROOM_ALPHABET}]{${ROOM_CODE_LENGTH}}$`);

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
  hostKeyHash: string;
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
  host: boolean; // connexion de l'hôte (clé de l'hôte présentée)
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
 * Une salle de watch-party, anonyme : aucun compte, aucune identité. Seuls
 * position et état de lecture y transitent.
 * API d'hibernation : les sockets survivent à l'éviction de l'objet, l'état
 * par socket est dans l'attachement.
 */
export class Room extends DurableObject<Bindings> {
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
    hostKeyHash: string,
    codeHash: string,
    expiresAt: number,
    metaId: string | null,
    type: string | null = null,
  ) {
    if (await this.load()) return;
    await this.save({
      hostKeyHash,
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
  async setControl(hostKey: string, allControl: boolean): Promise<'ok' | 'forbidden' | 'gone'> {
    const m = await this.load();
    if (!m || Date.now() >= m.expiresAt) return 'gone';
    if (!timingSafeEqual(await sha256Hex(hostKey), m.hostKeyHash)) return 'forbidden';
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
    const hostKey = request.headers.get('x-room-host-key') ?? '';
    const host = hostKey !== '' && timingSafeEqual(await sha256Hex(hostKey), m.hostKeyHash);
    const pair = new WebSocketPair();
    const [client, server] = [pair[0], pair[1]];
    const att: Attachment = {
      host,
      tokens: ROOM_MSG_PER_SEC,
      ts: Date.now(),
    };
    this.ctx.acceptWebSocket(server);
    server.serializeAttachment(att);
    await this.onJoined(server, host);
    const headers = new Headers();
    if (request.headers.get('x-room-protocol') === '1') headers.set('Sec-WebSocket-Protocol', ROOM_PROTOCOL);
    return new Response(null, { status: 101, webSocket: client, headers });
  }

  private openSockets(): WebSocket[] {
    return this.ctx.getWebSockets().filter((w) => w.readyState === 1 && !this.gone.has(w));
  }

  private participants(): number {
    return this.openSockets().length;
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
      this.send(w, msg);
    }
  }

  private snapshot(m: RoomMeta, host: boolean) {
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
      host,
      allControl: m.allControl,
      metaId: m.metaId,
      mediaType: m.type,
      expiresAt: m.expiresAt,
      state,
    };
  }

  private async onJoined(ws: WebSocket, host: boolean) {
    const m = (await this.load())!;
    if (!m.everJoined) {
      m.everJoined = true;
      await this.save(m);
    }
    this.send(ws, this.snapshot(m, host));
    this.broadcast({ type: 'join', participants: this.participants() }, ws);
  }

  async alarm() {
    const m = await this.load();
    if (!m) return;
    if (Date.now() >= m.expiresAt) {
      await this.destroy(1000, 'Salle expirée');
      return;
    }
    await this.ctx.storage.setAlarm(m.expiresAt);
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
    this.gone.add(ws);
    try {
      ws.close(code, reason);
    } catch {
      // déjà fermé
    }
    if (wasKnown) await this.afterDeparture();
  }

  private async afterDeparture() {
    const m = await this.load();
    if (!m) return;
    if (m.everJoined && this.openSockets().length === 0) {
      await this.destroy(1000, 'Salle vide');
      return;
    }
    this.broadcast({ type: 'leave', participants: this.participants() }, null);
  }

  async webSocketClose(ws: WebSocket) {
    if (this.gone.has(ws)) return;
    this.gone.add(ws);
    try {
      ws.close(1000, 'bye');
    } catch {
      // déjà fermé
    }
    await this.afterDeparture();
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
        this.send(ws, this.snapshot(m, att.host));
        return;
      case 'state': {
        // Seul l'hôte contrôle, sauf si « tout le monde peut contrôler ».
        if (!att.host && !m.allControl) {
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
  const { now } = c.var.deps;
  const rl = await rateLimit(c.env.RATE, `roomcreate:${clientIp(c)}`, CREATE_LIMIT, 3600, now());
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
  const hostKey = generateHostKey();
  await stub(c, roomId).init(await sha256Hex(hostKey), await sha256Hex(inviteCode), expiresAt, metaId, type);
  c.header('Cache-Control', 'no-store');
  return c.json({ roomId, inviteCode, hostKey, expiresAt }, 201);
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

  // Clé de l'hôte (facultative) : jamais dans l'URL. Sous-protocole
  // « lumio.v1, <clé> » ; un invité n'envoie que le code de la salle.
  const offered = (c.req.header('Sec-WebSocket-Protocol') ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  const speaksV1 = offered.includes(ROOM_PROTOCOL);
  const hostKey = offered.find((p) => p !== ROOM_PROTOCOL);
  const headers = new Headers({ Upgrade: 'websocket', 'x-room-code': code });
  if (hostKey) headers.set('x-room-host-key', hostKey);
  if (speaksV1) headers.set('x-room-protocol', '1');
  const res = await stub(c, roomId).fetch('https://room/join', { headers });
  if (res.status === 403) await rateLimit(c.env.RATE, `roomfail:${clientIp(c)}`, JOIN_FAIL_LIMIT, 60, now());
  return res;
});

roomRoutes.post('/room/:id/control', async (c) => {
  const hostKey = /^Bearer (\S+)$/.exec(c.req.header('Authorization') ?? '')?.[1];
  if (!hostKey) return c.json({ error: 'Réservé à l’hôte' }, 403);
  const roomId = c.req.param('id');
  if (!ID_RE.test(roomId)) return c.json({ error: 'Salle inconnue ou expirée' }, 404);
  let allControl: unknown;
  try {
    allControl = ((await c.req.json()) as { allControl?: unknown }).allControl;
  } catch {
    allControl = undefined;
  }
  if (typeof allControl !== 'boolean') throw new HTTPException(400, { message: 'Paramètre invalide' });
  const r = await stub(c, roomId).setControl(hostKey, allControl);
  if (r === 'gone') return c.json({ error: 'Salle inconnue ou expirée' }, 404);
  if (r === 'forbidden') return c.json({ error: 'Réservé à l’hôte' }, 403);
  return c.body(null, 204);
});
