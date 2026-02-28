# AGENTS.md

## Project Context
- App Name: **Strata** — Personal AI Task Manager
- Repository: `strata` (macOS app)
- Primary app module: `TaskManager/`
- Inline enhancement work is actively developed and tested across native apps, Electron apps, and browsers.

## Communication & Working Style
- Keep responses concise and action-oriented.
- Do not expand scope without explicit approval.
- Before changing build/run behavior, check `TaskManager/README.md`.
- Prefer incremental, verifiable fixes over broad refactors.
- After each fix, report what changed and how to validate it.

## Evidence-First Protocol (Mandatory)
Apply this protocol for research, debugging, planning, and implementation tasks.
Do **not** require this full protocol for simple operational requests (e.g. quick status checks, one-step commands).

1. Validate with evidence before proposing a fix:
   - Check local code and relevant logs first.
   - Check official documentation (primary source) for APIs/platform behavior.
   - Check community reports for similar real-world failures and resolutions.
2. No silent assumptions:
   - If an assumption is unavoidable, label it explicitly as `Assumption`.
   - Keep assumptions minimal and replace them with evidence as soon as possible.
3. If user asks for plan first, do not modify code before delivering:
   - Findings
   - Evidence links
   - Root cause
   - Fix plan
   - Validation checklist
4. Source quality order:
   - Official vendor/platform docs first.
   - Then high-signal community threads (issue trackers, maintainer discussions, Stack Overflow with reproducible context).
5. Every non-trivial technical report must include:
   - `Code Evidence`: concrete `file:line` references
   - `Docs Evidence`: links to official docs used
   - `Community Evidence`: links to similar cases
   - `Assumptions`: explicit list or `none`
6. If evidence is insufficient, stop and state what is missing instead of guessing.

## Test Operations Shortcuts
- Cancel active Dodo test subscriptions for an email:
  - `cd backend`
  - `npm run dodo:test:subscription:cancel -- --email <email>`
- Check active Dodo test subscriptions for an email:
  - `cd backend`
  - `npm run dodo:test:subscription:check -- --email <email>`
- Notes:
  - Defaults to Dodo Test Mode base URL (`https://test.dodopayments.com`).
  - Requires `DODO_API_KEY` in env, unless provided via `--api-key`.

## Build & Run (Source of Truth)
Always use commands aligned with `TaskManager/README.md`:

- Generate Xcode project:
  - `cd TaskManager`
  - `./scripts/generate_xcodeproj.sh`
- Debug app build (preferred for testing):
  - `cd TaskManager`
  - `./scripts/build-debug.sh`
  - Output: `build/Debug/TaskManager.app` (repo root `build/`)
- Release build:
  - `cd TaskManager`
  - `./scripts/build-release.sh`
- Quick SPM run:
  - `cd TaskManager`
  - `swift run TaskManager`

## Distribution Model
- Developer ID only (notarized, distributed via website).
- App Sandbox is disabled (required for Accessibility API).
- Payments via DodoPayments (Merchant of Record) — license keys for VIP, subscription linking for Pro.
- All features (including inline enhance) ship in one build.

## Inline Enhancement Guardrails
- Preserve currently working behavior for:
  - Native apps
  - Electron apps
  - Browsers (including Arc)
- Avoid risky rewrites in capture/replace strategy ordering unless explicitly requested.
- Maintain fallback behavior:
  - Inline enhance shortcut path first
  - Fallback to Enhance Me panel when capture is unavailable

## Debugging & Cleanup Policy
- Remove temporary debug artifacts once issue is stabilized.
- Keep debug logging gated by existing debug flags.
- Prefer deleting dead code/duplicate paths only after confirming no references.
- For potentially risky cleanup, build and validate immediately after each step.

## Validation Expectations
For changes affecting inline enhancement, validate at minimum:
- Capture + replace in one native app
- Capture + replace in one Electron app
- Capture + replace in one Chromium browser and Safari
- Arc-specific replacement path (no duplication, no false-success)

## Documentation Discipline
- Keep README-consistent commands and workflow.
- If behavior or workflow changes, update related docs in:
  - `TaskManager/README.md`
  - relevant files under `plans/` or `docs/` when applicable.
