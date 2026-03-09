# Account Ownership Hardening — Finalization Plan

Date: 2026-03-03
Status: SUPERSEDED — See `plans/260304-security-hardening-finalization/plan.md`
Owner: Backend + macOS client
Predecessor: `plans/260228-account-ownership-hardening/plan.md`

## Summary

Phases 0–4 of account ownership hardening are **fully implemented** in both backend (Cloudflare Workers + D1) and client (Swift/macOS). Security audit identified 3 CRITICAL, 6 HIGH, 8 MEDIUM, and 5 LOW findings. This plan covers the finalization: critical remediations, remaining Phase 5–6 work, legacy cleanup, and document updates.

## Phase Status (Predecessor)

| Phase | Scope | Backend | Client | Notes |
|-------|-------|---------|--------|-------|
| 0 | Foundation | DONE | DONE | Schema, flags, migrations |
| 1 | Email OTP | DONE | DONE | Full OTP lifecycle, Resend, Keychain |
| 2 | Purchase Binding | DONE | DONE | user_id entitlements, webhook sync |
| 3 | Secure Restore/Resolve | DONE | DONE | Auth-gated, install proof required |
| 4 | Device Seats | DONE | DONE | Free:1 / Pro:2 / VIP:3, revoke UI |
| 5 | Anti-Sharing | PARTIAL | N/A | Flags set, anomaly logging missing |
| 6 | Migration/GA | PARTIAL | DONE | Backfill done, legacy code not removed |

## Finalization Phases

### Phase A — Critical Security Remediations

Priority: **P0 — Do before any production rollout**

#### A-1: Remove debugCode from API response (C-1)
- **File**: `backend/src/auth.ts:375-377`
- **Action**: Delete the `response.debugCode = otpCode` line. OTP is already logged server-side at line 289 for dev debugging.
- **File**: `backend/src/routes/auth-start.ts:27` — remove `debug_code` from response mapping.
- **File**: `backend/src/types.ts:148` — remove `debug_code?` field from `AuthStartResponse`.
- **Client**: `AccountSignInView.swift:53-59` — remove debug code display.

#### A-2: Auth rate limiter fail CLOSED (C-3)
- **File**: `backend/src/auth.ts:102-105`
- **Action**: Change `return true` to `return false` in the catch block. Add error logging.

#### A-3: Add rate limiting to /v1/auth/email/verify (H-2)
- **File**: `backend/src/routes/auth-verify.ts`
- **Action**: Add per-IP rate limit (max 30/min) using existing `checkAuthRateLimit` helper.

#### A-4: Device seat TOCTOU fix (H-6)
- **File**: `backend/src/user-entitlements.ts:155-173`
- **Action**: After INSERT/UPDATE, re-count active devices. If over limit, revoke the just-activated device and throw `DEVICE_LIMIT_REACHED`.

#### A-5: Max concurrent sessions per user (H-4)
- **File**: `backend/src/auth.ts:500-505`
- **Action**: After session INSERT, count active sessions per user_id. If > 10, revoke oldest sessions.

#### A-6: Restrict CORS (H-5)
- **File**: `backend/src/index.ts:84-91`
- **Action**: Remove CORS headers entirely (native macOS app doesn't need them) or restrict to `strata://` scheme.

#### Exit Criteria
- [ ] No debugCode in any API response (test + production)
- [ ] Auth rate limiter fails closed
- [ ] `/v1/auth/email/verify` rate-limited
- [ ] Device seat race condition eliminated
- [ ] Session count capped per user
- [ ] CORS headers restricted or removed

### Phase B — Medium Security + Quality

Priority: **P1 — Before GA cutover**

#### B-1: Webhook idempotency atomic INSERT (M-2)
- **File**: `backend/src/routes/webhook.ts:169-190`
- **Action**: Replace SELECT-then-INSERT with `INSERT ... ON CONFLICT DO NOTHING`, check changes count.

#### B-2: Challenge endpoint rate limiting (M-6)
- **File**: `backend/src/routes/challenge.ts`
- **Action**: Add per-IP rate limit (max 20/min).

#### B-3: License key revocation handling (M-8)
- **File**: `backend/src/projector.ts`
- **Action**: Add handling for `license_key.revoked`/`payment.refunded` events to set VIP entitlement inactive.

#### B-4: Email length validation (M-4)
- **File**: `backend/src/validation.ts`
- **Action**: Add `if (normalized.length > 254)` check in `requireEmail`.

#### B-5: OTP modulo bias fix (M-1)
- **File**: `backend/src/auth.ts:141-152`
- **Action**: Use rejection sampling (`if (byte < 250)`) in `randomDigits`.

#### B-6: Request body size limit (L-3)
- **File**: `backend/src/index.ts` or individual route handlers
- **Action**: Check `Content-Length > 65536` before parsing.

#### B-7: Seat limit error UI (Client gap)
- **File**: `TaskManager/.../SubscriptionLinkingView.swift`
- **Action**: Parse `DEVICE_LIMIT_REACHED` error code, show explicit "seat full" message with link to Manage Devices.

#### Exit Criteria
- [ ] Webhook dedup is atomic
- [ ] Challenge endpoint rate-limited
- [ ] VIP revocation via webhook handled
- [ ] Email validation tightened
- [ ] OTP generation unbiased
- [ ] Body size checked
- [ ] Client shows seat limit error with device management link

### Phase C — Legacy Cleanup + GA Gate

Priority: **P2 — Final production cutover**

#### C-1: Remove legacy email-only code paths
- **File**: `backend/src/routes/restore.ts:366-384` — delete legacy fallback block
- **File**: `backend/src/routes/resolve.ts:170-187` — delete legacy fallback block
- **Action**: Remove the `else` branches that read `entitlements` by email without auth.

#### C-2: Remove feature flag conditional branching
- **Files**: `restore.ts`, `resolve.ts`, `checkout.ts`
- **Action**: Hard-require auth session (remove `optionalAuthSession` fallback). Delete flag functions if no longer needed.

#### C-3: Anomaly logging (Phase 5 remainder)
- **File**: `backend/src/user-entitlements.ts` or new `anomaly.ts`
- **Action**: Log warnings for:
  - Frequent account switches on one install_id (> 3/day)
  - Many installs per user_id in short window (> 5/hour)

#### C-4: Scheduled cleanup
- **File**: `backend/wrangler.jsonc`
- **Action**: Add Cloudflare Cron Trigger for periodic cleanup of:
  - Expired `auth_challenges` rows
  - Expired `install_challenges` rows
  - Expired `resolve_rate_limits` rows
  - Expired/revoked `account_sessions` rows

#### C-5: Dodo product collection config
- **Action**: Verify `allow_multiple_subscriptions=false` in Dodo dashboard for Pro products.
- **Verification**: Manual check in Dodo control panel.

#### GA Gate Checklist
- [ ] No endpoint grants paid tier from unverified email
- [ ] Legacy code paths deleted (not just gated)
- [ ] Device seat policy enforced for all tiers
- [ ] All auth flags can be removed (hardcoded true)
- [ ] Anomaly logging active
- [ ] Scheduled cleanup running
- [ ] Dodo anti-sharing config verified
- [ ] Test suite passes with legacy paths removed
- [ ] Docs and runbooks updated

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Rate limiter DB failure enables brute force | HIGH | Phase A-2 fix (fail closed) |
| Device seat bypass via concurrent requests | HIGH | Phase A-4 fix (post-insert check) |
| Accidental flag misconfiguration re-enables email trust | HIGH | Phase C-1/C-2 (delete legacy code) |
| VIP cannot be revoked via webhook | MEDIUM | Phase B-3 (license revocation event) |
| Test Worker leaks OTP codes publicly | CRITICAL | Phase A-1 (remove debugCode) |

## Validation Checklist

1. Run `npm run test` after Phase A changes — all tests must pass.
2. Deploy to test environment, run E2E: OTP → restore → device list → revoke.
3. Verify test Worker no longer returns debugCode in response.
4. Run concurrent device seat test: 3 simultaneous restore requests for same user_id with 2-seat limit.
5. Run rate limit test: > 30 verify requests/min from same IP.
6. After Phase C: verify restore/resolve fail with 401 when no auth token provided.
7. After Phase C: run full regression suite.

## Documents to Update

| Document | Update Needed |
|----------|---------------|
| `docs/features-status.md` | Add Account section (OTP, devices, auth gates) |
| `docs/features-status.md` | Update "Last updated" date |
| `AGENTS.md` | Add auth/device test shortcuts |
| Old plan archive | Mark predecessor plan as superseded |
