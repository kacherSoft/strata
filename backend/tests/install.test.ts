// ---------------------------------------------------------------------------
// Tests for POST /v1/installs/register
// ---------------------------------------------------------------------------

import { describe, it, expect, vi, beforeEach } from "vitest";
import { handleInstallRegister } from "../src/routes/install.js";
import type { Env } from "../src/types.js";

let mockExistingPubkey: string | null = null;
let mockUpdateChanges = 1;
let mockPersistedPubkey: string | null = null;
const VALID_PUBKEY = "BAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE=";
const OTHER_VALID_PUBKEY = "BAICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI=";

function makeEnv(overrides: Partial<Env> = {}): Env {
    return {
        STRATA_DB: {
            prepare: (sql: string) => {
                let boundArgs: unknown[] = [];
                const statement = {
                    bind: (...args: unknown[]) => {
                        boundArgs = args;
                        return statement;
                    },
                    first: async () => {
                        if (sql.includes("WHERE install_id = ? AND install_pubkey IS NOT NULL")) {
                            return mockExistingPubkey ? { install_pubkey: mockExistingPubkey } : null;
                        }
                        if (sql.includes("FROM purchase_links") && sql.includes("WHERE install_id = ?")) {
                            return mockPersistedPubkey ? { install_pubkey: mockPersistedPubkey } : null;
                        }
                        return null;
                    },
                    run: async () => {
                        if (sql.includes("INSERT INTO purchase_links")) {
                            const pubkeyArg = boundArgs[1];
                            if (typeof pubkeyArg === "string") {
                                mockPersistedPubkey = pubkeyArg;
                            }
                        }
                        return { success: true, meta: { changes: mockUpdateChanges } };
                    },
                };
                return statement;
            },
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
    return new Request("https://api.test/v1/installs/register", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
    });
}

describe("POST /v1/installs/register", () => {
    beforeEach(() => {
        mockExistingPubkey = null;
        mockUpdateChanges = 1;
        mockPersistedPubkey = null;
    });

    it("should reject missing install_id", async () => {
        const req = makeRequest({ install_pubkey: "base64pubkeydata" });
        const res = await handleInstallRegister(req, makeEnv());
        expect(res.status).toBe(400);
    });

    it("should reject invalid pubkey", async () => {
        const req = makeRequest({
            install_id: "550e8400-e29b-41d4-a716-446655440000",
            install_pubkey: "short",
        });
        const res = await handleInstallRegister(req, makeEnv());
        expect(res.status).toBe(400);
        const body: any = await res.json();
        expect(body.error_code).toBe("INVALID_PUBKEY");
    });

    it("should register new pubkey successfully", async () => {
        const req = makeRequest({
            install_id: "550e8400-e29b-41d4-a716-446655440000",
            install_pubkey: VALID_PUBKEY,
        });
        const res = await handleInstallRegister(req, makeEnv());
        expect(res.status).toBe(200);
        const body: any = await res.json();
        expect(body.registered).toBe(true);
    });

    it("should return success when re-registering identical pubkey", async () => {
        const pubkey = VALID_PUBKEY;
        mockExistingPubkey = pubkey;

        const req = makeRequest({
            install_id: "550e8400-e29b-41d4-a716-446655440000",
            install_pubkey: pubkey,
        });
        const res = await handleInstallRegister(req, makeEnv());
        expect(res.status).toBe(200);
    });

    it("should return 409 Conflict when registering different pubkey for same install_id", async () => {
        mockExistingPubkey = OTHER_VALID_PUBKEY;

        const req = makeRequest({
            install_id: "550e8400-e29b-41d4-a716-446655440000",
            install_pubkey: VALID_PUBKEY,
        });
        const res = await handleInstallRegister(req, makeEnv());
        expect(res.status).toBe(409);
        const body: any = await res.json();
        expect(body.error_code).toBe("ALREADY_REGISTERED");
    });
});
