// ---------------------------------------------------------------------------
// POST /v1/auth/email/verify
// ---------------------------------------------------------------------------

import type { AuthVerifyRequest, AuthVerifyResponse, Env } from "../types.js";
import { AppError, generateRequestId, handleError } from "../errors.js";
import { verifyEmailAuth } from "../auth.js";

export async function handleAuthEmailVerify(request: Request, env: Env): Promise<Response> {
    const requestId = generateRequestId();

    try {
        let body: AuthVerifyRequest;
        try {
            body = (await request.json()) as AuthVerifyRequest;
        } catch {
            throw new AppError(400, "INVALID_BODY", "Request body must be valid JSON");
        }

        const verified = await verifyEmailAuth(env, body.email, body.challenge_id, body.code);

        const response: AuthVerifyResponse = {
            session_token: verified.sessionToken,
            session_expires_at: verified.principal.sessionExpiresAt,
            user_id: verified.principal.userId,
            email: verified.principal.email,
        };

        return new Response(JSON.stringify(response), {
            status: 200,
            headers: { "Content-Type": "application/json" },
        });
    } catch (error) {
        return handleError(error, requestId);
    }
}
