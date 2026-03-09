# Strata Backend Security Audit Report

Date: 2026-03-03
Scope: Account Ownership Hardening (auth, devices, restore, resolve, checkout, entitlements)
Auditor: code-reviewer agent
Status: Complete

---

## Executive Summary

The account ownership hardening implementation is **architecturally sound** and addresses the core threat model: preventing email-only entitlement theft. The OTP auth system, install proof mechanism, device seat enforcement, and webhook security all follow industry-standard patterns. However, several issues ranging from CRITICAL to LOW were identified that need remediation before the feature flags can be fully trusted in production.

**Overall Assessment: GOOD with targeted remediations needed**

The PRIMARY concern (email-only entitlement grants) is addressed when feature flags are enabled. All three critical flags (`AUTH_REQUIRED_FOR_RESTORE`, `AUTH_REQUIRED_FOR_RESOLVE`, `AUTH_REQUIRED_FOR_CHECKOUT`) default to `true` and are set to `true` in both production and test wrangler configs. The legacy code paths remain but are gated behind these flags.

---

## Scope

- **Files reviewed**: 24 backend source files + 5 migration files + wrangler.jsonc
- **LOC**: ~2,700 (backend/src/)
- **Focus**: Security of auth flows, entitlement grant paths, device enforcement, webhook integrity, input validation

---

## CRITICAL Findings

### C-1: OTP Code Leaked in Non-Production API Response

**File**: `backend/src/auth.ts:375-377`
**Also**: `backend/src/routes/auth-start.ts:27` (passes `debugCode` to response)

```typescript
if (!isLiveEnvironment(env)) {
    response.debugCode = otpCode;
}
```

The OTP code is returned in the HTTP response body when `ENVIRONMENT !== "production"`. The test environment wrangler config sets `ENVIRONMENT: "test"`, meaning the test Cloudflare Worker (accessible over the internet) returns OTP codes directly.

**Impact**: Anyone hitting the test Worker URL can authenticate as any email address without email access. If the test Worker URL is discoverable or shared, it becomes a full authentication bypass for the test environment.

**Remediation**:
1. Remove `debugCode` from the API response entirely. Log it server-side only (`console.log` is already present at line 289).
2. If client-side debugging is needed, use a separate dev-only allowlist of test emails, not a response-embedded code.
3. At minimum, ensure the test Worker is not publicly discoverable or add IP allowlisting at the Cloudflare level.

---

### C-2: Legacy Email-Only Entitlement Grant Paths Still Exist (Flag-Gated)

**File**: `backend/src/routes/restore.ts:366-384` (legacy restore path)
**File**: `backend/src/routes/resolve.ts:170-187` (legacy resolve path)

When `AUTH_REQUIRED_FOR_RESTORE=false` or `AUTH_REQUIRED_FOR_RESOLVE=false`, the old email-only trust model is fully active:

```typescript
// restore.ts:366-384 — Legacy path
const localEntitlement = await env.STRATA_DB.prepare(
    "SELECT tier, state FROM entitlements WHERE subject_type = 'email' AND subject_id = ? AND state = 'active'",
).bind(email).first<...>();
if (localEntitlement) {
    tier = localEntitlement.tier as "free" | "pro" | "vip";
    // ...
}
if (tier === "free") {
    const subscription = await dodo.findActiveSubscription(email);
    if (subscription) { tier = "pro"; }
}
```

```typescript
// resolve.ts:170-187 — Legacy path
const localEntitlement = await env.STRATA_DB.prepare(
    "SELECT tier, state FROM entitlements WHERE subject_type = 'email' AND subject_id = ? AND state = 'active'",
).bind(email).first<...>();
if (localEntitlement) {
    tier = localEntitlement.tier as typeof tier;
} else {
    const dodo = new DodoClient(env);
    const subscription = await dodo.findActiveSubscription(email);
    tier = subscription ? "pro" : "free";
}
```

**Current status**: Both flags default to `true` in code (`auth.ts:218-227`) and are set to `true` in `wrangler.jsonc:9-11`. This means the legacy paths should NOT be reachable in deployed environments.

**Impact**: If any deployment accidentally sets these flags to false (env var misconfiguration, Cloudflare dashboard override, or rollback scenario), the original vulnerability is fully restored.

**Remediation**:
1. Add a "sunset deadline" comment with a date by which these legacy paths must be deleted.
2. Add telemetry/logging specifically when the legacy code path is entered so any accidental activation is immediately visible.
3. Consider adding a hard kill switch: after a certain date, refuse to run legacy paths even if the flag says false.
4. Plan to remove these code paths entirely once the migration window closes.

---

### C-3: Rate Limiter Fails Open

**File**: `backend/src/auth.ts:102-105`
**File**: `backend/src/routes/resolve.ts:55-58`

```typescript
} catch {
    // Fail open if shared limiter table is unavailable.
    return true;
}
```

Both the auth rate limiter and the resolve rate limiter silently allow all requests when the D1 database query fails (network issue, schema mismatch, query error).

**Impact**: If D1 is degraded or the `resolve_rate_limits` table is missing/corrupted, brute-force attacks against the OTP endpoint and resolve endpoint face zero resistance. An attacker who can trigger D1 errors (e.g., heavy concurrent writes causing contention) can then brute-force OTP codes (10^6 = 1 million combinations for 6-digit code, easily attempted in minutes without rate limiting).

**Remediation**:
1. For the OTP verification path specifically, fail CLOSED (deny the request) rather than open. Authentication is security-critical.
2. For resolve, failing open is more defensible to preserve availability, but log aggressively when it happens.
3. Consider adding a secondary in-memory rate limiter as a fallback (even if per-isolate, it reduces blast radius).

```typescript
// For auth rate limiting: fail closed
} catch (error) {
    console.error(`[auth] rate limiter unavailable, failing closed:`, error);
    return false; // Deny the request
}
```

---

## HIGH Priority Findings

### H-1: OTP Brute Force Window is Wider Than Documented

**File**: `backend/src/auth.ts:9-10, 213-215`

The OTP is 6 digits (line 333: `randomDigits(6)`) with max 5 attempts per challenge and 10-minute expiry. However, the rate limiting allows 5 new challenges per email per 60-second window.

**Attack math**: An attacker can start 5 challenges per minute for 10 minutes = 50 challenges. Each challenge allows 5 attempts = 250 OTP guesses. Against a 6-digit code space (1,000,000 possibilities), probability of success per email per 10-min window = 250/1,000,000 = 0.025%. This is acceptable per individual attempt.

However, the per-IP limit of 20 starts/minute allows an attacker to target MULTIPLE emails simultaneously (20 starts/min, up to 100 OTP guesses/min spread across different emails).

**Real risk**: If the rate limiter fails open (C-3 above), the attacker can submit unlimited verification attempts, making brute force trivially feasible.

**Remediation**:
1. Fix C-3 first (fail closed for auth endpoints).
2. Consider reducing OTP TTL from 10 minutes to 5 minutes for new challenges.
3. Add a global rate limit on `POST /v1/auth/email/verify` by IP (currently only `auth/email/start` has IP rate limiting; verify endpoint has none).
4. Consider implementing exponential backoff: after N failed attempts across any challenge for an email, temporarily lock the email.

---

### H-2: No Rate Limiting on OTP Verify Endpoint

**File**: `backend/src/routes/auth-verify.ts` (entire file)
**File**: `backend/src/auth.ts:417-516` (`verifyEmailAuth`)

The `/v1/auth/email/start` endpoint has per-IP and per-email rate limiting. The `/v1/auth/email/verify` endpoint has NO independent rate limiting. While individual challenges are limited to 5 attempts, an attacker with multiple challenge IDs can verify in parallel.

**Impact**: Combined with the 50-challenge-per-10-minutes window from H-1, this means the verify endpoint can sustain substantial brute-force traffic.

**Remediation**: Add per-IP rate limiting on the verify endpoint. Example: max 30 verify attempts per IP per minute.

---

### H-3: Resolve Provider Fallback Leaks Entitlement Data via Email

**File**: `backend/src/user-entitlements.ts:110-122`

```typescript
if (params.allowProviderFallback && params.dodo) {
    const subscription = await params.dodo.findActiveSubscription(params.email);
    if (subscription) {
        await upsertUserEntitlement(env, {
            userId: params.userId,
            tier: "pro",
            state: "active",
            sourceEventId: "provider-subscription-fallback",
            effectiveUntil: subscription.nextBillingDateISO8601,
        });
        return { tier: "pro", source: "provider" };
    }
}
```

When `AUTH_REQUIRED_FOR_RESOLVE=true` (current production config), this fallback's `allowProviderFallback` is set to `false` in `resolve.ts:161`:

```typescript
allowProviderFallback: !authRequiredForResolve(env),
```

This is correctly disabled. However, in `restore.ts:353-358`, `allowProviderFallback` is `true`:

```typescript
const resolved = await resolveTierForUser(env, {
    userId: principal.userId,
    email: principal.email,
    dodo,
    allowProviderFallback: true,  // Always true for restore
});
```

The restore path requires auth session when the flag is on, so the email here comes from the verified principal. This is **acceptable** because the email is verified. But the provider fallback means the email is used to query Dodo for subscriptions, then the result is persisted to `user_entitlements` permanently.

**Residual risk**: If a user signs in with a verified email that happens to match another Dodo customer's email (unlikely but possible with email reuse), the wrong entitlement could be granted. This is low probability but the persistence makes it permanent.

**Remediation**: Log provider fallback usage with high-visibility telemetry. Consider making it time-limited rather than permanent (e.g., mark the source and re-verify periodically).

---

### H-4: Session Tokens Have No Maximum Concurrent Session Limit

**File**: `backend/src/auth.ts:500-505`

Each OTP verification creates a new session. There is no cap on how many active sessions a single user can have. An attacker who knows the email and can intercept the OTP (social engineering, shared mailbox) can create unlimited sessions.

**Impact**: No way to do a "sign out all devices" without iterating all sessions. Enables session proliferation for shared accounts.

**Remediation**:
1. Add a max concurrent sessions limit (e.g., 10 per user).
2. Add a "revoke all sessions" endpoint for the user.
3. When creating a new session, optionally invalidate older sessions beyond the limit.

---

### H-5: CORS Wildcard Allows Cross-Origin Attacks

**File**: `backend/src/index.ts:84-91`

```typescript
function corsHeaders(): Record<string, string> {
    return {
        "Access-Control-Allow-Origin": "*",
        // ...
    };
}
```

`Access-Control-Allow-Origin: *` is set on ALL responses including auth endpoints.

**Impact**: Any website can make authenticated requests to the Strata API if the user's session token is known/stored in a way accessible to the attacking page. For a native macOS app, this is lower risk since the primary client is not a browser. However, if any web-based admin tools or debugging tools use the same API, this becomes a vector.

**Remediation**: If the API is only consumed by the native macOS app (not a browser), consider removing CORS headers entirely or restricting to specific origins. At minimum, do NOT allow `*` on auth-sensitive endpoints.

---

### H-6: Device Seat Check Race Condition (TOCTOU)

**File**: `backend/src/user-entitlements.ts:155-173`

```typescript
const activeCountRow = await env.STRATA_DB.prepare(
    `SELECT COUNT(*) AS count FROM user_devices WHERE user_id = ? AND revoked_at IS NULL`,
).bind(params.userId).first<...>();

const activeCount = Number(activeCountRow?.count || 0);
const currentDeviceIsActive = Boolean(existing && existing.revoked_at === null);

if (!currentDeviceIsActive && activeCount >= limit) {
    throw new AppError(403, "DEVICE_LIMIT_REACHED", ...);
}
// ... then INSERT/UPDATE the device
```

The seat count check and the device insert are NOT atomic. Two concurrent requests for different install_ids but the same user_id can both pass the count check before either inserts, resulting in exceeding the seat limit.

**Impact**: A user with Pro (2 seats) could activate 3 or more devices by making concurrent restore/resolve requests from multiple machines simultaneously.

**Remediation**:
1. Wrap the check + insert in a D1 transaction (if supported).
2. Alternatively, add a UNIQUE constraint on `(user_id, install_id)` (already exists) and use a check constraint or trigger.
3. Pragmatic option: After the INSERT, re-count and if over limit, immediately revoke and throw. This is an optimistic locking pattern.

```typescript
// After insert, verify we didn't exceed
const postInsertCount = await env.STRATA_DB.prepare(
    `SELECT COUNT(*) AS count FROM user_devices WHERE user_id = ? AND revoked_at IS NULL`,
).bind(params.userId).first<...>();
if (Number(postInsertCount?.count || 0) > limit) {
    // Rollback: re-revoke the just-inserted device
    await env.STRATA_DB.prepare(
        `UPDATE user_devices SET revoked_at = ? WHERE user_id = ? AND install_id = ?`,
    ).bind(now, params.userId, params.installId).run();
    throw new AppError(403, "DEVICE_LIMIT_REACHED", ...);
}
```

---

## MEDIUM Priority Findings

### M-1: OTP Digit Generation Has Modulo Bias

**File**: `backend/src/auth.ts:141-152`

```typescript
function randomDigits(length: number): string {
    const out: string[] = [];
    while (out.length < length) {
        const buffer = new Uint8Array(length);
        crypto.getRandomValues(buffer);
        for (const byte of buffer) {
            out.push(String(byte % 10));
            if (out.length >= length) break;
        }
    }
    return out.join("");
}
```

`byte % 10` introduces modulo bias. Bytes 0-255: digits 0-5 each appear 26 times (values 0-5, 10-15, ..., 250-255), while digits 6-9 each appear 25 times. Bias is 26/25 = 4% per digit.

**Impact**: Very minor; reduces effective entropy by approximately 0.04 bits per digit. For a 6-digit code, effective entropy is ~19.89 bits instead of ~19.93 bits. Not practically exploitable but is a code quality issue.

**Remediation**: Use rejection sampling to eliminate modulo bias:

```typescript
function randomDigits(length: number): string {
    const out: string[] = [];
    while (out.length < length) {
        const buffer = new Uint8Array(length * 2);
        crypto.getRandomValues(buffer);
        for (const byte of buffer) {
            if (byte < 250) { // 250 is evenly divisible by 10
                out.push(String(byte % 10));
                if (out.length >= length) break;
            }
        }
    }
    return out.join("");
}
```

---

### M-2: Webhook Idempotency Check Has Race Condition

**File**: `backend/src/routes/webhook.ts:169-190`

```typescript
const existing = await env.STRATA_DB.prepare(
    "SELECT webhook_id, status FROM webhook_events WHERE webhook_id = ?"
).bind(webhookId).first<...>();

if (existing) {
    return new Response(JSON.stringify({ status: "ok", deduplicated: true }), ...);
}

// Persist event
await env.STRATA_DB.prepare(
    `INSERT INTO webhook_events (webhook_id, ...) VALUES (?, ?, ?, ?, 'pending')`,
).bind(webhookId, ...).run();
```

SELECT then INSERT is not atomic. If Dodo retries the same webhook concurrently, both requests could pass the SELECT check and both attempt to INSERT, potentially causing duplicate processing.

**Impact**: Duplicate entitlement projections. The projector has stale-event detection which mitigates double-processing for the same event, but the raw INSERT could fail or succeed depending on D1 conflict handling.

**Remediation**: Change to INSERT ... ON CONFLICT to make it atomic:

```typescript
const insertResult = await env.STRATA_DB.prepare(
    `INSERT INTO webhook_events (webhook_id, event_type, event_ts, payload_json, status)
     VALUES (?, ?, ?, ?, 'pending')
     ON CONFLICT(webhook_id) DO NOTHING`,
).bind(webhookId, eventType, eventTs, body).run();

const changes = (insertResult as { meta?: { changes?: number } }).meta?.changes || 0;
if (changes < 1) {
    return new Response(JSON.stringify({ status: "ok", deduplicated: true }), ...);
}
```

---

### M-3: Session Token in Response Body (Not HttpOnly Cookie)

**File**: `backend/src/routes/auth-verify.ts:29`

```typescript
const response: AuthVerifyResponse = {
    session_token: verified.sessionToken,
    // ...
};
```

The session token is returned in the JSON response body. For a native macOS app storing in Keychain, this is acceptable. However, if any web client ever consumes this API, the token would be accessible to JavaScript (XSS-exploitable).

**Impact**: Low for current architecture (native macOS app). Would be HIGH if web clients are added.

**Remediation**: Document that session tokens must be stored in secure storage (Keychain on macOS/iOS, equivalent on other platforms). If web clients are ever planned, implement HttpOnly cookie-based sessions as an alternative.

---

### M-4: Email Validation Regex is Overly Permissive

**File**: `backend/src/validation.ts:8`

```typescript
export const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
```

This regex allows many invalid email patterns such as `"test@a.b"`, `"a@b.c"`, or more importantly, emails with special characters that could cause issues in downstream systems (Dodo API, Resend API).

**Impact**: Could allow edge-case emails that Dodo or Resend reject, causing confusing error messages. Not a direct security vulnerability but an input validation gap.

**Remediation**: Use a stricter regex or add length limits. At minimum, ensure the email length is bounded (e.g., max 254 characters per RFC 5321):

```typescript
export function requireEmail(value: unknown): string {
    // ... existing validation ...
    if (normalized.length > 254) {
        throw new AppError(400, "INVALID_EMAIL", "email is too long");
    }
    return normalized;
}
```

---

### M-5: Install Registration Allows Unauthenticated Public Key Binding

**File**: `backend/src/routes/install.ts:14-94`

The `/v1/installs/register` endpoint has no authentication requirement. Any client can register an install_id with a public key, and once registered, the key cannot be changed (line 58: throws `ALREADY_REGISTERED` for different key).

**Impact**: A race condition where an attacker registers a victim's install_id with the attacker's public key before the victim does. The victim would then be unable to register their real key. However, install_ids are UUIDs generated client-side and are hard to predict, so this is theoretical.

**Remediation**:
1. No immediate action needed given UUID unpredictability.
2. Consider adding a "re-registration with proof of previous key" mechanism for key rotation scenarios.
3. Document that install_ids must be treated as secrets and not exposed in logs or analytics.

---

### M-6: Challenge Endpoint Not Rate Limited

**File**: `backend/src/routes/challenge.ts` (entire file)

The `/v1/installs/challenge` endpoint has no rate limiting. An attacker can request unlimited challenges for any registered install_id, filling the `install_challenges` table.

**Impact**: D1 storage exhaustion (DoS). Each challenge row is small but unlimited creation without cleanup beyond expired rows could degrade performance.

**Remediation**: Add per-IP and per-install_id rate limiting similar to the resolve endpoint.

---

### M-7: `purchase_links` ON CONFLICT Uses Stale Precedence for install_pubkey

**File**: `backend/src/routes/install.ts:62-69`

```typescript
`INSERT INTO purchase_links (install_id, install_pubkey, ...)
 ON CONFLICT(install_id) DO UPDATE SET
   install_pubkey = COALESCE(purchase_links.install_pubkey, excluded.install_pubkey),
   ...`
```

The `COALESCE(purchase_links.install_pubkey, excluded.install_pubkey)` means once a pubkey is set, it can never be updated via this path. This is intentional for security (prevent key swapping). However, there is no key rotation or recovery mechanism.

**Impact**: If a device loses its private key (e.g., Keychain corruption), the install_id is permanently bricked. User must generate a new install_id.

**Remediation**: This is by-design for security but should be documented. Consider adding an admin-only key reset endpoint for support cases.

---

### M-8: Projector Tier Precedence Prevents Downgrade on Cancellation

**File**: `backend/src/projector.ts:466-473`

```typescript
if (existing) {
    const existingPrecedence = TIER_PRECEDENCE[existing.tier as Tier] ?? 0;
    const newPrecedence = TIER_PRECEDENCE[projection.tier] ?? 0;
    if (newPrecedence < existingPrecedence) {
        await markWebhookIgnored(env, webhookId);
        return;
    }
```

If a user has VIP (lifetime) and also had a Pro subscription that gets cancelled, the `subscription.cancelled` event (which maps to `tier: "pro", state: "inactive"`) is ignored because Pro < VIP precedence. This is correct for this case.

However, if a VIP entitlement should be revoked (e.g., license refunded), there is no event type that would set VIP to inactive because `license_key.created` only grants, never revokes.

**Impact**: VIP entitlements granted via webhook are effectively irrevocable via webhook events. Manual DB intervention would be needed.

**Remediation**:
1. Add handling for `license_key.revoked` or `license_key.deactivated` events if Dodo emits them.
2. Add handling for `payment.refunded` events that could cascade to VIP revocation.
3. Consider adding an admin endpoint for manual entitlement revocation.

---

## LOW Priority Findings

### L-1: Timing Information Leakage in Auth Challenge Lookup

**File**: `backend/src/auth.ts:437-478`

When `verifyEmailAuth` is called with an invalid challenge_id, it returns immediately (line 453). When called with a valid but expired/used challenge, it takes slightly longer (additional DB check). This timing difference could theoretically reveal whether a challenge_id exists.

**Impact**: Negligible. Challenge IDs are random UUIDs and not user-facing secrets. The OTP hash comparison already uses timing-safe comparison (line 469).

**Remediation**: No action needed. The timing-safe OTP comparison is the important one, and it is correctly implemented.

---

### L-2: Console Logging of Email Addresses

**File**: `backend/src/auth.ts:289` — `console.log([auth] OTP code for ${email}: ${code})`
**File**: `backend/src/routes/resolve.ts:189` — `console.log([${requestId}] resolve: email=${email} ...)`

Email addresses appear in Cloudflare Worker logs.

**Impact**: PII in logs. Depends on log retention and access policies.

**Remediation**: Consider hashing or truncating emails in log output. The OTP code logging on line 289 is particularly sensitive (exposes both email and code in dev mode).

---

### L-3: No Request Body Size Limit

**File**: `backend/src/index.ts` (all endpoints)

None of the endpoints enforce a maximum request body size before calling `request.json()`.

**Impact**: Cloudflare Workers have built-in limits (128MB for the request body), but parsing a very large JSON body could consume CPU time.

**Remediation**: Add a body size check before parsing:

```typescript
const contentLength = request.headers.get("content-length");
if (contentLength && parseInt(contentLength, 10) > 65536) {
    throw new AppError(413, "BODY_TOO_LARGE", "Request body is too large");
}
```

---

### L-4: Cleanup Jobs Use Best-Effort DELETE with LIMIT

**File**: `backend/src/auth.ts:358-367` (auth challenge cleanup)
**File**: `backend/src/auth.ts:117-131` (rate limit cleanup)
**File**: `backend/src/install-proof.ts:252-268` (install challenge cleanup)

All cleanup jobs delete at most 500 rows per invocation and run opportunistically. Under heavy load, expired rows could accumulate faster than they are cleaned up.

**Impact**: Gradual table growth. D1 performance degradation over months/years.

**Remediation**: Consider adding a scheduled cleanup via Cloudflare Cron Triggers rather than relying on request-driven cleanup.

---

### L-5: `user_entitlements` Foreign Key Not Enforced

**File**: `backend/migrations/0004_account_auth.sql:48-56`

The `user_entitlements.user_id` column references users logically but has no FOREIGN KEY constraint.

**Impact**: Orphaned rows possible if users are ever deleted. SQLite/D1 foreign key enforcement requires `PRAGMA foreign_keys = ON`.

**Remediation**: Add explicit FOREIGN KEY constraint if D1 supports enforcement, or document this as accepted debt.

---

## Plan Implementation Status

### What is Implemented (Phases 0-4)

| Plan Item | Status | Evidence |
|---|---|---|
| Users table | DONE | migration 0004 |
| Auth challenges table | DONE | migration 0004 |
| Account sessions table | DONE | migration 0004 |
| User devices table | DONE | migration 0004 |
| User entitlements table | DONE | migration 0004 |
| Feature flags (AUTH_REQUIRED_FOR_RESTORE/RESOLVE, ENFORCE_DEVICE_SEATS) | DONE | auth.ts:217-231, wrangler.jsonc |
| POST /v1/auth/email/start | DONE | routes/auth-start.ts |
| POST /v1/auth/email/verify | DONE | routes/auth-verify.ts |
| Session verification middleware | DONE | auth.ts:518-565 |
| OTP expiry 10 min | DONE | auth.ts:9 |
| Max attempts 5 per challenge | DONE | auth.ts:10 |
| Rate limit per IP + email | DONE (start only) | auth.ts:71-106 |
| Checkout requires auth | DONE (flag-gated) | routes/checkout.ts:70-72 |
| Restore requires auth session + install proof | DONE (flag-gated) | routes/restore.ts:310-314 |
| Resolve requires auth session + install proof | DONE (flag-gated) | routes/resolve.ts:126-131 |
| Resolve by user_id (user_entitlements) | DONE | user-entitlements.ts:75-125 |
| Device seat enforcement | DONE | user-entitlements.ts:133-196 |
| GET /v1/devices | DONE | routes/devices-list.ts |
| POST /v1/devices/revoke | DONE | routes/devices-revoke.ts |
| User backfill migration | DONE | migration 0005 |
| Webhook signature verification | DONE | routes/webhook.ts:37-98 |
| Webhook idempotency | DONE (with race condition, see M-2) | routes/webhook.ts:169-181 |
| Stale event detection | DONE | projector.ts:49-57 |
| Purchase-to-user linkage sync | DONE | projector.ts:301-354 |
| Portal requires auth | DONE | routes/portal.ts:26 |

### What is NOT Implemented (Phases 5-6)

| Plan Item | Status | Notes |
|---|---|---|
| Dodo `allow_multiple_subscriptions=false` | NOT VERIFIED | Config-side, not code-side |
| Reject restore on customer mismatch (Dodo customer vs user_id) | PARTIAL | Email mismatch checked but no user_id<->customer_id binding table |
| Anomaly logging (frequent account switches, many installs) | NOT DONE | No anomaly detection implemented |
| Account mismatch UI copy | CLIENT SIDE | Not backend scope |
| Remove/deprecate legacy email-only code paths | NOT DONE | Legacy paths still exist behind flags |
| Rate limit on /v1/auth/email/verify | NOT DONE | See H-2 |
| Rate limit on /v1/installs/challenge | NOT DONE | See M-6 |
| Max concurrent sessions per user | NOT DONE | See H-4 |
| License key revocation handling | NOT DONE | See M-8 |
| Scheduled cleanup jobs | NOT DONE | See L-4 |

---

## Email-Only Entitlement Grant Analysis (PRIMARY CONCERN)

### Paths that CAN still grant entitlements from email alone (when flags are OFF)

1. **`restore.ts:366-384`** - Legacy restore reads `entitlements` table by email, queries Dodo by email
2. **`restore.ts:331-335`** - When no principal, accepts `body.email` directly from request
3. **`resolve.ts:146`** - Legacy resolve reads `entitlements` table by email
4. **`resolve.ts:182-184`** - Legacy resolve queries Dodo `findActiveSubscription` by email

### Paths that are SAFE (require verified identity)

1. **`restore.ts:312-313`** - When `AUTH_REQUIRED_FOR_RESTORE=true`: `requireAuthSession` enforced
2. **`resolve.ts:128-129`** - When `AUTH_REQUIRED_FOR_RESOLVE=true`: `requireAuthSession` enforced
3. **`checkout.ts:70-71`** - When `AUTH_REQUIRED_FOR_CHECKOUT=true`: `requireAuthSession` enforced
4. **`restore.ts:352-358`** - Authenticated path uses `resolveTierForUser` with `principal.userId`
5. **`resolve.ts:155-169`** - Authenticated path uses `resolveTierForUser` with `principal.userId`
6. **`projector.ts:407-534`** - Webhook path trusts Dodo-signed events only (not user input)

### Current Production State

With `wrangler.jsonc` flags:
- `AUTH_REQUIRED_FOR_CHECKOUT: "true"` -- checkout gated
- `AUTH_REQUIRED_FOR_RESTORE: "true"` -- restore gated
- `AUTH_REQUIRED_FOR_RESOLVE: "true"` -- resolve gated
- `ENFORCE_DEVICE_SEATS: "true"` -- seats enforced

**All email-only grant paths are currently unreachable in production.** The PRIMARY concern is adequately addressed by the current configuration. The residual risk is configuration drift (see C-2).

---

## Positive Observations

1. **Timing-safe OTP comparison** (auth.ts:168-180, webhook.ts:16-31) -- correctly prevents timing attacks on both OTP verification and webhook signature verification.

2. **Install proof challenge-response** is well-implemented: single-use nonces, 5-minute expiry, ECDSA P-256 signature verification with both P1363 and DER format support, and atomic used_at marking.

3. **Session tokens stored as SHA-256 hashes** (auth.ts:496, 524) -- database compromise does not reveal session tokens.

4. **OTP codes stored as SHA-256 hashes** (auth.ts:334, 468) -- database compromise does not reveal active OTP codes.

5. **Webhook signature verification** follows the Svix/Dodo standard correctly with timestamp tolerance, HMAC-SHA256, and constant-time comparison.

6. **Feature flag defaults** are secure-by-default (all `true`), meaning new deployments are hardened without explicit configuration.

7. **Error handling** never leaks internal details to clients (errors.ts:46-64).

8. **Input validation** is consistent across all endpoints with typed AppError codes.

9. **Challenge consumed_at marking** uses atomic UPDATE with WHERE consumed_at IS NULL (auth.ts:480-491), preventing double-spend of OTP codes.

10. **Install challenge used_at marking** similarly uses atomic UPDATE (install-proof.ts:350-358), preventing replay attacks.

---

## Recommended Actions (Priority Order)

1. **[CRITICAL]** Remove `debugCode` from API response or restrict to localhost-only environments (C-1)
2. **[CRITICAL]** Change auth rate limiter to fail CLOSED, not open (C-3)
3. **[HIGH]** Add rate limiting to `/v1/auth/email/verify` endpoint (H-2)
4. **[HIGH]** Add post-insert verification to device seat enforcement to prevent TOCTOU race (H-6)
5. **[HIGH]** Add max concurrent session limit per user (H-4)
6. **[HIGH]** Restrict CORS to specific origins or remove wildcard (H-5)
7. **[MEDIUM]** Make webhook idempotency check atomic with INSERT ON CONFLICT (M-2)
8. **[MEDIUM]** Add rate limiting to `/v1/installs/challenge` endpoint (M-6)
9. **[MEDIUM]** Handle license_key revocation/payment refund webhook events (M-8)
10. **[MEDIUM]** Add email length validation (M-4)
11. **[MEDIUM]** Fix OTP digit modulo bias with rejection sampling (M-1)
12. **[LOW]** Add request body size limits (L-3)
13. **[LOW]** Plan legacy code path removal with sunset deadline (C-2)
14. **[LOW]** Add Cron Trigger-based scheduled cleanup (L-4)

---

## Metrics

- **Type Coverage**: High (TypeScript strict, all interfaces typed)
- **Input Validation**: All endpoints validate inputs; email, UUID, and non-empty string validators are reused consistently
- **Rate Limiting**: Present on auth/start and resolve; missing on auth/verify, challenge, and install/register
- **Error Handling**: Consistent AppError pattern across all endpoints; no internal error leakage
- **Cryptographic Hygiene**: SHA-256 hashing for secrets at rest; timing-safe comparisons; proper CSPRNG usage; Ed25519 token signing

---

## Unresolved Questions

1. Is the test Cloudflare Worker URL (`strata-backend-test`) publicly accessible? If so, C-1 is actively exploitable in the test environment.
2. What is the D1 transaction isolation level? This affects the severity of race conditions in H-6 and M-2.
3. Is there a plan for periodic review of the `user_entitlements` data to detect and clean up stale provider-fallback entries?
4. Should there be an admin API for manual entitlement management (grant/revoke), or is D1 console access sufficient?
5. Is Cloudflare's built-in DDoS protection sufficient for the unauthenticated endpoints, or should additional WAF rules be added?
