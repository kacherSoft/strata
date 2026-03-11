// ---------------------------------------------------------------------------
// Shared D1-backed rate limiter (used by resolve and restore endpoints)
// ---------------------------------------------------------------------------

import type { Env } from "./types.js";

const CLEANUP_INTERVAL_MS = 30_000;

let lastCleanupMs = 0;

/**
 * Token-bucket rate limiter backed by D1.
 * Uses a fixed time-window bucket keyed by `key:window`.
 *
 * @param env - Worker environment with STRATA_DB binding
 * @param key - Unique rate limit key (e.g. "restore:ip:1.2.3.4")
 * @param max - Maximum requests allowed within the window
 * @param windowSeconds - Window size in seconds (default: 60)
 * @returns true if request is allowed, false if rate-limited
 */
export async function checkRateLimit(
    env: Env,
    key: string,
    max: number,
    windowSeconds = 60,
): Promise<boolean> {
    const nowMs = Date.now();
    const nowSec = Math.floor(nowMs / 1000);
    const window = Math.floor(nowSec / windowSeconds);
    const bucketKey = `${key}:${window}`;
    const expiresAt = nowSec + windowSeconds * 2;

    try {
        await env.STRATA_DB.prepare(
            `INSERT INTO resolve_rate_limits (bucket_key, request_count, expires_at)
             VALUES (?, 1, ?)
             ON CONFLICT(bucket_key) DO UPDATE SET
               request_count = request_count + 1,
               expires_at = excluded.expires_at`,
        )
            .bind(bucketKey, expiresAt)
            .run();

        const bucket = await env.STRATA_DB.prepare(
            "SELECT request_count FROM resolve_rate_limits WHERE bucket_key = ? LIMIT 1",
        )
            .bind(bucketKey)
            .first<{ request_count: number }>();

        await cleanupRateLimitRows(env, nowMs, nowSec, windowSeconds);
        return (bucket?.request_count ?? 0) <= max;
    } catch (error) {
        console.error("[rate-limit] DB error, failing closed:", error);
        return false; // Deny on error — fail closed
    }
}

async function cleanupRateLimitRows(
    env: Env,
    nowMs: number,
    nowSec: number,
    _windowSeconds: number,
): Promise<void> {
    if (nowMs - lastCleanupMs < CLEANUP_INTERVAL_MS) return;
    lastCleanupMs = nowMs;

    try {
        await env.STRATA_DB.prepare(
            `DELETE FROM resolve_rate_limits
             WHERE bucket_key IN (
                SELECT bucket_key
                FROM resolve_rate_limits
                WHERE expires_at < ?
                ORDER BY expires_at ASC
                LIMIT 2000
             )`,
        )
            .bind(nowSec)
            .run();
    } catch {
        // Best effort cleanup only.
    }
}
