# Phase 1: Foundation & Data Layer

**Priority:** HIGH | **Status:** Pending | **Effort:** 1.5 weeks

## Overview

Set up SwiftData models, basic task CRUD, and integrate with existing UI components. Foundation for all subsequent phases.

## Context Links

- [PRD](../../docs/product-requirements-document.md)
- [Brainstorm Report](../reports/brainstorm-260204-0942-taskflow-pro-implementation.md)
- [Existing UI Components](../../TaskManagerUIComponents/Sources/TaskManagerUIComponents/)

## Key Insights

- SwiftData chosen for 60% less boilerplate (aggressive timeline)
- Existing TaskItem model in UIComponents is demo-only; need real SwiftData models
- Must support 100-5,000 tasks with indexed search

## Requirements

### Functional
- Task CRUD operations (create, read, update, delete)
- Search across title, description, tags
- Filter by priority, completion status, tags
- Sort by date, priority, manual order
- Due date and reminder support

### Non-Functional
- <100ms UI response time
- Indexed fields for fast search
- Proper @Model annotations for SwiftData

## Architecture

```
TaskManager/Sources/TaskManager/
├── Data/
│   ├── Models/
│   │   ├── TaskModel.swift        # @Model for tasks
│   │   ├── AIModeModel.swift      # @Model for AI modes
│   │   └── SettingsModel.swift    # @Model for app settings
│   ├── Repositories/
│   │   ├── TaskRepository.swift   # CRUD operations
│   │   └── AIModeRepository.swift
│   └── ModelContainer+Config.swift
├── ViewModels/
│   ├── TaskListViewModel.swift
│   └── TaskDetailViewModel.swift
└── TaskManagerApp.swift           # Add modelContainer
```

## Related Code Files

### Create
- `TaskManager/Sources/TaskManager/Data/Models/TaskModel.swift`
- `TaskManager/Sources/TaskManager/Data/Models/AIModeModel.swift`
- `TaskManager/Sources/TaskManager/Data/Models/SettingsModel.swift`
- `TaskManager/Sources/TaskManager/Data/Repositories/TaskRepository.swift`
- `TaskManager/Sources/TaskManager/Data/Repositories/AIModeRepository.swift`
- `TaskManager/Sources/TaskManager/Data/ModelContainer+Config.swift`
- `TaskManager/Sources/TaskManager/ViewModels/TaskListViewModel.swift`
- `TaskManager/Sources/TaskManager/ViewModels/TaskDetailViewModel.swift`

### Modify
- `TaskManager/Sources/TaskManager/TaskManagerApp.swift` - Add modelContainer
- `TaskManager/Package.swift` - Add SwiftData dependency

### Integrate
- Update UI components to use real SwiftData models instead of sample data

## Implementation Steps

### Step 1: SwiftData Models (Day 1-2)

**1.1 TaskModel.swift**
```swift
import SwiftData
import Foundation

@Model
final class TaskModel {
    @Attribute(.unique) var id: UUID
    var title: String
    var taskDescription: String
    var dueDate: Date?
    var reminderDate: Date?
    var priority: TaskPriority
    var tags: [String]
    var isCompleted: Bool
    var completedDate: Date?
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int
    
    init(
        title: String,
        taskDescription: String = "",
        dueDate: Date? = nil,
        priority: TaskPriority = .medium,
        tags: [String] = []
    ) {
        self.id = UUID()
        self.title = title
        self.taskDescription = taskDescription
        self.dueDate = dueDate
        self.priority = priority
        self.tags = tags
        self.isCompleted = false
        self.createdAt = Date()
        self.updatedAt = Date()
        self.sortOrder = 0
    }
}

enum TaskPriority: String, Codable, CaseIterable {
    case low, medium, high, critical
    
    var color: String {
        switch self {
        case .low: return "gray"
        case .medium: return "blue"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}
```

**1.2 AIModeModel.swift**
```swift
@Model
final class AIModeModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var systemPrompt: String
    var sortOrder: Int
    var isBuiltIn: Bool
    
    init(name: String, systemPrompt: String, isBuiltIn: Bool = false) {
        self.id = UUID()
        self.name = name
        self.systemPrompt = systemPrompt
        self.sortOrder = 0
        self.isBuiltIn = isBuiltIn
    }
}
```

**1.3 SettingsModel.swift**
```swift
@Model
final class SettingsModel {
    var id: UUID
    var aiProvider: AIProvider
    var geminiAPIKey: String?
    var zaiAPIKey: String?
    var selectedAIModeId: UUID?
    var alwaysOnTop: Bool
    var reducedMotion: Bool
    
    init() {
        self.id = UUID()
        self.aiProvider = .gemini
        self.alwaysOnTop = false
        self.reducedMotion = false
    }
}

enum AIProvider: String, Codable, CaseIterable {
    case gemini = "Google Gemini"
    case zai = "z.ai (GLM 4.6)"
}
```

### Step 2: Model Container Configuration (Day 2)

**ModelContainer+Config.swift**
```swift
import SwiftData

extension ModelContainer {
    static func configured() throws -> ModelContainer {
        let schema = Schema([
            TaskModel.self,
            AIModeModel.self,
            SettingsModel.self
        ])
        
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

### Step 3: Repositories (Day 3-4)

**TaskRepository.swift** - CRUD with search/filter support
- `fetchAll(sortBy:filter:)`
- `create(title:description:dueDate:priority:tags:)`
- `update(_:)`
- `delete(_:)`
- `toggleComplete(_:)`
- `search(query:)`

### Step 4: ViewModels (Day 4-5)

**TaskListViewModel.swift**
- `@Published var tasks: [TaskModel]`
- `@Published var searchText: String`
- `@Published var selectedFilter: TaskFilter`
- Auto-fetch on init with `@Query` or repository pattern

### Step 5: App Integration (Day 5-6)

**TaskManagerApp.swift**
```swift
@main
struct TaskManagerApp: App {
    let container: ModelContainer
    
    init() {
        do {
            container = try ModelContainer.configured()
            seedDefaultAIModes(container: container)
        } catch {
            fatalError("Failed to configure SwiftData: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup("Task Manager", id: "main-window") {
            ContentView()
        }
        .modelContainer(container)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 700)
    }
}
```

### Step 6: UI Component Integration (Day 6-7)

- Bridge existing TaskItem (display) ↔ TaskModel (data)
- Update TaskListView to use real data
- Connect NewTaskSheet to create real tasks
- Wire up search/filter to repository queries

## Todo List

- [x] Create TaskModel with all properties
- [x] Create AIModeModel
- [x] Create SettingsModel
- [x] Configure ModelContainer
- [x] Implement TaskRepository CRUD
- [x] Implement TaskListViewModel
- [x] Integrate with TaskManagerApp
- [x] Seed default AI modes (Correct Me, Enhance Prompt, Simplify, Break Down)
- [x] Update ContentView to use SwiftData
- [ ] Test CRUD operations
- [ ] Test search performance with 1000+ items

## Success Criteria

- [x] Can create, edit, delete tasks
- [ ] Search returns results <100ms
- [x] Tasks persist across app restarts
- [x] Default AI modes seeded on first launch
- [x] All existing UI components work with real data

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| SwiftData bugs on Tahoe | Medium | High | File bugs, Core Data fallback plan |
| @Query performance | Low | Medium | Use indexed fields, profile with Instruments |
| Model migration issues | Low | Medium | Lightweight migration strategy |

## Security Considerations

- API keys NOT stored in SwiftData (Keychain in Phase 3)
- No sensitive data in model attributes

## Implementation Notes (Lessons Learned)

### Window Focus Issue (macOS)
- **Problem:** `.hiddenTitleBar` window style caused TextField inputs to not receive keyboard focus
- **Solution:** Added `AppDelegate` with `NSApp.setActivationPolicy(.regular)` + `WindowActivator` NSViewRepresentable
- **Files:** `TaskManagerApp.swift`, `Extensions/WindowActivator.swift`

### Callback Architecture for UI Components
- UI components (TaskManagerUIComponents) don't have access to SwiftData
- **Pattern:** Pass callbacks through view hierarchy: `ContentView` → `DetailPanelView` → `TaskListView` → `TaskRow` → `EditTaskSheet`
- All persistence logic stays in ContentView where `modelContext` is available

### TaskItem ID Propagation
- Original `TaskItem.id = UUID()` created new ID each time, breaking lookup
- **Fix:** Accept `id` in initializer, pass from `TaskModel.id` in `toTaskItem()`

### SwiftData Model Notes
- Use `@Attribute(.unique)` for ID fields
- Arrays like `tags: [String]` work natively in SwiftData
- Call `modelContext.save()` after modifications for immediate persistence

## Next Steps

→ Phase 2: Global Shortcuts & Quick Entry (depends on TaskModel being ready)
