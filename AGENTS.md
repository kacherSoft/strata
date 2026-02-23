# AGENTS.md

## Project Context
- Repository: `TaskManager` (macOS app)
- Primary app module: `TaskManager/`
- Inline enhancement work is actively developed and tested across native apps, Electron apps, and browsers.

## Communication & Working Style
- Keep responses concise and action-oriented.
- Do not expand scope without explicit approval.
- Before changing build/run behavior, check `TaskManager/README.md`.
- Prefer incremental, verifiable fixes over broad refactors.
- After each fix, report what changed and how to validate it.

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

## Branch / Distribution Model
- `main`: App Store-oriented, sandboxed constraints.
- `feature/inline-enhance-system-wide`: Developer ID flow for system-wide Accessibility-based inline enhancement.
- Do not assume sandbox-compatible behavior for system-wide AX features.

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
