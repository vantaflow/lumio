-- Synchronisation multi-appareils. Les versions sont attribuées par le serveur :
-- un compteur par utilisateur, incrémenté dans le même lot D1 (transaction)
-- que l'écriture des éléments. `payload` est NULL pour une pierre tombale.
CREATE TABLE sync_state (
  user_id TEXT PRIMARY KEY REFERENCES users(id),
  version INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE sync_items (
  user_id TEXT NOT NULL REFERENCES users(id),
  kind TEXT NOT NULL,
  key TEXT NOT NULL,
  payload TEXT,
  version INTEGER NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, kind, key)
);

CREATE INDEX idx_sync_items_version ON sync_items(user_id, version);
