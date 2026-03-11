// ---------------------------------------------------------------------------
// Anomaly detection — best-effort account-sharing signal logging
// ---------------------------------------------------------------------------

import type { Env } from "./types.js";

/**
 * Log warning when abnormal account-sharing patterns are detected.
 * Called from restore/resolve after successful entitlement grant via ctx.waitUntil().
 * Never throws — any error is caught internally so the main request is never affected.
 */
export async function checkAnomalies(
    env: Env,
    params: {
        userId: string;
        installId: string;
        action: "restore" | "resolve";
    },
): Promise<void> {
    const now = Math.floor(Date.now() / 1000);
    const oneDayAgo = now - 86400;
    const oneHourAgo = now - 3600;

    try {
        // Detect >3 distinct accounts sharing one install_id in a 24h window
        const accountSwitches = await env.STRATA_DB.prepare(
            `SELECT COUNT(DISTINCT user_id) AS count FROM user_devices
             WHERE install_id = ? AND first_seen_at > ?`,
        ).bind(params.installId, oneDayAgo).first<{ count: number }>();

        if (accountSwitches && accountSwitches.count > 3) {
            console.warn(
                `[anomaly] install ${params.installId}: ${accountSwitches.count} account switches in 24h (action=${params.action})`,
            );
        }

        // Detect >5 device registrations for one user_id in a 1h window
        const deviceBurst = await env.STRATA_DB.prepare(
            `SELECT COUNT(*) AS count FROM user_devices
             WHERE user_id = ? AND first_seen_at > ?`,
        ).bind(params.userId, oneHourAgo).first<{ count: number }>();

        if (deviceBurst && deviceBurst.count > 5) {
            console.warn(
                `[anomaly] user ${params.userId}: ${deviceBurst.count} devices in 1h (action=${params.action})`,
            );
        }
    } catch (error) {
        // Best effort — never block the main request flow
        console.error("[anomaly] check failed:", error);
    }
}
