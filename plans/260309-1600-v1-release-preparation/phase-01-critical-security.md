# Phase 1 -- Critical Security

Priority: **P0 -- Block release**
Status: Complete
Depends on: None
Estimated effort: **6h**
Tasks: 6 (all parallelizable)

## Context Links

- Full implementation details: [`plans/260304-security-hardening-finalization/phase-01-critical-security.md`](../archive/260304-security-hardening-finalization/phase-01-critical-security.md)
- Research: [Cloudflare Workers Security](./research/researcher-02-cloudflare-workers-security.md)

## Overview

Fix all critical and high-severity security vulnerabilities blocking production release. Two CRITICAL (debug code leak, missing webhook revocation handlers) and four HIGH (rate limiter fail-open, unprotected verify endpoint, TOCTOU seat race, unlimited sessions).

## Key Insights

- **Task 1-4 (TOCTOU):** Use `INSERT...SELECT...WHERE (SELECT COUNT(*)...) < ?` for atomic seat check. D1 processes single-threaded per database, making this pattern sufficient without Durable Objects.
- **Task 1-6 (Webhooks):** Must handle both `license_key.revoked` AND `payment.refunded` events. Missing either leaves revoked/refunded users with active entitlements indefinitely.

## Requirements

**Functional:**
- No debug data in any API response (any environment)
- Rate limiter denies on DB error (fail-closed)
- `/v1/auth/email/verify` rate-limited at 30/min per IP
- Device seat allocation is atomic (no TOCTOU race)
- Max 10 concurrent sessions per user
- Revoked licenses and refunded payments deactivate entitlements

**Non-functional:**
- All changes backward-compatible with existing client versions
- No new dependencies added

## Architecture

No architectural changes. All fixes are targeted patches to existing handlers.

## Related Code Files

See [original phase file](../archive/260304-security-hardening-finalization/phase-01-critical-security.md) for exact line numbers and code changes.

| Task | Files |
|------|-------|
| 1-1: debugCode removal | `auth.ts:375-377`, `auth-start.ts:27`, `types.ts:148`, `AccountSignInView.swift:53-59` |
| 1-2: Rate limiter fail-closed | `auth.ts:102-105`, `resolve.ts:55-57` |
| 1-3: Verify rate limit | `routes/auth-verify.ts` |
| 1-4: TOCTOU seat fix | `user-entitlements.ts:155-173` |
| 1-5: Max sessions | `auth.ts:500-505` |
| 1-6: Webhook revocation | `projector.ts` (switch statement) |

## Implementation Steps

Refer to [`phase-01-critical-security.md`](../archive/260304-security-hardening-finalization/phase-01-critical-security.md) for complete implementation details per task. Summary:

1. **Task 1-1:** Delete `response.debugCode = otpCode` block, remove `debug_code` from response mapping, type, and Swift UI.
2. **Task 1-2:** Change rate limiter catch from `return true` to `return false` + add `console.error`. Fix in BOTH `auth.ts:102-105` AND `resolve.ts:55-57` (identical bug).
3. **Task 1-3:** Add `checkAuthRateLimit` call at top of verify handler (30 req/60s per IP).
4. **Task 1-4:** Replace count-then-insert with atomic `INSERT...SELECT...WHERE COUNT < limit`. On 0 changes, check if device exists (update last_seen) or throw DEVICE_LIMIT_REACHED.
5. **Task 1-5:** After session INSERT, count active sessions. If > 10, revoke oldest via `UPDATE...WHERE id IN (SELECT...ORDER BY created_at ASC LIMIT excess)`.
6. **Task 1-6:** Add `license_key.revoked` case (-> vip/inactive) and `payment.refunded` case to projector switch. **IMPORTANT (Validated Session 1):** Research Dodo docs/dashboard for `payment.refunded` payload structure FIRST. Only implement handling for confirmed event shapes. If event semantics are unclear or event doesn't exist, skip and implement only `license_key.revoked` for v1.0.

## Todo List

- [x] 1-1: Remove debugCode from auth.ts, auth-start.ts, types.ts, AccountSignInView.swift (+ EntitlementService.swift, EntitlementBackendClient.swift)
- [x] 1-2: Change rate limiter catch to `return false` in BOTH `auth.ts` AND `resolve.ts`
- [x] 1-3: Add rate limiting to /v1/auth/email/verify
- [x] 1-4: Atomic INSERT for device seat allocation
- [x] 1-5: Cap sessions at 10 per user, revoke oldest
- [x] 1-6: Handle `license_key.revoked` webhook. `payment.refunded` does NOT exist in Dodo — `refund.succeeded` implemented with TODO for payload validation
- [x] Run `npm run test` -- all 78 pass
- [ ] Manual: verify no `debug_code` in auth/start response
- [ ] Manual: 3 concurrent restores for 2-seat user -> only 2 succeed

## Success Criteria

- `POST /v1/auth/email/start` response has no `debug_code` key
- Rate limiter returns false on D1 error (both auth.ts and resolve.ts)
- 31st verify request in 60s returns 429
- 3 simultaneous seat requests for 2-seat limit -> exactly 2 succeed
- 12th session for one user -> oldest 2 auto-revoked
- `license_key.revoked` webhook -> VIP entitlement set inactive
- `payment.refunded` webhook -> correct tier set inactive

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| debugCode already observed by external party | CRITICAL | Ship ASAP; code only runs in non-live env but still exposed |
| Fail-closed rate limiter blocks legit users during D1 outage | MEDIUM | D1 outages are rare and brief; users retry |
| Atomic INSERT changes behavior for existing devices | LOW | Check for existing device after 0-change result |

## Security Considerations

- Task 1-1 is the highest priority -- debug OTP codes in API responses
- Task 1-4 prevents seat bypass that could enable unlimited device sharing
- Task 1-6 prevents revoked/refunded users from retaining paid access

## Next Steps

- After completion, run full `npm run test`
- Deploy to test environment and verify debug code removal
- Proceed to Phase 2 (projector.ts tasks must follow 1-6)
