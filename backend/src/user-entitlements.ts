// ---------------------------------------------------------------------------
// User entitlement and device-seat helpers
// ---------------------------------------------------------------------------

import { AppError } from "./errors.js";
import type { Env, Tier } from "./types.js";
import { DodoClient } from "./dodo-client.js";
import { deviceSeatsEnforced, seatLimitForTier } from "./auth.js";

export interface UserEntitlementRow {
    user_id: string;
    tier: string;
    state: string;
    source_event_id: string | null;
    effective_from: string | null;
    effective_until: string | null;
    updated_at: string;
}

export interface DeviceRow {
    install_id: string;
    nickname: string | null;
    first_seen_at: number;
    last_seen_at: number;
    revoked_at: number | null;
}

export async function readUserEntitlement(
    env: Env,
    userId: string,
): Promise<UserEntitlementRow | null> {
    return await env.STRATA_DB.prepare(
        `SELECT user_id, tier, state, source_event_id, effective_from, effective_until, updated_at
         FROM user_entitlements
         WHERE user_id = ?
         LIMIT 1`,
    )
        .bind(userId)
        .first<UserEntitlementRow>();
}

export async function upsertUserEntitlement(
    env: Env,
    params: {
        userId: string;
        tier: Tier;
        state: "active" | "inactive";
        sourceEventId?: string | null;
        effectiveFrom?: string | null;
        effectiveUntil?: string | null;
    },
): Promise<void> {
    await env.STRATA_DB.prepare(
        `INSERT INTO user_entitlements (user_id, tier, state, source_event_id, effective_from, effective_until, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, datetime('now'))
         ON CONFLICT(user_id) DO UPDATE SET
           tier = excluded.tier,
           state = excluded.state,
           source_event_id = COALESCE(excluded.source_event_id, user_entitlements.source_event_id),
           effective_from = COALESCE(excluded.effective_from, user_entitlements.effective_from),
           effective_until = COALESCE(excluded.effective_until, user_entitlements.effective_until),
           updated_at = datetime('now')`,
    )
        .bind(
            params.userId,
            params.tier,
            params.state,
            params.sourceEventId || null,
            params.effectiveFrom || null,
            params.effectiveUntil || null,
        )
        .run();
}

export async function resolveTierForUser(
    env: Env,
    params: {
        userId: string;
        email: string;
        dodo?: DodoClient;
        allowProviderFallback: boolean;
    },
): Promise<{ tier: Tier; source: "user-store" | "legacy-store" | "provider" | "none" }> {
    const userEntitlement = await readUserEntitlement(env, params.userId);
    if (userEntitlement && userEntitlement.state === "active") {
        const tier = normalizeTier(userEntitlement.tier);
        return { tier, source: "user-store" };
    }

    const legacyEntitlement = await env.STRATA_DB.prepare(
        `SELECT tier, state
         FROM entitlements
         WHERE subject_type = 'email' AND subject_id = ? AND state = 'active'
         LIMIT 1`,
    )
        .bind(params.email)
        .first<{ tier: string; state: string }>();

    if (legacyEntitlement && legacyEntitlement.state === "active") {
        const tier = normalizeTier(legacyEntitlement.tier);
        await upsertUserEntitlement(env, {
            userId: params.userId,
            tier,
            state: "active",
            sourceEventId: "legacy-email-backfill",
        });
        return { tier, source: "legacy-store" };
    }

    if (params.allowProviderFallback && params.dodo) {
        const subscription = await params.dodo.findActiveSubscription(params.email);
        if (subscription) {
            await upsertUserEntitlement(env, {
                userId: params.userId,
                tier: "pro",
                state: "active",
                sourceEventId: "provider-subscription-fallback",
                effectiveUntil: subscription.nextBillingDateISO8601,
            });
            return { tier: "pro", source: "provider" };
        }
    }

    return { tier: "free", source: "none" };
}

function normalizeTier(raw: string): Tier {
    if (raw === "vip") return "vip";
    if (raw === "pro") return "pro";
    return "free";
}

export async function ensureDeviceSeat(
    env: Env,
    params: {
        userId: string;
        installId: string;
        tier: Tier;
        nickname?: string | null;
    },
): Promise<void> {
    const now = Math.floor(Date.now() / 1000);

    const existing = await env.STRATA_DB.prepare(
        `SELECT install_id, revoked_at
         FROM user_devices
         WHERE user_id = ? AND install_id = ?
         LIMIT 1`,
    )
        .bind(params.userId, params.installId)
        .first<{ install_id: string; revoked_at: number | null }>();

    const limit = seatLimitForTier(env, params.tier);

    if (deviceSeatsEnforced(env)) {
        const activeCountRow = await env.STRATA_DB.prepare(
            `SELECT COUNT(*) AS count
             FROM user_devices
             WHERE user_id = ? AND revoked_at IS NULL`,
        )
            .bind(params.userId)
            .first<{ count: number }>();

        const activeCount = Number(activeCountRow?.count || 0);
        const currentDeviceIsActive = Boolean(existing && existing.revoked_at === null);

        if (!currentDeviceIsActive && activeCount >= limit) {
            throw new AppError(
                403,
                "DEVICE_LIMIT_REACHED",
                `Device limit reached for your plan (${limit} active device${limit === 1 ? "" : "s"})`,
            );
        }
    }

    if (existing) {
        await env.STRATA_DB.prepare(
            `UPDATE user_devices
             SET revoked_at = NULL,
                 nickname = COALESCE(?, nickname),
                 last_seen_at = ?,
                 updated_at = ?
             WHERE user_id = ? AND install_id = ?`,
        )
            .bind(params.nickname || null, now, now, params.userId, params.installId)
            .run();
        return;
    }

    await env.STRATA_DB.prepare(
        `INSERT INTO user_devices (user_id, install_id, nickname, first_seen_at, last_seen_at, revoked_at, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, NULL, ?, ?)`,
    )
        .bind(params.userId, params.installId, params.nickname || null, now, now, now, now)
        .run();
}

export async function listUserDevices(env: Env, userId: string): Promise<DeviceRow[]> {
    const response = await env.STRATA_DB.prepare(
        `SELECT install_id, nickname, first_seen_at, last_seen_at, revoked_at
         FROM user_devices
         WHERE user_id = ?
         ORDER BY last_seen_at DESC`,
    )
        .bind(userId)
        .all<DeviceRow>();

    return response.results || [];
}

export async function revokeUserDevice(
    env: Env,
    userId: string,
    installId: string,
): Promise<void> {
    const now = Math.floor(Date.now() / 1000);
    const result = await env.STRATA_DB.prepare(
        `UPDATE user_devices
         SET revoked_at = ?, updated_at = ?
         WHERE user_id = ? AND install_id = ? AND revoked_at IS NULL`,
    )
        .bind(now, now, userId, installId)
        .run();

    const changes = (result as { meta?: { changes?: number } }).meta?.changes || 0;
    if (changes < 1) {
        throw new AppError(404, "DEVICE_NOT_FOUND", "Active device not found");
    }
}
