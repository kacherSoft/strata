# Phase 5 — Legacy Cleanup & GA Gate

Priority: **P3 — Final production cutover**
Status: Pending
Depends on: **ALL of Phase 1, 2, 3, 4 must be complete**
Estimated tasks: 6
Parallelism: **Tasks 5-1/5-2 sequential (same files). Tasks 5-3, 5-4, 5-5, 5-6 parallel.**

## Overview

Remove all legacy email-only code paths, feature flag conditional branching, and unused code. Add anomaly logging. Verify GA gate checklist. Update documentation.

This phase is the final cutover — after this, there is no fallback to email-only trust paths.

## Agent Assignment Strategy

```
Agent R (restore/resolve/checkout): Tasks 5-1, 5-2     [SEQUENTIAL — same files]
Agent S (anomaly logging):          Task 5-3            [PARALLEL]
Agent T (Dodo config):              Task 5-4            [PARALLEL — manual verification]
Agent U (test suite):               Task 5-5            [PARALLEL — after 5-1/5-2]
Agent V (docs):                     Task 5-6            [PARALLEL]
```

Minimum 2 agents. Ideal 4 agents (R handles 5-1/5-2 sequentially, then U runs tests).

---

## Task 5-1: Remove Legacy Email-Only Code Paths [SEQUENTIAL with 5-2]

**Severity**: HIGH (removes attack surface)
**Files**:
- `backend/src/routes/restore.ts:366-384` — delete legacy `else` branch
- `backend/src/routes/resolve.ts:170-187` — delete legacy `else` branch

**Current state**: These code paths are unreachable under production flags (`AUTH_REQUIRED_FOR_RESTORE=true`, `AUTH_REQUIRED_FOR_RESOLVE=true`). However, they represent dormant attack surface that could be re-enabled by accidental flag misconfiguration.

**Action for `restore.ts`**:
1. Delete the `else` block at ~line 365-384 that handles `if (!principal)` with email-only lookup.
2. The `if (principal)` block becomes the only path — remove the conditional wrapper since `principal` is always non-null after `requireAuthSession`.
3. Remove `findActiveSubscription` email-only fallback call.

**Action for `resolve.ts`**:
1. Delete the `else` block at ~lines 170-187 that handles `if (!principal)` with email-only lookup.
2. The `if (principal)` block becomes the only path.
3. Remove `requireEmail(body.email)` call at line 146 — email is no longer needed from request body for resolve.

**Important**: After deletion, ensure the `requireEmail` import is removed if no longer used in these files.

**Test**: Send resolve/restore request with no auth token → verify 401 (not email fallback). Send with auth token → verify normal flow.

---

## Task 5-2: Remove Feature Flag Conditional Branching [SEQUENTIAL with 5-1]

**Severity**: HIGH
**Files**:
- `backend/src/routes/restore.ts` — replace `optionalAuthSession` with `requireAuthSession`
- `backend/src/routes/resolve.ts` — replace `optionalAuthSession` with `requireAuthSession`
- `backend/src/routes/checkout.ts` — replace `optionalAuthSession` with `requireAuthSession`
- `backend/src/auth.ts` — delete unused flag functions

**Action for each route file**:
1. Replace:
```typescript
const principal = authRequiredForRestore(env)
    ? await requireAuthSession(request, env)
    : await optionalAuthSession(request, env);
```
With:
```typescript
const principal = await requireAuthSession(request, env);
```

2. Remove the redundant null-check guard:
```typescript
// DELETE this — principal is now guaranteed non-null
if (authRequiredForRestore(env) && !principal) {
    throw new AppError(401, "AUTH_REQUIRED", "...");
}
```

**Action for `auth.ts`**:
1. Delete functions that are no longer called:
   - `authRequiredForRestore(env)` — if no longer referenced
   - `authRequiredForResolve(env)` — if no longer referenced
   - `authRequiredForCheckout(env)` — if no longer referenced
   - `optionalAuthSession(request, env)` — if no longer referenced
   - `isTruthyFlag()` — if no longer referenced
2. Remove corresponding env var types from `types.ts` if unused.
3. Remove flag values from `wrangler.jsonc` if unused.

**Warning**: Check if `optionalAuthSession` or flag functions are used anywhere else before deleting. Use grep to verify:
```bash
grep -r "optionalAuthSession\|authRequiredFor\|isTruthyFlag" backend/src/
```

**Test**: All endpoints return 401 without auth token. Full regression suite passes.

---

## Task 5-3: Anomaly Logging [PARALLEL]

**Severity**: MEDIUM
**File**: New file `backend/src/anomaly-detection.ts`

**Current state**: Phase 5 of the predecessor plan specified anomaly logging for account-sharing signals. Not yet implemented.

**Action** — Create `backend/src/anomaly-detection.ts`:
```typescript
import type { Env } from "./types.js";

/**
 * Log warning when abnormal patterns detected.
 * Called from restore/resolve after successful entitlement grant.
 */
export async function checkAnomalies(
    env: Env,
    params: {
        userId: string;
        installId: string;
        action: "restore" | "resolve";
    },
): Promise<void> {
    const now = Math.floor(Date.now() / 1000);
    const oneDayAgo = now - 86400;
    const oneHourAgo = now - 3600;

    try {
        // Frequent account switches on one install_id (> 3 users/day)
        const accountSwitches = await env.STRATA_DB.prepare(
            `SELECT COUNT(DISTINCT user_id) AS count FROM user_devices
             WHERE install_id = ? AND first_seen_at > ?`,
        ).bind(params.installId, oneDayAgo).first<{ count: number }>();

        if (accountSwitches && accountSwitches.count > 3) {
            console.warn(`[anomaly] install ${params.installId}: ${accountSwitches.count} account switches in 24h`);
        }

        // Many installs per user_id in short window (> 5 devices/hour)
        const deviceBurst = await env.STRATA_DB.prepare(
            `SELECT COUNT(*) AS count FROM user_devices
             WHERE user_id = ? AND first_seen_at > ?`,
        ).bind(params.userId, oneHourAgo).first<{ count: number }>();

        if (deviceBurst && deviceBurst.count > 5) {
            console.warn(`[anomaly] user ${params.userId}: ${deviceBurst.count} devices in 1h`);
        }
    } catch (error) {
        // Best effort — never block the main flow
        console.error("[anomaly] check failed:", error);
    }
}
```

2. Call from `restore.ts` and `resolve.ts` after successful entitlement grant:
```typescript
import { checkAnomalies } from "../anomaly-detection.js";
// After ensureDeviceSeat succeeds:
ctx.waitUntil(checkAnomalies(env, { userId: principal.userId, installId, action: "restore" }));
```

**Note**: Use `ctx.waitUntil()` or fire-and-forget to avoid adding latency to the main request path. If `ctx` is not available in restore/resolve handlers, wrap in a try-catch with async.

**Test**: Create 4+ device registrations for same install with different users → verify console.warn logged.

---

## Task 5-4: Dodo Product Collection Config Verification [PARALLEL — Manual]

**Severity**: LOW
**Action**: Manual check in Dodo dashboard
**No code changes required**

**Verification checklist**:
- [ ] Log into Dodo merchant dashboard
- [ ] Navigate to Pro subscription product settings
- [ ] Verify `allow_multiple_subscriptions = false`
- [ ] Verify webhook subscriptions include ALL entitlement-affecting events:
  - `subscription.active`
  - `subscription.renewed`
  - `subscription.cancelled`
  - `subscription.expired`
  - `subscription.failed`
  - `subscription.on_hold`
  - `subscription.plan_changed`
  - `subscription.updated`
  - `license_key.created`
  - `license_key.revoked` (new — added in Phase 1)
  - `payment.succeeded`
  - `payment.refunded` (new — added in Phase 1)
- [ ] Screenshot settings for audit trail

---

## Task 5-5: Full Regression Test Suite [PARALLEL — after 5-1/5-2]

**Severity**: HIGH
**Files**: `backend/tests/*.test.ts`

**Action**:
1. Run full test suite:
```bash
cd backend && npm run test
```

2. Fix any failures caused by legacy code removal.

3. Add new test cases:
   - Restore without auth → 401 (not email fallback)
   - Resolve without auth → 401 (not email fallback)
   - Checkout without auth → 401
   - All flag functions removed (no references in codebase)

4. Verify no test relies on `optionalAuthSession` returning null for email fallback.

5. Run comprehensive E2E flow:
   - OTP start → verify → session token
   - Checkout with session → return URL → restore
   - Device list → device revoke → re-restore
   - Concurrent seat test (3 devices, 2-seat limit)
   - Subscription cancel webhook → tier downgrade
   - License revoke webhook → VIP deactivation

**Test**: All tests green. Zero references to deleted functions.

---

## Task 5-6: Documentation Updates [PARALLEL]

**Severity**: MEDIUM
**Files**:
- `docs/features-status.md` — update Security Hardening row to "Done"
- `docs/codebase-summary.md` — update if exists
- `AGENTS.md` — add auth/device test shortcuts
- `plans/260303-account-ownership-hardening-finalization/plan.md` — mark SUPERSEDED

**Action for `docs/features-status.md`**:
1. Change "Security hardening (finalization)" from "Planned" to "Done"
2. Change "Legacy email-only paths" from "Gated" to "Removed"
3. Update "Last updated" date to current date
4. Add any new entries for anomaly logging, CRON cleanup

**Action for `AGENTS.md`**:
1. Add test shortcuts for auth flow:
```
## Auth Testing
- OTP flow: curl -X POST .../v1/auth/email/start -d '{"email":"test@example.com"}'
- Verify: curl -X POST .../v1/auth/email/verify -d '{"email":"test@example.com","challenge_id":"...","otp":"..."}'
- Device list: curl -H "Authorization: Bearer ..." .../v1/devices
```

**Action for predecessor plan**:
1. Add `Status: SUPERSEDED — See plans/260304-security-hardening-finalization/plan.md` to `plans/260303-account-ownership-hardening-finalization/plan.md`

---

## GA Gate Checklist

All items below must be true before public release:

- [ ] No endpoint grants paid tier from unverified email
- [ ] Legacy email-only code paths **deleted** (not just flag-gated)
- [ ] Feature flag functions removed from codebase
- [ ] `optionalAuthSession` removed or only used for non-entitlement endpoints
- [ ] Device seat policy enforced for all tiers (including downgrade)
- [ ] `license_key.revoked` and `payment.refunded` webhooks handled
- [ ] Tier precedence accounts for state (active/inactive)
- [ ] Anomaly logging active
- [ ] Scheduled CRON cleanup running
- [ ] Dodo anti-sharing config verified
- [ ] Rate limiting on ALL auth + entitlement endpoints
- [ ] No debug code in any API response
- [ ] Test suite passes with all legacy paths removed
- [ ] Documentation updated
- [ ] Key rotation procedure documented

## Exit Criteria

- [ ] All GA Gate items checked
- [ ] Full regression suite green
- [ ] No references to deleted flag functions
- [ ] Documentation current
- [ ] Plan status set to DONE

## Post-GA Monitoring

After release, monitor for 7 days:
- [ ] Anomaly warnings in logs (account switching, device bursts)
- [ ] Rate limit triggers (restore, verify, resolve)
- [ ] CRON cleanup execution (6-hourly)
- [ ] Any 500 errors on auth/entitlement endpoints
- [ ] Customer support tickets related to auth or device limits
