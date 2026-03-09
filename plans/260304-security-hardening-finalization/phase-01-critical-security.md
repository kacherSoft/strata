# Phase 1 — Critical Security Remediations

Priority: **P0 — Block release**
Status: Pending
Depends on: None
Estimated tasks: 6
Parallelism: **All 6 tasks can run in parallel** (different files/sections)

## Overview

Fix all critical and high-severity issues that must be resolved before any production rollout. These are active security vulnerabilities in the current codebase.

## Agent Assignment Strategy

```
Agent A (auth.ts specialist):  Tasks 1-1, 1-2, 1-3, 1-5  (all in auth.ts + related)
Agent B (user-entitlements.ts): Task 1-4                    (user-entitlements.ts only)
Agent C (projector.ts):         Task 1-6                    (projector.ts only)
```

Minimum 2 agents (A handles auth.ts tasks sequentially, B+C parallel). Ideal 3 agents.

---

## Task 1-1: Remove debugCode from API Response [PARALLEL]

**Severity**: CRITICAL
**Files**:
- `backend/src/auth.ts:375-377` — delete `response.debugCode = otpCode` block
- `backend/src/routes/auth-start.ts:27` — remove `debug_code` from response mapping
- `backend/src/types.ts:148` — remove `debug_code?` field from `AuthStartResponse`
- `TaskManager/Sources/TaskManager/Views/Premium/AccountSignInView.swift:53-59` — remove debug code display UI

**Action**:
1. In `auth.ts`, delete lines 375-377 (the `if (!isLiveEnvironment(env))` block that sets `response.debugCode`). OTP is already logged server-side at line 289 via `console.log` for dev debugging.
2. In `auth-start.ts`, remove `debug_code: started.debugCode` from the response JSON mapping.
3. In `types.ts`, remove the `debugCode?: string` field from the `AuthStartResult` interface.
4. In `AccountSignInView.swift`, remove the conditional debug code display block.

**Test**: After change, `POST /v1/auth/email/start` response body must NOT contain `debug_code` key in any environment.

---

## Task 1-2: Auth Rate Limiter Fail CLOSED [PARALLEL]

**Severity**: HIGH
**File**: `backend/src/auth.ts:102-105`

**Action**:
1. Change the catch block from `return true` to `return false`:
```typescript
} catch (error) {
    console.error("[auth] rate limiter DB error, failing closed:", error);
    return false; // Deny on error — fail closed
}
```
2. Add `console.error` for observability.

**Rationale**: If D1 is unavailable, rate limiting silently stops. Failing closed (deny) prevents brute-force during outages. Legitimate users will retry; attackers cannot exploit the window.

**Test**: Mock D1 failure in rate limiter → verify requests are denied (return false).

---

## Task 1-3: Rate Limit /v1/auth/email/verify [PARALLEL]

**Severity**: HIGH
**File**: `backend/src/routes/auth-verify.ts`

**Action**:
1. Import `checkAuthRateLimit` from `../auth.js`.
2. Extract client IP from request headers (same pattern as `auth-start.ts`).
3. Add rate limit check before calling `verifyEmailAuth`:
```typescript
const clientIp = request.headers.get("CF-Connecting-IP") || "unknown";
const allowed = await checkAuthRateLimit(env, `verify:ip:${clientIp}`, 30, 60);
if (!allowed) {
    throw new AppError(429, "RATE_LIMITED", "Too many verification attempts");
}
```
4. Max 30 verify requests per IP per 60 seconds.

**Rationale**: Even though per-challenge attempt limit is 5, without endpoint rate limiting an attacker can rapidly exhaust attempts and create DB load. Defense-in-depth.

**Test**: Fire > 30 verify requests from same IP in 60s → verify 429 on the 31st.

---

## Task 1-4: Device Seat TOCTOU Fix (Atomic) [PARALLEL]

**Severity**: HIGH
**File**: `backend/src/user-entitlements.ts:155-173`

**Current problem**: `ensureDeviceSeat()` performs separate COUNT query then INSERT. Two concurrent requests both read `activeCount = 1` with limit 2, both insert, resulting in 3 devices.

**Action** — Replace the count-check-then-insert with an atomic conditional INSERT:

```typescript
// Atomic seat check + insert
const insertResult = await env.STRATA_DB.prepare(
    `INSERT INTO user_devices (user_id, install_id, nickname, first_seen_at, last_seen_at, revoked_at, updated_at)
     SELECT ?, ?, ?, ?, ?, NULL, ?
     WHERE (SELECT COUNT(*) FROM user_devices WHERE user_id = ? AND revoked_at IS NULL) < ?`,
).bind(
    params.userId, params.installId, params.nickname || null,
    now, now, now,
    params.userId, limit,
).run();

if (!insertResult.meta.changes || insertResult.meta.changes < 1) {
    // Either device already exists OR seat limit reached
    // Check which case:
    const existing = await env.STRATA_DB.prepare(
        `SELECT install_id FROM user_devices WHERE user_id = ? AND install_id = ? AND revoked_at IS NULL`,
    ).bind(params.userId, params.installId).first();

    if (existing) {
        // Device already registered — update last_seen
        await env.STRATA_DB.prepare(
            `UPDATE user_devices SET last_seen_at = ?, updated_at = ?, nickname = COALESCE(?, nickname)
             WHERE user_id = ? AND install_id = ?`,
        ).bind(now, now, params.nickname || null, params.userId, params.installId).run();
        return;
    }

    // Seat limit reached
    throw new AppError(403, "DEVICE_LIMIT_REACHED",
        `Device limit (${limit}) reached for your plan. Remove a device first.`);
}
```

**Key**: The `INSERT ... SELECT ... WHERE (SELECT COUNT(*) ...) < ?` runs as a single SQL statement, making the check-and-insert atomic within D1's implicit transaction.

**Test**: Fire 3 simultaneous restore requests for a Pro user (2-seat limit) from 3 different devices → verify only 2 devices are registered.

---

## Task 1-5: Max Concurrent Sessions Per User [PARALLEL]

**Severity**: HIGH
**File**: `backend/src/auth.ts:500-505`

**Action**:
1. Add constant: `const MAX_SESSIONS_PER_USER = 10;`
2. After the session INSERT (line 505), add cleanup of oldest sessions:
```typescript
// Cap concurrent sessions — revoke oldest if over limit
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
```

**Rationale**: Without a cap, an attacker with OTP access can create thousands of sessions. Revoking oldest (FIFO) preserves the most recent active sessions.

**Test**: Create 12 sessions for one user → verify only 10 remain active (oldest 2 revoked).

---

## Task 1-6: Add Missing Webhook Revocation Handlers [PARALLEL]

**Severity**: CRITICAL
**File**: `backend/src/projector.ts` — `projectEvent()` switch statement

**Current problem**: `license_key.revoked` and `payment.refunded` events hit `default: return null` and are silently ignored. Revoked VIP licenses retain access forever. Refunded payments keep tier active.

**Action**:
1. Add case for `license_key.revoked`:
```typescript
case "license_key.revoked": {
    const email = extractEmail(data);
    if (!email) return null;
    return {
        tier: "vip" as Tier,
        state: "inactive" as EntitlementState,
        subjectType: "email",
        subjectId: email,
    };
}
```

2. Add case for `payment.refunded`:
```typescript
case "payment.refunded": {
    const email = extractEmail(data);
    if (!email) return null;
    // Determine tier from product_id if available
    const productId = ((data.product_id as string) || "").trim();
    const tier: Tier = productId === PRODUCT_IDS.vipLifetime ? "vip" : "pro";
    return {
        tier,
        state: "inactive" as EntitlementState,
        subjectType: "email",
        subjectId: email,
    };
}
```

3. Add both event types to imports/documentation as needed.

**Test**: Send `license_key.revoked` webhook → verify VIP entitlement set to inactive. Send `payment.refunded` → verify entitlement downgraded.

---

## Exit Criteria

- [ ] No `debug_code` in any API response (test + production)
- [ ] Auth rate limiter fails closed on DB error
- [ ] `/v1/auth/email/verify` rate-limited (30/min per IP)
- [ ] Device seat race condition eliminated (atomic INSERT)
- [ ] Session count capped at 10 per user
- [ ] `license_key.revoked` and `payment.refunded` webhooks handled
- [ ] All existing tests pass (`npm run test`)
- [ ] New tests added for each task

## Verification

```bash
# After all tasks complete:
cd backend && npm run test

# Manual E2E:
# 1. POST /v1/auth/email/start → verify no debug_code in response
# 2. Simulate 3 concurrent restores for 2-seat user → verify only 2 succeed
# 3. Fire 31 /verify requests → verify 429 on 31st
# 4. Send license_key.revoked webhook → verify entitlement inactive
```
