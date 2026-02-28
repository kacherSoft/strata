-- ---------------------------------------------------------------------------
-- Strata Backend — Initial D1 Schema
-- Phase 2 tables included for forward compatibility
-- ---------------------------------------------------------------------------

-- Idempotent webhook event log
CREATE TABLE IF NOT EXISTS webhook_events (
  webhook_id    TEXT PRIMARY KEY,
  event_type    TEXT NOT NULL,
  event_ts      TEXT NOT NULL,
  payload_json  TEXT NOT NULL,
  received_at   TEXT NOT NULL DEFAULT (datetime('now')),
  processed_at  TEXT,
  status        TEXT NOT NULL DEFAULT 'pending'
);

-- Entitlement state (authoritative from Phase 2 onward)
CREATE TABLE IF NOT EXISTS entitlements (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  subject_type    TEXT NOT NULL,
  subject_id      TEXT NOT NULL,
  tier            TEXT NOT NULL DEFAULT 'free',
  state           TEXT NOT NULL DEFAULT 'inactive',
  source_event_id TEXT,
  effective_from  TEXT,
  effective_until TEXT,
  updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(subject_type, subject_id)
);

-- Purchase-to-install linkage
CREATE TABLE IF NOT EXISTS purchase_links (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  install_id          TEXT NOT NULL,
  checkout_session_id TEXT,
  customer_id         TEXT,
  customer_email      TEXT,
  license_key_id      TEXT,
  install_pubkey      TEXT,
  created_at          TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at          TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Indexes for query performance
CREATE INDEX IF NOT EXISTS idx_entitlements_subject
  ON entitlements(subject_type, subject_id);

CREATE INDEX IF NOT EXISTS idx_purchase_links_install
  ON purchase_links(install_id);

CREATE INDEX IF NOT EXISTS idx_purchase_links_checkout
  ON purchase_links(checkout_session_id);

CREATE INDEX IF NOT EXISTS idx_purchase_links_email
  ON purchase_links(customer_email);
