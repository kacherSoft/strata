// ---------------------------------------------------------------------------
// POST /v1/customer-portal/session
// ---------------------------------------------------------------------------

import type { Env, PortalSessionRequest, PortalSessionResponse } from "../types.js";
import { AppError, handleError, generateRequestId } from "../errors.js";
import { DodoClient } from "../dodo-client.js";
import { verifyInstallProof } from "../install-proof.js";
import { requireEmail, requireNonEmptyString, requireUUID } from "../validation.js";

export async function handlePortalSession(
    request: Request,
    env: Env,
): Promise<Response> {
    const requestId = generateRequestId();

    try {
        let body: PortalSessionRequest;
        try {
            body = (await request.json()) as PortalSessionRequest;
        } catch {
            throw new AppError(400, "INVALID_BODY", "Request body must be valid JSON");
        }

        const email = requireEmail(body.email);
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

        await verifyInstallProof(env, installId, challengeId, nonceSignature);

        // Ensure this install is linked to the email before issuing portal access.
        const link = await env.STRATA_DB.prepare(
            `SELECT id
             FROM purchase_links
             WHERE install_id = ? AND customer_email = ?
             LIMIT 1`,
        )
            .bind(installId, email)
            .first<{ id: number }>();

        if (!link) {
            throw new AppError(
                403,
                "VERIFICATION_REQUIRED",
                "Install is not linked to this customer. Restore purchases first",
            );
        }

        const dodo = new DodoClient(env);
        const portalUrl = await dodo.createPortalSession(email);

        const response: PortalSessionResponse = { portal_url: portalUrl };
        return new Response(JSON.stringify(response), {
            status: 200,
            headers: { "Content-Type": "application/json" },
        });
    } catch (error) {
        return handleError(error, requestId);
    }
}
