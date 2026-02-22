# TaskManager

TaskManager is a macOS task management app with AI enhancement, premium entitlements (Pro + VIP), global shortcuts, and floating productivity panels.

## Current Status

- ✅ Core task management: tags, priority, due dates, reminders, photos
- ✅ Pro features: Kanban, recurring tasks, custom fields
- ✅ AI modes + Enhance Me panel
- ✅ AI attachments (image/PDF) for supported premium modes/providers
- ✅ StoreKit 2 subscriptions + VIP lifetime purchase
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
│   ├── Services/                     # subscription, notifications, export, storage
│   ├── AI/                           # providers (Gemini/z.ai), protocol, service, models
│   ├── Views/                        # main UI + settings + premium UI
│   ├── Windows/                      # Enhance Me / Quick Entry / Settings windows
│   └── Shortcuts/                    # keyboard shortcut integration
└── Package.swift
```

## Entitlements

- `Free`: core task features
- `Pro (subscription)`: premium feature set
- `VIP (lifetime)`: same feature access as Pro, one-time purchase model

App gating uses `SubscriptionService.hasFullAccess`.

## AI Attachments

- Attachments are handled in the Enhance Me flow and passed to the selected provider.
- Availability is mode + provider capability + entitlement dependent.
- Attachment size/count limits are enforced in-app.

## Inline Enhance (System-Wide) — Developer ID Branch

The `feature/inline-enhance-system-wide` branch adds **system-wide inline AI text enhancement** — press ⌘⌥E in any app's text field to enhance text in-place (like Grammarly).

> ⚠️ This version disables App Sandbox (required for Accessibility API) and is distributed via **Developer ID only**, not the App Store.

### What it does
- **⌘⌥E** in any app → captures text (selected or full field) → AI enhances → replaces inline
- Floating HUD shows progress without stealing focus
- Falls back to Enhance Me panel (⌘⇧E) when no text field is focused
- Requires macOS Accessibility permission (prompted on first use)

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
3. Open any app (TextEdit, Notes, Safari), type text, press **⌘⌥E**

### Coexistence with App Store version
- `main` branch = App Store version (sandboxed, no Accessibility API)
- `feature/inline-enhance-system-wide` = Developer ID version (unsandboxed, with inline enhance)
- Both share the same ⌘⇧E panel workflow

## Requirements

- macOS 15+ (Sequoia)
- Xcode 16+
- Swift 6.0+

## Component Library

See [TaskManagerUIComponents/README.md](../TaskManagerUIComponents/README.md) for UI component references.
