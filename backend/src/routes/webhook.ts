// ---------------------------------------------------------------------------
// POST /v1/webhooks/dodo — Dodo payment webhook ingress
// ---------------------------------------------------------------------------

import type { Env } from "../types.js";
import { AppError, generateRequestId, handleError } from "../errors.js";
import { processWebhookEvent } from "../projector.js";

// ---------------------------------------------------------------------------
// Webhook signature verification (Dodo / svix format)
// ---------------------------------------------------------------------------

/**
 * Constant-time string comparison to prevent timing attacks.
 */
function timingSafeEqual(a: string, b: string): boolean {
    const encoder = new TextEncoder();
    const bufA = encoder.encode(a);
    const bufB = encoder.encode(b);

    const maxLength = Math.max(bufA.length, bufB.length);
    let result = bufA.length ^ bufB.length;

    for (let i = 0; i < maxLength; i++) {
        const valueA = i < bufA.length ? bufA[i] : 0;
        const valueB = i < bufB.length ? bufB[i] : 0;
        result |= valueA ^ valueB;
    }

    return result === 0;
}

/**
 * Verify Dodo webhook signature using HMAC-SHA256.
 * Dodo uses svix-style signatures: base64(HMAC-SHA256(secret, "{msgId}.{timestamp}.{body}"))
 */
async function verifyWebhookSignature(
    body: string,
    webhookId: string,
    timestamp: string,
    signatureHeader: string,
    secret: string,
): Promise<boolean> {
    const trimmedSecret = secret.trim();
    if (!trimmedSecret) {
        throw new AppError(500, "INVALID_SERVER_CONFIG", "Webhook secret is not configured");
    }

    const encodedSecret = trimmedSecret.startsWith("whsec_")
        ? trimmedSecret.slice("whsec_".length)
        : trimmedSecret;

    const normalizedSecret = encodedSecret.replace(/-/g, "+").replace(/_/g, "/");
    const paddedSecret = normalizedSecret + "=".repeat((4 - (normalizedSecret.length % 4)) % 4);

    let secretBinary: string;
    try {
        secretBinary = atob(paddedSecret);
    } catch {
        throw new AppError(500, "INVALID_SERVER_CONFIG", "Webhook secret is malformed");
    }

    const secretBytes = Uint8Array.from(secretBinary, (c) => c.charCodeAt(0));

    const signContent = `${webhookId}.${timestamp}.${body}`;
    const key = await crypto.subtle.importKey(
        "raw",
        secretBytes,
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["sign"],
    );

    const signatureBytes = await crypto.subtle.sign(
        "HMAC",
        key,
        new TextEncoder().encode(signContent),
    );

    const computedSig = btoa(String.fromCharCode(...new Uint8Array(signatureBytes)));

    // The header may contain one or many v1 signatures.
    const signatureMatches = Array.from(signatureHeader.matchAll(/v1,([A-Za-z0-9+/=_-]+)/g))
        .map((match) => match[1]);

    const signatures = signatureMatches.length
        ? signatureMatches
        : signatureHeader.split(/\s+/).filter(Boolean);

    for (const sig of signatures) {
        const value = sig.startsWith("v1,") ? sig.slice(3) : sig;
        if (timingSafeEqual(computedSig, value)) {
            return true;
        }
    }

    return false;
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

const TIMESTAMP_TOLERANCE_SECONDS = 300; // 5 minutes

export async function handleWebhook(
    request: Request,
    env: Env,
    ctx: ExecutionContext,
): Promise<Response> {
    const requestId = generateRequestId();

    try {
        // Extract required headers
        const webhookId = request.headers.get("webhook-id");
        const webhookTimestamp = request.headers.get("webhook-timestamp");
        const webhookSignature = request.headers.get("webhook-signature");

        if (!webhookId || !webhookTimestamp || !webhookSignature) {
            throw new AppError(400, "MISSING_HEADERS", "Missing required webhook headers");
        }

        if (!env.DODO_WEBHOOK_SECRET || !env.DODO_WEBHOOK_SECRET.trim()) {
            throw new AppError(500, "INVALID_SERVER_CONFIG", "DODO_WEBHOOK_SECRET is not configured");
        }

        // Reject stale timestamps
        const timestamp = parseInt(webhookTimestamp, 10);
        if (isNaN(timestamp)) {
            throw new AppError(400, "INVALID_TIMESTAMP", "Invalid webhook timestamp");
        }
        const now = Math.floor(Date.now() / 1000);
        if (Math.abs(now - timestamp) > TIMESTAMP_TOLERANCE_SECONDS) {
            throw new AppError(400, "STALE_TIMESTAMP", "Webhook timestamp is too old or too far in the future");
        }

        // Read body
        const body = await request.text();
        if (!body) {
            throw new AppError(400, "EMPTY_BODY", "Webhook body is empty");
        }

        // Verify signature
        const verified = await verifyWebhookSignature(
            body,
            webhookId,
            webhookTimestamp,
            webhookSignature,
            env.DODO_WEBHOOK_SECRET,
        );
        if (!verified) {
            throw new AppError(401, "INVALID_SIGNATURE", "Webhook signature verification failed");
        }

        // Parse payload
        let payload: Record<string, unknown>;
        try {
            payload = JSON.parse(body) as Record<string, unknown>;
        } catch {
            throw new AppError(400, "INVALID_BODY", "Webhook body is not valid JSON");
        }

        const eventType = (payload.type as string) || (payload.event_type as string) || "";
        if (!eventType) {
            throw new AppError(400, "MISSING_EVENT_TYPE", "Webhook payload is missing event type");
        }

        // Check for duplicate (idempotent)
        const existing = await env.STRATA_DB.prepare(
            "SELECT webhook_id, status FROM webhook_events WHERE webhook_id = ?",
        )
            .bind(webhookId)
            .first<{ webhook_id: string; status: string }>();

        if (existing) {
            // Already processed — return success (idempotent)
            return new Response(JSON.stringify({ status: "ok", deduplicated: true }), {
                status: 200,
                headers: { "Content-Type": "application/json" },
            });
        }

        // Persist event
        const eventTs = webhookTimestamp;
        await env.STRATA_DB.prepare(
            `INSERT INTO webhook_events (webhook_id, event_type, event_ts, payload_json, status)
       VALUES (?, ?, ?, ?, 'pending')`,
        )
            .bind(webhookId, eventType, eventTs, body)
            .run();

        // Return 200 quickly, process async
        ctx.waitUntil(
            processWebhookEvent(env, webhookId, eventType, payload, webhookTimestamp).catch((err: unknown) => {
                console.error(`[${requestId}] Projection error for ${webhookId}:`, err);
                // Mark as error for retry
                env.STRATA_DB.prepare(
                    "UPDATE webhook_events SET status = 'error' WHERE webhook_id = ?",
                )
                    .bind(webhookId)
                    .run()
                    .catch(() => { });
            }),
        );

        return new Response(JSON.stringify({ status: "ok" }), {
            status: 200,
            headers: { "Content-Type": "application/json" },
        });
    } catch (error) {
        return handleError(error, requestId);
    }
}

// Re-export for tests
export { verifyWebhookSignature, timingSafeEqual };
