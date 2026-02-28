// ---------------------------------------------------------------------------
// Tests for Ed25519 signing module
// ---------------------------------------------------------------------------

import { describe, it, expect } from "vitest";
import {
    signToken,
    verifyToken,
    publicKeyFromPrivate,
    hexToBytes,
    base64urlDecode,
} from "../src/signing.js";
import type { TokenClaims } from "../src/types.js";

// Test keypair (DO NOT use in production!)
// Generated with: crypto.getRandomValues(new Uint8Array(32))
const TEST_PRIVATE_KEY_HEX =
    "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60";

describe("signing", () => {
    let testPublicKeyHex: string;

    // Derive the public key from the test private key
    it("should derive public key from private key", async () => {
        testPublicKeyHex = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        expect(testPublicKeyHex).toMatch(/^[0-9a-f]{64}$/);
    });

    it("should sign and verify a token round-trip", async () => {
        if (!testPublicKeyHex) {
            testPublicKeyHex = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        }

        const token = await signToken({
            tier: "pro",
            sub: "test@example.com",
            installId: "550e8400-e29b-41d4-a716-446655440000",
            ttlSeconds: 3600,
            privateKeyHex: TEST_PRIVATE_KEY_HEX,
        });

        // Token format: base64url.base64url
        expect(token).toMatch(/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/);

        // Verify signature and get claims
        const claims = await verifyToken(token, testPublicKeyHex);
        expect(claims.tier).toBe("pro");
        expect(claims.sub).toBe("test@example.com");
        expect(claims.install_id).toBe("550e8400-e29b-41d4-a716-446655440000");
        expect(claims.iat).toBeGreaterThan(0);
        expect(claims.exp).toBeGreaterThan(claims.iat);
        expect(claims.exp - claims.iat).toBe(3600);
        expect(claims.jti).toMatch(
            /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,
        );
    });

    it("should include install_pubkey_hash when provided", async () => {
        if (!testPublicKeyHex) {
            testPublicKeyHex = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        }

        const token = await signToken({
            tier: "vip",
            sub: "vip@example.com",
            installId: "550e8400-e29b-41d4-a716-446655440000",
            ttlSeconds: 3600,
            privateKeyHex: TEST_PRIVATE_KEY_HEX,
            installPubkeyHash: "sha256-abc123",
        });

        const claims = await verifyToken(token, testPublicKeyHex);
        expect(claims.tier).toBe("vip");
        expect(claims.install_pubkey_hash).toBe("sha256-abc123");
    });

    it("should reject a tampered token", async () => {
        if (!testPublicKeyHex) {
            testPublicKeyHex = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        }

        const token = await signToken({
            tier: "pro",
            sub: "test@example.com",
            installId: "550e8400-e29b-41d4-a716-446655440000",
            ttlSeconds: 3600,
            privateKeyHex: TEST_PRIVATE_KEY_HEX,
        });

        // Tamper with the payload (change a character)
        const parts = token.split(".");
        const payload = base64urlDecode(parts[0]);
        payload[0] = payload[0] ^ 0xff; // flip bits
        const tamperedPayload = btoa(String.fromCharCode(...payload))
            .replace(/\+/g, "-")
            .replace(/\//g, "_")
            .replace(/=+$/, "");
        const tamperedToken = `${tamperedPayload}.${parts[1]}`;

        await expect(verifyToken(tamperedToken, testPublicKeyHex)).rejects.toThrow(
            "Invalid token signature",
        );
    });

    it("should reject a token with wrong public key", async () => {
        const token = await signToken({
            tier: "pro",
            sub: "test@example.com",
            installId: "550e8400-e29b-41d4-a716-446655440000",
            ttlSeconds: 3600,
            privateKeyHex: TEST_PRIVATE_KEY_HEX,
        });

        // Use a random different public key
        const wrongKeyHex =
            "0000000000000000000000000000000000000000000000000000000000000001";
        // Derive the actual public key for this "private key"
        const wrongPubKey = await publicKeyFromPrivate(wrongKeyHex);

        await expect(verifyToken(token, wrongPubKey)).rejects.toThrow(
            "Invalid token signature",
        );
    });

    it("should reject malformed token format", async () => {
        if (!testPublicKeyHex) {
            testPublicKeyHex = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        }

        await expect(verifyToken("notavalidtoken", testPublicKeyHex)).rejects.toThrow(
            "Invalid token format",
        );

        await expect(
            verifyToken("a.b.c", testPublicKeyHex),
        ).rejects.toThrow("Invalid token format");
    });

    it("should produce unique jti for each token", async () => {
        const token1 = await signToken({
            tier: "free",
            sub: "test@example.com",
            installId: "550e8400-e29b-41d4-a716-446655440000",
            ttlSeconds: 3600,
            privateKeyHex: TEST_PRIVATE_KEY_HEX,
        });

        const token2 = await signToken({
            tier: "free",
            sub: "test@example.com",
            installId: "550e8400-e29b-41d4-a716-446655440000",
            ttlSeconds: 3600,
            privateKeyHex: TEST_PRIVATE_KEY_HEX,
        });

        if (!testPublicKeyHex) {
            testPublicKeyHex = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        }
        const claims1 = await verifyToken(token1, testPublicKeyHex);
        const claims2 = await verifyToken(token2, testPublicKeyHex);
        expect(claims1.jti).not.toBe(claims2.jti);
    });

    it("should set correct TTL in token claims", async () => {
        if (!testPublicKeyHex) {
            testPublicKeyHex = await publicKeyFromPrivate(TEST_PRIVATE_KEY_HEX);
        }

        const ttl = 86400; // 24h
        const beforeSign = Math.floor(Date.now() / 1000);

        const token = await signToken({
            tier: "pro",
            sub: "test@example.com",
            installId: "550e8400-e29b-41d4-a716-446655440000",
            ttlSeconds: ttl,
            privateKeyHex: TEST_PRIVATE_KEY_HEX,
        });

        const claims = await verifyToken(token, testPublicKeyHex);
        const afterSign = Math.floor(Date.now() / 1000);

        expect(claims.iat).toBeGreaterThanOrEqual(beforeSign);
        expect(claims.iat).toBeLessThanOrEqual(afterSign);
        expect(claims.exp - claims.iat).toBe(ttl);
    });
});
