# Strata — AI Productivity Utility for Mac

## Quick Links

| What | Where |
|------|-------|
| **Active plan** | [`plans/260304-security-hardening-finalization/plan.md`](plans/260304-security-hardening-finalization/plan.md) |
| **All plans** | [`plans/README.md`](plans/README.md) |
| **Feature status** | [`docs/features-status.md`](docs/features-status.md) |
| **Design guidelines** | [`docs/design-guidelines.md`](docs/design-guidelines.md) |
| **Marketing** | [`docs/strata-marketing-master-document.md`](docs/strata-marketing-master-document.md) |
| **App Store listing** | [`docs/app-store-listing.md`](docs/app-store-listing.md) |
| **Agent instructions** | [`AGENTS.md`](AGENTS.md) |

## Project Structure

```
TaskManager/             # macOS app (Swift/SwiftUI)
backend/                 # Cloudflare Workers + D1 (TypeScript)
docs/                    # Product docs (features, design, marketing)
plans/                   # Implementation plans (active + archived)
  260304-.../            # Current active plan
  archive/               # Superseded/completed plans
  reports/               # Agent-generated research & analysis
    research/            # Technical research reports
    marketing/           # Marketing & positioning reports
```

## Current Status

**All product features: DONE** (see [`docs/features-status.md`](docs/features-status.md))

**Active work: Security Hardening Finalization** — 29 tasks across 5 phases
- Phase 1: Critical security (P0) — debug code leak, rate limiter, TOCTOU, webhook handlers
- Phase 2: High security (P1) — restore rate limit, tier precedence, webhook race
- Phase 3: Medium quality (P2) — validation, body size, product ID mapping
- Phase 4: Infrastructure (P2) — CRON cleanup, key rotation, tier downgrade
- Phase 5: Legacy cleanup + GA gate (P3) — remove email-only paths, flag cleanup

## Build & Run

See [`AGENTS.md`](AGENTS.md) for build commands, test operations, and development workflow.
