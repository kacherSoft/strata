// ---------------------------------------------------------------------------
// POST /v1/devices/revoke
// ---------------------------------------------------------------------------

import type { Env, RevokeDeviceRequest } from "../types.js";
import { AppError, generateRequestId, handleError } from "../errors.js";
import { requireUUID } from "../validation.js";
import { requireAuthSession } from "../auth.js";
import { revokeUserDevice, clearUserEntitlementCache } from "../user-entitlements.js";

export async function handleDevicesRevoke(
    request: Request,
    env: Env,
): Promise<Response> {
    const requestId = generateRequestId();

    try {
        let body: RevokeDeviceRequest;
        try {
            body = (await request.json()) as RevokeDeviceRequest;
        } catch {
            throw new AppError(400, "INVALID_BODY", "Request body must be valid JSON");
        }

        const installId = requireUUID(
            body.install_id,
            "install_id",
            "INVALID_INSTALL_ID",
        );
        const principal = await requireAuthSession(request, env);
        await revokeUserDevice(env, principal.userId, installId);

        // Clear cached entitlement so next resolve re-checks Dodo for real status
        await clearUserEntitlementCache(env, principal.userId, principal.email);

        return new Response(JSON.stringify({ revoked: true }), {
            status: 200,
            headers: { "Content-Type": "application/json" },
        });
    } catch (error) {
        return handleError(error, requestId);
    }
}
