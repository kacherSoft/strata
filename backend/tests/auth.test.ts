// ---------------------------------------------------------------------------
// Tests for auth endpoints
// ---------------------------------------------------------------------------

import { beforeEach, describe, expect, it } from "vitest";
import { handleAuthEmailStart } from "../src/routes/auth-start.js";
import { handleAuthEmailVerify } from "../src/routes/auth-verify.js";
import { handleAuthSessionRevoke } from "../src/routes/auth-session-revoke.js";
import type { Env } from "../src/types.js";

interface ChallengeRow {
    challenge_id: string;
    email_normalized: string;
    otp_hash: string;
    expires_at: number;
    attempts: number;
    consumed_at: number | null;
    created_at: number;
}

interface UserRow {
    id: string;
    email_normalized: string;
    email_verified_at: number;
    created_at: number;
    updated_at: number;
}

interface SessionRow {
    id: string;
    user_id: string;
    session_hash: string;
    expires_at: number;
    revoked_at: number | null;
    created_at: number;
    last_seen_at: number;
}

interface MockState {
    challenges: Map<string, ChallengeRow>;
    usersByEmail: Map<string, UserRow>;
    usersById: Map<string, UserRow>;
    sessionsByHash: Map<string, SessionRow>;
    sessionsById: Map<string, SessionRow>;
    rateLimits: Map<string, { request_count: number; expires_at: number }>;
}

function createState(): MockState {
    return {
        challenges: new Map(),
        usersByEmail: new Map(),
        usersById: new Map(),
        sessionsByHash: new Map(),
        sessionsById: new Map(),
        rateLimits: new Map(),
    };
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
                    if (sql.includes("FROM auth_challenges") && sql.includes("WHERE challenge_id = ?")) {
                        const [challengeId, email] = params as [string, string];
                        const row = state.challenges.get(challengeId);
                        if (!row || row.email_normalized !== email) return null;
                        return row;
                    }

                    if (sql.includes("FROM users") && sql.includes("email_normalized = ?")) {
                        const [email] = params as [string];
                        return state.usersByEmail.get(email) || null;
                    }

                    if (sql.includes("FROM account_sessions") && sql.includes("session_hash = ?")) {
                        const [sessionHash, now] = params as [string, number];
                        const session = state.sessionsByHash.get(sessionHash);
                        if (!session) return null;
                        if (session.revoked_at !== null) return null;
                        if (session.expires_at <= now) return null;
                        const user = state.usersById.get(session.user_id);
                        if (!user) return null;
                        return {
                            session_id: session.id,
                            user_id: session.user_id,
                            expires_at: session.expires_at,
                            email_normalized: user.email_normalized,
                        };
                    }

                    if (sql.includes("FROM resolve_rate_limits")) {
                        const [bucketKey] = params as [string];
                        const bucket = state.rateLimits.get(bucketKey);
                        if (!bucket) return null;
                        return bucket;
                    }

                    return null;
                },
                run: async () => {
                    if (sql.startsWith("INSERT INTO resolve_rate_limits")) {
                        const [bucketKey, expiresAt] = params as [string, number];
                        const existing = state.rateLimits.get(bucketKey);
                        if (existing) {
                            existing.request_count += 1;
                            existing.expires_at = expiresAt;
                        } else {
                            state.rateLimits.set(bucketKey, {
                                request_count: 1,
                                expires_at: expiresAt,
                            });
                        }
                        return { meta: { changes: 1 } };
                    }

                    if (sql.startsWith("DELETE FROM resolve_rate_limits")) {
                        const [threshold] = params as [number];
                        let changes = 0;
                        for (const [bucketKey, bucket] of state.rateLimits.entries()) {
                            if (bucketKey.startsWith("auth:") && bucket.expires_at < threshold) {
                                state.rateLimits.delete(bucketKey);
                                changes += 1;
                            }
                        }
                        return { meta: { changes } };
                    }

                    if (sql.includes("UPDATE auth_challenges") && sql.includes("email_normalized = ?")) {
                        const [consumedAt, email] = params as [number, string];
                        let changes = 0;
                        for (const row of state.challenges.values()) {
                            if (row.email_normalized === email && row.consumed_at === null) {
                                row.consumed_at = consumedAt;
                                changes += 1;
                            }
                        }
                        return { meta: { changes } };
                    }

                    if (sql.startsWith("INSERT INTO auth_challenges")) {
                        const [challengeId, email, otpHash, expiresAt, createdAt] =
                            params as [string, string, string, number, number];
                        state.challenges.set(challengeId, {
                            challenge_id: challengeId,
                            email_normalized: email,
                            otp_hash: otpHash,
                            expires_at: expiresAt,
                            attempts: 0,
                            consumed_at: null,
                            created_at: createdAt,
                        });
                        return { meta: { changes: 1 } };
                    }

                    if (sql.startsWith("DELETE FROM auth_challenges")) {
                        const [threshold] = params as [number];
                        let changes = 0;
                        for (const [id, row] of state.challenges.entries()) {
                            if (row.expires_at < threshold) {
                                state.challenges.delete(id);
                                changes += 1;
                            }
                        }
                        return { meta: { changes } };
                    }

                    if (sql.includes("UPDATE auth_challenges") && sql.includes("attempts = attempts + 1")) {
                        const [challengeId] = params as [string];
                        const row = state.challenges.get(challengeId);
                        if (!row) return { meta: { changes: 0 } };
                        row.attempts += 1;
                        return { meta: { changes: 1 } };
                    }

                    if (sql.includes("UPDATE auth_challenges") && sql.includes("WHERE challenge_id = ? AND consumed_at IS NULL")) {
                        const [consumedAt, challengeId] = params as [number, string];
                        const row = state.challenges.get(challengeId);
                        if (!row || row.consumed_at !== null) return { meta: { changes: 0 } };
                        row.consumed_at = consumedAt;
                        return { meta: { changes: 1 } };
                    }

                    if (sql.startsWith("UPDATE users")) {
                        const [verifiedAt, updatedAt, userId] = params as [number, number, string];
                        const row = state.usersById.get(userId);
                        if (!row) return { meta: { changes: 0 } };
                        row.email_verified_at = verifiedAt;
                        row.updated_at = updatedAt;
                        return { meta: { changes: 1 } };
                    }

                    if (sql.startsWith("INSERT INTO users")) {
                        const [userId, email, verifiedAt, createdAt, updatedAt] =
                            params as [string, string, number, number, number];
                        const row: UserRow = {
                            id: userId,
                            email_normalized: email,
                            email_verified_at: verifiedAt,
                            created_at: createdAt,
                            updated_at: updatedAt,
                        };
                        state.usersById.set(userId, row);
                        state.usersByEmail.set(email, row);
                        return { meta: { changes: 1 } };
                    }

                    if (sql.startsWith("INSERT INTO account_sessions")) {
                        const [sessionId, userId, sessionHash, expiresAt, createdAt, lastSeenAt] =
                            params as [string, string, string, number, number, number];
                        const row: SessionRow = {
                            id: sessionId,
                            user_id: userId,
                            session_hash: sessionHash,
                            expires_at: expiresAt,
                            revoked_at: null,
                            created_at: createdAt,
                            last_seen_at: lastSeenAt,
                        };
                        state.sessionsById.set(sessionId, row);
                        state.sessionsByHash.set(sessionHash, row);
                        return { meta: { changes: 1 } };
                    }

                    if (sql.startsWith("UPDATE account_sessions") && sql.includes("last_seen_at")) {
                        const [lastSeenAt, sessionId] = params as [number, string];
                        const row = state.sessionsById.get(sessionId);
                        if (!row) return { meta: { changes: 0 } };
                        row.last_seen_at = lastSeenAt;
                        return { meta: { changes: 1 } };
                    }

                    if (sql.startsWith("UPDATE account_sessions") && sql.includes("revoked_at")) {
                        const [revokedAt, sessionId] = params as [number, string];
                        const row = state.sessionsById.get(sessionId);
                        if (!row) return { meta: { changes: 0 } };
                        row.revoked_at = revokedAt;
                        return { meta: { changes: 1 } };
                    }

                    return { meta: { changes: 1 } };
                },
            };
            return statement;
        },
    } as unknown as D1Database;
}

function makeEnv(state: MockState, overrides: Partial<Env> = {}): Env {
    return {
        STRATA_DB: makeD1Mock(state),
        DODO_API_KEY: "test-api-key",
        DODO_WEBHOOK_SECRET: "test-webhook-secret",
        ENTITLEMENT_SIGNING_PRIVATE_KEY:
            "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60",
        ENVIRONMENT: "test",
        DODO_BASE_URL: "https://test.dodopayments.com",
        TOKEN_TTL_SECONDS: "3600",
        AUTH_REQUIRED_FOR_CHECKOUT: "true",
        AUTH_REQUIRED_FOR_RESTORE: "true",
        AUTH_REQUIRED_FOR_RESOLVE: "true",
        ENFORCE_DEVICE_SEATS: "true",
        ...overrides,
    };
}

describe("auth endpoints", () => {
    let state: MockState;

    beforeEach(() => {
        state = createState();
    });

    it("starts and verifies OTP challenge", async () => {
        const startReq = new Request("https://api.test/v1/auth/email/start", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ email: "user@example.com" }),
        });

        const startRes = await handleAuthEmailStart(startReq, makeEnv(state));
        expect(startRes.status).toBe(200);

        const startBody = await startRes.json() as {
            challenge_id: string;
            debug_code?: string;
            delivery: string;
        };

        expect(startBody.challenge_id).toBeTruthy();
        expect(startBody.delivery).toBe("dev-log");
        expect(startBody.debug_code).toMatch(/^\d{6}$/);

        const verifyReq = new Request("https://api.test/v1/auth/email/verify", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                email: "user@example.com",
                challenge_id: startBody.challenge_id,
                code: startBody.debug_code,
            }),
        });

        const verifyRes = await handleAuthEmailVerify(verifyReq, makeEnv(state));
        expect(verifyRes.status).toBe(200);

        const verifyBody = await verifyRes.json() as {
            session_token: string;
            user_id: string;
            email: string;
        };

        expect(verifyBody.session_token).toBeTruthy();
        expect(verifyBody.user_id).toMatch(/[0-9a-f-]{36}/);
        expect(verifyBody.email).toBe("user@example.com");
    });

    it("rejects wrong OTP code", async () => {
        const startReq = new Request("https://api.test/v1/auth/email/start", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ email: "wrong@example.com" }),
        });

        const startRes = await handleAuthEmailStart(startReq, makeEnv(state));
        const startBody = await startRes.json() as { challenge_id: string };

        const verifyReq = new Request("https://api.test/v1/auth/email/verify", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                email: "wrong@example.com",
                challenge_id: startBody.challenge_id,
                code: "000000",
            }),
        });

        const verifyRes = await handleAuthEmailVerify(verifyReq, makeEnv(state));
        expect(verifyRes.status).toBe(401);
        const body = await verifyRes.json() as { error_code: string };
        expect(body.error_code).toBe("INVALID_OTP");
    });

    it("rate limits repeated OTP start requests for same email", async () => {
        const env = makeEnv(state, {
            AUTH_START_MAX_PER_EMAIL: "1",
            AUTH_START_MAX_PER_IP: "10",
            AUTH_RATE_LIMIT_WINDOW_SECONDS: "60",
        });

        const firstReq = new Request("https://api.test/v1/auth/email/start", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "CF-Connecting-IP": "203.0.113.8",
            },
            body: JSON.stringify({ email: "limited@example.com" }),
        });
        const firstRes = await handleAuthEmailStart(firstReq, env);
        expect(firstRes.status).toBe(200);

        const secondReq = new Request("https://api.test/v1/auth/email/start", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "CF-Connecting-IP": "203.0.113.8",
            },
            body: JSON.stringify({ email: "limited@example.com" }),
        });
        const secondRes = await handleAuthEmailStart(secondReq, env);
        expect(secondRes.status).toBe(429);
        const body = await secondRes.json() as { error_code: string };
        expect(body.error_code).toBe("RATE_LIMITED");
    });

    it("revokes auth session", async () => {
        const startReq = new Request("https://api.test/v1/auth/email/start", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ email: "revoke@example.com" }),
        });
        const startRes = await handleAuthEmailStart(startReq, makeEnv(state));
        const startBody = await startRes.json() as { challenge_id: string; debug_code: string };

        const verifyReq = new Request("https://api.test/v1/auth/email/verify", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                email: "revoke@example.com",
                challenge_id: startBody.challenge_id,
                code: startBody.debug_code,
            }),
        });
        const verifyRes = await handleAuthEmailVerify(verifyReq, makeEnv(state));
        const verifyBody = await verifyRes.json() as { session_token: string };

        const revokeReq = new Request("https://api.test/v1/auth/session/revoke", {
            method: "POST",
            headers: {
                Authorization: `Bearer ${verifyBody.session_token}`,
            },
        });
        const revokeRes = await handleAuthSessionRevoke(revokeReq, makeEnv(state));
        expect(revokeRes.status).toBe(200);

        const revokeAgainRes = await handleAuthSessionRevoke(revokeReq, makeEnv(state));
        expect(revokeAgainRes.status).toBe(401);
        const body = await revokeAgainRes.json() as { error_code: string };
        expect(body.error_code).toBe("INVALID_SESSION");
    });
});
