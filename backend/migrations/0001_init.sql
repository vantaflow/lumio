CREATE TABLE users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  created_at INTEGER NOT NULL
);

-- Jetons de lien magique : seul le hachage SHA-256 est stocké.
CREATE TABLE login_tokens (
  token_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  expires_at INTEGER NOT NULL,
  used INTEGER NOT NULL DEFAULT 0
);

-- id = SHA-256 du jeton de session ; refresh_hash = SHA-256 du jeton de rafraîchissement.
CREATE TABLE sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  refresh_hash TEXT NOT NULL UNIQUE,
  expires_at INTEGER NOT NULL,
  refresh_expires_at INTEGER NOT NULL
);

CREATE INDEX idx_sessions_user ON sessions(user_id);
