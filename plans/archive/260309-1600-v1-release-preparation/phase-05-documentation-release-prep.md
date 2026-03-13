# Phase 5 -- Documentation + Release Prep

Priority: **P3**
Status: Complete
Depends on: **Phase 4 must be complete**
Estimated effort: **6h**
Tasks: 8

## Context Links

- Current features status: [`docs/features-status.md`](../../docs/features-status.md)
- Current README: [`README.md`](../../README.md)
- Git history: 55 commits, Feb 3 - Mar 9, 2026

## Overview

Create and update all project documentation for GA release. Generate retroactive changelog from git history, document system architecture, establish code standards, and perform final release verification.

## Key Insights

- No `development-roadmap.md`, `project-changelog.md`, `system-architecture.md`, or `code-standards.md` currently exist
- Git history is clean and well-organized by feature area -- good for retroactive changelog
- Release verification must cover both Swift app (debug + release builds) and backend (tests + E2E)

## Requirements

**Functional:**
- All documentation reflects current GA state
- Changelog covers all 55 commits grouped by release milestone
- Architecture doc covers both Swift app and CF Workers backend
- Code standards doc captures existing conventions
- Release build passes all smoke tests

**Non-functional:**
- Each doc follows kebab-case naming
- Docs accurate, concise, and useful for onboarding new contributors

## Architecture

No code changes. Documentation + verification only.

## Related Code Files

**Create:**
- `docs/development-roadmap.md`
- `docs/project-changelog.md`
- `docs/system-architecture.md`
- `docs/code-standards.md`

**Modify:**
- `docs/features-status.md`
- `plans/README.md`
- `README.md`

## Implementation Steps

### Task 5-1: Update features-status.md

1. Update "Last updated" date to current
2. Change security hardening status from "In Progress" to "Done"
3. Change legacy email-only paths from "Flag-gated" to "Removed"
4. Add data integrity section:
   - VersionedSchema: Done
   - Pre-migration backup: Done
   - DataErrorView: Done
5. Add CRON cleanup, anomaly logging, key rotation as new rows
6. Verify all feature statuses are accurate

### Task 5-2: Create development-roadmap.md

Structure:
```
# Development Roadmap

## v1.0 -- GA Release (Current)
- [ ] Data integrity fix (Phase 0)
- [ ] Security hardening (Phases 1-4)
- [ ] Documentation (Phase 5)
- [ ] Release verification

## v1.1 -- Post-GA Improvements
- [ ] Performance monitoring / analytics (opt-in)
- [ ] Additional AI providers
- [ ] Keyboard shortcut customization improvements
- [ ] iCloud sync consideration

## v2.0 -- Future
- [ ] Collaboration features
- [ ] iOS companion app
- [ ] Web admin dashboard
```

Include progress percentages per area.

### Task 5-3: Create project-changelog.md

Retroactive changelog from git history (55 commits). Structure:

```markdown
## [Unreleased] -- v1.0 Release Preparation
### Security
- Remove debug OTP code from API responses
- Add rate limiting to verify and restore endpoints
- Fix device seat TOCTOU race condition (atomic INSERT)
- Handle license_key.revoked and payment.refunded webhooks
- Fix tier precedence state bug
- Remove CORS headers (native app only)
- Remove legacy email-only code paths
### Fixed
- Critical: SwiftData silent in-memory fallback causing data loss
### Added
- VersionedSchema with migration plan (V1->V2)
- Pre-migration store backups
- DataErrorView for container init failures
- CRON scheduled cleanup (every 6h)
- Anomaly logging for account-sharing detection
- Ed25519 key rotation support (kid claim)

## [0.9.0] -- 2026-03-03
### Added
- Email OTP authentication (passwordless)
- Device seat management (Free:1, Pro:2, VIP:3)
- Auth-gated premium flows (restore, resolve, checkout)
- Account sign-in UI and device management view

## [0.8.0] -- 2026-02-25
### Added
- Backend entitlement system (Cloudflare Workers + D1)
- DodoPayments integration (subscription + lifetime)
- Install proof via Secure Enclave (ECDSA P-256)
- Ed25519 server-signed entitlement tokens

## [0.7.0] -- 2026-02-22
### Added
- Inline Enhance (system-wide text enhancement)
- Rename to "Strata"
- Developer ID signing and notarization

## [0.6.0] -- 2026-02-18
### Added
- Custom fields (text, number, currency, date, toggle)
- Premium tier structure (Pro/VIP)
- Theme system
- Code review improvements

## [0.5.0] -- 2026-02-13
### Added
- Calendar view
- Reminders with alarm handling
- Global keyboard shortcuts (Quick Entry, Enhance Me)
- Data persistence improvements

## [0.4.0] -- 2026-02-06
### Added
- AI integration (Gemini, z.ai providers)
- Built-in AI modes (Correct Me, Enhance Prompt, Explain)
- Enhance Me floating panel
- Custom AI modes

## [0.3.0] -- 2026-02-03
### Added
- Initial app with SwiftData
- Task CRUD (title, description, status, tags, priorities)
- Due dates, photo attachments
- Search and filtering
- List view with sorting
- Data import/export
```

Fill in details from actual git log.

### Task 5-4: Create system-architecture.md

Document:
1. **Swift App Layers:**
   - Data: @Model classes, ModelContainer, VersionedSchema
   - Services: EntitlementService, DodoPaymentsClient, SecureEnclaveService, AIService
   - Views: Premium views, Settings, Kanban, Onboarding
   - Windows: WindowManager, SettingsWindow, EnhanceMePanel, InlineEnhanceHUD, QuickEntry
   - AI: Protocol-based provider system (Gemini, z.ai)

2. **Backend Layers:**
   - Router: itty-router with middleware
   - Auth: Email OTP via Resend, session management, rate limiting
   - Entitlements: user_entitlements table, projector pattern, webhook processing
   - Signing: Ed25519 token signing with kid claim
   - Install Proof: Secure Enclave challenge-nonce protocol

3. **Data Flow Diagrams:**
   - Entitlement lifecycle: checkout -> webhook -> projector -> entitlement -> token -> client
   - Auth flow: email -> OTP -> verify -> session -> bearer token
   - Install binding: Secure Enclave keypair -> challenge -> sign -> verify

4. **Security Model:**
   - Auth: OTP + session tokens (SHA-256 hashed, 30-day TTL)
   - Install binding: P-256 ECDSA via Secure Enclave
   - Entitlements: Ed25519 signed tokens (72h TTL, install-bound)
   - Rate limiting: per-IP and per-install on all auth/entitlement endpoints

### Task 5-5: Create code-standards.md

Document existing conventions:
1. **Swift:**
   - @Model patterns (properties, relationships)
   - Repository pattern for data access
   - Service layer for business logic
   - View composition (extract subviews, preference keys)
   - Error handling patterns

2. **TypeScript:**
   - AppError pattern for typed API errors
   - Route handler structure (validate -> auth -> logic -> response)
   - Validation helpers in validation.ts
   - D1 query patterns (prepared statements, batch API)

3. **General:**
   - File naming: kebab-case with descriptive names
   - Max 200 LOC per file (modularize when exceeded)
   - Testing patterns (vitest, mock env)
   - Commit message format (conventional commits)

### Task 5-6: Update plans/README.md

1. Add this plan as active, replacing 260304 plan
2. Move 260304 plan to archive section
3. Update plan index

### Task 5-7: Update README.md

1. Change "Active plan" link to this plan
2. Update "Current Status" section to reflect v1.0 release prep
3. Verify build instructions still accurate

### Task 5-8: Final Release Verification

1. Build debug configuration -- verify success
2. Build release configuration -- verify success
3. Run `cd backend && npm run test` -- all pass
4. E2E smoke test:
   - OTP start -> verify -> session token
   - Restore with session -> entitlement token
   - Device list -> device revoke
   - Inline Enhance activation
5. Verify no debug artifacts in release build:
   - No `debug_code` in API responses
   - No debug UI in release build
   - No console.log of sensitive data
6. Final sign-off checklist

## Todo List

- [x] 5-1: Update features-status.md (data integrity, security done, legacy removed)
- [x] 5-2: Create development-roadmap.md
- [x] 5-3: Create project-changelog.md (retroactive from 55 commits)
- [x] 5-4: Create system-architecture.md (Swift + backend + data flows)
- [x] 5-5: Create code-standards.md (Swift + TS conventions)
- [x] 5-6: Update plans/README.md (archive 260304, add this plan)
- [x] 5-7: Update README.md (active plan link, current status)
- [x] 5-8: Final release verification (builds, tests, no debug artifacts)

## Success Criteria

- All 4 new docs exist and are accurate
- features-status.md reflects GA state
- README.md and plans/README.md updated
- Debug + release builds succeed
- All backend tests pass
- E2E smoke test passes
- No debug artifacts in release build
- GA Gate checklist from Phase 4 fully checked

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Docs become stale quickly | LOW | docs-manager agent updates on each milestone |
| Changelog missing commits | LOW | Cross-reference with `git log --oneline` |
| Release build fails on clean machine | MEDIUM | Test on fresh checkout if possible |

## Security Considerations

- Verify no API keys, secrets, or credentials in any documentation
- Ensure debug artifacts are absent from release build
- Review all new docs for accidental exposure of internal architecture details

## Next Steps

- After sign-off, tag `v1.0.0` in git
- Notarize release build via Developer ID
- Upload to distribution channel
- Begin 7-day post-GA monitoring (see Phase 4)
