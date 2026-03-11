# Phase 3 -- Medium Quality + Infrastructure

Priority: **P2 -- Before GA**
Status: Complete
Depends on: None (but some tasks must follow Phases 1-2, see notes)
Estimated effort: **10h**
Tasks: 12 (combined from security Phases 3 + 4)

## Context Links

- Quality fixes: [`plans/260304-security-hardening-finalization/phase-03-medium-quality.md`](../archive/260304-security-hardening-finalization/phase-03-medium-quality.md)
- Infrastructure: [`plans/260304-security-hardening-finalization/phase-04-infrastructure.md`](../archive/260304-security-hardening-finalization/phase-04-infrastructure.md)
- Research: [Cloudflare Workers Security](./research/researcher-02-cloudflare-workers-security.md)

## Overview

Combined medium-severity quality/validation fixes (7 tasks) and infrastructure improvements (5 tasks). All P2 and mostly independent. Addresses input validation gaps, OTP bias, body size limits, product ID mapping, CRON cleanup, key rotation, and tier downgrade enforcement.

## Key Insights

- **Task 4-1 (CRON):** Use `ctx.waitUntil()` pattern and `controller.cron` switch for multiple schedules. Test with `wrangler dev --test-scheduled`.
- **Task 4-4 (Rate limit index):** Add DB index on `expires_at` for cleanup query performance. Without it, full table scan as rate_limits table grows.
- **Task 3-2 (OTP bias):** Rejection sampling (discard bytes >= 250) eliminates modulo bias. Low practical impact but trivial fix.

## Requirements

**Functional (Quality):**
- Email validation rejects > 254 characters
- OTP generation unbiased (rejection sampling)
- POST requests > 1MB rejected with 413
- Non-JSON Content-Type rejected with 415 (except webhook)
- Subscription events use product_id for correct tier mapping
- Device nickname validated and length-capped
- Client shows actionable seat limit error with "Manage Devices" link

**Functional (Infrastructure):**
- CRON trigger cleans expired rows every 6 hours
- Tier downgrade auto-revokes excess devices
- Token `kid` claim for key rotation support
- Rate limit table indexed for cleanup performance
- TTL boundary consistent (`<=`) across all challenge types

## Architecture

### CRON Cleanup Architecture
```
wrangler.jsonc triggers.crons: ["0 */6 * * *"]
    |
    v
scheduled() handler in index.ts
    |
    v
ctx.waitUntil(handleScheduledCleanup(env))
    |
    v
Clean: auth_challenges, install_challenges,
       resolve_rate_limits, expired sessions
```

### Key Rotation Architecture
```
Token signing: sign with current key + kid claim
Token verify:  lookup key by kid -> try current, then previous
Rotation:      new key -> PREV = old key -> wait 72h TTL -> remove PREV
```

## Related Code Files

### Quality Tasks (from security Phase 3)

| Task | Files | Depends on |
|------|-------|------------|
| 3-1: Email length | `validation.ts:26-36` | None |
| 3-2: OTP bias fix | `auth.ts:141-152` | After Ph1 auth.ts tasks |
| 3-3: Body size limit | `index.ts` (before route dispatch) | None |
| 3-4: Content-Type check | `index.ts` (before route dispatch) | After 3-3 |
| 3-5: Subscription product_id | `projector.ts` (subscription branch) | After Ph1-1-6, Ph2-2-2/2-3 |
| 3-6: Nickname validation | `validation.ts` (new fn) + `user-entitlements.ts` | None |
| 3-7: Seat limit error UI | `SubscriptionLinkingView.swift` | None |

### Infrastructure Tasks (from security Phase 4)

| Task | Files | Depends on |
|------|-------|------------|
| 4-1: CRON cleanup | `wrangler.jsonc`, `index.ts`, new `scheduled-cleanup.ts` | None |
| 4-2: Tier downgrade enforcement | `user-entitlements.ts` | After Ph1-1-4 |
| 4-3: Key rotation support | `signing.ts`, `types.ts`, `wrangler.jsonc`, `EntitlementService.swift` | None |
| 4-4: Rate limit index | New migration `0006_rate_limit_index.sql`, `resolve.ts`, `auth.ts` | None |
| 4-5: TTL consistency | `install-proof.ts:325` | None |

## Implementation Steps

Refer to original phase files for complete code examples:
- Quality: [`phase-03-medium-quality.md`](../archive/260304-security-hardening-finalization/phase-03-medium-quality.md)
- Infrastructure: [`phase-04-infrastructure.md`](../archive/260304-security-hardening-finalization/phase-04-infrastructure.md)

### Quality Tasks Summary

1. **3-1:** Add `if (normalized.length > 254)` check in `requireEmail()` before regex test.
2. **3-2:** Replace `byte % 10` with rejection sampling: discard bytes >= 250, use `byte % 10` for 0-249.
3. **3-3:** Check `Content-Length` header on POST; reject > 1MB with 413.
4. **3-4:** Check `Content-Type` includes `application/json` on POST (exclude `/v1/webhooks/dodo`); reject with 415.
5. **3-5:** Extract `product_id` from subscription event data; map to tier via `PRODUCT_IDS` lookup. Apply to both active and inactive subscription events.
6. **3-6:** Add `sanitizeNickname()` to validation.ts (trim, 100 char max, strip control chars). Use in `ensureDeviceSeat`.
7. **3-7:** Parse `error_code` from backend response in SubscriptionLinkingView. If `DEVICE_LIMIT_REACHED`, show "Manage Devices" action button.

### Infrastructure Tasks Summary

1. **4-1:** Add `"triggers": {"crons": ["0 */6 * * *"]}` to wrangler.jsonc. Create `scheduled-cleanup.ts` deleting expired auth_challenges, install_challenges, resolve_rate_limits, and old sessions. Export `scheduled` handler from index.ts using `ctx.waitUntil()`.
2. **4-2:** In `upsertUserEntitlement`, after tier change, count active devices. If exceeds new limit, revoke oldest (FIFO by `last_seen_at`).
3. **4-3:** Backend: Add `kid` claim to token payload. Add `ENTITLEMENT_SIGNING_PRIVATE_KEY_PREV` and key ID env vars to types.ts. Client (`EntitlementService.swift`): parse `kid` from token header, maintain key dictionary (`[String: Curve25519.Signing.PublicKey]`), verify against matching key. Replace hardcoded single `entitlementPublicKeyHex` with multi-key lookup.
4. **4-4:** Create `0006_rate_limit_index.sql` with index on `expires_at`. Increase cleanup batch size from 500 to 2000. Reduce cleanup interval from 60s to 30s.
5. **4-5:** Change `install-proof.ts:325` from `<` to `<=` for TTL boundary consistency with auth.ts.

## Todo List

### Quality
- [x] 3-1: Email length validation (254 char max)
- [x] 3-2: OTP rejection sampling (unbias)
- [x] 3-3: Request body size limit (1MB)
- [x] 3-4: Content-Type validation (application/json)
- [x] 3-5: Subscription product_id tier mapping
- [x] 3-6: Nickname validation + sanitization
- [x] 3-7: Seat limit error UI in SubscriptionLinkingView

### Infrastructure
- [x] 4-1: CRON trigger + scheduled cleanup handler
- [x] 4-2: Tier downgrade excess device revocation
- [x] 4-3: Ed25519 key rotation support — backend (kid claim) + client (`EntitlementService.swift` multi-key)
- [x] 4-4: Rate limit table index + cleanup improvements
- [x] 4-5: TTL boundary consistency (< to <=)
- [x] Run `npm run test` -- all pass (78 tests)
- [ ] Run migration 0006 on test DB (manual step — deploy to D1)

## Success Criteria

- Email > 254 chars returns 400
- OTP chi-squared test shows uniform distribution
- POST > 1MB returns 413; non-JSON Content-Type returns 415
- Subscription with VIP product_id maps to "vip" tier
- Nickname truncated at 100 chars, control chars stripped
- Seat limit error shows "Manage Devices" in client
- CRON cleans expired rows every 6h
- Pro->Free downgrade auto-revokes excess devices
- Token includes `kid` claim; multi-key verification works
- Rate limit index exists; cleanup processes 2000 rows/cycle
- `install-proof.ts` uses `<=` for TTL check

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| CRON not firing in production | MEDIUM | Verify via Cloudflare dashboard after deploy |
| Key rotation procedure error loses all tokens | HIGH | Document procedure; keep PREV key for full TTL |
| Body size check bypassed via Transfer-Encoding | LOW | CloudFlare Workers limit provides backstop |
| Auto-revoke wrong device on downgrade | MEDIUM | Revoke least-recently-seen (FIFO), user can re-choose |

## Security Considerations

- Email length cap prevents memory/storage abuse
- Body size limit prevents resource exhaustion
- Content-Type check blocks CSRF-like probes from HTML forms
- Key rotation readiness enables incident response without breaking clients

## Next Steps

- After all tasks, run full test suite
- Deploy migration 0006 to D1
- Verify CRON fires in Cloudflare dashboard
- Proceed to Phase 4 (legacy cleanup)
