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

let mockLocalEntitlement: { tier: string; state: string } | null = null;
let mockInstallLinkedEmail: string | null = null;
let mockInstallLinkedCheckoutId: string | null = null;
let mockInstallLinkedCustomerId: string | null = null;

function makeEnv(overrides: Partial<Env> = {}): Env {
    return {
        STRATA_DB: {
            prepare: (sql: string) => {
                const mockStatement = {
                    bind: () => mockStatement,
                    first: async () => {
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
                        return null;
                    },
                    run: async () => ({ success: true }),
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
        AUTH_REQUIRED_FOR_RESTORE: "false",
        ...overrides,
    };
}

function makeRequest(body: Record<string, unknown>): Request {
    const payload = {
        challenge_id: "f1f5bfc2-0a66-4f93-8178-f8a4c2f00d23",
        nonce_signature: "MEYCIQDaQ5I5QW1VQq2r2b2+X2j6G9QW3b2mF5Dq3xHh8A+8jwIhAOe+5x+2Uy9Y5nxe9vF6kWv9G1w+L1Qc6Y7m+WSfJUN8",
        ...body,
    };
    return new Request("https://api.test/v1/purchases/restore", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
    });
}

const mockFetch = vi.fn();
vi.stubGlobal("fetch", mockFetch);

describe("POST /v1/purchases/restore", () => {
    beforeEach(() => {
        vi.clearAllMocks();
        mockLocalEntitlement = null;
        mockInstallLinkedEmail = null;
        mockInstallLinkedCheckoutId = null;
        mockInstallLinkedCustomerId = null;
        vi.mocked(verifyInstallProof).mockResolvedValue({
            installPubkeyHash: "test_install_pubkey_hash",
        });
    });

    it("should restore from local D1 store (VIP fallback)", async () => {
        mockLocalEntitlement = { tier: "vip", state: "active" };

        const req = makeRequest({
            email: "vip@example.com",
            install_id: "550e8400-e29b-41d4-a716-446655440000",
        });
        const res = await handleRestore(req, makeEnv());
        expect(res.status).toBe(200);

        const body: any = await res.json();
        expect(body.restore_type).toBe("lifetime");

        const pubKey = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        const claims = await verifyToken(body.token, pubKey);
        expect(claims.tier).toBe("vip");
        expect(claims.install_pubkey_hash).toBe("test_install_pubkey_hash");
    });

    it("should fallback to Dodo API if not found locally", async () => {
        // Dodo subscription proxy mock (customer + active subscription)
        mockFetch.mockResolvedValueOnce(new Response(JSON.stringify({ items: [{ customer_id: "123", email: "pro@example.com" }] }), { status: 200 }));
        mockFetch.mockResolvedValueOnce(new Response(JSON.stringify({ items: [{ status: "active", product_id: "pdt_0NZEvu9tI0aecVEYkmxOH", next_billing_date: "2026-03-26T00:00:00Z", customer: { customer_id: "123", email: "pro@example.com" } }] }), { status: 200 }));

        const req = makeRequest({
            email: "pro@example.com",
            install_id: "550e8400-e29b-41d4-a716-446655440000",
        });
        const res = await handleRestore(req, makeEnv());
        expect(res.status).toBe(200);

        const body: any = await res.json();
        expect(body.restore_type).toBe("subscription");

        const pubKey = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        const claims = await verifyToken(body.token, pubKey);
        expect(claims.tier).toBe("pro");
        expect(claims.install_pubkey_hash).toBe("test_install_pubkey_hash");
    });

    it("should activate license key if Dodo subscription not found", async () => {
        // No local, no subscription in Dodo
        mockFetch.mockResolvedValueOnce(new Response(JSON.stringify({ items: [] }), { status: 200 })); // customer search

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

        const req = makeRequest({
            email: "lic@example.com",
            install_id: "550e8400-e29b-41d4-a716-446655440000",
            license_key: "KAAA-BBBB-CCCC",
        });
        const res = await handleRestore(req, makeEnv());
        expect(res.status).toBe(200);

        const body: any = await res.json();
        expect(body.restore_type).toBe("lifetime");

        const pubKey = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        const claims = await verifyToken(body.token, pubKey);
        expect(claims.tier).toBe("vip");
        expect(claims.install_pubkey_hash).toBe("test_install_pubkey_hash");
    });

    it("should return free pattern if nothing found", async () => {
        // No local, no sub, license activation fails
        mockFetch.mockResolvedValueOnce(new Response(JSON.stringify({ items: [] }), { status: 200 })); // customer search
        mockFetch.mockResolvedValueOnce(new Response(JSON.stringify({ error: "invalid" }), { status: 400 })); // license activation

        const req = makeRequest({
            email: "none@example.com",
            install_id: "550e8400-e29b-41d4-a716-446655440000",
            license_key: "INVALID",
        });
        const res = await handleRestore(req, makeEnv());
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

        const req = makeRequest({
            email: "none@example.com",
            install_id: "550e8400-e29b-41d4-a716-446655440000",
            license_key: "NOT-VIP",
        });
        const res = await handleRestore(req, makeEnv());
        expect(res.status).toBe(200);

        const body: any = await res.json();
        expect(body.restore_type).toBe("none");

        const pubKey = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        const claims = await verifyToken(body.token, pubKey);
        expect(claims.tier).toBe("free");
    });

    it("should infer email from install link when request email is omitted", async () => {
        mockInstallLinkedEmail = "linked@example.com";
        mockFetch.mockResolvedValueOnce(new Response(JSON.stringify({ items: [] }), { status: 200 }));

        const req = makeRequest({
            install_id: "550e8400-e29b-41d4-a716-446655440000",
            email: undefined,
        });
        const res = await handleRestore(req, makeEnv());
        expect(res.status).toBe(200);

        const body: any = await res.json();
        expect(body.resolved_email).toBe("linked@example.com");

        const pubKey = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        const claims = await verifyToken(body.token, pubKey);
        expect(claims.sub).toBe("linked@example.com");
    });

    it("should infer email from successful checkout session when request email is omitted", async () => {
        mockInstallLinkedCheckoutId = "cks_123";
        mockFetch.mockResolvedValueOnce(
            new Response(
                JSON.stringify({
                    checkout_id: "cks_123",
                    customer_email: "checkout@example.com",
                    payment_status: "succeeded",
                }),
                { status: 200 },
            ),
        );
        mockFetch.mockResolvedValueOnce(
            new Response(JSON.stringify({ items: [] }), { status: 200 }),
        );
        mockFetch.mockResolvedValueOnce(
            new Response(
                JSON.stringify({
                    checkout_id: "cks_123",
                    customer_email: "checkout@example.com",
                    payment_status: "succeeded",
                }),
                { status: 200 },
            ),
        );

        const req = makeRequest({
            install_id: "550e8400-e29b-41d4-a716-446655440000",
            email: undefined,
        });
        const res = await handleRestore(req, makeEnv());
        expect(res.status).toBe(200);

        const body: any = await res.json();
        expect(body.resolved_email).toBe("checkout@example.com");

        const pubKey = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        const claims = await verifyToken(body.token, pubKey);
        expect(claims.sub).toBe("checkout@example.com");
    });

    it("should restore VIP from successful linked checkout payment without license key", async () => {
        mockInstallLinkedCheckoutId = "cks_vip";
        mockInstallLinkedCustomerId = "cus_vip";
        mockFetch.mockResolvedValueOnce(
            new Response(JSON.stringify({ items: [] }), { status: 200 }),
        );
        mockFetch.mockResolvedValueOnce(
            new Response(
                JSON.stringify({
                    checkout_id: "cks_vip",
                    payment_id: "pay_vip",
                    payment_status: "succeeded",
                    customer_email: "vip@example.com",
                    customer_id: "cus_vip",
                }),
                { status: 200 },
            ),
        );
        mockFetch.mockResolvedValueOnce(
            new Response(
                JSON.stringify({
                    payment_id: "pay_vip",
                    status: "succeeded",
                    customer: {
                        customer_id: "cus_vip",
                        email: "vip@example.com",
                    },
                    product_cart: [{ product_id: PRODUCT_IDS.vipLifetime, quantity: 1 }],
                }),
                { status: 200 },
            ),
        );

        const req = makeRequest({
            email: "vip@example.com",
            install_id: "550e8400-e29b-41d4-a716-446655440000",
        });
        const res = await handleRestore(req, makeEnv());
        expect(res.status).toBe(200);

        const body: any = await res.json();
        expect(body.restore_type).toBe("lifetime");

        const pubKey = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        const claims = await verifyToken(body.token, pubKey);
        expect(claims.tier).toBe("vip");
        expect(claims.sub).toBe("vip@example.com");
    });

    it("should not restore VIP from linked checkout when payment product is not VIP", async () => {
        mockInstallLinkedCheckoutId = "cks_nonvip";
        mockInstallLinkedCustomerId = "cus_nonvip";
        mockFetch.mockResolvedValueOnce(
            new Response(JSON.stringify({ items: [] }), { status: 200 }),
        );
        mockFetch.mockResolvedValueOnce(
            new Response(
                JSON.stringify({
                    checkout_id: "cks_nonvip",
                    payment_id: "pay_nonvip",
                    payment_status: "succeeded",
                    customer_email: "user@example.com",
                    customer_id: "cus_nonvip",
                }),
                { status: 200 },
            ),
        );
        mockFetch.mockResolvedValueOnce(
            new Response(
                JSON.stringify({
                    payment_id: "pay_nonvip",
                    status: "succeeded",
                    customer: {
                        customer_id: "cus_nonvip",
                        email: "user@example.com",
                    },
                    product_cart: [{ product_id: PRODUCT_IDS.proMonthly, quantity: 1 }],
                }),
                { status: 200 },
            ),
        );

        const req = makeRequest({
            email: "user@example.com",
            install_id: "550e8400-e29b-41d4-a716-446655440000",
        });
        const res = await handleRestore(req, makeEnv());
        expect(res.status).toBe(200);

        const body: any = await res.json();
        expect(body.restore_type).toBe("none");

        const pubKey = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        const claims = await verifyToken(body.token, pubKey);
        expect(claims.tier).toBe("free");
    });

    it("should require auth when AUTH_REQUIRED_FOR_RESTORE is enabled", async () => {
        const req = makeRequest({
            email: "vip@example.com",
            install_id: "550e8400-e29b-41d4-a716-446655440000",
        });
        const res = await handleRestore(req, makeEnv({ AUTH_REQUIRED_FOR_RESTORE: "true" }));
        expect(res.status).toBe(401);
        const body: any = await res.json();
        expect(body.error_code).toBe("AUTH_REQUIRED");
    });
});
