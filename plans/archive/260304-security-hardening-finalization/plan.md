# Security Hardening Finalization — Master Plan

Date: 2026-03-04
Status: Active
Owner: Backend + macOS client
Predecessor: `plans/260303-account-ownership-hardening-finalization/plan.md`
Source: Parallel codebase review (64 edge cases, 6 code-reviewer agents)

## Summary

Comprehensive parallel edge-case review identified **10 unhandled**, **23 partially handled** issues across 64 edge cases in the account ownership hardening codebase. This plan breaks remediations into 5 phases with parallelism annotations for agent team execution.

## Findings Summary

| Severity | Count | Examples |
|----------|-------|---------|
| Critical | 2 | Debug code leak, missing webhook revocation handlers |
| High | 6 | TOCTOU seat race, unlimited sessions, tier precedence bug, no restore rate limit |
| Medium | 10 | Webhook idempotency, subscription product_id, email length, body size |
| Low | 5 | Content-Type, TTL inconsistency, UUID strictness, nickname validation |

## Phase Documents

| Phase | Priority | Scope | Parallelism | File |
|-------|----------|-------|-------------|------|
| 1 | **P0 — Block release** | Critical security fixes | 6 tasks, all parallel | [phase-01](./phase-01-critical-security.md) |
| 2 | **P1 — Before GA** | High-severity security | 5 tasks, partial parallel | [phase-02](./phase-02-high-security.md) |
| 3 | **P2 — Before GA** | Medium quality + validation | 7 tasks, all parallel | [phase-03](./phase-03-medium-quality.md) |
| 4 | **P2 — Before GA** | Infrastructure + resilience | 5 tasks, all parallel | [phase-04](./phase-04-infrastructure.md) |
| 5 | **P3 — Final cutover** | Legacy cleanup + GA gate | Sequential (depends on 1-4) | [phase-05](./phase-05-legacy-cleanup-ga.md) |

## Phase Dependencies

```
Phase 1 (P0 Critical) ──┐
Phase 2 (P1 High)    ───┤──→ Phase 5 (Legacy + GA)
Phase 3 (P2 Medium)  ───┤
Phase 4 (P2 Infra)   ───┘
```

- Phases 1-4 can run **in parallel** (no file conflicts between phases)
- Phase 5 depends on ALL of 1-4 completing
- Within each phase, tasks marked `[PARALLEL]` can be assigned to separate agents
- Tasks marked `[SEQUENTIAL]` share files and must be done by one agent

## File Ownership Map (Conflict Prevention)

| File | Phase 1 | Phase 2 | Phase 3 | Phase 4 | Phase 5 |
|------|---------|---------|---------|---------|---------|
| `auth.ts` | 1-1, 1-2, 1-3, 1-5 | — | 3-2 | — | — |
| `user-entitlements.ts` | 1-4 | — | — | 4-2 | — |
| `projector.ts` | 1-6 | 2-2, 2-3 | 3-5 | — | — |
| `routes/restore.ts` | — | 2-1 | — | — | 5-1, 5-2 |
| `routes/resolve.ts` | — | — | — | — | 5-1, 5-2 |
| `routes/webhook.ts` | — | 2-4 | — | — | — |
| `routes/auth-start.ts` | 1-1 | — | — | — | — |
| `routes/auth-verify.ts` | 1-3 | — | — | — | — |
| `validation.ts` | — | — | 3-1, 3-6 | — | — |
| `index.ts` | — | 2-5 | 3-3, 3-4 | — | — |
| `routes/checkout.ts` | — | — | — | — | 5-2 |
| `install-proof.ts` | — | — | — | 4-5 | — |
| `signing.ts` | — | — | — | 4-3 | — |
| `types.ts` | 1-1 | — | — | 4-3 | — |
| `wrangler.jsonc` | — | — | — | 4-1 | — |
| `SubscriptionLinkingView.swift` | — | — | 3-7 | — | — |
| `AccountSignInView.swift` | 1-1 | — | — | — | — |

### Cross-Phase Conflicts

- **`projector.ts`**: Touched by Phase 1 (task 1-6), Phase 2 (tasks 2-2, 2-3), and Phase 3 (task 3-5). **Resolution**: Phase 1 task 1-6 adds new event handlers (additive). Phase 2 tasks 2-2/2-3 modify existing projection logic. Phase 3 task 3-5 modifies the subscription branch. **Recommendation**: Assign all projector.ts work to ONE agent across phases, or run Phase 1-6 first, then Phase 2-2/2-3 + 3-5 sequentially.
- **`auth.ts`**: Touched by Phase 1 (tasks 1-1, 1-2, 1-3, 1-5) and Phase 3 (task 3-2). Phase 1 tasks touch different sections (debug code, rate limiter, verify rate limit, sessions). Phase 3-2 touches `randomDigits()`. **Recommendation**: Run Phase 1 auth.ts tasks as one agent, then Phase 3-2 after.
- **`index.ts`**: Phase 2 (task 2-5 CORS) and Phase 3 (tasks 3-3/3-4 body size + Content-Type). Different sections. Can be parallel if careful, or sequential for safety.

## Validation Strategy

1. Run `npm run test` after each phase — all tests must pass
2. Phase 1: Deploy to test env, verify no debugCode in responses
3. Phase 2: Run concurrent device seat test (3 simultaneous requests, 2-seat limit)
4. Phase 3: Run input validation edge case tests
5. Phase 4: Verify CRON triggers fire in test env
6. Phase 5: Verify 401 on all endpoints without auth token; full regression suite

## Risk Assessment

| Risk | Severity | Phase | Mitigation |
|------|----------|-------|------------|
| Test Worker leaks OTP codes publicly | CRITICAL | 1 | Task 1-1: remove debugCode |
| Revoked VIP licenses retain access forever | CRITICAL | 1 | Task 1-6: add revocation handlers |
| Device seat bypass via concurrent requests | HIGH | 1 | Task 1-4: atomic seat check |
| Rate limiter fails open on DB error | HIGH | 1 | Task 1-2: fail closed |
| Restore endpoint abused (no rate limit) | HIGH | 2 | Task 2-1: add rate limiting |
| VIP-inactive overwrites Pro-active | HIGH | 2 | Task 2-2: state-aware precedence |
| Flag misconfiguration re-enables email trust | HIGH | 5 | Tasks 5-1/5-2: delete legacy code |
