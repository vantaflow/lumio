export interface Bindings {
  RATE: KVNamespace;
  ROOMS: DurableObjectNamespace;
}

/** Dépendances injectables (horloge) pour les tests. */
export interface Deps {
  now: () => number;
}

export interface AppEnv {
  Bindings: Bindings;
  Variables: { deps: Deps };
}
