declare namespace Cloudflare {
  interface Env {
    DB: D1Database;
    RATE: KVNamespace;
    ROOMS: DurableObjectNamespace;
    TEST_MIGRATIONS: import('@cloudflare/vitest-pool-workers').D1Migration[];
  }
}
