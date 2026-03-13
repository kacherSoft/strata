# Strata — AI Productivity Utility for Mac

## Quick Links

| What | Where |
|------|-------|
| **Active plan** | None — ready for new features |
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
plans/                   # Implementation plans
  archive/               # Completed/superseded plans
```

## Current Status

Backend integration complete. Security hardening complete. App features working.

Ready for new feature development and UI improvements before v1.0 release.

See [`docs/development-roadmap.md`](docs/development-roadmap.md) for roadmap.

## Build & Run

See [`AGENTS.md`](AGENTS.md) for build commands, test operations, and development workflow.
