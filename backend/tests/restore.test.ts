// ---------------------------------------------------------------------------
// Tests for POST /v1/purchases/restore
// ---------------------------------------------------------------------------

import { describe, it, expect, vi, beforeEach } from "vitest";
vi.mock("../src/install-proof.js", () => ({
    verifyInstallProof: vi.fn(async () => ({ installPubkeyHash: "test_install_pubkey_hash" })),
}));
import { handleRestore } from "../src/routes/restore.js";
import { verifyToken, publicKeyFromPrivate } from "../src/signing.js";
import { verifyInstallProof } from "../src/install-proof.js";
import type { Env } from "../src/types.js";
import { PRODUCT_IDS } from "../src/types.js";

const TEST_PRIVATE_KEY_HEX = "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60";

// Simulated session state for DB mock
let mockSessionValid = true;
let mockLocalEntitlement: { tier: string; state: string } | null = null;
let mockInstallLinkedEmail: string | null = null;
let mockInstallLinkedCheckoutId: string | null = null;
let mockInstallLinkedCustomerId: string | null = null;

const TEST_USER_ID = "user-123";
const TEST_EMAIL = "test@example.com";
const VALID_SESSION_TOKEN = "valid-session-token";

function makeEnv(overrides: Partial<Env> = {}): Env {
    return {
        STRATA_DB: {
            prepare: (sql: string) => {
                const mockStatement = {
                    bind: () => mockStatement,
                    first: async () => {
                        if (sql.includes("FROM account_sessions")) {
                            if (!mockSessionValid) return null;
                            return {
                                session_id: "sess-1",
                                user_id: TEST_USER_ID,
                                expires_at: Math.floor(Date.now() / 1000) + 86400,
                                email_normalized: TEST_EMAIL,
                            };
                        }
                        if (sql.includes("FROM entitlements")) {
                            return mockLocalEntitlement;
                        }
                        if (sql.includes("FROM purchase_links")) {
                            if (
                                !mockInstallLinkedEmail &&
                                !mockInstallLinkedCheckoutId &&
                                !mockInstallLinkedCustomerId
                            ) {
                                return null;
                            }
                            return {
                                customer_email: mockInstallLinkedEmail,
                                checkout_session_id: mockInstallLinkedCheckoutId,
                                customer_id: mockInstallLinkedCustomerId,
                            };
                        }
                        if (sql.includes("FROM user_devices")) {
                            return { count: 0 };
                        }
                        return null;
                    },
                    all: async () => ({ results: [] }),
                    run: async () => ({ success: true, meta: { changes: 1 } }),
                };
                return mockStatement;
            },
        } as unknown as D1Database,
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
        challenge_id: "f1f5bfc2-0a66-4f93-8178-f8a4c2f00d23",
        nonce_signature: "MEYCIQDaQ5I5QW1VQq2r2b2+X2j6G9QW3b2mF5Dq3xHh8A+8jwIhAOe+5x+2Uy9Y5nxe9vF6kWv9G1w+L1Qc6Y7m+WSfJUN8",
        ...body,
    };
    const headers: Record<string, string> = { "Content-Type": "application/json" };
    if (sessionToken) {
        headers["Authorization"] = `Bearer ${sessionToken}`;
    }
    return new Request("https://api.test/v1/purchases/restore", {
        method: "POST",
        headers,
        body: JSON.stringify(payload),
    });
}

const mockFetch = vi.fn();
vi.stubGlobal("fetch", mockFetch);

describe("POST /v1/purchases/restore", () => {
    beforeEach(() => {
        vi.clearAllMocks();
        mockSessionValid = true;
        mockLocalEntitlement = null;
        mockInstallLinkedEmail = null;
        mockInstallLinkedCheckoutId = null;
        mockInstallLinkedCustomerId = null;
        vi.mocked(verifyInstallProof).mockResolvedValue({
            installPubkeyHash: "test_install_pubkey_hash",
        });
    });

    it("should return 401 without auth token", async () => {
        const req = makeRequest({ install_id: "550e8400-e29b-41d4-a716-446655440000" });
        const res = await handleRestore(req, makeEnv(), makeCtx());
        expect(res.status).toBe(401);
        const body: any = await res.json();
        expect(body.error_code).toBe("AUTH_REQUIRED");
    });

    it("should return 401 with invalid/expired session", async () => {
        mockSessionValid = false;
        const req = makeRequest(
            { install_id: "550e8400-e29b-41d4-a716-446655440000" },
            VALID_SESSION_TOKEN,
        );
        const res = await handleRestore(req, makeEnv(), makeCtx());
        expect(res.status).toBe(401);
        const body: any = await res.json();
        expect(body.error_code).toBe("INVALID_SESSION");
    });

    it("should restore from Dodo API (pro subscription)", async () => {
        // resolveTierForUser calls: list customers, then list subscriptions
        mockFetch.mockResolvedValueOnce(new Response(JSON.stringify({ items: [{ customer_id: "123", email: TEST_EMAIL }] }), { status: 200 }));
        mockFetch.mockResolvedValueOnce(new Response(JSON.stringify({ items: [{ status: "active", product_id: "pdt_0NZEvu9tI0aecVEYkmxOH", next_billing_date: "2026-03-26T00:00:00Z", customer: { customer_id: "123", email: TEST_EMAIL } }] }), { status: 200 }));

        const req = makeRequest(
            { install_id: "550e8400-e29b-41d4-a716-446655440000" },
            VALID_SESSION_TOKEN,
        );
        const res = await handleRestore(req, makeEnv(), makeCtx());
        expect(res.status).toBe(200);

        const body: any = await res.json();
        expect(body.restore_type).toBe("subscription");

        const pubKey = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        const claims = await verifyToken(body.token, pubKey);
        expect(claims.tier).toBe("pro");
        expect(claims.install_pubkey_hash).toBe("test_install_pubkey_hash");
    });

    it("should restore free tier when no subscription found", async () => {
        // No customers found in Dodo
        mockFetch.mockResolvedValueOnce(new Response(JSON.stringify({ items: [] }), { status: 200 }));

        const req = makeRequest(
            { install_id: "550e8400-e29b-41d4-a716-446655440000" },
            VALID_SESSION_TOKEN,
        );
        const res = await handleRestore(req, makeEnv(), makeCtx());
        expect(res.status).toBe(200);

        const body: any = await res.json();
        expect(body.restore_type).toBe("none");

        const pubKey = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        const claims = await verifyToken(body.token, pubKey);
        expect(claims.tier).toBe("free");
        expect(claims.install_pubkey_hash).toBe("test_install_pubkey_hash");
    });

    it("should activate license key and grant VIP", async () => {
        // No Dodo subscription
        mockFetch.mockResolvedValueOnce(new Response(JSON.stringify({ items: [] }), { status: 200 }));

        // License activation mock
        mockFetch.mockResolvedValueOnce(
            new Response(
                JSON.stringify({
                    status: "active",
                    product_id: PRODUCT_IDS.vipLifetime,
                }),
                { status: 200 },
            ),
        );

        const req = makeRequest(
            {
                install_id: "550e8400-e29b-41d4-a716-446655440000",
                license_key: "KAAA-BBBB-CCCC",
            },
            VALID_SESSION_TOKEN,
        );
        const res = await handleRestore(req, makeEnv(), makeCtx());
        expect(res.status).toBe(200);

        const body: any = await res.json();
        expect(body.restore_type).toBe("lifetime");

        const pubKey = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        const claims = await verifyToken(body.token, pubKey);
        expect(claims.tier).toBe("vip");
        expect(claims.install_pubkey_hash).toBe("test_install_pubkey_hash");
    });

    it("should return free pattern if nothing found", async () => {
        // No Dodo subscription
        mockFetch.mockResolvedValueOnce(new Response(JSON.stringify({ items: [] }), { status: 200 }));
        // License activation fails
        mockFetch.mockResolvedValueOnce(new Response(JSON.stringify({ error: "invalid" }), { status: 400 }));

        const req = makeRequest(
            {
                install_id: "550e8400-e29b-41d4-a716-446655440000",
                license_key: "INVALID",
            },
            VALID_SESSION_TOKEN,
        );
        const res = await handleRestore(req, makeEnv(), makeCtx());
        expect(res.status).toBe(200);

        const body: any = await res.json();
        expect(body.restore_type).toBe("none");

        const pubKey = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        const claims = await verifyToken(body.token, pubKey);
        expect(claims.tier).toBe("free");
        expect(claims.install_pubkey_hash).toBe("test_install_pubkey_hash");
    });

    it("should not grant VIP for non-lifetime license product", async () => {
        mockFetch.mockResolvedValueOnce(new Response(JSON.stringify({ items: [] }), { status: 200 }));
        mockFetch.mockResolvedValueOnce(
            new Response(
                JSON.stringify({
                    status: "active",
                    product_id: PRODUCT_IDS.proMonthly,
                }),
                { status: 200 },
            ),
        );

        const req = makeRequest(
            {
                install_id: "550e8400-e29b-41d4-a716-446655440000",
                license_key: "NOT-VIP",
            },
            VALID_SESSION_TOKEN,
        );
        const res = await handleRestore(req, makeEnv(), makeCtx());
        expect(res.status).toBe(200);

        const body: any = await res.json();
        expect(body.restore_type).toBe("none");

        const pubKey = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        const claims = await verifyToken(body.token, pubKey);
        expect(claims.tier).toBe("free");
    });

    it("should reject email that does not match signed-in account", async () => {
        const req = makeRequest(
            {
                email: "other@example.com",
                install_id: "550e8400-e29b-41d4-a716-446655440000",
            },
            VALID_SESSION_TOKEN,
        );
        const res = await handleRestore(req, makeEnv(), makeCtx());
        expect(res.status).toBe(403);
        const body: any = await res.json();
        expect(body.error_code).toBe("ACCOUNT_MISMATCH");
    });

    it("should restore VIP from successful linked checkout payment without license key", async () => {
        mockInstallLinkedCheckoutId = "cks_vip";
        mockInstallLinkedCustomerId = "cus_vip";
        // resolveTierForUser: no subscription
        mockFetch.mockResolvedValueOnce(
            new Response(JSON.stringify({ items: [] }), { status: 200 }),
        );
        // tryRestoreVipFromLinkedCheckout: checkout session lookup
        mockFetch.mockResolvedValueOnce(
            new Response(
                JSON.stringify({
                    checkout_id: "cks_vip",
                    payment_id: "pay_vip",
                    payment_status: "succeeded",
                    customer_email: TEST_EMAIL,
                    customer_id: "cus_vip",
                }),
                { status: 200 },
            ),
        );
        // payment lookup
        mockFetch.mockResolvedValueOnce(
            new Response(
                JSON.stringify({
                    payment_id: "pay_vip",
                    status: "succeeded",
                    customer: {
                        customer_id: "cus_vip",
                        email: TEST_EMAIL,
                    },
                    product_cart: [{ product_id: PRODUCT_IDS.vipLifetime, quantity: 1 }],
                }),
                { status: 200 },
            ),
        );

        const req = makeRequest(
            { install_id: "550e8400-e29b-41d4-a716-446655440000" },
            VALID_SESSION_TOKEN,
        );
        const res = await handleRestore(req, makeEnv(), makeCtx());
        expect(res.status).toBe(200);

        const body: any = await res.json();
        expect(body.restore_type).toBe("lifetime");

        const pubKey = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        const claims = await verifyToken(body.token, pubKey);
        expect(claims.tier).toBe("vip");
        expect(claims.sub).toBe(TEST_EMAIL);
    });

    it("should not restore VIP from linked checkout when payment product is not VIP", async () => {
        mockInstallLinkedCheckoutId = "cks_nonvip";
        mockInstallLinkedCustomerId = "cus_nonvip";
        // resolveTierForUser: no subscription
        mockFetch.mockResolvedValueOnce(
            new Response(JSON.stringify({ items: [] }), { status: 200 }),
        );
        // checkout session lookup
        mockFetch.mockResolvedValueOnce(
            new Response(
                JSON.stringify({
                    checkout_id: "cks_nonvip",
                    payment_id: "pay_nonvip",
                    payment_status: "succeeded",
                    customer_email: TEST_EMAIL,
                    customer_id: "cus_nonvip",
                }),
                { status: 200 },
            ),
        );
        // payment lookup
        mockFetch.mockResolvedValueOnce(
            new Response(
                JSON.stringify({
                    payment_id: "pay_nonvip",
                    status: "succeeded",
                    customer: {
                        customer_id: "cus_nonvip",
                        email: TEST_EMAIL,
                    },
                    product_cart: [{ product_id: PRODUCT_IDS.proMonthly, quantity: 1 }],
                }),
                { status: 200 },
            ),
        );
        // license activation: no license key provided so this won't be called

        const req = makeRequest(
            { install_id: "550e8400-e29b-41d4-a716-446655440000" },
            VALID_SESSION_TOKEN,
        );
        const res = await handleRestore(req, makeEnv(), makeCtx());
        expect(res.status).toBe(200);

        const body: any = await res.json();
        expect(body.restore_type).toBe("none");

        const pubKey = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        const claims = await verifyToken(body.token, pubKey);
        expect(claims.tier).toBe("free");
    });
});
