// ---------------------------------------------------------------------------
// Tests for device management endpoints
// ---------------------------------------------------------------------------

import { describe, it, expect, vi, beforeEach } from "vitest";
import { AppError } from "../src/errors.js";
import { handleDevicesList } from "../src/routes/devices-list.js";
import { handleDevicesRevoke } from "../src/routes/devices-revoke.js";
import type { Env } from "../src/types.js";
import { requireAuthSession } from "../src/auth.js";
import { listUserDevices, revokeUserDevice } from "../src/user-entitlements.js";

vi.mock("../src/auth.js", () => ({
    requireAuthSession: vi.fn(),
}));

vi.mock("../src/user-entitlements.js", () => ({
    listUserDevices: vi.fn(),
    revokeUserDevice: vi.fn(),
}));

const TEST_ENV = {
    STRATA_DB: {} as D1Database,
    DODO_API_KEY: "test",
    DODO_WEBHOOK_SECRET: "test",
    ENTITLEMENT_SIGNING_PRIVATE_KEY: "test",
    ENVIRONMENT: "test",
    DODO_BASE_URL: "https://test.dodopayments.com",
    TOKEN_TTL_SECONDS: "3600",
} satisfies Env;

describe("device routes", () => {
    beforeEach(() => {
        vi.clearAllMocks();
        vi.mocked(requireAuthSession).mockResolvedValue({
            userId: "user_123",
            email: "user@example.com",
            sessionId: "sess_123",
            sessionExpiresAt: Math.floor(Date.now() / 1000) + 3600,
        });
    });

    it("lists devices for the signed-in account", async () => {
        vi.mocked(listUserDevices).mockResolvedValue([
            {
                install_id: "550e8400-e29b-41d4-a716-446655440000",
                nickname: "MacBook Pro",
                first_seen_at: 100,
                last_seen_at: 200,
                revoked_at: null,
            },
            {
                install_id: "550e8400-e29b-41d4-a716-446655440001",
                nickname: "Old iMac",
                first_seen_at: 50,
                last_seen_at: 90,
                revoked_at: 91,
            },
        ]);

        const request = new Request("https://api.test/v1/devices", { method: "GET" });
        const response = await handleDevicesList(request, TEST_ENV);
        expect(response.status).toBe(200);

        const body = await response.json() as {
            devices: Array<{ install_id: string; active: boolean }>;
        };
        expect(body.devices).toHaveLength(2);
        expect(body.devices[0].install_id).toBe("550e8400-e29b-41d4-a716-446655440000");
        expect(body.devices[0].active).toBe(true);
        expect(body.devices[1].install_id).toBe("550e8400-e29b-41d4-a716-446655440001");
        expect(body.devices[1].active).toBe(false);
    });

    it("returns auth required when session is missing", async () => {
        vi.mocked(requireAuthSession).mockRejectedValue(
            new AppError(401, "AUTH_REQUIRED", "A valid account session is required"),
        );

        const request = new Request("https://api.test/v1/devices", { method: "GET" });
        const response = await handleDevicesList(request, TEST_ENV);
        expect(response.status).toBe(401);

        const body = await response.json() as { error_code: string };
        expect(body.error_code).toBe("AUTH_REQUIRED");
    });

    it("revokes an active device for the signed-in account", async () => {
        vi.mocked(revokeUserDevice).mockResolvedValue();

        const request = new Request("https://api.test/v1/devices/revoke", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                install_id: "550e8400-e29b-41d4-a716-446655440000",
            }),
        });

        const response = await handleDevicesRevoke(request, TEST_ENV);
        expect(response.status).toBe(200);
        expect(vi.mocked(revokeUserDevice)).toHaveBeenCalledWith(
            TEST_ENV,
            "user_123",
            "550e8400-e29b-41d4-a716-446655440000",
        );
    });

    it("validates install_id when revoking device", async () => {
        const request = new Request("https://api.test/v1/devices/revoke", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ install_id: "not-a-uuid" }),
        });

        const response = await handleDevicesRevoke(request, TEST_ENV);
        expect(response.status).toBe(400);
        const body = await response.json() as { error_code: string };
        expect(body.error_code).toBe("INVALID_INSTALL_ID");
    });
});
