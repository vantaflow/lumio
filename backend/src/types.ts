import type { EmailSender } from './email';

export interface Bindings {
  DB: D1Database;
  RATE: KVNamespace;
}

/** Dépendances injectables (horloge, e-mail) pour les tests. */
export interface Deps {
  now: () => number;
  email: EmailSender;
}

export interface AppEnv {
  Bindings: Bindings;
  Variables: { deps: Deps };
}
