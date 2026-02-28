// ---------------------------------------------------------------------------
// Tests for POST /v1/installs/challenge
// ---------------------------------------------------------------------------

import { describe, it, expect, vi, beforeEach } from "vitest";
vi.mock("../src/install-proof.js", () => ({
    createInstallChallenge: vi.fn(async () => ({
        challenge_id: "31d4922b-8f57-4577-aef7-b19889fef0a7",
        nonce: "nonce",
        expires_at: 1730000000,
    })),
}));
import { handleInstallChallenge } from "../src/routes/challenge.js";
import { createInstallChallenge } from "../src/install-proof.js";
import type { Env } from "../src/types.js";

function makeEnv(overrides: Partial<Env> = {}): Env {
    const mockStatement = {
        bind: () => mockStatement,
        first: async () => null,
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
    return new Request("https://api.test/v1/installs/challenge", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
    });
}

describe("POST /v1/installs/challenge", () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });

    it("should reject invalid install_id", async () => {
        const req = makeRequest({ install_id: "bad" });
        const res = await handleInstallChallenge(req, makeEnv());
        expect(res.status).toBe(400);
        const body = await res.json() as { error_code: string };
        expect(body.error_code).toBe("INVALID_INSTALL_ID");
    });

    it("should return challenge payload", async () => {
        const req = makeRequest({ install_id: "550e8400-e29b-41d4-a716-446655440000" });
        const res = await handleInstallChallenge(req, makeEnv());
        expect(res.status).toBe(200);

        const body = await res.json() as {
            challenge_id: string;
            nonce: string;
            expires_at: number;
        };
        expect(body.challenge_id).toBe("31d4922b-8f57-4577-aef7-b19889fef0a7");
        expect(body.nonce).toBe("nonce");
        expect(body.expires_at).toBe(1730000000);
        expect(vi.mocked(createInstallChallenge)).toHaveBeenCalledTimes(1);
    });
});
