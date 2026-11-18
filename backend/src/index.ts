import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { roomRoutes } from './room';
import type { AppEnv, Deps } from './types';

export { Room } from './room';
export type { AppEnv, Deps };

/**
 * Serveur des salles de Watch party. Aucun compte : une salle est protégée par
 * son identifiant aléatoire (128 bits) et son code d'invitation.
 */
export function createApp(overrides: Partial<Deps> = {}) {
  const deps: Deps = { now: Date.now, ...overrides };
  const app = new Hono<AppEnv>();

  app.use('*', async (c, next) => {
    c.set('deps', deps);
    await next();
  });

  app.get('/health', (c) => c.json({ ok: true }));
  app.route('/', roomRoutes);

  app.onError((err, c) => {
    if (err instanceof HTTPException) return c.json({ error: err.message }, err.status);
    console.error('[error] erreur interne');
    return c.json({ error: 'Erreur interne' }, 500);
  });

  return app;
}

export default createApp();
