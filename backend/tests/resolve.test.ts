// ---------------------------------------------------------------------------
// Tests for POST /v1/entitlements/resolve
// ---------------------------------------------------------------------------

import { describe, it, expect, vi, beforeEach } from "vitest";
vi.mock("../src/install-proof.js", () => ({
    verifyInstallProof: vi.fn(async () => ({ installPubkeyHash: "test_install_pubkey_hash" })),
}));
import { handleResolve } from "../src/routes/resolve.js";
import { verifyToken, publicKeyFromPrivate } from "../src/signing.js";
import { verifyInstallProof } from "../src/install-proof.js";
import type { Env } from "../src/types.js";

const TEST_PRIVATE_KEY_HEX =
    "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60";

const TEST_USER_ID = "user-resolve-123";
const TEST_EMAIL = "test@example.com";
const VALID_SESSION_TOKEN = "valid-session-token";

let mockSessionValid = true;

function makeD1Mock(): D1Database {
    return {
        prepare: (sql: string) => {
            const stmt = {
                bind: () => stmt,
                first: async () => {
                    if (sql.includes("FROM account_sessions")) {
                        if (!mockSessionValid) return null;
                        return {
                            session_id: "sess-resolve-1",
                            user_id: TEST_USER_ID,
                            expires_at: Math.floor(Date.now() / 1000) + 86400,
                            email_normalized: TEST_EMAIL,
                        };
                    }
                    if (sql.includes("user_entitlements")) {
                        return null;
                    }
                    if (sql.includes("FROM user_devices")) {
                        return { count: 0 };
                    }
                    return null;
                },
                all: async () => ({ results: [] }),
                run: async () => ({ success: true, meta: { changes: 1 } }),
            };
            return stmt;
        },
    } as unknown as D1Database;
}

function makeEnv(overrides: Partial<Env> = {}): Env {
    return {
        STRATA_DB: makeD1Mock(),
        DODO_API_KEY: "test-api-key",
        DODO_WEBHOOK_SECRET: "test-webhook-secret",
        ENTITLEMENT_SIGNING_PRIVATE_KEY: TEST_PRIVATE_KEY_HEX,
        ENVIRONMENT: "test",
        DODO_BASE_URL: "https://test.dodopayments.com",
        TOKEN_TTL_SECONDS: "3600",
        ...overrides,
    };
}

// Minimal ctx mock for waitUntil
function makeCtx(): ExecutionContext {
    return { waitUntil: vi.fn(), passThroughOnException: vi.fn() } as unknown as ExecutionContext;
}

function makeRequest(body: Record<string, unknown>, sessionToken?: string): Request {
    const payload = {
        challenge_id: "4a394f45-1792-4ae9-a18f-bf7ce33420b1",
        nonce_signature: "MEUCIQDm5H9XbQ2x8Xj5gD8rVq5S2sQ4Myp9A9SLM2w3bTWq1wIgE2Pzq4w8Xbq8WwRkW5oloxhAa6oWn3wy4ABQ0kQmE4c=",
        ...body,
    };
    const headers: Record<string, string> = {
        "Content-Type": "application/json",
        "CF-Connecting-IP": "127.0.0.1",
    };
    if (sessionToken) {
        headers["Authorization"] = `Bearer ${sessionToken}`;
    }
    return new Request("https://api.test/v1/entitlements/resolve", {
        method: "POST",
        headers,
        body: JSON.stringify(payload),
    });
}

// Mock global fetch
const mockFetch = vi.fn();
vi.stubGlobal("fetch", mockFetch);

describe("POST /v1/entitlements/resolve", () => {
    beforeEach(() => {
        vi.clearAllMocks();
        mockSessionValid = true;
        vi.mocked(verifyInstallProof).mockResolvedValue({
            installPubkeyHash: "test_install_pubkey_hash",
        });
    });

    it("should return 401 without auth token", async () => {
        const req = makeRequest({ install_id: "550e8400-e29b-41d4-a716-446655440000" });
        const res = await handleResolve(req, makeEnv(), makeCtx());
        expect(res.status).toBe(401);
        const body = await res.json() as { error_code: string };
        expect(body.error_code).toBe("AUTH_REQUIRED");
    });

    it("should return 401 with invalid session token", async () => {
        mockSessionValid = false;
        const req = makeRequest(
            { install_id: "550e8400-e29b-41d4-a716-446655440000" },
            VALID_SESSION_TOKEN,
        );
        const res = await handleResolve(req, makeEnv(), makeCtx());
        expect(res.status).toBe(401);
        const body = await res.json() as { error_code: string };
        expect(body.error_code).toBe("INVALID_SESSION");
    });

    it("should reject missing install_id", async () => {
        const req = makeRequest({}, VALID_SESSION_TOKEN);
        const res = await handleResolve(req, makeEnv(), makeCtx());
        expect(res.status).toBe(400);
        const body = await res.json() as { error_code: string };
        expect(body.error_code).toBe("INVALID_INSTALL_ID");
    });

    it("should reject non-UUID install_id", async () => {
        const req = makeRequest(
            { install_id: "not-a-uuid" },
            VALID_SESSION_TOKEN,
        );
        const res = await handleResolve(req, makeEnv(), makeCtx());
        expect(res.status).toBe(400);
        const body = await res.json() as { error_code: string };
        expect(body.error_code).toBe("INVALID_INSTALL_ID");
    });

    it("should reject non-JSON body", async () => {
        const req = new Request("https://api.test/v1/entitlements/resolve", {
            method: "POST",
            headers: {
                "Content-Type": "text/plain",
                "CF-Connecting-IP": "127.0.0.1",
                "Authorization": `Bearer ${VALID_SESSION_TOKEN}`,
            },
            body: "this is not json",
        });
        const res = await handleResolve(req, makeEnv(), makeCtx());
        expect(res.status).toBe(400);
        const body = await res.json() as { error_code: string };
        expect(body.error_code).toBe("INVALID_BODY");
    });

    it("should return free tier token when no subscription found", async () => {
        // Mock: no customers found
        mockFetch.mockResolvedValueOnce(
            new Response(JSON.stringify({ items: [] }), { status: 200 }),
        );

        const req = makeRequest(
            { install_id: "550e8400-e29b-41d4-a716-446655440000" },
            VALID_SESSION_TOKEN,
        );
        const res = await handleResolve(req, makeEnv(), makeCtx());
        expect(res.status).toBe(200);

        const body = await res.json() as { token: string };
        expect(body.token).toBeDefined();

        const pubKey = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        const claims = await verifyToken(body.token, pubKey);
        expect(claims.tier).toBe("free");
        expect(claims.sub).toBe(TEST_EMAIL);
        expect(claims.install_id).toBe("550e8400-e29b-41d4-a716-446655440000");
        expect(claims.install_pubkey_hash).toBe("test_install_pubkey_hash");
    });

    it("should return pro tier token when active subscription exists", async () => {
        // Mock: customer found
        mockFetch.mockResolvedValueOnce(
            new Response(
                JSON.stringify({
                    items: [{ customer_id: "cust_123", email: TEST_EMAIL }],
                }),
                { status: 200 },
            ),
        );
        // Mock: active subscription found
        mockFetch.mockResolvedValueOnce(
            new Response(
                JSON.stringify({
                    items: [
                        {
                            status: "active",
                            product_id: "pdt_0NZEvu9tI0aecVEYkmxOH", // proMonthly
                            next_billing_date: "2026-03-26T00:00:00Z",
                            customer: {
                                customer_id: "cust_123",
                                email: TEST_EMAIL,
                            },
                        },
                    ],
                }),
                { status: 200 },
            ),
        );

        const req = makeRequest(
            { install_id: "550e8400-e29b-41d4-a716-446655440000" },
            VALID_SESSION_TOKEN,
        );
        const res = await handleResolve(req, makeEnv(), makeCtx());
        expect(res.status).toBe(200);

        const body = await res.json() as { token: string };
        const pubKey = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        const claims = await verifyToken(body.token, pubKey);
        expect(claims.tier).toBe("pro");
        expect(claims.sub).toBe(TEST_EMAIL);
        expect(claims.install_pubkey_hash).toBe("test_install_pubkey_hash");
    });

    it("should handle provider errors gracefully", async () => {
        mockFetch.mockResolvedValueOnce(
            new Response("Internal Server Error", { status: 500 }),
        );

        const req = makeRequest(
            { install_id: "550e8400-e29b-41d4-a716-446655440000" },
            VALID_SESSION_TOKEN,
        );
        const res = await handleResolve(req, makeEnv(), makeCtx());
        expect(res.status).toBe(502);
        const body = await res.json() as { error_code: string; message: string };
        expect(body.error_code).toBe("PROVIDER_ERROR");
        // Must not leak provider error body
        expect(body.message).not.toContain("Internal Server Error");
    });

    it("should include request_id in error responses", async () => {
        const req = makeRequest({});
        const res = await handleResolve(req, makeEnv(), makeCtx());
        const body = await res.json() as { request_id: string };
        expect(body.request_id).toBeDefined();
        expect(body.request_id.length).toBeGreaterThan(0);
    });

    it("should reject email that does not match signed-in account", async () => {
        const req = makeRequest(
            {
                email: "other@example.com",
                install_id: "550e8400-e29b-41d4-a716-446655440000",
            },
            VALID_SESSION_TOKEN,
        );
        const res = await handleResolve(req, makeEnv(), makeCtx());
        expect(res.status).toBe(403);
        const body = await res.json() as { error_code: string };
        expect(body.error_code).toBe("ACCOUNT_MISMATCH");
    });
});
