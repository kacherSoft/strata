# TaskManagerUIComponents

A reusable Swift package containing macOS Liquid Glass UI components for Task Manager and similar productivity apps.

## Features

- **Liquid Glass Design**: macOS Tahoe (OS 26) inspired translucent materials
- **25+ Reusable Components**: Modular, well-documented SwiftUI views
- **Dark Mode Ready**: Automatic theme adaptation
- **Type-Safe**: Full Swift 6 concurrency support

## Usage

### Add as Dependency

```swift
// In your Package.swift
dependencies: [
    .package(path: "../TaskManagerUIComponents")
]
```

### Import & Use

```swift
import TaskManagerUIComponents
import SwiftUI

struct ContentView: View {
    @State private var tasks = TaskItem.sampleTasks

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedItem: $selectedItem)
        } detail: {
            DetailPanelView(
                selectedSidebarItem: selectedItem,
                selectedTask: $selectedTask,
                tasks: tasks,
                searchText: $searchText,
                showNewTaskSheet: $showNewTaskSheet
            )
        }
    }
}
```

## Components

### Buttons
| Component | Description |
|-----------|-------------|
| `ActionButton` | Circular icon button with glass background |
| `PrimaryButton` | Gradient CTA button |
| `FloatingActionButton` | Capsule glass button (iOS 26 camera style) |

### Inputs
| Component | Description |
|-----------|-------------|
| `SearchBar` | Search input with focus state |
| `TextareaField` | Multi-line text input |
| `PriorityPicker` | 4-option priority selector |

### Display
| Component | Description |
|-----------|-------------|
| `TagChip` | Individual tag badge |
| `TagCloud` | Horizontal tag list |
| `ProgressIndicator` | Progress bar with fraction |
| `EmptyStateView` | No results placeholder |
| `PriorityIndicator` | Colored flag icon |

### Views
| Category | Components |
|---------|-----------|
| **Sidebar** | `SidebarView`, `SidebarRow` |
| **TaskList** | `TaskListView`, `TaskRow` |
| **Detail** | `DetailView`, `HeaderView`, `DetailPanelView` |
| **Sheets** | `NewTaskSheet`, `EditTaskSheet` |

### Models
| Model | Properties |
|-------|-----------|
| `TaskItem` | title, notes, priority, dueDate, tags, subtasks |
| `SidebarItem` | title, icon, count |

## Glass Materials

```swift
.ultraThinMaterial  // Badges, buttons, tags
.thinMaterial      // Selected rows, inputs
.regularMaterial   // Headers, panels
.thickMaterial     // Modal backgrounds
.ultraThickMaterial // Overlays
```

## Requirements

- macOS 15+ (Sequoia)
- Swift 6.0+
- Xcode 16+

## Project Structure

```
TaskManagerUIComponents/
├── Package.swift
├── Sources/
│   └── TaskManagerUIComponents/
│       ├── Models/
│       │   ├── TaskItem.swift
│       │   └── SidebarItem.swift
│       └── Views/
│           ├── Sidebar/
│           ├── Detail/
│           ├── TaskList/
│           ├── Sheets/
│           └── Components/
│               ├── Buttons/
│               ├── Inputs/
│               ├── Display/
│               └── Misc/
└── README.md
```

## Design Guidelines

See [DESIGN-GUIDELINES.md](../TaskManagerPrototype/DESIGN-GUIDELINES.md) for:
- Material hierarchy
- Color system
- Typography scale
- Component specifications
- Spacing & layout
- Accessibility guidelines

## License

MIT License - Feel free to use in your projects!
