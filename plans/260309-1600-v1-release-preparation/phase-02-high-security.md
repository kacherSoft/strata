# Phase 2 -- High Security

Priority: **P1 -- Before GA**
Status: Complete
Depends on: None (but projector.ts tasks must follow Phase 1 task 1-6)
Estimated effort: **6h**
Tasks: 5

## Context Links

- Full implementation details: [`plans/260304-security-hardening-finalization/phase-02-high-security.md`](../archive/260304-security-hardening-finalization/phase-02-high-security.md)
- Research: [Cloudflare Workers Security](./research/researcher-02-cloudflare-workers-security.md)

## Overview

Fix high-severity issues enabling abuse or incorrect entitlement state: unprotected restore endpoint, tier precedence bug, concurrent webhook race, webhook idempotency gap, and unnecessary CORS headers.

## Key Insights

- **Task 2-5 (CORS):** Since Strata is a native macOS app, CORS headers can be removed entirely. Native HTTP clients (URLSession) don't enforce CORS. Only add them back if/when browser-based admin tools are built.
- **Task 2-3 (Webhook race):** Start with application-level guards from Task 2-2. Atomic SQL CASE approach is complex; only implement if races observed in production.

## Requirements

**Functional:**
- Restore endpoint rate-limited (20/min per IP, 5/min per install)
- Inactive higher-tier event never overwrites active lower-tier entitlement
- Concurrent webhooks produce deterministic state
- Duplicate webhooks handled atomically (no 500 errors)
- No CORS headers in responses (native app only)

## Architecture

No architectural changes. Targeted patches to existing route handlers and projector.

## Related Code Files

See [original phase file](../archive/260304-security-hardening-finalization/phase-02-high-security.md) for exact line numbers and code changes.

| Task | Files |
|------|-------|
| 2-1: Restore rate limit | `routes/restore.ts` |
| 2-2: Tier precedence fix | `projector.ts:466-472` |
| 2-3: Webhook race fix | `projector.ts:488-521` |
| 2-4: Webhook idempotency | `routes/webhook.ts:169-190` |
| 2-5: CORS restriction | `index.ts:84-91` |

## Implementation Steps

Refer to [`phase-02-high-security.md`](../archive/260304-security-hardening-finalization/phase-02-high-security.md) for complete implementation details. Summary:

1. **Task 2-1:** Add `checkRateLimit` to restore handler -- 20/min per IP, 5/min per install_id. Consider extracting shared `rate-limit.ts` module from resolve.ts.
2. **Task 2-2:** Replace simple tier precedence with state-aware logic: (a) never downgrade active higher-tier, (b) inactive higher-tier must not overwrite active different-tier, (c) same-tier same-state is no-op.
3. **Task 2-3:** Convert projection to atomic `INSERT...ON CONFLICT DO UPDATE` with inline CASE guards. OR start with 2-2's application-level guards and defer atomic SQL.
4. **Task 2-4:** Replace SELECT-then-INSERT with `INSERT...ON CONFLICT(webhook_id) DO NOTHING`. Check `meta.changes` for dedup.
5. **Task 2-5:** Replace `corsHeaders()` body with `return {}`. Remove wildcard `Access-Control-Allow-Origin: *`. Native macOS app does not need CORS.

## Todo List

- [x] 2-1: Add rate limiting to restore endpoint
- [x] 2-2: Implement state-aware tier precedence in projector
- [x] 2-3: Fix concurrent webhook projection race (app-level guards via 2-2)
- [x] 2-4: Atomic webhook idempotency (INSERT ON CONFLICT DO NOTHING)
- [x] 2-5: Remove CORS headers from all responses
- [x] Run `npm run test` -- all pass (78/78)
- [ ] Manual: 21 restore requests -> 429 on 21st
- [ ] Manual: Pro active + VIP revoked webhook -> Pro preserved

## Success Criteria

- Restore returns 429 after 20 requests/min from same IP
- VIP-inactive event does not overwrite Pro-active entitlement
- Same-tier cancel correctly deactivates entitlement
- Duplicate webhook_id returns 200 with `deduplicated: true`
- No `Access-Control-Allow-Origin` header in responses

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| CORS removal breaks future web admin tools | LOW | Add origin-specific CORS when web tools are built |
| Tier precedence logic too strict (blocks valid upgrades) | MEDIUM | Test: free->pro, pro->vip, vip->pro, all with active/inactive combos |
| Restore rate limit too aggressive for legit use | LOW | 20/min is generous; normal use is 1-2 calls |

## Security Considerations

- CORS wildcard removal prevents browser-based token theft if session tokens leak
- Rate limiting restore prevents Dodo API cost amplification attacks
- Webhook idempotency prevents duplicate entitlement state changes

## Next Steps

- After 2-2/2-3, run concurrent webhook test suite
- Deploy to test env and verify CORS headers absent
- Proceed to Phase 3 (projector.ts task 3-5 must follow 2-2/2-3)
