// ---------------------------------------------------------------------------
// Strata Backend — Cloudflare Worker entry point
// ---------------------------------------------------------------------------

import type { Env } from "./types.js";
import { errorResponse, generateRequestId } from "./errors.js";
import { handleScheduledCleanup } from "./scheduled-cleanup.js";
import { handleResolve } from "./routes/resolve.js";
import { handlePortalSession } from "./routes/portal.js";
import { handleWebhook } from "./routes/webhook.js";
import { handleCheckoutSession } from "./routes/checkout.js";
import { handleInstallRegister } from "./routes/install.js";
import { handleInstallChallenge } from "./routes/challenge.js";
import { handleRestore } from "./routes/restore.js";
import { handleAuthEmailStart } from "./routes/auth-start.js";
import { handleAuthEmailVerify } from "./routes/auth-verify.js";
import { handleAuthSessionRevoke } from "./routes/auth-session-revoke.js";
import { handleDevicesList } from "./routes/devices-list.js";
import { handleDevicesRevoke } from "./routes/devices-revoke.js";

export default {
    async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
        const url = new URL(request.url);
        const path = url.pathname;
        const method = request.method;

        // CORS preflight — not needed for native macOS app; reject OPTIONS
        if (method === "OPTIONS") {
            return new Response(null, { status: 405 });
        }

        // Body size limit — reject large POST requests before any buffering
        if (method === "POST") {
            const contentLength = parseInt(request.headers.get("Content-Length") || "0", 10);
            if (contentLength > 1_048_576) { // 1MB
                const requestId = generateRequestId();
                return addCorsHeaders(errorResponse(413, "BODY_TOO_LARGE", "Request body exceeds size limit", requestId));
            }
        }

        // Content-Type check — require application/json for all POSTs except webhook
        if (method === "POST" && path !== "/v1/webhooks/dodo") {
            const contentType = request.headers.get("Content-Type") || "";
            if (!contentType.includes("application/json")) {
                const requestId = generateRequestId();
                return addCorsHeaders(errorResponse(415, "UNSUPPORTED_MEDIA_TYPE", "Content-Type must be application/json", requestId));
            }
        }

        let response: Response;

        // Route matching
        if (method === "POST" && path === "/v1/entitlements/resolve") {
            response = await handleResolve(request, env, ctx);
        } else if (method === "POST" && path === "/v1/customer-portal/session") {
            response = await handlePortalSession(request, env);
        } else if (method === "POST" && path === "/v1/webhooks/dodo") {
            response = await handleWebhook(request, env, ctx);
        } else if (method === "POST" && path === "/v1/checkout-sessions") {
            response = await handleCheckoutSession(request, env);
        } else if (method === "POST" && path === "/v1/installs/register") {
            response = await handleInstallRegister(request, env);
        } else if (method === "POST" && path === "/v1/installs/challenge") {
            response = await handleInstallChallenge(request, env);
        } else if (method === "POST" && path === "/v1/purchases/restore") {
            response = await handleRestore(request, env, ctx);
        } else if (method === "POST" && path === "/v1/auth/email/start") {
            response = await handleAuthEmailStart(request, env);
        } else if (method === "POST" && path === "/v1/auth/email/verify") {
            response = await handleAuthEmailVerify(request, env);
        } else if (method === "POST" && path === "/v1/auth/session/revoke") {
            response = await handleAuthSessionRevoke(request, env);
        } else if (method === "GET" && path === "/v1/devices") {
            response = await handleDevicesList(request, env);
        } else if (method === "POST" && path === "/v1/devices/revoke") {
            response = await handleDevicesRevoke(request, env);
        } else if (path === "/health") {
            response = new Response(JSON.stringify({ status: "ok" }), {
                status: 200,
                headers: { "Content-Type": "application/json" },
            });
        } else {
            const requestId = generateRequestId();
            response = errorResponse(404, "NOT_FOUND", "Endpoint not found", requestId);
        }

        return addCorsHeaders(response);
    },
    async scheduled(_event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
        ctx.waitUntil(handleScheduledCleanup(env));
    },
} satisfies ExportedHandler<Env>;

// ---------------------------------------------------------------------------
// CORS helpers — intentionally empty; Strata is a native macOS app.
// URLSession does not enforce CORS. Add origin-specific headers here
// only when browser-based admin tools are introduced.
// ---------------------------------------------------------------------------

function corsHeaders(): Record<string, string> {
    return {};
}

function addCorsHeaders(response: Response): Response {
    const corsResp = new Response(response.body, response);
    for (const [key, value] of Object.entries(corsHeaders())) {
        corsResp.headers.set(key, value);
    }
    return corsResp;
}
