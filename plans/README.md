# Plans — Navigation Index

_Last updated: 2026-03-10_

## Active Plans

| Plan | Status | Priority | Description |
|------|--------|----------|-------------|
| [260309-v1-release-preparation](./260309-1600-v1-release-preparation/plan.md) | **Active** | P0 | 42 tasks across 6 phases: data loss fix, security hardening (29 tasks), legacy cleanup, documentation, release prep |

## Archived Plans (Superseded / Completed / Stale)

All superseded and completed plans live in [`archive/`](./archive/).

| Plan | Status | Description |
|------|--------|-------------|
| [260304-security-hardening-finalization](./archive/260304-security-hardening-finalization/plan.md) | Superseded by 260309 | Security-only plan; absorbed into v1.0 release preparation with data loss fix added |
| [260303-account-ownership-hardening-finalization](./archive/260303-account-ownership-hardening-finalization/plan.md) | Superseded by 260304 | Initial finalization plan, replaced with detailed phase breakdown |
| [260228-account-ownership-hardening](./archive/260228-account-ownership-hardening/plan.md) | Superseded by 260303 | Original 6-phase ownership hardening plan (Phases 0-4 done) |
| [260225-tiny-backend-entitlements](./archive/260225-tiny-backend-entitlements/plan.md) | Superseded by 260228 | First backend entitlement plan (proxy, webhooks, activation) |
| [2026-02-19-ui-mode-settings](./archive/2026-02-19-ui-mode-settings/plan.md) | Stale (pending) | Light/dark theme support — never started |
| [260303-account-ownership-hardening-file-audit.md](./archive/260303-account-ownership-hardening-file-audit.md) | Reference | Complete file audit of auth/entitlement codebase |

## Reports

Agent-generated research and analysis reports.

| Category | Location | Contents |
|----------|----------|----------|
| Research | [`reports/research/`](./reports/research/) | DodoPayments integration, AI market research, competitive analysis, architecture review, security audit |
| Marketing | [`reports/marketing/`](./reports/marketing/) | Product identity, repositioning, launch kit, landing page design, marketing copy |

## How Plans Work

- **One active plan at a time** for each workstream
- When a plan is superseded, it moves to `archive/`
- Each plan has a `plan.md` overview + `phase-XX-*.md` detail files
- Phase files include parallelism annotations for agent team execution
- Reports generated during planning live in `reports/{category}/`
