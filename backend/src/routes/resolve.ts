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
import { requireAuthSession } from "../auth.js";
import { ensureDeviceSeat, resolveTierForUser } from "../user-entitlements.js";
import { checkAnomalies } from "../anomaly-detection.js";
import { checkRateLimit } from "../rate-limit.js";

// ---------------------------------------------------------------------------
// Rate limit constants for resolve endpoint
// ---------------------------------------------------------------------------
const RATE_LIMIT_MAX_IP = 30; // requests per IP per minute
const RATE_LIMIT_MAX_INSTALL = 10; // requests per install_id per minute

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

export async function handleResolve(
    request: Request,
    env: Env,
    ctx: ExecutionContext,
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

        const principal = await requireAuthSession(request, env);

        if (body.email && requireEmail(body.email) !== principal.email) {
            throw new AppError(
                403,
                "ACCOUNT_MISMATCH",
                "Resolve email must match the signed-in account",
            );
        }
        const email: string = principal.email;

        // -------------------------------------------------------------------
        // Local entitlement store first, Dodo API fallback
        // -------------------------------------------------------------------
        let tier: "free" | "pro" | "vip" = "free";
        let source: "store" | "fallback" = "fallback";

        const dodo = new DodoClient(env);
        const resolved = await resolveTierForUser(env, {
            userId: principal.userId,
            email: principal.email,
            dodo,
            allowProviderFallback: true,
        });
        tier = resolved.tier;
        source = resolved.source === "provider" ? "fallback" : "store";
        await ensureDeviceSeat(env, {
            userId: principal.userId,
            installId,
            tier,
        });

        console.log(`[${requestId}] resolve: email=${email} tier=${tier} source=${source}`);

        const ttl = parseTokenTTLSeconds(env);

        const token = await signToken({
            tier,
            sub: email,
            uid: principal.userId,
            installId,
            ttlSeconds: ttl,
            privateKeyHex: env.ENTITLEMENT_SIGNING_PRIVATE_KEY,
            installPubkeyHash: proof.installPubkeyHash,
            kid: env.ENTITLEMENT_SIGNING_KEY_ID || "default",
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

            ctx.waitUntil(checkAnomalies(env, { userId: principal.userId, installId, action: "resolve" }));
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
