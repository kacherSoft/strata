// ---------------------------------------------------------------------------
// Account auth helpers (email OTP + bearer sessions)
// ---------------------------------------------------------------------------

import type { Env } from "./types.js";
import { AppError } from "./errors.js";
import { requireEmail } from "./validation.js";

const DEFAULT_OTP_TTL_SECONDS = 10 * 60;
const DEFAULT_OTP_MAX_ATTEMPTS = 5;
const DEFAULT_SESSION_TTL_SECONDS = 30 * 24 * 60 * 60;
const DEFAULT_AUTH_RATE_LIMIT_WINDOW_SECONDS = 60;
const DEFAULT_AUTH_START_MAX_PER_EMAIL = 5;
const DEFAULT_AUTH_START_MAX_PER_IP = 20;

const MIN_OTP_TTL_SECONDS = 60;
const MAX_OTP_TTL_SECONDS = 30 * 60;
const MIN_SESSION_TTL_SECONDS = 15 * 60;
const MAX_SESSION_TTL_SECONDS = 90 * 24 * 60 * 60;
const MAX_AUTH_RATE_LIMIT_WINDOW_SECONDS = 10 * 60;

const AUTH_RATE_LIMIT_CLEANUP_INTERVAL_MS = 30_000;
let lastAuthRateLimitCleanupMs = 0;

export interface AuthPrincipal {
    userId: string;
    email: string;
    sessionId: string;
    sessionExpiresAt: number;
}

export interface StartEmailAuthResult {
    challengeId: string;
    expiresAt: number;
    delivery: "email" | "dev-log";
}

export interface VerifyEmailAuthResult {
    principal: AuthPrincipal;
    sessionToken: string;
}

function isTruthyFlag(raw: string | undefined, defaultValue: boolean): boolean {
    if (raw === undefined || raw === null) return defaultValue;
    const normalized = raw.trim().toLowerCase();
    if (!normalized) return defaultValue;
    if (["1", "true", "yes", "on"].includes(normalized)) return true;
    if (["0", "false", "no", "off"].includes(normalized)) return false;
    return defaultValue;
}

function parseBoundedInt(
    raw: string | undefined,
    fallback: number,
    min: number,
    max: number,
): number {
    if (raw === undefined || raw === null || !raw.trim()) return fallback;
    const parsed = Number.parseInt(raw.trim(), 10);
    if (!Number.isFinite(parsed) || !Number.isInteger(parsed) || parsed < min || parsed > max) {
        return fallback;
    }
    return parsed;
}

function nowSeconds(): number {
    return Math.floor(Date.now() / 1000);
}

export async function checkAuthRateLimit(
    env: Env,
    key: string,
    max: number,
    windowSeconds: number,
): Promise<boolean> {
    const nowMs = Date.now();
    const nowSec = Math.floor(nowMs / 1000);
    const window = Math.floor(nowSec / windowSeconds);
    const bucketKey = `auth:${key}:${window}`;
    const expiresAt = nowSec + windowSeconds * 2;

    try {
        await env.STRATA_DB.prepare(
            `INSERT INTO resolve_rate_limits (bucket_key, request_count, expires_at)
             VALUES (?, 1, ?)
             ON CONFLICT(bucket_key) DO UPDATE SET
               request_count = request_count + 1,
               expires_at = excluded.expires_at`,
        )
            .bind(bucketKey, expiresAt)
            .run();

        const bucket = await env.STRATA_DB.prepare(
            "SELECT request_count FROM resolve_rate_limits WHERE bucket_key = ? LIMIT 1",
        )
            .bind(bucketKey)
            .first<{ request_count: number }>();

        await cleanupAuthRateLimitRows(env, nowMs, nowSec);
        return (bucket?.request_count ?? 0) <= max;
    } catch (error) {
        console.error("[auth] rate limiter DB error, failing closed:", error);
        return false; // Deny on error — fail closed
    }
}

async function cleanupAuthRateLimitRows(
    env: Env,
    nowMs: number,
    nowSec: number,
): Promise<void> {
    if (nowMs - lastAuthRateLimitCleanupMs < AUTH_RATE_LIMIT_CLEANUP_INTERVAL_MS) return;
    lastAuthRateLimitCleanupMs = nowMs;

    try {
        await env.STRATA_DB.prepare(
            `DELETE FROM resolve_rate_limits
             WHERE bucket_key IN (
                SELECT bucket_key
                FROM resolve_rate_limits
                WHERE bucket_key LIKE 'auth:%' AND expires_at < ?
                ORDER BY expires_at ASC
                LIMIT 2000
             )`,
        )
            .bind(nowSec)
            .run();
    } catch {
        // Best effort cleanup only.
    }
}

function bytesToBase64url(data: Uint8Array): string {
    return btoa(String.fromCharCode(...data))
        .replace(/\+/g, "-")
        .replace(/\//g, "_")
        .replace(/=+$/, "");
}

function randomDigits(length: number): string {
    const out: string[] = [];
    while (out.length < length) {
        // Over-allocate to ensure enough non-rejected bytes in a single pass.
        const buffer = new Uint8Array(length * 2);
        crypto.getRandomValues(buffer);
        for (const byte of buffer) {
            if (byte >= 250) continue; // Reject biased values (250-255); 0-249 = 25 each digit
            out.push(String(byte % 10));
            if (out.length >= length) break;
        }
    }
    return out.join("");
}

function randomToken(bytes = 32): string {
    const buffer = new Uint8Array(bytes);
    crypto.getRandomValues(buffer);
    return bytesToBase64url(buffer);
}

async function sha256Hex(value: string): Promise<string> {
    const data = new TextEncoder().encode(value);
    const digest = await crypto.subtle.digest("SHA-256", data);
    return Array.from(new Uint8Array(digest))
        .map((byte) => byte.toString(16).padStart(2, "0"))
        .join("");
}

function timingSafeEqualString(a: string, b: string): boolean {
    const encoder = new TextEncoder();
    const bytesA = encoder.encode(a);
    const bytesB = encoder.encode(b);
    const max = Math.max(bytesA.length, bytesB.length);
    let result = bytesA.length ^ bytesB.length;
    for (let index = 0; index < max; index += 1) {
        const valueA = index < bytesA.length ? bytesA[index] : 0;
        const valueB = index < bytesB.length ? bytesB[index] : 0;
        result |= valueA ^ valueB;
    }
    return result === 0;
}

function parseBearerToken(request: Request): string | null {
    const header = request.headers.get("Authorization");
    if (!header) return null;
    const [scheme, token] = header.trim().split(/\s+/, 2);
    if (!scheme || !token || scheme.toLowerCase() !== "bearer") return null;
    const normalized = token.trim();
    return normalized || null;
}

function isLiveEnvironment(env: Env): boolean {
    return (env.ENVIRONMENT || "").trim().toLowerCase() === "production";
}

function otpTTLSeconds(env: Env): number {
    return parseBoundedInt(
        env.AUTH_OTP_TTL_SECONDS,
        DEFAULT_OTP_TTL_SECONDS,
        MIN_OTP_TTL_SECONDS,
        MAX_OTP_TTL_SECONDS,
    );
}

function sessionTTLSeconds(env: Env): number {
    return parseBoundedInt(
        env.AUTH_SESSION_TTL_SECONDS,
        DEFAULT_SESSION_TTL_SECONDS,
        MIN_SESSION_TTL_SECONDS,
        MAX_SESSION_TTL_SECONDS,
    );
}

function otpMaxAttempts(env: Env): number {
    return parseBoundedInt(env.AUTH_OTP_MAX_ATTEMPTS, DEFAULT_OTP_MAX_ATTEMPTS, 1, 10);
}

export function deviceSeatsEnforced(env: Env): boolean {
    return isTruthyFlag(env.ENFORCE_DEVICE_SEATS, true);
}

export function seatLimitForTier(env: Env, tier: "free" | "pro" | "vip"): number {
    const freeLimit = parseBoundedInt(env.FREE_DEVICE_LIMIT, 1, 1, 10);
    const proLimit = parseBoundedInt(env.PRO_DEVICE_LIMIT, 2, 1, 20);
    const vipLimit = parseBoundedInt(env.VIP_DEVICE_LIMIT, 3, 1, 30);

    if (tier === "vip") return vipLimit;
    if (tier === "pro") return proLimit;
    return freeLimit;
}

function authRateLimitWindowSeconds(env: Env): number {
    return parseBoundedInt(
        env.AUTH_RATE_LIMIT_WINDOW_SECONDS,
        DEFAULT_AUTH_RATE_LIMIT_WINDOW_SECONDS,
        10,
        MAX_AUTH_RATE_LIMIT_WINDOW_SECONDS,
    );
}

function authStartMaxPerEmail(env: Env): number {
    return parseBoundedInt(env.AUTH_START_MAX_PER_EMAIL, DEFAULT_AUTH_START_MAX_PER_EMAIL, 1, 100);
}

function authStartMaxPerIP(env: Env): number {
    return parseBoundedInt(env.AUTH_START_MAX_PER_IP, DEFAULT_AUTH_START_MAX_PER_IP, 1, 500);
}

async function sendOTPEmail(env: Env, email: string, code: string): Promise<"email" | "dev-log"> {
    const resendApiKey = env.RESEND_API_KEY?.trim();
    const fromAddress = env.AUTH_EMAIL_FROM?.trim();

    if (resendApiKey && fromAddress) {
        const response = await fetch("https://api.resend.com/emails", {
            method: "POST",
            headers: {
                Authorization: `Bearer ${resendApiKey}`,
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                from: fromAddress,
                to: [email],
                subject: "Your Strata verification code",
                text: `Your Strata verification code is ${code}. It expires in ${Math.floor(otpTTLSeconds(env) / 60)} minutes.`,
            }),
        });

        if (!response.ok) {
            const providerBody = await response.text().catch(() => "");
            console.error(`[auth] resend provider error status=${response.status} body=${providerBody}`);
            throw new AppError(502, "OTP_PROVIDER_ERROR", "Failed to send verification email");
        }

        return "email";
    }

    if (!isLiveEnvironment(env)) {
        console.log(`[auth] OTP code for ${email}: ${code}`);
        return "dev-log";
    }

    throw new AppError(
        500,
        "OTP_PROVIDER_NOT_CONFIGURED",
        "Email OTP provider is not configured",
    );
}

export async function startEmailAuth(
    env: Env,
    emailInput: string,
    clientIp?: string | null,
): Promise<StartEmailAuthResult> {
    const email = requireEmail(emailInput);
    const normalizedIp = (clientIp || "unknown").trim().toLowerCase() || "unknown";
    const rateLimitWindow = authRateLimitWindowSeconds(env);

    const allowedByIP = await checkAuthRateLimit(
        env,
        `start:ip:${normalizedIp}`,
        authStartMaxPerIP(env),
        rateLimitWindow,
    );
    if (!allowedByIP) {
        throw new AppError(429, "RATE_LIMITED", "Too many verification requests from this network");
    }

    const allowedByEmail = await checkAuthRateLimit(
        env,
        `start:email:${email}`,
        authStartMaxPerEmail(env),
        rateLimitWindow,
    );
    if (!allowedByEmail) {
        throw new AppError(429, "RATE_LIMITED", "Too many verification requests for this email");
    }

    const now = nowSeconds();
    const ttl = otpTTLSeconds(env);
    const expiresAt = now + ttl;
    const challengeId = crypto.randomUUID().toLowerCase();
    const otpCode = randomDigits(6);
    const otpHash = await sha256Hex(otpCode);

    // Invalidate older unconsumed challenges for this email.
    await env.STRATA_DB.prepare(
        `UPDATE auth_challenges
         SET consumed_at = ?
         WHERE email_normalized = ? AND consumed_at IS NULL`,
    )
        .bind(now, email)
        .run()
        .catch(() => {
            // Best effort.
        });

    await env.STRATA_DB.prepare(
        `INSERT INTO auth_challenges (challenge_id, email_normalized, otp_hash, expires_at, attempts, consumed_at, created_at)
         VALUES (?, ?, ?, ?, 0, NULL, ?)`,
    )
        .bind(challengeId, email, otpHash, expiresAt, now)
        .run();

    const delivery = await sendOTPEmail(env, email, otpCode);

    // Cleanup old rows opportunistically.
    await env.STRATA_DB.prepare(
        `DELETE FROM auth_challenges
         WHERE expires_at < ?
         LIMIT 500`,
    )
        .bind(now - 60)
        .run()
        .catch(() => {
            // Best effort.
        });

    const response: StartEmailAuthResult = {
        challengeId,
        expiresAt,
        delivery,
    };

    return response;
}

async function getOrCreateUser(env: Env, email: string): Promise<{ userId: string; email: string }> {
    const now = nowSeconds();

    const existing = await env.STRATA_DB.prepare(
        `SELECT id
         FROM users
         WHERE email_normalized = ?
         LIMIT 1`,
    )
        .bind(email)
        .first<{ id: string }>();

    if (existing?.id) {
        await env.STRATA_DB.prepare(
            `UPDATE users
             SET email_verified_at = ?, updated_at = ?
             WHERE id = ?`,
        )
            .bind(now, now, existing.id)
            .run();

        return { userId: existing.id, email };
    }

    const userId = crypto.randomUUID().toLowerCase();
    await env.STRATA_DB.prepare(
        `INSERT INTO users (id, email_normalized, email_verified_at, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?)`,
    )
        .bind(userId, email, now, now, now)
        .run();

    return { userId, email };
}

export async function verifyEmailAuth(
    env: Env,
    emailInput: string,
    challengeIdInput: string,
    codeInput: string,
): Promise<VerifyEmailAuthResult> {
    const email = requireEmail(emailInput);
    const challengeId = challengeIdInput.trim().toLowerCase();
    const otpCode = codeInput.trim();

    if (!challengeId) {
        throw new AppError(400, "INVALID_CHALLENGE", "challenge_id is required");
    }
    if (!otpCode) {
        throw new AppError(400, "INVALID_OTP", "verification code is required");
    }

    const now = nowSeconds();
    const maxAttempts = otpMaxAttempts(env);

    const challenge = await env.STRATA_DB.prepare(
        `SELECT challenge_id, otp_hash, expires_at, attempts, consumed_at
         FROM auth_challenges
         WHERE challenge_id = ? AND email_normalized = ?
         LIMIT 1`,
    )
        .bind(challengeId, email)
        .first<{
            challenge_id: string;
            otp_hash: string;
            expires_at: number;
            attempts: number;
            consumed_at: number | null;
        }>();

    if (!challenge) {
        throw new AppError(401, "INVALID_OTP", "Invalid verification code");
    }

    if (challenge.consumed_at !== null) {
        throw new AppError(401, "OTP_ALREADY_USED", "Verification code already used");
    }

    if (challenge.expires_at <= now) {
        throw new AppError(401, "OTP_EXPIRED", "Verification code expired");
    }

    if ((challenge.attempts || 0) >= maxAttempts) {
        throw new AppError(429, "OTP_ATTEMPTS_EXCEEDED", "Too many failed verification attempts");
    }

    const submittedHash = await sha256Hex(otpCode);
    if (!timingSafeEqualString(submittedHash, challenge.otp_hash)) {
        await env.STRATA_DB.prepare(
            `UPDATE auth_challenges
             SET attempts = attempts + 1
             WHERE challenge_id = ?`,
        )
            .bind(challengeId)
            .run();
        throw new AppError(401, "INVALID_OTP", "Invalid verification code");
    }

    const consume = await env.STRATA_DB.prepare(
        `UPDATE auth_challenges
         SET consumed_at = ?
         WHERE challenge_id = ? AND consumed_at IS NULL`,
    )
        .bind(now, challengeId)
        .run();

    const consumeChanges = (consume as { meta?: { changes?: number } }).meta?.changes || 0;
    if (consumeChanges < 1) {
        throw new AppError(409, "OTP_ALREADY_USED", "Verification code already used");
    }

    const user = await getOrCreateUser(env, email);

    const sessionToken = randomToken(32);
    const sessionHash = await sha256Hex(sessionToken);
    const sessionId = crypto.randomUUID().toLowerCase();
    const sessionExpiresAt = now + sessionTTLSeconds(env);

    await env.STRATA_DB.prepare(
        `INSERT INTO account_sessions (id, user_id, session_hash, expires_at, revoked_at, created_at, last_seen_at)
         VALUES (?, ?, ?, ?, NULL, ?, ?)`,
    )
        .bind(sessionId, user.userId, sessionHash, sessionExpiresAt, now, now)
        .run();

    // Cap concurrent sessions — revoke oldest if over limit
    const MAX_SESSIONS_PER_USER = 10;
    const sessionCount = await env.STRATA_DB.prepare(
        `SELECT COUNT(*) AS count FROM account_sessions
         WHERE user_id = ? AND revoked_at IS NULL AND expires_at > ?`,
    ).bind(user.userId, now).first<{ count: number }>();

    if (sessionCount && sessionCount.count > MAX_SESSIONS_PER_USER) {
        await env.STRATA_DB.prepare(
            `UPDATE account_sessions SET revoked_at = ?
             WHERE id IN (
                 SELECT id FROM account_sessions
                 WHERE user_id = ? AND revoked_at IS NULL AND expires_at > ?
                 ORDER BY created_at ASC
                 LIMIT ?
             )`,
        ).bind(now, user.userId, now, sessionCount.count - MAX_SESSIONS_PER_USER).run();
    }

    return {
        principal: {
            userId: user.userId,
            email: user.email,
            sessionId,
            sessionExpiresAt,
        },
        sessionToken,
    };
}

export async function requireAuthSession(request: Request, env: Env): Promise<AuthPrincipal> {
    const token = parseBearerToken(request);
    if (!token) {
        throw new AppError(401, "AUTH_REQUIRED", "A valid account session is required");
    }

    const sessionHash = await sha256Hex(token);
    const now = nowSeconds();

    const session = await env.STRATA_DB.prepare(
        `SELECT s.id AS session_id, s.user_id, s.expires_at, u.email_normalized
         FROM account_sessions s
         JOIN users u ON u.id = s.user_id
         WHERE s.session_hash = ?
           AND s.revoked_at IS NULL
           AND s.expires_at > ?
         LIMIT 1`,
    )
        .bind(sessionHash, now)
        .first<{
            session_id: string;
            user_id: string;
            expires_at: number;
            email_normalized: string;
        }>();

    if (!session) {
        throw new AppError(401, "INVALID_SESSION", "Session is invalid or expired");
    }

    await env.STRATA_DB.prepare(
        `UPDATE account_sessions
         SET last_seen_at = ?
         WHERE id = ?`,
    )
        .bind(now, session.session_id)
        .run()
        .catch(() => {
            // Best effort.
        });

    return {
        userId: session.user_id,
        email: session.email_normalized,
        sessionId: session.session_id,
        sessionExpiresAt: session.expires_at,
    };
}

export async function revokeAuthSession(request: Request, env: Env): Promise<void> {
    const principal = await requireAuthSession(request, env);
    const now = nowSeconds();
    await env.STRATA_DB.prepare(
        `UPDATE account_sessions
         SET revoked_at = ?
         WHERE id = ?`,
    )
        .bind(now, principal.sessionId)
        .run();
}
