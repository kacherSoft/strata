// ---------------------------------------------------------------------------
// Scheduled cleanup — removes expired rows from rate limit and challenge tables
// Triggered every 6 hours via CRON (see wrangler.jsonc triggers.crons)
// ---------------------------------------------------------------------------

import type { Env } from "./types.js";

const CLEANUP_BATCH_SIZE = 2000;

export async function handleScheduledCleanup(env: Env): Promise<void> {
    const nowUnix = Math.floor(Date.now() / 1000);

    // Expired auth challenges (expires_at is INTEGER — Unix seconds)
    await cleanupTable(env, "auth_challenges", "expires_at", nowUnix);

    // Expired install challenges (expires_at is INTEGER — Unix seconds)
    await cleanupTable(env, "install_challenges", "expires_at", nowUnix);

    // Expired rate limit rows (expires_at is INTEGER — Unix seconds)
    await cleanupTable(env, "resolve_rate_limits", "expires_at", nowUnix);

    // Expired + revoked sessions (grace: 7 days past expiry or creation)
    // All timestamp columns are INTEGER (Unix seconds) — must compare with integers.
    const cutoffUnix = nowUnix - 7 * 24 * 60 * 60;
    await env.STRATA_DB.prepare(
        `DELETE FROM account_sessions
         WHERE id IN (
             SELECT id FROM account_sessions
             WHERE (expires_at < ? OR revoked_at IS NOT NULL)
             AND created_at < ?
             ORDER BY created_at ASC
             LIMIT ?
         )`,
    ).bind(nowUnix, cutoffUnix, CLEANUP_BATCH_SIZE).run().catch(e =>
        console.error("[cleanup] sessions error:", e)
    );

    console.log("[cleanup] scheduled cleanup completed");
}

async function cleanupTable(
    env: Env,
    table: string,
    expiryColumn: string,
    threshold: string | number,
): Promise<void> {
    try {
        // Table names are hardcoded at call sites — string interpolation is safe here.
        await env.STRATA_DB.prepare(
            `DELETE FROM ${table}
             WHERE rowid IN (
                 SELECT rowid FROM ${table}
                 WHERE ${expiryColumn} < ?
                 ORDER BY ${expiryColumn} ASC
                 LIMIT ?
             )`,
        ).bind(threshold, CLEANUP_BATCH_SIZE).run();
    } catch (error) {
        console.error(`[cleanup] ${table} error:`, error);
    }
}
