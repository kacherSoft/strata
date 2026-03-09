# Phase 2 — High-Severity Security Fixes

Priority: **P1 — Before GA cutover**
Status: Pending
Depends on: None (can run parallel with Phase 1, but see file conflicts below)
Estimated tasks: 5
Parallelism: **Tasks 2-1, 2-4, 2-5 are parallel. Tasks 2-2 and 2-3 are sequential (same file section).**

## Overview

Fix high-severity issues that enable abuse or produce incorrect entitlement state. These don't leak secrets but can result in unauthorized access or data inconsistency.

## Agent Assignment Strategy

```
Agent D (restore.ts):    Task 2-1                    [PARALLEL]
Agent E (projector.ts):  Tasks 2-2, 2-3              [SEQUENTIAL — same file]
Agent F (webhook.ts):    Task 2-4                    [PARALLEL]
Agent G (index.ts):      Task 2-5                    [PARALLEL]
```

**File conflict note**: `projector.ts` is also touched by Phase 1 task 1-6. Run 1-6 BEFORE 2-2/2-3, or assign all projector work to one agent.

Minimum 2 agents. Ideal 4 agents.

---

## Task 2-1: Add Rate Limiting to Restore Endpoint [PARALLEL]

**Severity**: HIGH
**File**: `backend/src/routes/restore.ts`

**Current problem**: Restore has NO rate limiting. Expensive Dodo API calls (checkout lookup, payment lookup, license activation, subscription query) can be abused for cost amplification and enumeration.

**Action**:
1. Import `checkRateLimit` and `cleanupRateLimitRows` from resolve.ts pattern (or extract shared rate limit module).
2. Add per-IP and per-install_id rate limits at top of `handleRestore`:
```typescript
const clientIp = request.headers.get("CF-Connecting-IP") || "unknown";

// Per-IP: max 20 restore requests per minute
const ipAllowed = await checkRateLimit(env, `restore:ip:${clientIp}`, 20, 60);
if (!ipAllowed) {
    throw new AppError(429, "RATE_LIMITED", "Too many restore requests");
}

// Per-install: max 5 restore requests per minute
const installAllowed = await checkRateLimit(env, `restore:install:${installId}`, 5, 60);
if (!installAllowed) {
    throw new AppError(429, "RATE_LIMITED", "Too many restore requests from this device");
}
```

**Note**: The `checkRateLimit` function currently lives inside `resolve.ts`. Consider extracting it to a shared `rate-limit.ts` module so both resolve and restore can use it. If modularizing, keep it under 200 lines per the codebase rules.

**Test**: Fire > 20 restore requests from same IP in 60s → verify 429.

---

## Task 2-2: Fix Tier Precedence State Bug [SEQUENTIAL with 2-3]

**Severity**: HIGH
**File**: `backend/src/projector.ts:466-472`

**Current problem**: Precedence check only compares tier rank, ignoring state. A VIP-inactive event (from `license_key.revoked`) would overwrite an active Pro subscription because `vip(2) >= pro(1)` passes the check.

**Scenario**: User has active Pro subscription + VIP license gets revoked → projection sets `tier: "vip", state: "inactive"` → user loses Pro access.

**Action** — Replace the simple precedence guard with state-aware logic:

```typescript
if (existing) {
    const existingPrecedence = TIER_PRECEDENCE[existing.tier as Tier] ?? 0;
    const newPrecedence = TIER_PRECEDENCE[projection.tier] ?? 0;

    // Rule 1: Never downgrade an active higher-tier with a lower-tier event
    if (newPrecedence < existingPrecedence && existing.state === "active") {
        await markWebhookIgnored(env, webhookId);
        return;
    }

    // Rule 2: Don't let an inactive higher-tier overwrite an active lower-tier
    // (e.g., VIP revoked should not overwrite active Pro)
    if (projection.state === "inactive"
        && existing.state === "active"
        && projection.tier !== existing.tier) {
        await markWebhookIgnored(env, webhookId);
        return;
    }

    // Rule 3: Same tier + same state = no-op
    if (existing.tier === projection.tier
        && existing.state === projection.state) {
        await markWebhookIgnored(env, webhookId);
        return;
    }
}
```

**Rationale**: The core principle is "an inactive event for tier X should never overwrite an active entitlement for tier Y (where X ≠ Y)." Same-tier inactive events (Pro cancel while Pro active) correctly deactivate.

**Test**:
1. Set user to `tier: pro, state: active` → process `license_key.revoked` (vip, inactive) → verify Pro remains active
2. Set user to `tier: pro, state: active` → process `subscription.cancelled` (pro, inactive) → verify Pro deactivated
3. Set user to `tier: vip, state: active` → process `subscription.cancelled` (pro, inactive) → verify VIP remains active

---

## Task 2-3: Fix Concurrent Webhook Projection Race [SEQUENTIAL with 2-2]

**Severity**: HIGH
**File**: `backend/src/projector.ts:488-521`

**Current problem**: Projection uses SELECT-then-UPDATE/INSERT. Two concurrent webhooks for the same customer can both read the same state, pass checks independently, then last-writer-wins.

**Action** — Convert to atomic `INSERT ... ON CONFLICT DO UPDATE` with inline conditional logic:

```typescript
// Atomic upsert with inline state guards
const upsertResult = await env.STRATA_DB.prepare(
    `INSERT INTO entitlements (subject_type, subject_id, tier, state, source_event_id, effective_from, effective_until, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(subject_type, subject_id) DO UPDATE SET
       tier = CASE
         -- Don't let inactive higher-tier overwrite active different-tier
         WHEN excluded.state = 'inactive' AND entitlements.state = 'active' AND excluded.tier != entitlements.tier THEN entitlements.tier
         -- Don't downgrade active higher-tier
         WHEN entitlements.state = 'active' AND (
           CASE entitlements.tier WHEN 'vip' THEN 2 WHEN 'pro' THEN 1 ELSE 0 END
         ) > (
           CASE excluded.tier WHEN 'vip' THEN 2 WHEN 'pro' THEN 1 ELSE 0 END
         ) THEN entitlements.tier
         ELSE excluded.tier
       END,
       state = CASE
         WHEN excluded.state = 'inactive' AND entitlements.state = 'active' AND excluded.tier != entitlements.tier THEN entitlements.state
         WHEN entitlements.state = 'active' AND (
           CASE entitlements.tier WHEN 'vip' THEN 2 WHEN 'pro' THEN 1 ELSE 0 END
         ) > (
           CASE excluded.tier WHEN 'vip' THEN 2 WHEN 'pro' THEN 1 ELSE 0 END
         ) THEN entitlements.state
         ELSE excluded.state
       END,
       source_event_id = CASE
         WHEN excluded.state = 'inactive' AND entitlements.state = 'active' AND excluded.tier != entitlements.tier THEN entitlements.source_event_id
         ELSE excluded.source_event_id
       END,
       effective_from = COALESCE(excluded.effective_from, entitlements.effective_from),
       effective_until = CASE
         WHEN excluded.state = 'inactive' AND entitlements.state = 'active' AND excluded.tier != entitlements.tier THEN entitlements.effective_until
         ELSE excluded.effective_until
       END,
       updated_at = excluded.updated_at`,
).bind(
    projection.subjectType, projection.subjectId,
    projection.tier, projection.state,
    webhookId, projection.effectiveFrom || null, projection.effectiveUntil || null, now,
).run();
```

**Alternative simpler approach**: If the inline SQL CASE logic is too complex, use the existing stale-event check + the state-aware precedence from Task 2-2, and accept that very rare concurrent webhooks may produce a brief incorrect state that self-corrects on the next event. Document the trade-off.

**Recommendation**: Start with Task 2-2's application-level guards. Only implement the atomic SQL approach if concurrent webhook race is observed in production metrics.

**Test**: Send `subscription.active` and `subscription.cancelled` for same email simultaneously → verify final state is deterministic and correct.

---

## Task 2-4: Webhook Idempotency Atomic INSERT [PARALLEL]

**Severity**: MEDIUM
**File**: `backend/src/routes/webhook.ts:169-190`

**Current problem**: SELECT-then-INSERT for webhook_id deduplication. Concurrent duplicate webhooks cause the second INSERT to fail with PK violation → 500 error → Dodo retries.

**Action**:
```typescript
// Replace lines 169-190 with:
const insertResult = await env.STRATA_DB.prepare(
    `INSERT INTO webhook_events (webhook_id, event_type, event_ts, payload_json, status)
     VALUES (?, ?, ?, ?, 'pending')
     ON CONFLICT(webhook_id) DO NOTHING`,
).bind(webhookId, eventType, eventTs, body).run();

const changes = (insertResult as { meta?: { changes?: number } }).meta?.changes || 0;
if (changes === 0) {
    // Duplicate — already processed or in-flight
    return new Response(JSON.stringify({ status: "ok", deduplicated: true }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
    });
}
```

**Test**: Send same webhook_id twice concurrently → both return 200, only one event is processed.

---

## Task 2-5: Restrict CORS Headers [PARALLEL]

**Severity**: MEDIUM
**File**: `backend/src/index.ts:84-91`

**Current problem**: `Access-Control-Allow-Origin: *` on all responses. While acceptable for a native app backend (CORS is browser-enforced), it's unnecessary and exposes the API to browser-based abuse if session tokens leak.

**Action** — Remove CORS headers entirely since native macOS app doesn't need them:
```typescript
function corsHeaders(): Record<string, string> {
    // Native macOS app does not use CORS.
    // Only return minimal headers for any browser-based admin tools.
    return {};
}
```

**Alternative**: If any browser-based admin/debug tools exist, restrict to specific origins:
```typescript
function corsHeaders(request?: Request): Record<string, string> {
    const origin = request?.headers.get("Origin") || "";
    const allowed = ["https://admin.kachersoft.com"];
    if (!allowed.includes(origin)) return {};
    return {
        "Access-Control-Allow-Origin": origin,
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
        "Access-Control-Max-Age": "86400",
    };
}
```

**Test**: Verify native app still works (doesn't rely on CORS headers). Verify browser fetch from `https://evil.com` is blocked.

---

## Exit Criteria

- [ ] Restore endpoint rate-limited (20/min per IP, 5/min per install)
- [ ] Tier precedence accounts for active/inactive state
- [ ] Concurrent webhook projection safe (atomic or guarded)
- [ ] Webhook idempotency uses atomic INSERT ON CONFLICT
- [ ] CORS headers restricted or removed
- [ ] All existing tests pass
- [ ] New tests for tier precedence edge cases
- [ ] New tests for concurrent webhook behavior

## Verification

```bash
cd backend && npm run test

# Manual:
# 1. Fire 21 restore requests from same IP → 429 on 21st
# 2. Set Pro active → send VIP revoked webhook → verify Pro preserved
# 3. Send duplicate webhook_id → verify clean 200 dedup
```
