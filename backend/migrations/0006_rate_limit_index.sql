-- Migration 0006: Add index on resolve_rate_limits.expires_at for cleanup query performance.
-- Without this index, the scheduled cleanup and opportunistic cleanup do a full table scan.
CREATE INDEX IF NOT EXISTS idx_rate_limits_expires
ON resolve_rate_limits (expires_at);
