-- ---------------------------------------------------------------------------
-- Strata Backend — Hardening updates
-- ---------------------------------------------------------------------------

-- Normalize existing duplicate purchase_links rows by install_id.
-- Keep the newest row and backfill missing fields from older rows.
UPDATE purchase_links AS target
SET
  checkout_session_id = COALESCE(
    target.checkout_session_id,
    (
      SELECT source.checkout_session_id
      FROM purchase_links AS source
      WHERE source.install_id = target.install_id
        AND source.checkout_session_id IS NOT NULL
      ORDER BY source.id DESC
      LIMIT 1
    )
  ),
  customer_id = COALESCE(
    target.customer_id,
    (
      SELECT source.customer_id
      FROM purchase_links AS source
      WHERE source.install_id = target.install_id
        AND source.customer_id IS NOT NULL
      ORDER BY source.id DESC
      LIMIT 1
    )
  ),
  customer_email = COALESCE(
    target.customer_email,
    (
      SELECT source.customer_email
      FROM purchase_links AS source
      WHERE source.install_id = target.install_id
        AND source.customer_email IS NOT NULL
      ORDER BY source.id DESC
      LIMIT 1
    )
  ),
  license_key_id = COALESCE(
    target.license_key_id,
    (
      SELECT source.license_key_id
      FROM purchase_links AS source
      WHERE source.install_id = target.install_id
        AND source.license_key_id IS NOT NULL
      ORDER BY source.id DESC
      LIMIT 1
    )
  ),
  install_pubkey = COALESCE(
    target.install_pubkey,
    (
      SELECT source.install_pubkey
      FROM purchase_links AS source
      WHERE source.install_id = target.install_id
        AND source.install_pubkey IS NOT NULL
      ORDER BY source.id DESC
      LIMIT 1
    )
  ),
  updated_at = datetime('now')
WHERE target.id IN (
  SELECT MAX(id)
  FROM purchase_links
  GROUP BY install_id
);

DELETE FROM purchase_links
WHERE id NOT IN (
  SELECT MAX(id)
  FROM purchase_links
  GROUP BY install_id
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_purchase_links_install_unique
  ON purchase_links(install_id);

CREATE TABLE IF NOT EXISTS resolve_rate_limits (
  bucket_key    TEXT PRIMARY KEY,
  request_count INTEGER NOT NULL DEFAULT 0,
  expires_at    INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_resolve_rate_limits_expires
  ON resolve_rate_limits(expires_at);
