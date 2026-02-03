# TaskManagerPrototype - macOS Liquid Glass UI

A prototype macOS app showcasing Apple's **Liquid Glass** design system from OS 26. Complete UI skeleton with 25+ reusable components.

## Features

- **Liquid Glass Effects**: 5 material levels (.ultraThinMaterial to .ultraThickMaterial)
- **Dark Mode Ready**: Automatic theme adaptation
- **SF Symbols**: Native icons that adapt to appearance
- **macOS Native**: NavigationSplitView with sidebar/detail layout
- **25+ Reusable Components**: Modular, well-documented SwiftUI views

## Quick Start

### Using Xcode
```bash
cd TaskManagerPrototype
open Package.swift
# Or: xed .
```

### Using Command Line
```bash
cd TaskManagerPrototype
swift run
```

## UI Components (25+)

### Layout
| Component | Description | Lines |
|-----------|-------------|-------|
| [ContentView](TaskManagerPrototype/Sources/TaskManagerPrototype/TaskManagerPrototype.swift#L15) | Main NavigationSplitView | 15-40 |
| [SidebarView](TaskManagerPrototype/Sources/TaskManagerPrototype/TaskManagerPrototype.swift#L42) | Left navigation panel | 42-72 |
| [DetailPanelView](TaskManagerPrototype/Sources/TaskManagerPrototype/TaskManagerPrototype.swift#L105) | Main content area | 105-176 |

### Navigation & Header
| Component | Description | Lines |
|-----------|-------------|-------|
| [HeaderView](TaskManagerPrototype/Sources/TaskManagerPrototype/TaskManagerPrototype.swift#L178) | Top header bar | 178-229 |
| [SearchBar](TaskManagerPrototype/Sources/TaskManagerPrototype/TaskManagerPrototype.swift#L231) | Search input with focus | 231-266 |
| [MenuButton](TaskManagerPrototype/Sources/TaskManagerPrototype/TaskManagerPrototype.swift#L268) | Dropdown menu trigger | 268-290 |

### List Items
| Component | Description | Lines |
|-----------|-------------|-------|
| [SidebarRow](TaskManagerPrototype/Sources/TaskManagerPrototype/TaskManagerPrototype.swift#L74) | Sidebar item with badge | 74-103 |
| [TaskListView](TaskManagerPrototype/Sources/TaskManagerPrototype/TaskManagerPrototype.swift#L292) | Scrollable list container | 292-311 |
| [TaskRow](TaskManagerPrototype/Sources/TaskManagerPrototype/TaskManagerPrototype.swift#L313) | Card-style task item | 313-391 |

### Display Components
| Component | Description | Lines |
|-----------|-------------|-------|
| [TagCloud](TaskManagerPrototype/Sources/TaskManagerPrototype/TaskManagerPrototype.swift#L393) | Horizontal tag list | 393-406 |
| [TagChip](TaskManagerPrototype/Sources/TaskManagerPrototype/TaskManagerPrototype.swift#L408) | Single tag badge | 408-421 |
| [PriorityIndicator](TaskManagerPrototype/Sources/TaskManagerPrototype/TaskManagerPrototype.swift#L423) | Flag priority icon | 423-441 |
| [EmptyStateView](TaskManagerPrototype/Sources/TaskManagerPrototype/TaskManagerPrototype.swift#L517) | No results placeholder | 517-540 |
| [ProgressIndicator](TaskManagerPrototype/Sources/TaskManagerPrototype/TaskManagerPrototype.swift#L900) | Progress bar with label | 900-940 |

### Input Components
| Component | Description | Lines |
|-----------|-------------|-------|
| [TextareaField](TaskManagerPrototype/Sources/TaskManagerPrototype/TaskManagerPrototype.swift#L716) | Multi-line text input | 716-746 |
| [PriorityPicker](TaskManagerPrototype/Sources/TaskManagerPrototype/TaskManagerPrototype.swift#L748) | 4-option priority selector | 748-793 |
| [PriorityOption](TaskManagerPrototype/Sources/TaskManagerPrototype/TaskManagerPrototype.swift#L795) | Single priority button | 795-826 |

### Buttons
| Component | Description | Lines |
|-----------|-------------|-------|
| [ActionButton](TaskManagerPrototype/Sources/TaskManagerPrototype/TaskManagerPrototype.swift#L828) | Circular icon button | 828-843 |
| [PrimaryButton](TaskManagerPrototype/Sources/TaskManagerPrototype/TaskManagerPrototype.swift#L845) | Gradient CTA button | 845-873 |
| [FloatingActionButton](TaskManagerPrototype/Sources/TaskManagerPrototype/TaskManagerPrototype.swift#L875) | Circular FAB | 875-898 |

### Sheets (Modals)
| Component | Description | Lines |
|-----------|-------------|-------|
| [NewTaskSheet](TaskManagerPrototype/Sources/TaskManagerPrototype/TaskManagerPrototype.swift#L542) | Create task form | 542-636 |
| [EditTaskSheet](TaskManagerPrototype/Sources/TaskManagerPrototype/TaskManagerPrototype.swift#L638) | Edit task form | 638-714 |

### Detail Views
| Component | Description | Lines |
|-----------|-------------|-------|
| [TaskDetailView](TaskManagerPrototype/Sources/TaskManagerPrototype/TaskManagerPrototype.swift#L443) | Bottom task detail panel | 443-515 |

## Glass Materials Used

```swift
.ultraThinMaterial  // Badges, buttons, tags
.thinMaterial      // Selected rows, inputs
.regularMaterial   // Headers, panels
.thickMaterial     // (available for use)
.ultraThickMaterial // (available for use)
```

## Reusing Components

```swift
// Quick copy examples

// Search bar with binding
SearchBar(text: $searchText)

// Tag display
TagCloud(tags: ["design", "ui", "urgent"])

// Priority selector
PriorityPicker(selectedPriority: $selectedPriority)

// Circular action button
ActionButton(icon: "pencil", action: { ... })

// Primary CTA button
PrimaryButton(title: "Create Task", icon: "plus") { ... }

// Glass card background
.padding(16)
.background(.thinMaterial)
.clipShape(RoundedRectangle(cornerRadius: 12))
```

## Design Guidelines

See [DESIGN-GUIDELINES.md](DESIGN-GUIDELINES.md) for:
- Material hierarchy
- Color system
- Typography scale
- Component specifications
- Spacing & layout
- Dark mode support
- Accessibility guidelines

## Screenshots

Run the app to see:
- Sidebar with sections and count badges
- Search bar with focus state
- Task rows with tags, priority, dates
- New/Edit task sheets with calendar picker
- Empty states
- Progress indicators

## Requirements

- macOS 15+ (Sequoia)
- Xcode 16+
- Swift 6.0+

## File Structure

```
TaskManagerPrototype/
├── Package.swift
├── README.md
├── DESIGN-GUIDELINES.md
└── Sources/
    └── TaskManagerPrototype/
        └── TaskManagerPrototype.swift  (1083 lines, 25+ components)
```

## Research

See [Research Report](../plans/reports/research-260203-liquid-glass-ui-macos.md)
