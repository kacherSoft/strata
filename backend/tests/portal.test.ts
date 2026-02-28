// ---------------------------------------------------------------------------
// Tests for POST /v1/customer-portal/session
// ---------------------------------------------------------------------------

import { describe, it, expect, vi, beforeEach } from "vitest";
vi.mock("../src/install-proof.js", () => ({
    verifyInstallProof: vi.fn(async () => ({ installPubkeyHash: "test_hash" })),
}));
import { handlePortalSession } from "../src/routes/portal.js";
import { verifyInstallProof } from "../src/install-proof.js";
import type { Env } from "../src/types.js";

let hasPurchaseLink = true;

function makeEnv(overrides: Partial<Env> = {}): Env {
    const mockStatement = {
        bind: () => mockStatement,
        first: async () => {
            if (hasPurchaseLink) return { id: 1 };
            return null;
        },
        run: async () => ({ success: true }),
    };

    return {
        STRATA_DB: {
            prepare: () => mockStatement,
        } as unknown as D1Database,
        DODO_API_KEY: "test-api-key",
        DODO_WEBHOOK_SECRET: "test-webhook-secret",
        ENTITLEMENT_SIGNING_PRIVATE_KEY: "test-key",
        ENVIRONMENT: "test",
        DODO_BASE_URL: "https://test.dodopayments.com",
        TOKEN_TTL_SECONDS: "3600",
        ...overrides,
    };
}

function makeRequest(body: Record<string, unknown>): Request {
    const payload = {
        email: "pro@example.com",
        install_id: "550e8400-e29b-41d4-a716-446655440000",
        challenge_id: "4a394f45-1792-4ae9-a18f-bf7ce33420b1",
        nonce_signature: "MEUCIGiZmyydFJXrw+2Gb6G6drx7M0w4mU0QWABk34rv5AtVAiEA7z4FzQxM0d8QnG4qA8xH7wBqWtlX7JSD8j2g6a8H+HU=",
        ...body,
    };

    return new Request("https://api.test/v1/customer-portal/session", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
    });
}

const mockFetch = vi.fn();
vi.stubGlobal("fetch", mockFetch);

describe("POST /v1/customer-portal/session", () => {
    beforeEach(() => {
        vi.clearAllMocks();
        hasPurchaseLink = true;
        vi.mocked(verifyInstallProof).mockResolvedValue({ installPubkeyHash: "test_hash" });

        // Dodo customer lookup + portal session
        mockFetch.mockResolvedValueOnce(
            new Response(
                JSON.stringify({
                    items: [{ customer_id: "cust_123", email: "pro@example.com" }],
                }),
                { status: 200 },
            ),
        );
        mockFetch.mockResolvedValueOnce(
            new Response(
                JSON.stringify({
                    link: "https://portal.dodopayments.com/session/abc",
                }),
                { status: 200 },
            ),
        );
    });

    it("should require install proof fields", async () => {
        const req = makeRequest({ challenge_id: "" });
        const res = await handlePortalSession(req, makeEnv());
        expect(res.status).toBe(400);
    });

    it("should return verification required when install/email link is missing", async () => {
        hasPurchaseLink = false;
        const req = makeRequest({});
        const res = await handlePortalSession(req, makeEnv());
        expect(res.status).toBe(403);
        const body = await res.json() as { error_code: string };
        expect(body.error_code).toBe("VERIFICATION_REQUIRED");
    });

    it("should return portal url when install proof and ownership are valid", async () => {
        const req = makeRequest({});
        const res = await handlePortalSession(req, makeEnv());
        expect(res.status).toBe(200);
        const body = await res.json() as { portal_url: string };
        expect(body.portal_url).toBe("https://portal.dodopayments.com/session/abc");
    });
});
