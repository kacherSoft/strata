// ---------------------------------------------------------------------------
// Tests for install proof verification
// ---------------------------------------------------------------------------

import { describe, it, expect } from "vitest";
import { verifyInstallProof } from "../src/install-proof.js";
import type { Env } from "../src/types.js";

interface MockState {
    installId: string;
    installPubkeyB64: string;
    challengeId: string;
    nonce: string;
    expiresAt: number;
    usedAt: number | null;
}

function bytesToBinaryString(data: Uint8Array): string {
    let binary = "";
    const CHUNK = 0x8000;
    for (let offset = 0; offset < data.length; offset += CHUNK) {
        const chunk = data.subarray(offset, offset + CHUNK);
        binary += String.fromCharCode(...chunk);
    }
    return binary;
}

function encodeBase64(data: Uint8Array): string {
    return btoa(bytesToBinaryString(data));
}

function encodeBase64url(data: Uint8Array): string {
    return encodeBase64(data).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function p1363ToDer(signature: Uint8Array): Uint8Array {
    function encodeDerInteger(raw: Uint8Array): Uint8Array {
        let start = 0;
        while (start < raw.length - 1 && raw[start] === 0) {
            start += 1;
        }
        let value = raw.subarray(start);
        if ((value[0] ?? 0) & 0x80) {
            const prefixed = new Uint8Array(value.length + 1);
            prefixed[0] = 0;
            prefixed.set(value, 1);
            value = prefixed;
        }
        const der = new Uint8Array(2 + value.length);
        der[0] = 0x02;
        der[1] = value.length;
        der.set(value, 2);
        return der;
    }

    const r = signature.subarray(0, 32);
    const s = signature.subarray(32, 64);
    const rDer = encodeDerInteger(r);
    const sDer = encodeDerInteger(s);
    const sequenceLength = rDer.length + sDer.length;

    const result = new Uint8Array(2 + sequenceLength);
    result[0] = 0x30;
    result[1] = sequenceLength;
    result.set(rDer, 2);
    result.set(sDer, 2 + rDer.length);
    return result;
}

function makeD1Mock(state: MockState): D1Database {
    return {
        prepare: (sql: string) => {
            let params: unknown[] = [];
            const statement = {
                bind: (...args: unknown[]) => {
                    params = args;
                    return statement;
                },
                first: async () => {
                    if (sql.includes("FROM install_challenges")) {
                        const [challengeId, installId] = params as [string, string];
                        if (challengeId === state.challengeId && installId === state.installId) {
                            return {
                                nonce: state.nonce,
                                expires_at: state.expiresAt,
                                used_at: state.usedAt,
                            };
                        }
                        return null;
                    }

                    if (sql.includes("FROM purchase_links")) {
                        const [installId] = params as [string];
                        if (installId === state.installId) {
                            return { install_pubkey: state.installPubkeyB64 };
                        }
                        return null;
                    }

                    return null;
                },
                run: async () => {
                    if (sql.startsWith("UPDATE install_challenges SET used_at")) {
                        const [usedAt, challengeId] = params as [number, string];
                        if (challengeId === state.challengeId && state.usedAt === null) {
                            state.usedAt = usedAt;
                            return { meta: { changes: 1 } };
                        }
                        return { meta: { changes: 0 } };
                    }

                    return { meta: { changes: 1 } };
                },
            };
            return statement;
        },
    } as unknown as D1Database;
}

function makeEnv(state: MockState): Env {
    return {
        STRATA_DB: makeD1Mock(state),
        DODO_API_KEY: "test-api-key",
        DODO_WEBHOOK_SECRET: "test-webhook-secret",
        ENTITLEMENT_SIGNING_PRIVATE_KEY:
            "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60",
        ENVIRONMENT: "test",
        DODO_BASE_URL: "https://test.dodopayments.com",
        TOKEN_TTL_SECONDS: "3600",
    };
}

describe("install proof verification", () => {
    it("accepts IEEE-P1363 ECDSA signatures", async () => {
        const installId = "550e8400-e29b-41d4-a716-446655440000";
        const challengeId = "f5a9e7a0-2f36-4b14-8e4f-8eb30e92431b";
        const nonce = "nonce-value";

        const keyPair = await crypto.subtle.generateKey(
            { name: "ECDSA", namedCurve: "P-256" },
            true,
            ["sign", "verify"],
        );
        const rawPublicKey = new Uint8Array(
            await crypto.subtle.exportKey("raw", keyPair.publicKey),
        );
        const signature = new Uint8Array(
            await crypto.subtle.sign(
                { name: "ECDSA", hash: "SHA-256" },
                keyPair.privateKey,
                new TextEncoder().encode(nonce),
            ),
        );

        const state: MockState = {
            installId,
            installPubkeyB64: encodeBase64(rawPublicKey),
            challengeId,
            nonce,
            expiresAt: Math.floor(Date.now() / 1000) + 300,
            usedAt: null,
        };

        const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", rawPublicKey));
        const expectedHash = encodeBase64url(digest);

        const result = await verifyInstallProof(
            makeEnv(state),
            installId,
            challengeId,
            encodeBase64(signature),
        );

        expect(result.installPubkeyHash).toBe(expectedHash);
        expect(state.usedAt).not.toBeNull();
    });

    it("accepts DER-encoded ECDSA signatures from SecKey", async () => {
        const installId = "550e8400-e29b-41d4-a716-446655440000";
        const challengeId = "fd5fb8c5-df5d-44df-b0d5-a9bb6dad1d58";
        const nonce = "nonce-value-2";

        const keyPair = await crypto.subtle.generateKey(
            { name: "ECDSA", namedCurve: "P-256" },
            true,
            ["sign", "verify"],
        );
        const rawPublicKey = new Uint8Array(
            await crypto.subtle.exportKey("raw", keyPair.publicKey),
        );
        const rawSignature = new Uint8Array(
            await crypto.subtle.sign(
                { name: "ECDSA", hash: "SHA-256" },
                keyPair.privateKey,
                new TextEncoder().encode(nonce),
            ),
        );
        const derSignature = p1363ToDer(rawSignature);

        const state: MockState = {
            installId,
            installPubkeyB64: encodeBase64(rawPublicKey),
            challengeId,
            nonce,
            expiresAt: Math.floor(Date.now() / 1000) + 300,
            usedAt: null,
        };

        const result = await verifyInstallProof(
            makeEnv(state),
            installId,
            challengeId,
            encodeBase64(derSignature),
        );

        expect(result.installPubkeyHash.length).toBeGreaterThan(0);
        expect(state.usedAt).not.toBeNull();
    });
});
