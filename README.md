# Strata — AI Productivity Utility for Mac

## Quick Links

| What | Where |
|------|-------|
| **Active plan** | [`plans/260309-1600-v1-release-preparation/plan.md`](plans/260309-1600-v1-release-preparation/plan.md) |
| **All plans** | [`plans/README.md`](plans/README.md) |
| **Feature status** | [`docs/features-status.md`](docs/features-status.md) |
| **Roadmap** | [`docs/development-roadmap.md`](docs/development-roadmap.md) |
| **Changelog** | [`docs/project-changelog.md`](docs/project-changelog.md) |
| **Architecture** | [`docs/system-architecture.md`](docs/system-architecture.md) |
| **Code standards** | [`docs/code-standards.md`](docs/code-standards.md) |
| **Design guidelines** | [`docs/design-guidelines.md`](docs/design-guidelines.md) |
| **Marketing** | [`docs/strata-marketing-master-document.md`](docs/strata-marketing-master-document.md) |
| **Agent instructions** | [`AGENTS.md`](AGENTS.md) |

## Project Structure

```
TaskManager/             # macOS app (Swift/SwiftUI)
backend/                 # Cloudflare Workers + D1 (TypeScript)
docs/                    # Project docs (features, architecture, standards, roadmap)
plans/                   # Implementation plans (active + archived)
  260309-.../            # Current active plan (v1.0 release prep)
  archive/               # Superseded/completed plans
  reports/               # Agent-generated research & analysis
    research/            # Technical research reports
    marketing/           # Marketing & positioning reports
```

## Current Status

**All product features: DONE** (see [`docs/features-status.md`](docs/features-status.md))

**Active work: v1.0 Release Preparation — Phase 5 (Documentation)**
- Phase 0: Data loss fix — ✅ Done
- Phase 1: Critical security — ✅ Done
- Phase 2: High security — ✅ Done
- Phase 3: Medium quality + infrastructure — ✅ Done
- Phase 4: Legacy cleanup + GA gate — ✅ Done
- Phase 5: Documentation + release verification — In Progress

See [`docs/development-roadmap.md`](docs/development-roadmap.md) for v1.0, v1.1, and v2.0 plans.

## Build & Run

See [`AGENTS.md`](AGENTS.md) for build commands, test operations, and development workflow.
