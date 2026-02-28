# Strata

**Your AI, Anywhere on Your Mac**

Strata is a macOS AI productivity utility with system-wide text enhancement, premium entitlements (Pro + VIP), global shortcuts, and built-in task management.

## Current Status

- ✅ Core task management: tags, priority, due dates, reminders, photos
- ✅ **Free tier: All core features, NO LIMITS** (unlimited AI enhancements in-app)
- ✅ AI modes + Enhance Me panel
- ✅ **Inline Enhance** (⌘⌥E system-wide text enhancement in ANY app) — *Premium feature*
- ✅ Pro features: Kanban, recurring tasks, custom fields, AI attachments
- ✅ DodoPayments licensing (VIP lifetime) + subscriptions (Pro)
- ✅ Unified entitlement gating (`hasFullAccess`)

## Quick Start

### Using Xcode (development)
```bash
cd TaskManager
./scripts/generate_xcodeproj.sh
open TaskManagerApp.xcodeproj
```

### Build Debug (for testing)
```bash
cd TaskManager
./scripts/build-debug.sh
```

Output: `../build/Debug/TaskManager.app`

### Build Release (for production/distribution)
```bash
cd TaskManager
./scripts/build-release.sh
```

Output: `../build/Release/TaskManager.app`

Install to Applications:
```bash
ditto ../build/Release/TaskManager.app /Applications/TaskManager.app
open /Applications/TaskManager.app
```

### Using Command Line (SPM run)
```bash
cd TaskManager
swift run
```

## Architecture

```text
TaskManager/
├── Sources/TaskManager/
│   ├── TaskManagerApp.swift          # app entry + window scene
│   ├── Data/                         # SwiftData models, config, repositories
│   ├── Services/                     # entitlements (DodoPayments), notifications, export, storage
│   ├── AI/                           # providers (Gemini/z.ai), protocol, service, models
│   ├── Views/                        # main UI + settings + premium UI
│   ├── Windows/                      # Enhance Me / Quick Entry / Settings windows
│   └── Shortcuts/                    # keyboard shortcut integration
└── Package.swift
```

## Entitlements

| Tier | Price | Features |
|------|-------|----------|
| **Free** | $0 forever | Task management, list/calendar views, AI modes (unlimited), local storage — **no limits** |
| **Pro** | $4.99/month | Inline Enhance (⌘⌥E system-wide), Kanban, recurring tasks, custom fields, AI attachments |
| **VIP** | $99.99 one-time | Everything in Pro + lifetime updates, priority support, early access |

App gating uses `EntitlementService.hasFullAccess`.

### Dodo API Notes

- The app uses backend-issued signed entitlement tokens (`/v1/entitlements/resolve`) for Pro/VIP restore and validation.
- Dodo secret API keys must stay server-side (Cloudflare Worker), not in the distributed app.
- Subscription management uses backend `POST /v1/customer-portal/session` with install-bound proof.
- Configure backend URLs via app Info.plist keys:
  - `STRATA_BACKEND_TEST_BASE_URL`
  - `STRATA_BACKEND_LIVE_BASE_URL`
- Configure the entitlement verification key via `ENTITLEMENT_PUBLIC_KEY_HEX` (environment variable or Info.plist).
- `ENTITLEMENT_PUBLIC_KEY_HEX` must match the Worker signing secret `ENTITLEMENT_SIGNING_PRIVATE_KEY` (Ed25519 key pair).

## AI Attachments

- Attachments are handled in the Enhance Me flow and passed to the selected provider.
- Availability is mode + provider capability + entitlement dependent.
- Attachment size/count limits are enforced in-app.

## Inline Enhance (System-Wide) — Pro/VIP Feature

The **killer feature**: system-wide inline AI text enhancement. Press ⌘⌥E in any app's text field to enhance text in-place (like Grammarly, but with YOUR AI models).

> ⚠️ This version disables App Sandbox (required for Accessibility API) and is distributed via **Developer ID only**, not the App Store.

### What it does
- Press your configured global shortcut in any app → captures text (selected or full field) → AI enhances → replaces inline
- Floating HUD shows progress without stealing focus
- Falls back to Enhance Me panel when no text field is focused
- Requires macOS Accessibility permission (prompted on first use)
- Shortcut is customizable in Settings → General

### Build & Test
```bash
git checkout feature/inline-enhance-system-wide
cd TaskManager
./scripts/build-debug.sh
open ../build/Debug/TaskManager.app
```

### First Run
1. Launch the app → go to **Settings → General** → click **"Grant Access"** under System-Wide Enhancement
2. Toggle the app ON in **System Settings → Privacy & Security → Accessibility**
3. Open any app (TextEdit, Notes, Safari), type text, press your configured shortcut

### Coexistence with App Store version
- `main` branch = App Store version (sandboxed, no Accessibility API)
- `feature/inline-enhance-system-wide` = Developer ID version (unsandboxed, with inline enhance)
- Both share the same ⌘⇧E panel workflow

## Requirements

- macOS 15+ (Sequoia)
- Xcode 16+
- Swift 6.2+

## Component Library

See [TaskManagerUIComponents/README.md](../TaskManagerUIComponents/README.md) for UI component references.
