// ---------------------------------------------------------------------------
// Event projection engine — maps webhook events to entitlement state
// ---------------------------------------------------------------------------

import type { Env, Tier, EntitlementState } from "./types.js";
import { PRODUCT_IDS } from "./types.js";
import { DodoClient } from "./dodo-client.js";

// ---------------------------------------------------------------------------
// Event-to-entitlement mapping
// ---------------------------------------------------------------------------

interface ProjectionResult {
    tier: Tier;
    state: EntitlementState;
    subjectType: string;
    subjectId: string;
    effectiveFrom?: string;
    effectiveUntil?: string;
}

// Tier precedence: vip > pro > free
const TIER_PRECEDENCE: Record<Tier, number> = {
    free: 0,
    pro: 1,
    vip: 2,
};

const ACTIVE_SUBSCRIPTION_EVENTS = new Set<string>([
    "subscription.active",
    "subscription.renewed",
    "subscription.plan_changed",
]);

const INACTIVE_SUBSCRIPTION_EVENTS = new Set<string>([
    "subscription.cancelled",
    "subscription.expired",
    "subscription.failed",
    "subscription.on_hold",
]);

function parseEventTimestamp(value: string | number | null | undefined): number | null {
    if (value === null || value === undefined) return null;
    const parsed = typeof value === "number" ? value : Number.parseInt(value, 10);
    if (!Number.isFinite(parsed)) return null;
    return Math.floor(parsed);
}

function isStaleEvent(
    existingEventTs: string | number | null | undefined,
    incomingEventTs: string | number | null | undefined,
): boolean {
    const existing = parseEventTimestamp(existingEventTs);
    const incoming = parseEventTimestamp(incomingEventTs);
    if (existing === null || incoming === null) return false;
    return incoming < existing;
}

function normalizeSubscriptionState(
    eventType: string,
    data: Record<string, unknown>,
): EntitlementState | null {
    const statusRaw = typeof data.status === "string" ? data.status.trim().toLowerCase() : "";

    // Prefer explicit status when available.
    if (statusRaw) {
        if (statusRaw === "active" || statusRaw === "trialing") {
            return "active";
        }
        if (
            statusRaw === "cancelled" ||
            statusRaw === "canceled" ||
            statusRaw === "expired" ||
            statusRaw === "failed" ||
            statusRaw === "on_hold" ||
            statusRaw === "paused" ||
            statusRaw === "incomplete" ||
            statusRaw === "unpaid"
        ) {
            return "inactive";
        }
    }

    if (ACTIVE_SUBSCRIPTION_EVENTS.has(eventType)) return "active";
    if (INACTIVE_SUBSCRIPTION_EVENTS.has(eventType)) return "inactive";

    if (eventType === "subscription.updated") {
        // Provider emits this for many mutations; without a status, default to active.
        return "active";
    }

    return null;
}

/**
 * Determine the entitlement projection from a webhook event.
 */
function projectEvent(
    eventType: string,
    payload: Record<string, unknown>,
): ProjectionResult | null {
    const data = (payload.data || payload) as Record<string, unknown>;

    switch (eventType) {
        case "subscription.active":
        case "subscription.updated":
        case "subscription.renewed":
        case "subscription.plan_changed":
        case "subscription.cancelled":
        case "subscription.expired":
        case "subscription.failed":
        case "subscription.on_hold": {
            const email = extractEmail(data);
            if (!email) return null;

            const state = normalizeSubscriptionState(eventType, data);
            if (!state) return null;

            return {
                tier: "pro",
                state,
                subjectType: "email",
                subjectId: email,
                effectiveFrom: (data.current_period_start as string) || undefined,
                effectiveUntil:
                    (data.current_period_end as string) ||
                    (data.next_billing_date as string) ||
                    undefined,
            };
        }

        case "license_key.created": {
            const email = extractEmail(data);
            const productId = ((data.product_id as string) || "").trim();
            if (!email) return null;

            // Only VIP lifetime license keys trigger VIP tier.
            if (productId === PRODUCT_IDS.vipLifetime) {
                return {
                    tier: "vip",
                    state: "active",
                    subjectType: "email",
                    subjectId: email,
                    effectiveFrom: (data.created_at as string) || new Date().toISOString(),
                };
            }
            return null;
        }

        case "payment.succeeded":
            // Payment events trigger reconciliation but do not directly set entitlements.
            return null;

        default:
            return null;
    }
}

function extractEmail(data: Record<string, unknown>): string | null {
    const customer = data.customer as Record<string, unknown> | undefined;
    const email =
        (data.customer_email as string) ||
        (customer?.email as string) ||
        (data.email as string) ||
        "";

    const normalized = email.trim().toLowerCase();
    return normalized || null;
}

function extractCustomerId(data: Record<string, unknown>): string | null {
    const customer = data.customer as Record<string, unknown> | undefined;
    const customerId =
        (data.customer_id as string) ||
        (customer?.customer_id as string) ||
        "";

    const normalized = customerId.trim();
    return normalized || null;
}

function extractCheckoutSessionId(data: Record<string, unknown>): string | null {
    const checkout = data.checkout as Record<string, unknown> | undefined;
    const id =
        (data.checkout_session_id as string) ||
        (checkout?.checkout_session_id as string) ||
        (data.checkout_id as string) ||
        "";

    const normalized = id.trim();
    return normalized || null;
}

function extractPaymentId(data: Record<string, unknown>): string | null {
    const id = (data.payment_id as string) || (data.id as string) || "";
    const normalized = id.trim();
    return normalized || null;
}

function extractLicenseKeyId(data: Record<string, unknown>): string | null {
    const id = (data.license_key_id as string) || "";
    const normalized = id.trim();
    return normalized || null;
}

async function markWebhookIgnored(env: Env, webhookId: string): Promise<void> {
    await env.STRATA_DB.prepare(
        "UPDATE webhook_events SET status = 'ignored', processed_at = datetime('now') WHERE webhook_id = ?",
    )
        .bind(webhookId)
        .run();
}

async function lookupEmailFromPurchaseLinks(
    env: Env,
    lookupField: "checkout_session_id" | "customer_id",
    value: string,
): Promise<string | null> {
    const row = await env.STRATA_DB.prepare(
        `SELECT customer_email
         FROM purchase_links
         WHERE ${lookupField} = ? AND customer_email IS NOT NULL
         ORDER BY updated_at DESC, id DESC
         LIMIT 1`,
    )
        .bind(value)
        .first<{ customer_email: string }>();

    const normalized = (row?.customer_email || "").trim().toLowerCase();
    return normalized || null;
}

function withCustomerEmail(
    payload: Record<string, unknown>,
    email: string,
): Record<string, unknown> {
    const data = (payload.data || payload) as Record<string, unknown>;
    return {
        ...payload,
        data: {
            ...data,
            customer_email: email,
        },
    };
}

async function linkPurchaseRecord(
    env: Env,
    identifiers: {
        checkoutSessionId: string | null;
        paymentId: string | null;
        customerId: string | null;
        customerEmail: string | null;
        licenseKeyId: string | null;
    },
): Promise<void> {
    const { checkoutSessionId, paymentId, customerId, customerEmail, licenseKeyId } = identifiers;

    // Primary linkage uses checkout_session_id as emitted by checkout creation.
    if (checkoutSessionId) {
        await env.STRATA_DB.prepare(
            `UPDATE purchase_links
             SET customer_id = COALESCE(customer_id, ?),
                 customer_email = COALESCE(customer_email, ?),
                 license_key_id = COALESCE(license_key_id, ?),
                 updated_at = datetime('now')
             WHERE checkout_session_id = ?`,
        )
            .bind(customerId, customerEmail, licenseKeyId, checkoutSessionId)
            .run();
    }

    // Backward-compat fallback for historical rows that stored payment_id instead.
    if (paymentId) {
        await env.STRATA_DB.prepare(
            `UPDATE purchase_links
             SET customer_id = COALESCE(customer_id, ?),
                 customer_email = COALESCE(customer_email, ?),
                 license_key_id = COALESCE(license_key_id, ?),
                 updated_at = datetime('now')
             WHERE checkout_session_id = ?`,
        )
            .bind(customerId, customerEmail, licenseKeyId, paymentId)
            .run();
    }

    // If rows are already linked by customer_id, enrich missing fields.
    if (customerId) {
        await env.STRATA_DB.prepare(
            `UPDATE purchase_links
             SET customer_email = COALESCE(customer_email, ?),
                 license_key_id = COALESCE(license_key_id, ?),
                 updated_at = datetime('now')
             WHERE customer_id = ?`,
        )
            .bind(customerEmail, licenseKeyId, customerId)
            .run();
    }
}

async function syncUserEntitlementForEmail(
    env: Env,
    email: string,
    fallbackSourceEventId: string,
): Promise<void> {
    const user = await env.STRATA_DB.prepare(
        `SELECT id
         FROM users
         WHERE email_normalized = ?
         LIMIT 1`,
    )
        .bind(email)
        .first<{ id: string }>();

    if (!user?.id) return;

    const entitlement = await env.STRATA_DB.prepare(
        `SELECT tier, state, source_event_id, effective_from, effective_until
         FROM entitlements
         WHERE subject_type = 'email' AND subject_id = ?
         LIMIT 1`,
    )
        .bind(email)
        .first<{
            tier: string;
            state: string;
            source_event_id: string | null;
            effective_from: string | null;
            effective_until: string | null;
        }>();

    if (!entitlement) return;

    await env.STRATA_DB.prepare(
        `INSERT INTO user_entitlements (user_id, tier, state, source_event_id, effective_from, effective_until, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, datetime('now'))
         ON CONFLICT(user_id) DO UPDATE SET
           tier = excluded.tier,
           state = excluded.state,
           source_event_id = excluded.source_event_id,
           effective_from = COALESCE(excluded.effective_from, user_entitlements.effective_from),
           effective_until = COALESCE(excluded.effective_until, user_entitlements.effective_until),
           updated_at = datetime('now')`,
    )
        .bind(
            user.id,
            entitlement.tier,
            entitlement.state,
            entitlement.source_event_id || fallbackSourceEventId,
            entitlement.effective_from,
            entitlement.effective_until,
        )
        .run();
}

async function resolveCustomerEmail(
    env: Env,
    data: Record<string, unknown>,
    dodoClient: DodoClient,
): Promise<string | null> {
    const direct = extractEmail(data);
    if (direct) return direct;

    const checkoutSessionId = extractCheckoutSessionId(data);
    if (checkoutSessionId) {
        const linkedByCheckout = await lookupEmailFromPurchaseLinks(
            env,
            "checkout_session_id",
            checkoutSessionId,
        );
        if (linkedByCheckout) return linkedByCheckout;
    }

    const paymentId = extractPaymentId(data);
    if (paymentId) {
        const linkedByPayment = await lookupEmailFromPurchaseLinks(
            env,
            "checkout_session_id",
            paymentId,
        );
        if (linkedByPayment) return linkedByPayment;
    }

    const customerId = extractCustomerId(data);
    if (customerId) {
        const linkedByCustomer = await lookupEmailFromPurchaseLinks(
            env,
            "customer_id",
            customerId,
        );
        if (linkedByCustomer) return linkedByCustomer;

        return await dodoClient.findCustomerEmailById(customerId);
    }

    return null;
}

// ---------------------------------------------------------------------------
// Apply projection to D1 entitlement store
// ---------------------------------------------------------------------------

/**
 * Process a webhook event and update the entitlement store.
 * This function is called asynchronously via waitUntil.
 */
export async function processWebhookEvent(
    env: Env,
    webhookId: string,
    eventType: string,
    payload: Record<string, unknown>,
    eventTs?: string,
): Promise<void> {
    const data = (payload.data || payload) as Record<string, unknown>;
    const dodoClient = new DodoClient(env);

    const customerId = extractCustomerId(data);
    const checkoutSessionId = extractCheckoutSessionId(data);
    const paymentId = extractPaymentId(data);
    const licenseKeyId = extractLicenseKeyId(data);

    const customerEmail = await resolveCustomerEmail(env, data, dodoClient).catch((error) => {
        console.error(`[projector] email resolution failed for ${webhookId}:`, error);
        return null;
    });

    await linkPurchaseRecord(env, {
        checkoutSessionId,
        paymentId,
        customerId,
        customerEmail,
        licenseKeyId,
    }).catch(() => {
        // Best effort linkage only.
    });

    const projectionPayload = customerEmail ? withCustomerEmail(payload, customerEmail) : payload;
    const projection = projectEvent(eventType, projectionPayload);

    if (!projection) {
        await markWebhookIgnored(env, webhookId);
        return;
    }

    const existing = await env.STRATA_DB.prepare(
        `SELECT e.id, e.tier, e.state, e.updated_at, e.source_event_id, w.event_ts AS source_event_ts
         FROM entitlements e
         LEFT JOIN webhook_events w ON w.webhook_id = e.source_event_id
         WHERE e.subject_type = ? AND e.subject_id = ?`,
    )
        .bind(projection.subjectType, projection.subjectId)
        .first<{
            id: number;
            tier: string;
            state: string;
            updated_at: string;
            source_event_id: string | null;
            source_event_ts: string | null;
        }>();

    if (existing && isStaleEvent(existing.source_event_ts, eventTs)) {
        await markWebhookIgnored(env, webhookId);
        return;
    }

    if (existing) {
        const existingPrecedence = TIER_PRECEDENCE[existing.tier as Tier] ?? 0;
        const newPrecedence = TIER_PRECEDENCE[projection.tier] ?? 0;

        if (newPrecedence < existingPrecedence) {
            await markWebhookIgnored(env, webhookId);
            return;
        }

        const hasEffectiveFieldUpdate = Boolean(
            projection.effectiveFrom || projection.effectiveUntil,
        );

        if (
            projection.tier === existing.tier &&
            projection.state === existing.state &&
            !hasEffectiveFieldUpdate
        ) {
            await markWebhookIgnored(env, webhookId);
            return;
        }

        await env.STRATA_DB.prepare(
            `UPDATE entitlements
             SET tier = ?,
                 state = ?,
                 source_event_id = ?,
                 effective_from = COALESCE(?, effective_from),
                 effective_until = COALESCE(?, effective_until),
                 updated_at = datetime('now')
             WHERE id = ?`,
        )
            .bind(
                projection.tier,
                projection.state,
                webhookId,
                projection.effectiveFrom || null,
                projection.effectiveUntil || null,
                existing.id,
            )
            .run();
    } else {
        await env.STRATA_DB.prepare(
            `INSERT INTO entitlements (subject_type, subject_id, tier, state, source_event_id, effective_from, effective_until)
             VALUES (?, ?, ?, ?, ?, ?, ?)`,
        )
            .bind(
                projection.subjectType,
                projection.subjectId,
                projection.tier,
                projection.state,
                webhookId,
                projection.effectiveFrom || null,
                projection.effectiveUntil || null,
            )
            .run();
    }

    if (projection.subjectType === "email") {
        await syncUserEntitlementForEmail(env, projection.subjectId, webhookId).catch((error) => {
            console.error(`[projector] user entitlement sync failed for ${webhookId}:`, error);
        });
    }

    await env.STRATA_DB.prepare(
        "UPDATE webhook_events SET status = 'processed', processed_at = datetime('now') WHERE webhook_id = ?",
    )
        .bind(webhookId)
        .run();
}

// Re-export for tests
export { projectEvent, extractEmail, TIER_PRECEDENCE, isStaleEvent, normalizeSubscriptionState };
export type { ProjectionResult };
