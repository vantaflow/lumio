-- Appairage mobile : seul le hachage SHA-256 du code (et du jeton d'interrogation
-- de la télé) est stocké. `payload` est effacé dès sa lecture.
CREATE TABLE pairings (
  code_hash TEXT PRIMARY KEY,
  poll_hash TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  payload TEXT,
  consumed INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX idx_pairings_expires ON pairings(expires_at);
