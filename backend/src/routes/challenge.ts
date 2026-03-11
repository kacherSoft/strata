// ---------------------------------------------------------------------------
// POST /v1/installs/challenge — issue nonce challenge for install proof
// ---------------------------------------------------------------------------

import type { Env, InstallChallengeRequest, InstallChallengeResponse } from "../types.js";
import { AppError, generateRequestId, handleError } from "../errors.js";
import { createInstallChallenge } from "../install-proof.js";
import { requireUUID } from "../validation.js";

export async function handleInstallChallenge(
    request: Request,
    env: Env,
): Promise<Response> {
    const requestId = generateRequestId();

    try {
        let body: InstallChallengeRequest;
        try {
            body = (await request.json()) as InstallChallengeRequest;
        } catch {
            throw new AppError(400, "INVALID_BODY", "Request body must be valid JSON");
        }

        const installId = requireUUID(body.install_id, "install_id", "INVALID_INSTALL_ID");

        const challenge = await createInstallChallenge(env, installId);
        console.log(`[createChallenge] id=${challenge.challenge_id} install=${installId}`);
        const response: InstallChallengeResponse = challenge;
        return new Response(JSON.stringify(response), {
            status: 200,
            headers: { "Content-Type": "application/json" },
        });
    } catch (error) {
        return handleError(error, requestId);
    }
}
