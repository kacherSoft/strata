// ---------------------------------------------------------------------------
// Strata Backend — Cloudflare Worker entry point
// ---------------------------------------------------------------------------

import type { Env } from "./types.js";
import { errorResponse, generateRequestId } from "./errors.js";
import { handleResolve } from "./routes/resolve.js";
import { handlePortalSession } from "./routes/portal.js";
import { handleWebhook } from "./routes/webhook.js";
import { handleCheckoutSession } from "./routes/checkout.js";
import { handleInstallRegister } from "./routes/install.js";
import { handleInstallChallenge } from "./routes/challenge.js";
import { handleRestore } from "./routes/restore.js";

export default {
    async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
        const url = new URL(request.url);
        const path = url.pathname;
        const method = request.method;

        // CORS preflight
        if (method === "OPTIONS") {
            return new Response(null, {
                status: 204,
                headers: corsHeaders(),
            });
        }

        let response: Response;

        // Route matching
        if (method === "POST" && path === "/v1/entitlements/resolve") {
            response = await handleResolve(request, env);
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
            response = await handleRestore(request, env);
        } else if (path === "/health") {
            response = new Response(JSON.stringify({ status: "ok" }), {
                status: 200,
                headers: { "Content-Type": "application/json" },
            });
        } else {
            const requestId = generateRequestId();
            response = errorResponse(404, "NOT_FOUND", "Endpoint not found", requestId);
        }

        // Attach CORS headers to all responses
        const corsResp = new Response(response.body, response);
        for (const [key, value] of Object.entries(corsHeaders())) {
            corsResp.headers.set(key, value);
        }
        return corsResp;
    },
} satisfies ExportedHandler<Env>;

// ---------------------------------------------------------------------------
// CORS headers (permissive for app-to-worker communication)
// ---------------------------------------------------------------------------

function corsHeaders(): Record<string, string> {
    return {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type",
        "Access-Control-Max-Age": "86400",
    };
}
