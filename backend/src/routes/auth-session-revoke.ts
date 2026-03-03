// ---------------------------------------------------------------------------
// POST /v1/auth/session/revoke
// ---------------------------------------------------------------------------

import type { Env } from "../types.js";
import { generateRequestId, handleError } from "../errors.js";
import { revokeAuthSession } from "../auth.js";

export async function handleAuthSessionRevoke(request: Request, env: Env): Promise<Response> {
    const requestId = generateRequestId();

    try {
        await revokeAuthSession(request, env);

        return new Response(JSON.stringify({ revoked: true }), {
            status: 200,
            headers: { "Content-Type": "application/json" },
        });
    } catch (error) {
        return handleError(error, requestId);
    }
}
