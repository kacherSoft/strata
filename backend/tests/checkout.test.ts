// ---------------------------------------------------------------------------
// Tests for POST /v1/checkout-sessions
// ---------------------------------------------------------------------------

import { describe, it, expect, vi, beforeEach } from "vitest";
import { handleCheckoutSession } from "../src/routes/checkout.js";
import type { Env } from "../src/types.js";
import { PRODUCT_IDS } from "../src/types.js";

function makeEnv(overrides: Partial<Env> = {}): Env {
    const mockStatement = {
        bind: () => mockStatement,
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
        AUTH_REQUIRED_FOR_CHECKOUT: "false",
        ...overrides,
    };
}

function makeRequest(body: Record<string, unknown>): Request {
    return new Request("https://api.test/v1/checkout-sessions", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
    });
}

const mockFetch = vi.fn();
vi.stubGlobal("fetch", mockFetch);

describe("POST /v1/checkout-sessions", () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });

    it("should reject missing product_id", async () => {
        const req = makeRequest({ install_id: "550e8400-e29b-41d4-a716-446655440000" });
        const res = await handleCheckoutSession(req, makeEnv());
        expect(res.status).toBe(400);
        const body: any = await res.json();
        expect(body.error_code).toBe("INVALID_PRODUCT_ID");
    });

    it("should reject missing or invalid install_id", async () => {
        const req = makeRequest({ product_id: PRODUCT_IDS.proMonthly, install_id: "not-uuid" });
        const res = await handleCheckoutSession(req, makeEnv());
        expect(res.status).toBe(400);
        const body: any = await res.json();
        expect(body.error_code).toBe("INVALID_INSTALL_ID");
    });

    it("should reject unknown product_id", async () => {
        const req = makeRequest({
            product_id: "pdt_123",
            install_id: "550e8400-e29b-41d4-a716-446655440000",
        });
        const res = await handleCheckoutSession(req, makeEnv());
        expect(res.status).toBe(400);
        const body: any = await res.json();
        expect(body.error_code).toBe("INVALID_PRODUCT_ID");
    });

    it("should return checkout url on success", async () => {
        mockFetch.mockResolvedValueOnce(
            new Response(
                JSON.stringify({
                    payment_link: "https://checkout.dodo/123",
                    checkout_session_id: "cks_123",
                }),
                {
                    status: 200,
                },
            ),
        );

        const req = makeRequest({
            product_id: PRODUCT_IDS.proMonthly,
            install_id: "550e8400-e29b-41d4-a716-446655440000",
            email: "test@example.com",
        });

        const res = await handleCheckoutSession(req, makeEnv());
        expect(res.status).toBe(200);
        const body: any = await res.json();
        expect(body.checkout_url).toBe("https://checkout.dodo/123");
        expect(body.session_id).toBe("cks_123");

        // Check fetch args include the embedded install_id in return_url
        const fetchArgs = mockFetch.mock.calls[0];
        expect(fetchArgs[0]).toBe("https://test.dodopayments.com/checkouts");
        const fetchBody = JSON.parse(fetchArgs[1].body);
        expect(fetchBody.return_url).toContain("install_id=550e8400-e29b-41d4-a716-446655440000");
        expect(fetchBody.product_cart?.[0]?.product_id).toBe(PRODUCT_IDS.proMonthly);
        expect(fetchBody.product_cart?.[0]?.quantity).toBe(1);
        expect(fetchBody.customer.email).toBe("test@example.com");
        expect(fetchBody.metadata.install_id).toBe("550e8400-e29b-41d4-a716-446655440000");
    });

    it("should handle Dodo API failure", async () => {
        mockFetch.mockResolvedValueOnce(new Response("Gateway timeout", { status: 504 }));
        const req = makeRequest({
            product_id: PRODUCT_IDS.proMonthly,
            install_id: "550e8400-e29b-41d4-a716-446655440000",
        });
        const res = await handleCheckoutSession(req, makeEnv());
        expect(res.status).toBe(502);
        const body: any = await res.json();
        expect(body.error_code).toBe("PROVIDER_ERROR");
    });

    it("should reject invalid return_url", async () => {
        const req = makeRequest({
            product_id: PRODUCT_IDS.proMonthly,
            install_id: "550e8400-e29b-41d4-a716-446655440000",
            return_url: "https://example.com",
        });
        const res = await handleCheckoutSession(req, makeEnv());
        expect(res.status).toBe(400);
        const body: any = await res.json();
        expect(body.error_code).toBe("INVALID_RETURN_URL");
    });

    it("should require auth when AUTH_REQUIRED_FOR_CHECKOUT is enabled", async () => {
        const req = makeRequest({
            product_id: PRODUCT_IDS.proMonthly,
            install_id: "550e8400-e29b-41d4-a716-446655440000",
        });
        const res = await handleCheckoutSession(req, makeEnv({ AUTH_REQUIRED_FOR_CHECKOUT: "true" }));
        expect(res.status).toBe(401);
        const body: any = await res.json();
        expect(body.error_code).toBe("AUTH_REQUIRED");
    });
});
