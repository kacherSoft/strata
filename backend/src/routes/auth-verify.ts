// ---------------------------------------------------------------------------
// POST /v1/auth/email/verify
// ---------------------------------------------------------------------------

import type { AuthVerifyRequest, AuthVerifyResponse, Env } from "../types.js";
import { AppError, generateRequestId, handleError } from "../errors.js";
import { checkAuthRateLimit, verifyEmailAuth } from "../auth.js";

const VERIFY_RATE_LIMIT_MAX = 30;
const VERIFY_RATE_LIMIT_WINDOW_SECONDS = 60;

export async function handleAuthEmailVerify(request: Request, env: Env): Promise<Response> {
    const requestId = generateRequestId();

    try {
        const clientIp = request.headers.get("CF-Connecting-IP") || "unknown";
        const allowed = await checkAuthRateLimit(
            env,
            `verify:ip:${clientIp}`,
            VERIFY_RATE_LIMIT_MAX,
            VERIFY_RATE_LIMIT_WINDOW_SECONDS,
        );
        if (!allowed) {
            throw new AppError(429, "RATE_LIMITED", "Too many verification attempts");
        }

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
