// ---------------------------------------------------------------------------
// Install proof utilities (challenge + nonce signature verification)
// ---------------------------------------------------------------------------

import type { Env } from "./types.js";
import { AppError } from "./errors.js";

const CHALLENGE_TTL_SECONDS = 300; // 5 minutes
const NONCE_BYTES = 32;
const PUBLIC_KEY_LENGTH_BYTES = 65; // P-256 uncompressed point (0x04 + X + Y)
const ECDSA_P256_RAW_SIGNATURE_LENGTH_BYTES = 64; // r(32) + s(32), IEEE-P1363

export interface InstallProofResult {
    installPubkeyHash: string;
}

export interface InstallChallenge {
    challenge_id: string;
    nonce: string;
    expires_at: number;
}

interface ChallengeRow {
    nonce: string;
    expires_at: number;
    used_at: number | null;
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

function decodeBase64Flexible(input: string, fieldName: string): Uint8Array {
    const trimmed = input.trim();
    if (!trimmed) {
        throw new AppError(400, "INVALID_BODY", `${fieldName} is required`);
    }

    const normalized = trimmed.replace(/-/g, "+").replace(/_/g, "/");
    const padded = normalized + "===".slice((normalized.length + 3) % 4);

    let binary: string;
    try {
        binary = atob(padded);
    } catch {
        throw new AppError(400, "INVALID_BODY", `${fieldName} must be valid base64`);
    }
    return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}

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

function p1363ToDer(signature: Uint8Array): Uint8Array {
    if (signature.length !== ECDSA_P256_RAW_SIGNATURE_LENGTH_BYTES) {
        return signature;
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

function decodeDerLength(input: Uint8Array, offset: number): { length: number; next: number } | null {
    if (offset >= input.length) return null;
    const first = input[offset];
    if ((first & 0x80) === 0) {
        return { length: first, next: offset + 1 };
    }

    const octets = first & 0x7f;
    if (octets < 1 || octets > 2 || offset + 1 + octets > input.length) {
        return null;
    }

    let length = 0;
    for (let i = 0; i < octets; i += 1) {
        length = (length << 8) | input[offset + 1 + i];
    }
    return { length, next: offset + 1 + octets };
}

function decodeDerIntegerValue(value: Uint8Array): Uint8Array | null {
    if (!value.length) return null;

    let start = 0;
    while (start < value.length - 1 && value[start] === 0) {
        start += 1;
    }
    const trimmed = value.subarray(start);
    if (trimmed.length > 32) return null;

    const result = new Uint8Array(32);
    result.set(trimmed, 32 - trimmed.length);
    return result;
}

function derToP1363(signature: Uint8Array): Uint8Array | null {
    if (signature.length < 8 || signature[0] !== 0x30) return null;

    const sequenceLength = decodeDerLength(signature, 1);
    if (!sequenceLength) return null;
    let cursor = sequenceLength.next;
    const sequenceEnd = cursor + sequenceLength.length;
    if (sequenceEnd !== signature.length || cursor >= signature.length) return null;

    if (signature[cursor] !== 0x02) return null;
    cursor += 1;
    const rLength = decodeDerLength(signature, cursor);
    if (!rLength) return null;
    cursor = rLength.next;
    if (cursor + rLength.length > sequenceEnd) return null;
    const rValue = signature.subarray(cursor, cursor + rLength.length);
    cursor += rLength.length;

    if (cursor >= sequenceEnd || signature[cursor] !== 0x02) return null;
    cursor += 1;
    const sLength = decodeDerLength(signature, cursor);
    if (!sLength) return null;
    cursor = sLength.next;
    if (cursor + sLength.length > sequenceEnd) return null;
    const sValue = signature.subarray(cursor, cursor + sLength.length);
    cursor += sLength.length;

    if (cursor !== sequenceEnd) return null;

    const r = decodeDerIntegerValue(rValue);
    const s = decodeDerIntegerValue(sValue);
    if (!r || !s) return null;

    const raw = new Uint8Array(ECDSA_P256_RAW_SIGNATURE_LENGTH_BYTES);
    raw.set(r, 0);
    raw.set(s, 32);
    return raw;
}

async function verifyEcdsaSignature(
    publicKey: CryptoKey,
    signatureBytes: Uint8Array,
    message: Uint8Array,
): Promise<boolean> {
    const params: EcdsaParams = { name: "ECDSA", hash: "SHA-256" };

    if (await crypto.subtle.verify(params, publicKey, signatureBytes, message)) {
        return true;
    }

    const rawFromDer = derToP1363(signatureBytes);
    if (rawFromDer && await crypto.subtle.verify(params, publicKey, rawFromDer, message)) {
        return true;
    }

    if (signatureBytes.length === ECDSA_P256_RAW_SIGNATURE_LENGTH_BYTES) {
        const derSignature = p1363ToDer(signatureBytes);
        return crypto.subtle.verify(params, publicKey, derSignature, message);
    }

    return false;
}

export function parseInstallPublicKey(pubkey: string): Uint8Array {
    let publicKey: Uint8Array;
    try {
        publicKey = decodeBase64Flexible(pubkey, "install_pubkey");
    } catch (error) {
        if (error instanceof AppError) {
            throw new AppError(
                400,
                "INVALID_PUBKEY",
                "install_pubkey must be valid base64-encoded public key bytes",
            );
        }
        throw error;
    }
    if (publicKey.length !== PUBLIC_KEY_LENGTH_BYTES || publicKey[0] !== 0x04) {
        throw new AppError(
            400,
            "INVALID_PUBKEY",
            "install_pubkey must be a P-256 uncompressed public key",
        );
    }
    return publicKey;
}

async function getInstallPublicKey(env: Env, installId: string): Promise<Uint8Array> {
    const record = await env.STRATA_DB.prepare(
        `SELECT install_pubkey
         FROM purchase_links
         WHERE install_id = ? AND install_pubkey IS NOT NULL
         ORDER BY updated_at DESC, id DESC
         LIMIT 1`,
    )
        .bind(installId)
        .first<{ install_pubkey: string }>();

    if (!record?.install_pubkey) {
        throw new AppError(
            404,
            "INSTALL_NOT_REGISTERED",
            "Install is not registered. Register install before resolving entitlements",
        );
    }

    return parseInstallPublicKey(record.install_pubkey);
}

async function hashPublicKey(publicKey: Uint8Array): Promise<string> {
    const digest = await crypto.subtle.digest("SHA-256", publicKey);
    return base64urlEncode(new Uint8Array(digest));
}

async function cleanupExpiredChallenges(env: Env, now: number): Promise<void> {
    try {
        await env.STRATA_DB.prepare(
            `DELETE FROM install_challenges
             WHERE challenge_id IN (
                SELECT challenge_id
                FROM install_challenges
                WHERE expires_at < ?
                ORDER BY expires_at ASC
                LIMIT 500
             )`,
        )
            .bind(now)
            .run();
    } catch {
        // Best effort cleanup only.
    }
}

export async function createInstallChallenge(
    env: Env,
    installId: string,
): Promise<InstallChallenge> {
    // Ensure install is registered before issuing challenges.
    await getInstallPublicKey(env, installId);

    const now = Math.floor(Date.now() / 1000);
    await cleanupExpiredChallenges(env, now);

    const nonceBytes = new Uint8Array(NONCE_BYTES);
    crypto.getRandomValues(nonceBytes);
    const nonce = base64urlEncode(nonceBytes);
    const challengeId = crypto.randomUUID();
    const expiresAt = now + CHALLENGE_TTL_SECONDS;

    await env.STRATA_DB.prepare(
        `INSERT INTO install_challenges
            (challenge_id, install_id, nonce, expires_at, created_at)
         VALUES (?, ?, ?, ?, ?)`,
    )
        .bind(challengeId, installId, nonce, expiresAt, now)
        .run();

    return {
        challenge_id: challengeId,
        nonce,
        expires_at: expiresAt,
    };
}

export async function verifyInstallProof(
    env: Env,
    installId: string,
    challengeId: string,
    nonceSignature: string,
): Promise<InstallProofResult> {
    const now = Math.floor(Date.now() / 1000);

    const challenge = await env.STRATA_DB.prepare(
        `SELECT nonce, expires_at, used_at
         FROM install_challenges
         WHERE challenge_id = ? AND install_id = ?
         LIMIT 1`,
    )
        .bind(challengeId, installId)
        .first<ChallengeRow>();

    if (!challenge) {
        throw new AppError(401, "INVALID_CHALLENGE", "Challenge is invalid");
    }
    if (challenge.used_at) {
        throw new AppError(401, "CHALLENGE_ALREADY_USED", "Challenge has already been used");
    }
    if (challenge.expires_at < now) {
        throw new AppError(401, "CHALLENGE_EXPIRED", "Challenge has expired");
    }

    const publicKeyBytes = await getInstallPublicKey(env, installId);
    const signatureBytes = decodeBase64Flexible(nonceSignature, "nonce_signature");

    const publicKey = await crypto.subtle.importKey(
        "raw",
        publicKeyBytes,
        { name: "ECDSA", namedCurve: "P-256" },
        false,
        ["verify"],
    );

    const verified = await verifyEcdsaSignature(
        publicKey,
        signatureBytes,
        new TextEncoder().encode(challenge.nonce),
    );

    if (!verified) {
        throw new AppError(401, "INVALID_INSTALL_PROOF", "Install proof verification failed");
    }

    const useResult = await env.STRATA_DB.prepare(
        "UPDATE install_challenges SET used_at = ? WHERE challenge_id = ? AND used_at IS NULL",
    )
        .bind(now, challengeId)
        .run();

    if (!useResult.meta.changes || useResult.meta.changes < 1) {
        throw new AppError(401, "CHALLENGE_ALREADY_USED", "Challenge has already been used");
    }

    return {
        installPubkeyHash: await hashPublicKey(publicKeyBytes),
    };
}
