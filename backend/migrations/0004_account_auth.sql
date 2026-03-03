-- ---------------------------------------------------------------------------
-- Strata Backend — Account auth, user entitlements, and device seats
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS users (
  id               TEXT PRIMARY KEY,
  email_normalized TEXT NOT NULL UNIQUE,
  email_verified_at INTEGER,
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_users_email
  ON users(email_normalized);

CREATE TABLE IF NOT EXISTS auth_challenges (
  challenge_id      TEXT PRIMARY KEY,
  email_normalized  TEXT NOT NULL,
  otp_hash          TEXT NOT NULL,
  expires_at        INTEGER NOT NULL,
  attempts          INTEGER NOT NULL DEFAULT 0,
  consumed_at       INTEGER,
  created_at        INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_auth_challenges_email
  ON auth_challenges(email_normalized);

CREATE INDEX IF NOT EXISTS idx_auth_challenges_expires
  ON auth_challenges(expires_at);

CREATE TABLE IF NOT EXISTS account_sessions (
  id           TEXT PRIMARY KEY,
  user_id      TEXT NOT NULL,
  session_hash TEXT NOT NULL UNIQUE,
  expires_at   INTEGER NOT NULL,
  revoked_at   INTEGER,
  created_at   INTEGER NOT NULL,
  last_seen_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_account_sessions_user
  ON account_sessions(user_id);

CREATE INDEX IF NOT EXISTS idx_account_sessions_expires
  ON account_sessions(expires_at);

CREATE TABLE IF NOT EXISTS user_entitlements (
  user_id         TEXT PRIMARY KEY,
  tier            TEXT NOT NULL DEFAULT 'free',
  state           TEXT NOT NULL DEFAULT 'inactive',
  source_event_id TEXT,
  effective_from  TEXT,
  effective_until TEXT,
  updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_user_entitlements_tier_state
  ON user_entitlements(tier, state);

CREATE TABLE IF NOT EXISTS user_devices (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id       TEXT NOT NULL,
  install_id    TEXT NOT NULL,
  nickname      TEXT,
  first_seen_at INTEGER NOT NULL,
  last_seen_at  INTEGER NOT NULL,
  revoked_at    INTEGER,
  created_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL,
  UNIQUE(user_id, install_id)
);

CREATE INDEX IF NOT EXISTS idx_user_devices_user
  ON user_devices(user_id);

CREATE INDEX IF NOT EXISTS idx_user_devices_user_active
  ON user_devices(user_id, revoked_at, last_seen_at);
