---
title: "Strata v1.0 Release Preparation"
description: "Data loss fix, security hardening, documentation for GA release"
status: complete
priority: P0
effort: 55-70h
branch: main
tags: [security, data-integrity, release, documentation]
created: 2026-03-09
---

# Strata v1.0 Release Preparation

Supersedes: [`plans/260304-security-hardening-finalization/plan.md`](../archive/260304-security-hardening-finalization/plan.md)

## Phases

| # | Phase | Priority | Effort | Status | File |
|---|-------|----------|--------|--------|------|
| 0 | Data Loss Emergency Fix | P0 | 3h | Complete | [phase-00](./phase-00-data-loss-emergency-fix.md) |
| 1 | Critical Security | P0 | 6h | Complete | [phase-01](./phase-01-critical-security.md) |
| 2 | High Security | P1 | 6h | Complete | [phase-02](./phase-02-high-security.md) |
| 3 | Medium Quality + Infrastructure | P2 | 10h | Complete | [phase-03](./phase-03-medium-quality-infrastructure.md) |
| 4 | Legacy Cleanup + GA Gate | P3 | 6h | Complete | [phase-04](./phase-04-legacy-cleanup-ga-gate.md) |
| 5 | Documentation + Release Prep | P3 | 6h | Complete | [phase-05](./phase-05-documentation-release-prep.md) |

## Dependency Diagram

```
Phase 0 (P0 Data Loss) ──> Phase 1 (P0 Security) ──> Phase 2 (P1) ──> Phase 3 (P2) ──> Phase 4 ──> Phase 5
```

- Phase 0 runs **first** (~3h, simpler than originally estimated — no V1→V2 migration needed)
- Phases 1 → 2 → 3 are **strictly serial** — they share `auth.ts`, `projector.ts`, `user-entitlements.ts`, `index.ts`
- Phase 4 depends on ALL of Phases 0-3 completing
- Phase 5 depends on Phase 4 completing

## File Ownership Map

| File | Ph 0 | Ph 1 | Ph 2 | Ph 3 | Ph 4 | Ph 5 |
|------|------|------|------|------|------|------|
| `TaskManagerApp.swift` | 0-3 | - | - | - | - | - |
| `ModelContainer+Config.swift` | 0-2,0-4,0-5 | - | - | - | - | - |
| `SchemaVersioning.swift` (new) | 0-1 | - | - | - | - | - |
| `auth.ts` | - | 1-1..1-5 | - | 3-2 | 5-2 | - |
| `projector.ts` | - | 1-6 | 2-2,2-3 | 3-5 | - | - |
| `user-entitlements.ts` | - | 1-4 | - | - | 4-2 | - |
| `index.ts` | - | - | 2-5 | 3-3,3-4 | - | - |
| `restore.ts` | - | - | 2-1 | - | 5-1,5-2 | - |
| `resolve.ts` | - | 1-2 | - | - | 5-1,5-2 | - |
| `webhook.ts` | - | - | 2-4 | - | - | - |
| `validation.ts` | - | - | - | 3-1,3-6 | - | - |

## Research Reports

- [SwiftData Migration](./research/researcher-01-swiftdata-migration.md)
- [Cloudflare Workers Security](./research/researcher-02-cloudflare-workers-security.md)

## Validation Strategy

1. After Phase 0: Verify store migration from default.store → Strata/strata.store; verify backup creation; verify DataErrorView on corrupt store
2. After Phase 1: `npm run test` + manual debug_code check
3. After Phase 2: Concurrent device seat test (3 req, 2-seat limit)
4. After Phase 3: Input validation edge case tests
5. After Phase 4: Full regression + 401 on all endpoints without auth
6. After Phase 5: Release build + E2E smoke test

## Validation Log

### Session 1 — 2026-03-10
**Trigger:** Re-investigation of data loss root cause revealed plan assumptions were wrong
**Questions asked:** 7

#### Questions & Answers

1. **[Architecture]** Verified: the current store already has ALL 5 model tables with ALL current columns. No migration gap exists. How should we handle VersionedSchema?
   - Options: V1 = current schema (Recommended) | Skip VersionedSchema for now | V1 = original, V2 = current anyway
   - **Answer:** V1 = current schema (Recommended)
   - **Rationale:** The current SQLite store at `~/Library/Application Support/default.store` already contains all 5 tables with all columns matching the current Swift @Model definitions. No V1→V2 migration code is needed. Define V1 as the current full schema so future changes become V2.

2. **[Architecture]** The plan's store migration assumes data might exist at `~/Library/Application Support/<BUNDLE_ID>/default.store`. Actual location is `~/Library/Application Support/default.store`. Should we migrate to `Strata/strata.store`?
   - Options: Yes, migrate to Strata/ (Recommended) | Keep default.store location
   - **Answer:** Yes, migrate to Strata/ (Recommended)
   - **Rationale:** Cleaner app-scoped path prevents conflicts with other SwiftData apps using the same default location.

3. **[Scope]** Phase 3 Task 4-3 (Ed25519 key rotation with kid claim) — needed for v1.0 or defer?
   - Options: Defer to v1.1 (Recommended) | Keep in v1.0
   - **Answer:** Keep in v1.0
   - **Rationale:** User wants key rotation support from day one for security incident readiness.

4. **[Scope]** Phase 4 Task 4-3 (anomaly detection/logging) — needed for v1.0 or defer?
   - Options: Keep for v1.0 (Recommended) | Defer to v1.1
   - **Answer:** Keep for v1.0 (Recommended)
   - **Rationale:** Low effort (~1h), provides visibility into account sharing from launch day.

5. **[Architecture]** How elaborate should the DataErrorView be when ModelContainer fails?
   - Options: Simple error + Reset button (Recommended) | Full DataErrorView as planned | Just log + crash gracefully
   - **Answer:** Simple error + Reset button (Recommended)
   - **Rationale:** Container init failure is deterministic — retrying without reset won't help. Simple error message + Reset Data button + Contact Support link is sufficient.

6. **[Execution]** Should Phase 0 run in parallel with Phases 1-2-3 or sequentially first?
   - Options: Phase 0 first, then 1-2-3 (Recommended) | Keep parallel as planned | All sequential
   - **Answer:** Phase 0 first, then 1-2-3 (Recommended)
   - **Rationale:** Phase 0 is now ~3h (simpler without migration code). Do it first to secure data integrity immediately. Reduces coordination complexity.

7. **[Risk]** Phase 1 Task 1-6: How to handle Dodo's payment.refunded event with unknown semantics?
   - Options: Research first, implement what's confirmed (Recommended) | Implement conservative handler | Defer refund handling to post-GA
   - **Answer:** Research first, implement what's confirmed (Recommended)
   - **Rationale:** Check Dodo docs for payment.refunded payload structure. Only implement handling for confirmed event shapes. Skip if unclear.

#### Confirmed Decisions
- **VersionedSchema:** V1 = current full schema (all 5 models), no V1→V2 migration code needed
- **Store path:** Migrate from `~/Library/Application Support/default.store` to `~/Library/Application Support/Strata/strata.store`
- **Key rotation:** Keep in v1.0 (Task 4-3)
- **Anomaly logging:** Keep in v1.0 (Task 4-3)
- **Error UI:** Simple error + Reset button + Contact Support link (no "Try Again")
- **Execution order:** Phase 0 first (sequential), then Phases 1→2→3→4→5
- **Refund webhook:** Research Dodo docs first, only implement confirmed event shapes

#### Action Items
- [ ] Rewrite Phase 0 to reflect correct root cause and simplified scope (~3h)
- [ ] Update Phase 0 SchemaVersioning: V1 = current schema only, remove V1→V2 migration
- [ ] Fix store migration path: from `~/Library/Application Support/default.store` (not bundle ID path)
- [ ] Simplify DataErrorView: error message + Reset Data + Contact Support (no Try Again)
- [ ] Update dependency diagram: Phase 0 runs first, not in parallel
- [ ] Phase 1 Task 1-6: Add research step for Dodo payment.refunded before implementation

#### Impact on Phases
- Phase 0: Major rewrite — correct root cause description, simplify to V1-only schema, fix store migration source path, simplify error UI, reduce effort estimate to 3h
- Phase 1: Task 1-6 needs Dodo docs research step before payment.refunded implementation
- Plan overview: Dependency diagram changed to sequential (Phase 0 first)
