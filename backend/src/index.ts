import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { authRoutes, requireUser } from './auth';
import { LogEmailSender } from './email';
import { pairPageRoutes, pairRoutes } from './pair';
import type { AppEnv, Deps } from './types';

export { requireUser };
export type { AppEnv, Deps };

/**
 * Construit l'application. Chaque fonctionnalité monte son propre sous-routeur
 * (`app.route('/pair', pairRoutes)`, `/sync`, `/room`…) et réutilise `requireUser`.
 */
export function createApp(overrides: Partial<Deps> = {}) {
  // Par défaut l'e-mail n'est que journalisé (masqué) : le fournisseur réel est
  // branché au déploiement en passant un autre EmailSender.
  const deps: Deps = { now: Date.now, email: new LogEmailSender(), ...overrides };
  const app = new Hono<AppEnv>();

  app.use('*', async (c, next) => {
    c.set('deps', deps);
    await next();
  });

  app.get('/health', (c) => c.json({ ok: true }));
  app.route('/auth', authRoutes);
  app.route('/pair', pairRoutes);
  app.route('/p', pairPageRoutes);

  app.get('/me', async (c) => c.json({ userId: await requireUser(c) }));

  app.onError((err, c) => {
    if (err instanceof HTTPException) return c.json({ error: err.message }, err.status);
    console.error('[error] erreur interne');
    return c.json({ error: 'Erreur interne' }, 500);
  });

  return app;
}

export default createApp();
