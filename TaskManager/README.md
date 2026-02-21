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

## Requirements

- macOS 15+ (Sequoia)
- Xcode 16+
- Swift 6.0+

## Component Library

See [TaskManagerUIComponents/README.md](../TaskManagerUIComponents/README.md) for UI component references.
