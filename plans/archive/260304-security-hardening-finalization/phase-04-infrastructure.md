# Phase 4 — Infrastructure & Resilience

Priority: **P2 — Before GA**
Status: Pending
Depends on: None (can run parallel with Phase 1-3)
Estimated tasks: 5
Parallelism: **All 5 tasks can run in parallel** (different files)

## Overview

Infrastructure improvements for long-term operational health: scheduled cleanup, tier downgrade enforcement, key rotation readiness, and consistency fixes.

## Agent Assignment Strategy

```
Agent M (wrangler + cleanup):   Task 4-1                [PARALLEL]
Agent N (user-entitlements.ts): Task 4-2                [PARALLEL — after Phase 1-4]
Agent O (signing.ts + types.ts): Task 4-3               [PARALLEL]
Agent P (rate-limit module):    Task 4-4                [PARALLEL]
Agent Q (install-proof.ts):     Task 4-5                [PARALLEL]
```

**File conflict note**: Task 4-2 touches `user-entitlements.ts` which is modified by Phase 1 task 1-4. Run after 1-4 completes. All other tasks have no conflicts.

Minimum 2 agents. Ideal 5 agents.

---

## Task 4-1: Scheduled Cleanup via CRON Trigger [PARALLEL]

**Severity**: MEDIUM
**Files**:
- `backend/wrangler.jsonc` — add cron trigger
- `backend/src/index.ts` — add `scheduled` handler export
- New file: `backend/src/scheduled-cleanup.ts` — cleanup logic

**Current problem**: Expired `account_sessions`, `auth_challenges`, `install_challenges`, and `resolve_rate_limits` rows accumulate indefinitely. Existing opportunistic cleanup (500 rows per request) is insufficient under load.

**Action**:

1. Add cron trigger to `wrangler.jsonc`:
```jsonc
// In the main worker config:
"triggers": {
    "crons": ["0 */6 * * *"]  // Every 6 hours
}
```

2. Create `backend/src/scheduled-cleanup.ts`:
```typescript
import type { Env } from "./types.js";

const CLEANUP_BATCH_SIZE = 2000;

export async function handleScheduledCleanup(env: Env): Promise<void> {
    const now = new Date().toISOString();
    const nowUnix = Math.floor(Date.now() / 1000);

    // 1. Expired auth challenges
    await cleanupTable(env, "auth_challenges", "expires_at", now);

    // 2. Expired install challenges
    await cleanupTable(env, "install_challenges", "expires_at", nowUnix);

    // 3. Expired rate limit rows
    await cleanupTable(env, "resolve_rate_limits", "expires_at", nowUnix);

    // 4. Expired + revoked sessions (older than 7 days past expiry)
    const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
    await env.STRATA_DB.prepare(
        `DELETE FROM account_sessions
         WHERE id IN (
             SELECT id FROM account_sessions
             WHERE (expires_at < ? OR revoked_at IS NOT NULL)
             AND created_at < ?
             ORDER BY created_at ASC
             LIMIT ?
         )`,
    ).bind(now, cutoff, CLEANUP_BATCH_SIZE).run().catch(e =>
        console.error("[cleanup] sessions error:", e)
    );

    console.log("[cleanup] scheduled cleanup completed");
}

async function cleanupTable(
    env: Env,
    table: string,
    expiryColumn: string,
    threshold: string | number,
): Promise<void> {
    try {
        // Use parameterized column name via template (safe — hardcoded table names)
        await env.STRATA_DB.prepare(
            `DELETE FROM ${table}
             WHERE rowid IN (
                 SELECT rowid FROM ${table}
                 WHERE ${expiryColumn} < ?
                 ORDER BY ${expiryColumn} ASC
                 LIMIT ?
             )`,
        ).bind(threshold, CLEANUP_BATCH_SIZE).run();
    } catch (error) {
        console.error(`[cleanup] ${table} error:`, error);
    }
}
```

3. Update `backend/src/index.ts` to export the scheduled handler:
```typescript
import { handleScheduledCleanup } from "./scheduled-cleanup.js";

export default {
    async fetch(request, env, ctx) { ... },
    async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
        ctx.waitUntil(handleScheduledCleanup(env));
    },
} satisfies ExportedHandler<Env>;
```

**Note**: Table names in the `cleanupTable` helper use string interpolation, but they are hardcoded at call sites (not user input). This is safe.

**Test**: Manually trigger scheduled event in test env → verify expired rows are deleted.

---

## Task 4-2: Tier Downgrade Excess Device Enforcement [PARALLEL — after Phase 1-4]

**Severity**: MEDIUM
**File**: `backend/src/user-entitlements.ts`

**Current problem**: When a Pro user (2 seats) downgrades to Free (1 seat), their existing 2 active devices remain. The excess device is never auto-revoked. `ensureDeviceSeat` only blocks NEW registrations.

**Action** — Add enforcement in `upsertUserEntitlement` after tier change:
```typescript
export async function upsertUserEntitlement(env: Env, params: { ... }): Promise<void> {
    // ... existing INSERT ON CONFLICT logic ...

    // After upsert, check if device count exceeds new tier limit
    if (deviceSeatsEnforced(env)) {
        const limit = seatLimitForTier(env, params.tier);
        const activeDevices = await env.STRATA_DB.prepare(
            `SELECT install_id, last_seen_at FROM user_devices
             WHERE user_id = ? AND revoked_at IS NULL
             ORDER BY last_seen_at ASC`,
        ).bind(params.userId).all<{ install_id: string; last_seen_at: number }>();

        const devices = activeDevices.results || [];
        if (devices.length > limit) {
            // Revoke oldest devices beyond limit (FIFO — least recently seen first)
            const toRevoke = devices.slice(0, devices.length - limit);
            const now = Math.floor(Date.now() / 1000);
            for (const device of toRevoke) {
                await env.STRATA_DB.prepare(
                    `UPDATE user_devices SET revoked_at = ?, updated_at = ?
                     WHERE user_id = ? AND install_id = ? AND revoked_at IS NULL`,
                ).bind(now, now, params.userId, device.install_id).run();
            }
            console.warn(`[seats] auto-revoked ${toRevoke.length} excess device(s) for user ${params.userId} after tier change to ${params.tier}`);
        }
    }
}
```

**Rationale**: When `subscription.cancelled` webhook fires and tier drops from Pro→Free, excess devices should be auto-revoked. The user can later choose which device to keep via Manage Devices UI.

**Test**: Set user with 2 active devices on Pro → process subscription cancel → verify 1 device auto-revoked (oldest first).

---

## Task 4-3: Ed25519 Key Rotation Support [PARALLEL]

**Severity**: HIGH (operational risk, not immediate security)
**Files**:
- `backend/src/signing.ts` — add `kid` claim, multi-key signing
- `backend/src/types.ts` — add `ENTITLEMENT_SIGNING_PRIVATE_KEY_PREV` env var
- `backend/wrangler.jsonc` — add prev-key secret placeholder

**Current problem**: Single signing key. Rotation requires synchronized deployment of backend key + client public key. All existing tokens invalidated during 72h TTL window.

**Action**:

1. Add `kid` (key ID) claim to token payload:
```typescript
// In signing.ts signEntitlementToken():
const kid = env.ENTITLEMENT_SIGNING_KEY_ID || "default";
const claims: TokenClaims = {
    ...
    kid,
    iat: now,
    exp: now + params.ttlSeconds,
};
```

2. Add `kid` to `TokenClaims` type in `types.ts`.

3. Add support for previous key in env:
```typescript
// In types.ts Env interface:
ENTITLEMENT_SIGNING_PRIVATE_KEY_PREV?: string;
ENTITLEMENT_SIGNING_KEY_ID?: string;
ENTITLEMENT_SIGNING_KEY_ID_PREV?: string;
```

4. In the client-side Swift verification, accept tokens signed by either current or previous public key (lookup by `kid` claim).

**Rotation procedure** (document in `AGENTS.md` or ops runbook):
1. Generate new Ed25519 keypair
2. Set `_PREV` = current key, set primary = new key, set key IDs
3. Deploy backend → new tokens use new key, old tokens verified with `_PREV`
4. Wait 72h (token TTL) for all old tokens to expire
5. Remove `_PREV` env vars
6. Update client with new public key in next release

**Test**: Sign token with key A → verify with key A (pass). Sign with key A → verify with key B (fail). Sign with key A → verify with multi-key lookup including A (pass).

---

## Task 4-4: Rate Limit Table Index + Cleanup Improvement [PARALLEL]

**Severity**: MEDIUM
**Files**:
- New migration file: `backend/migrations/0006_rate_limit_index.sql`
- `backend/src/routes/resolve.ts` — increase cleanup batch size

**Current problem**: `resolve_rate_limits` table has no index on `expires_at`. Cleanup subquery `ORDER BY expires_at ASC LIMIT 500` does full table scan as table grows. Batch size of 500 is insufficient under sustained load.

**Action**:

1. Create migration `0006_rate_limit_index.sql`:
```sql
CREATE INDEX IF NOT EXISTS idx_rate_limits_expires
ON resolve_rate_limits (expires_at);
```

2. Increase cleanup batch size from 500 to 2000 in both:
   - `resolve.ts` `cleanupRateLimitRows()` — change `LIMIT 500` to `LIMIT 2000`
   - `auth.ts` `cleanupAuthRateLimitRows()` — change `LIMIT 500` to `LIMIT 2000`

3. Reduce cleanup interval from 60s to 30s:
   - `resolve.ts` — change `60_000` to `30_000`
   - `auth.ts` — change `60_000` to `30_000`

**Test**: Insert 5000 expired rate limit rows → trigger cleanup → verify all deleted within 2 cycles.

---

## Task 4-5: TTL Boundary Consistency [PARALLEL]

**Severity**: LOW
**File**: `backend/src/install-proof.ts:325`

**Current problem**: Install challenges use `<` (valid at exact boundary) while auth challenges use `<=` (expired at exact boundary). Inconsistency.

**Action** — Align install-proof to match auth.ts behavior:
```typescript
// Change from:
if (challenge.expires_at < now) {
// To:
if (challenge.expires_at <= now) {
```

**Rationale**: Strict `<=` is the secure default. Both systems should behave identically at the boundary.

**Test**: Create challenge with `expires_at = now` → verify it's rejected (not accepted).

---

## Exit Criteria

- [ ] CRON trigger configured and cleanup handler implemented
- [ ] Tier downgrade auto-revokes excess devices
- [ ] Token `kid` claim added; multi-key verification ready
- [ ] Rate limit table indexed; cleanup batch size increased
- [ ] TTL boundary consistent (`<=`) across install-proof and auth
- [ ] New migration file deployed
- [ ] All existing tests pass

## Verification

```bash
cd backend && npm run test

# Manual:
# 1. Trigger scheduled event → verify expired rows cleaned
# 2. Process subscription cancel for 2-device Pro user → verify 1 device auto-revoked
# 3. Verify token includes `kid` claim
# 4. Run migration → verify index created
```
