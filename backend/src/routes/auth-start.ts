// ---------------------------------------------------------------------------
// POST /v1/auth/email/start
// ---------------------------------------------------------------------------

import type { AuthStartRequest, AuthStartResponse, Env } from "../types.js";
import { AppError, generateRequestId, handleError } from "../errors.js";
import { startEmailAuth } from "../auth.js";

export async function handleAuthEmailStart(request: Request, env: Env): Promise<Response> {
    const requestId = generateRequestId();

    try {
        let body: AuthStartRequest;
        try {
            body = (await request.json()) as AuthStartRequest;
        } catch {
            throw new AppError(400, "INVALID_BODY", "Request body must be valid JSON");
        }

        const clientIP = request.headers.get("CF-Connecting-IP") ?? "unknown";
        const started = await startEmailAuth(env, body.email, clientIP);

        const response: AuthStartResponse = {
            challenge_id: started.challengeId,
            expires_at: started.expiresAt,
            delivery: started.delivery,
        };

        return new Response(JSON.stringify(response), {
            status: 200,
            headers: { "Content-Type": "application/json" },
        });
    } catch (error) {
        return handleError(error, requestId);
    }
}
