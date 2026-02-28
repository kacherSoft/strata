-- ---------------------------------------------------------------------------
-- Strata Backend — Install proof challenge storage
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS install_challenges (
  challenge_id TEXT PRIMARY KEY,
  install_id   TEXT NOT NULL,
  nonce        TEXT NOT NULL,
  expires_at   INTEGER NOT NULL,
  used_at      INTEGER,
  created_at   INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_install_challenges_install
  ON install_challenges(install_id);

CREATE INDEX IF NOT EXISTS idx_install_challenges_expires
  ON install_challenges(expires_at);
