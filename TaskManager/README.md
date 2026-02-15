# TaskManager

A macOS productivity app built with Liquid Glass UI components.

## Quick Start

### Using Xcode (recommended for app submission)
```bash
cd TaskManager
./scripts/generate_xcodeproj.sh
open TaskManagerApp.xcodeproj
```

### Build archive with .app output (unsigned/local test)
```bash
cd TaskManager
./scripts/archive_macos_app.sh
```

### Build signed archive (for Organizer upload)
```bash
cd TaskManager
xcodebuild -project TaskManagerApp.xcodeproj -scheme TaskManager -configuration Release -destination "generic/platform=macOS" -archivePath ../build/TaskManager-signed.xcarchive archive
```

Archive output:
- `../build/TaskManager.xcarchive`
- `../build/TaskManager.xcarchive/Products/Applications/TaskManager.app`
- `../build/TaskManager-signed.xcarchive`

See full release flow: `../docs/macos-release-workflow.md`

### Using Command Line (SPM run)
```bash
cd TaskManager
swift run
```

## Architecture

```
TaskManager/                    # Main App (your code)
├── Package.swift              # Depends on TaskManagerUIComponents
└── Sources/TaskManager/
    └── TaskManagerApp.swift   # App entry (60 lines)

TaskManagerUIComponents/       # UI Component Library (reusable)
├── 24 modular component files
└── All Liquid Glass UI
```

## How It Works

1. **Import Components** from `TaskManagerUIComponents`
2. **Compose Views** using modular components
3. **Add Logic** as you build features

## Main App Code

Only ~60 lines - all UI comes from components:

```swift
import SwiftUI
import TaskManagerUIComponents

@main
struct TaskManagerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowToolbarStyle(.unified)
    }
}

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            SidebarView(selectedItem: $selectedItem)
        } detail: {
            DetailPanelView(...)  // All components!
        }
    }
}
```

## Next Steps

1. **Add Data Layer** - Persistence, networking
2. **Add Business Logic** - Task CRUD, filtering
3. **Add State Management** - Observable models
4. **Add Tests** - Unit tests, UI tests

## Requirements

- macOS 15+ (Sequoia)
- Xcode 16+
- Swift 6.0+

## Component Library

See [TaskManagerUIComponents/README.md](../TaskManagerUIComponents/README.md) for full component reference.
