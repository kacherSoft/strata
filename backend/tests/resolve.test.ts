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

function makeD1Mock(): D1Database {
    const mockStatement = {
        bind: () => mockStatement,
        first: async () => null, // No local entitlement — forces Dodo API fallback
        all: async () => ({ results: [] }),
        run: async () => ({ success: true, meta: { changes: 1 } }),
    };
    return {
        prepare: () => mockStatement,
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
        AUTH_REQUIRED_FOR_RESOLVE: "false",
        ...overrides,
    };
}

function makeRequest(body: Record<string, unknown>): Request {
    const payload = {
        challenge_id: "4a394f45-1792-4ae9-a18f-bf7ce33420b1",
        nonce_signature: "MEUCIQDm5H9XbQ2x8Xj5gD8rVq5S2sQ4Myp9A9SLM2w3bTWq1wIgE2Pzq4w8Xbq8WwRkW5oloxhAa6oWn3wy4ABQ0kQmE4c=",
        ...body,
    };
    return new Request("https://api.test/v1/entitlements/resolve", {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "CF-Connecting-IP": "127.0.0.1",
        },
        body: JSON.stringify(payload),
    });
}

// Mock global fetch
const mockFetch = vi.fn();
vi.stubGlobal("fetch", mockFetch);

describe("POST /v1/entitlements/resolve", () => {
    beforeEach(() => {
        vi.clearAllMocks();
        vi.mocked(verifyInstallProof).mockResolvedValue({
            installPubkeyHash: "test_install_pubkey_hash",
        });
    });

    it("should reject missing email", async () => {
        const req = makeRequest({ install_id: "550e8400-e29b-41d4-a716-446655440000" });
        const res = await handleResolve(req, makeEnv());
        expect(res.status).toBe(400);
        const body = await res.json() as { error_code: string };
        expect(body.error_code).toBe("INVALID_EMAIL");
    });

    it("should reject invalid email format", async () => {
        const req = makeRequest({
            email: "notanemail",
            install_id: "550e8400-e29b-41d4-a716-446655440000",
        });
        const res = await handleResolve(req, makeEnv());
        expect(res.status).toBe(400);
        const body = await res.json() as { error_code: string };
        expect(body.error_code).toBe("INVALID_EMAIL");
    });

    it("should reject missing install_id", async () => {
        const req = makeRequest({ email: "test@example.com" });
        const res = await handleResolve(req, makeEnv());
        expect(res.status).toBe(400);
        const body = await res.json() as { error_code: string };
        expect(body.error_code).toBe("INVALID_INSTALL_ID");
    });

    it("should reject non-UUID install_id", async () => {
        const req = makeRequest({
            email: "test@example.com",
            install_id: "not-a-uuid",
        });
        const res = await handleResolve(req, makeEnv());
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
            },
            body: "this is not json",
        });
        const res = await handleResolve(req, makeEnv());
        expect(res.status).toBe(400);
        const body = await res.json() as { error_code: string };
        expect(body.error_code).toBe("INVALID_BODY");
    });

    it("should return free tier token when no subscription found", async () => {
        // Mock: no customers found
        mockFetch.mockResolvedValueOnce(
            new Response(JSON.stringify({ items: [] }), { status: 200 }),
        );

        const req = makeRequest({
            email: "free@example.com",
            install_id: "550e8400-e29b-41d4-a716-446655440000",
        });
        const res = await handleResolve(req, makeEnv());
        expect(res.status).toBe(200);

        const body = await res.json() as { token: string };
        expect(body.token).toBeDefined();

        // Verify the token contents
        const pubKey = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        const claims = await verifyToken(body.token, pubKey);
        expect(claims.tier).toBe("free");
        expect(claims.sub).toBe("free@example.com");
        expect(claims.install_id).toBe("550e8400-e29b-41d4-a716-446655440000");
        expect(claims.install_pubkey_hash).toBe("test_install_pubkey_hash");
    });

    it("should return pro tier token when active subscription exists", async () => {
        // Mock: customer found
        mockFetch.mockResolvedValueOnce(
            new Response(
                JSON.stringify({
                    items: [{ customer_id: "cust_123", email: "pro@example.com" }],
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
                                email: "pro@example.com",
                            },
                        },
                    ],
                }),
                { status: 200 },
            ),
        );

        const req = makeRequest({
            email: "pro@example.com",
            install_id: "550e8400-e29b-41d4-a716-446655440000",
        });
        const res = await handleResolve(req, makeEnv());
        expect(res.status).toBe(200);

        const body = await res.json() as { token: string };
        const pubKey = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        const claims = await verifyToken(body.token, pubKey);
        expect(claims.tier).toBe("pro");
        expect(claims.sub).toBe("pro@example.com");
        expect(claims.install_pubkey_hash).toBe("test_install_pubkey_hash");
    });

    it("should normalize email to lowercase", async () => {
        mockFetch.mockResolvedValueOnce(
            new Response(JSON.stringify({ items: [] }), { status: 200 }),
        );

        const req = makeRequest({
            email: "  User@Example.COM  ",
            install_id: "550e8400-e29b-41d4-a716-446655440000",
        });
        const res = await handleResolve(req, makeEnv());
        expect(res.status).toBe(200);

        const body = await res.json() as { token: string };
        const pubKey = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        const claims = await verifyToken(body.token, pubKey);
        expect(claims.sub).toBe("user@example.com");
    });

    it("should handle provider errors gracefully", async () => {
        mockFetch.mockResolvedValueOnce(
            new Response("Internal Server Error", { status: 500 }),
        );

        const req = makeRequest({
            email: "test@example.com",
            install_id: "550e8400-e29b-41d4-a716-446655440000",
        });
        const res = await handleResolve(req, makeEnv());
        expect(res.status).toBe(502);
        const body = await res.json() as { error_code: string; message: string };
        expect(body.error_code).toBe("PROVIDER_ERROR");
        // Must not leak provider error body
        expect(body.message).not.toContain("Internal Server Error");
    });

    it("should include request_id in error responses", async () => {
        const req = makeRequest({ email: "bad" });
        const res = await handleResolve(req, makeEnv());
        const body = await res.json() as { request_id: string };
        expect(body.request_id).toBeDefined();
        expect(body.request_id.length).toBeGreaterThan(0);
    });

    it("should require auth when AUTH_REQUIRED_FOR_RESOLVE is enabled", async () => {
        mockFetch.mockResolvedValueOnce(
            new Response(JSON.stringify({ items: [] }), { status: 200 }),
        );
        const req = makeRequest({
            email: "free@example.com",
            install_id: "550e8400-e29b-41d4-a716-446655440000",
        });
        const res = await handleResolve(req, makeEnv({ AUTH_REQUIRED_FOR_RESOLVE: "true" }));
        expect(res.status).toBe(401);
        const body = await res.json() as { error_code: string };
        expect(body.error_code).toBe("AUTH_REQUIRED");
    });
});
