// ---------------------------------------------------------------------------
// Ed25519 signing module for entitlement tokens
// ---------------------------------------------------------------------------

import * as ed from "@noble/ed25519";

import type { TokenClaims, Tier } from "./types.js";

// Use the Web Crypto SHA-512 for @noble/ed25519 v2+
// (Workers environment has global crypto available)
ed.etc.sha512Sync = undefined; // Force async path using webcrypto
// The library will use `crypto.subtle` automatically in Workers env

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function hexToBytes(hex: string): Uint8Array {
    const clean = hex.replace(/\s+/g, "");
    if (clean.length % 2 !== 0) throw new Error("Invalid hex string length");
    const bytes = new Uint8Array(clean.length / 2);
    for (let i = 0; i < clean.length; i += 2) {
        bytes[i / 2] = parseInt(clean.substring(i, i + 2), 16);
    }
    return bytes;
}

function bytesToHex(bytes: Uint8Array): string {
    return Array.from(bytes)
        .map((b) => b.toString(16).padStart(2, "0"))
        .join("");
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

function base64urlEncode(data: Uint8Array): string {
    const binary = bytesToBinaryString(data);
    return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64urlDecode(str: string): Uint8Array {
    const normalized = str.replace(/-/g, "+").replace(/_/g, "/");
    const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
    const binary = atob(padded);
    return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}

// ---------------------------------------------------------------------------
// Token creation
// ---------------------------------------------------------------------------

export interface SignTokenParams {
    tier: Tier;
    sub: string;
    uid?: string;
    installId: string;
    ttlSeconds: number;
    privateKeyHex: string;
    installPubkeyHash?: string;
    /** Key ID for rotation support — included in token payload as `kid` claim */
    kid?: string;
}

/**
 * Create and sign an entitlement token.
 * Format: base64url(JSON payload).base64url(signature)
 */
export async function signToken(params: SignTokenParams): Promise<string> {
    const now = Math.floor(Date.now() / 1000);

    const claims: TokenClaims = {
        tier: params.tier,
        sub: params.sub,
        install_id: params.installId,
        iat: now,
        exp: now + params.ttlSeconds,
        jti: crypto.randomUUID(),
    };

    if (params.uid) {
        claims.uid = params.uid;
    }

    if (params.kid) {
        claims.kid = params.kid;
    }

    if (params.installPubkeyHash) {
        claims.install_pubkey_hash = params.installPubkeyHash;
    }

    const payloadBytes = new TextEncoder().encode(JSON.stringify(claims));
    const payloadB64 = base64urlEncode(payloadBytes);

    const privateKey = hexToBytes(params.privateKeyHex);
    const signature = await ed.signAsync(payloadBytes, privateKey);
    const signatureB64 = base64urlEncode(signature);

    return `${payloadB64}.${signatureB64}`;
}

// ---------------------------------------------------------------------------
// Token verification (used in tests; app does this client-side)
// ---------------------------------------------------------------------------

/**
 * Verify an entitlement token and return its claims.
 * Throws on invalid signature or malformed token.
 */
export async function verifyToken(
    token: string,
    publicKeyHex: string,
): Promise<TokenClaims> {
    const parts = token.split(".");
    if (parts.length !== 2) {
        throw new Error("Invalid token format: expected payload.signature");
    }

    const [payloadB64, signatureB64] = parts;
    const payloadBytes = base64urlDecode(payloadB64);
    const signature = base64urlDecode(signatureB64);
    const publicKey = hexToBytes(publicKeyHex);

    const valid = await ed.verifyAsync(signature, payloadBytes, publicKey);
    if (!valid) {
        throw new Error("Invalid token signature");
    }

    const claimsJson = new TextDecoder().decode(payloadBytes);
    return JSON.parse(claimsJson) as TokenClaims;
}

/**
 * Verify a token against a map of key IDs to public key hex strings.
 * Uses the `kid` claim in the token payload to select the correct key.
 * Falls back to the "default" key if no `kid` claim is present.
 * Throws on invalid signature, unknown kid, or malformed token.
 */
export async function verifyTokenMultiKey(
    token: string,
    keyMap: Record<string, string>,
): Promise<TokenClaims> {
    const parts = token.split(".");
    if (parts.length !== 2) {
        throw new Error("Invalid token format: expected payload.signature");
    }

    const [payloadB64, signatureB64] = parts;
    const payloadBytes = base64urlDecode(payloadB64);
    const claimsJson = new TextDecoder().decode(payloadBytes);
    const claims = JSON.parse(claimsJson) as TokenClaims;

    const kid = claims.kid || "default";
    const publicKeyHex = keyMap[kid];
    if (!publicKeyHex) {
        throw new Error(`Unknown key ID: ${kid}`);
    }

    const signature = base64urlDecode(signatureB64);
    const publicKey = hexToBytes(publicKeyHex);

    const valid = await ed.verifyAsync(signature, payloadBytes, publicKey);
    if (!valid) {
        throw new Error("Invalid token signature");
    }

    return claims;
}

/**
 * Derive the public key hex from a private key hex (seed).
 */
export async function publicKeyFromPrivate(
    privateKeyHex: string,
): Promise<string> {
    const privateKey = hexToBytes(privateKeyHex);
    const publicKey = await ed.getPublicKeyAsync(privateKey);
    return bytesToHex(publicKey);
}

// Re-export helpers for tests
export { hexToBytes, bytesToHex, base64urlEncode, base64urlDecode };
