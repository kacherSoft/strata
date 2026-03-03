// ---------------------------------------------------------------------------
// GET /v1/devices
// ---------------------------------------------------------------------------

import type { DevicesListResponse, DeviceInfo, Env } from "../types.js";
import { generateRequestId, handleError } from "../errors.js";
import { requireAuthSession } from "../auth.js";
import { listUserDevices } from "../user-entitlements.js";

export async function handleDevicesList(
    request: Request,
    env: Env,
): Promise<Response> {
    const requestId = generateRequestId();

    try {
        const principal = await requireAuthSession(request, env);
        const rows = await listUserDevices(env, principal.userId);

        const devices: DeviceInfo[] = rows.map((row) => ({
            install_id: row.install_id,
            nickname: row.nickname,
            first_seen_at: row.first_seen_at,
            last_seen_at: row.last_seen_at,
            revoked_at: row.revoked_at,
            active: row.revoked_at === null,
        }));

        const response: DevicesListResponse = { devices };
        return new Response(JSON.stringify(response), {
            status: 200,
            headers: { "Content-Type": "application/json" },
        });
    } catch (error) {
        return handleError(error, requestId);
    }
}
