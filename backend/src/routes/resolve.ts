// ---------------------------------------------------------------------------
// POST /v1/entitlements/resolve
// ---------------------------------------------------------------------------

import type { Env, ResolveRequest, ResolveResponse } from "../types.js";
import { AppError, errorResponse, generateRequestId, handleError } from "../errors.js";
import { DodoClient } from "../dodo-client.js";
import { signToken } from "../signing.js";
import { parseTokenTTLSeconds } from "../config.js";
import { verifyInstallProof } from "../install-proof.js";
import { requireEmail, requireNonEmptyString, requireUUID } from "../validation.js";
import { authRequiredForResolve, optionalAuthSession, requireAuthSession } from "../auth.js";
import { ensureDeviceSeat, resolveTierForUser } from "../user-entitlements.js";

// ---------------------------------------------------------------------------
// D1-backed rate limiter (shared across Worker isolates)
// ---------------------------------------------------------------------------
const RATE_LIMIT_WINDOW_SECONDS = 60; // 1 minute
const RATE_LIMIT_MAX_IP = 30; // requests per IP per window
const RATE_LIMIT_MAX_INSTALL = 10; // requests per install_id per window
const RATE_LIMIT_CLEANUP_INTERVAL_MS = 60_000;

let lastCleanupMs = 0;

async function checkRateLimit(
    env: Env,
    key: string,
    max: number,
): Promise<boolean> {
    const nowMs = Date.now();
    const nowSec = Math.floor(nowMs / 1000);
    const window = Math.floor(nowSec / RATE_LIMIT_WINDOW_SECONDS);
    const bucketKey = `${key}:${window}`;
    const expiresAt = nowSec + RATE_LIMIT_WINDOW_SECONDS * 2;

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

        await cleanupRateLimitRows(env, nowMs, nowSec);
        return (bucket?.request_count ?? 0) <= max;
    } catch {
        // Fail open if migration is missing; availability is preferable to lockouts.
        return true;
    }
}

async function cleanupRateLimitRows(env: Env, nowMs: number, nowSec: number): Promise<void> {
    if (nowMs - lastCleanupMs < RATE_LIMIT_CLEANUP_INTERVAL_MS) return;
    lastCleanupMs = nowMs;

    try {
        await env.STRATA_DB.prepare(
            `DELETE FROM resolve_rate_limits
             WHERE bucket_key IN (
                SELECT bucket_key
                FROM resolve_rate_limits
                WHERE expires_at < ?
                ORDER BY expires_at ASC
                LIMIT 500
             )`,
        )
            .bind(nowSec)
            .run();
    } catch {
        // Best effort cleanup only.
    }
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

export async function handleResolve(
    request: Request,
    env: Env,
): Promise<Response> {
    const requestId = generateRequestId();

    try {
        // Rate limit by IP
        const clientIP = request.headers.get("CF-Connecting-IP") ?? "unknown";
        if (!(await checkRateLimit(env, `ip:${clientIP}`, RATE_LIMIT_MAX_IP))) {
            return errorResponse(429, "RATE_LIMITED", "Too many requests", requestId);
        }

        // Parse body
        let body: ResolveRequest;
        try {
            body = (await request.json()) as ResolveRequest;
        } catch {
            throw new AppError(400, "INVALID_BODY", "Request body must be valid JSON");
        }

        const installId = requireUUID(body.install_id, "install_id", "INVALID_INSTALL_ID");
        const challengeId = requireNonEmptyString(
            body.challenge_id,
            "INVALID_CHALLENGE",
            "challenge_id is required",
        );
        const nonceSignature = requireNonEmptyString(
            body.nonce_signature,
            "INVALID_INSTALL_PROOF",
            "nonce_signature is required",
        );

        // Rate limit by install_id
        if (!(await checkRateLimit(env, `install:${installId}`, RATE_LIMIT_MAX_INSTALL))) {
            return errorResponse(429, "RATE_LIMITED", "Too many requests", requestId);
        }

        // Require install-bound proof before issuing entitlements.
        const proof = await verifyInstallProof(env, installId, challengeId, nonceSignature);

        const principal = authRequiredForResolve(env)
            ? await requireAuthSession(request, env)
            : await optionalAuthSession(request, env);

        let email: string;
        if (principal) {
            if (body.email && requireEmail(body.email) !== principal.email) {
                throw new AppError(
                    403,
                    "ACCOUNT_MISMATCH",
                    "Resolve email must match the signed-in account",
                );
            }
            email = principal.email;
        } else {
            if (authRequiredForResolve(env)) {
                throw new AppError(401, "AUTH_REQUIRED", "Sign in is required to resolve entitlements");
            }
            email = requireEmail(body.email);
        }

        // -------------------------------------------------------------------
        // Phase 2: Local entitlement store first, Dodo API fallback
        // -------------------------------------------------------------------
        let tier: "free" | "pro" | "vip" = "free";
        let source: "store" | "fallback" = "fallback";

        if (principal) {
            const dodo = new DodoClient(env);
            const resolved = await resolveTierForUser(env, {
                userId: principal.userId,
                email: principal.email,
                dodo,
                allowProviderFallback: !authRequiredForResolve(env),
            });
            tier = resolved.tier;
            source = resolved.source === "provider" ? "fallback" : "store";
            await ensureDeviceSeat(env, {
                userId: principal.userId,
                installId,
                tier,
            });
        } else {
            // Legacy fallback (disabled once AUTH_REQUIRED_FOR_RESOLVE=true in all envs)
            const localEntitlement = await env.STRATA_DB.prepare(
                "SELECT tier, state FROM entitlements WHERE subject_type = 'email' AND subject_id = ? AND state = 'active'",
            )
                .bind(email)
                .first<{ tier: string; state: string }>();

            if (localEntitlement) {
                tier = localEntitlement.tier as typeof tier;
                source = "store";
            } else {
                const dodo = new DodoClient(env);
                const subscription = await dodo.findActiveSubscription(email);
                tier = subscription ? "pro" : "free";
                source = "fallback";
            }
        }

        console.log(`[${requestId}] resolve: email=${email} tier=${tier} source=${source}`);

        const ttl = parseTokenTTLSeconds(env);

        const token = await signToken({
            tier,
            sub: email,
            uid: principal?.userId,
            installId,
            ttlSeconds: ttl,
            privateKeyHex: env.ENTITLEMENT_SIGNING_PRIVATE_KEY,
            installPubkeyHash: proof.installPubkeyHash,
        });

        if (tier !== "free") {
            await env.STRATA_DB.prepare(
                `INSERT INTO purchase_links (install_id, customer_email, created_at, updated_at)
                 VALUES (?, ?, datetime('now'), datetime('now'))
                 ON CONFLICT(install_id) DO UPDATE SET
                   customer_email = COALESCE(purchase_links.customer_email, excluded.customer_email),
                   updated_at = datetime('now')`,
            )
                .bind(installId, email)
                .run();
        }

        const response: ResolveResponse = { token };
        return new Response(JSON.stringify(response), {
            status: 200,
            headers: { "Content-Type": "application/json" },
        });
    } catch (error) {
        return handleError(error, requestId);
    }
}
