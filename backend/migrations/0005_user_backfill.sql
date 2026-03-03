-- ---------------------------------------------------------------------------
-- Strata Backend — Backfill account ownership tables from legacy email rows
-- ---------------------------------------------------------------------------

INSERT INTO users (id, email_normalized, email_verified_at, created_at, updated_at)
SELECT
  lower(
    hex(randomblob(4)) || '-' ||
    hex(randomblob(2)) || '-' ||
    hex(randomblob(2)) || '-' ||
    hex(randomblob(2)) || '-' ||
    hex(randomblob(6))
  ) AS id,
  lower(trim(e.subject_id)) AS email_normalized,
  CAST(strftime('%s', 'now') AS INTEGER) AS email_verified_at,
  CAST(strftime('%s', 'now') AS INTEGER) AS created_at,
  CAST(strftime('%s', 'now') AS INTEGER) AS updated_at
FROM entitlements e
WHERE e.subject_type = 'email'
  AND e.subject_id IS NOT NULL
  AND trim(e.subject_id) <> ''
ON CONFLICT(email_normalized) DO NOTHING;

INSERT INTO user_entitlements (user_id, tier, state, source_event_id, effective_from, effective_until, updated_at)
SELECT
  u.id AS user_id,
  e.tier,
  e.state,
  e.source_event_id,
  e.effective_from,
  e.effective_until,
  datetime('now') AS updated_at
FROM entitlements e
JOIN users u
  ON u.email_normalized = lower(trim(e.subject_id))
WHERE e.subject_type = 'email'
ON CONFLICT(user_id) DO UPDATE SET
  tier = excluded.tier,
  state = excluded.state,
  source_event_id = COALESCE(excluded.source_event_id, user_entitlements.source_event_id),
  effective_from = COALESCE(excluded.effective_from, user_entitlements.effective_from),
  effective_until = COALESCE(excluded.effective_until, user_entitlements.effective_until),
  updated_at = datetime('now');
