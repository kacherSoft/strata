# Phase 2: Global Shortcuts & Quick Entry

**Priority:** HIGH | **Status:** Pending | **Effort:** 1 week

## Overview

Implement global keyboard shortcuts using KeyboardShortcuts package and create quick-entry floating panel for instant task capture from anywhere.

## Context Links

- [PRD - Global Shortcuts](../../docs/product-requirements-document.md)
- [KeyboardShortcuts GitHub](https://github.com/sindresorhus/KeyboardShortcuts)
- [Phase 1 - Foundation](./phase-01-foundation.md)

## Dependencies

- Phase 1 complete (TaskModel for quick entry)
- KeyboardShortcuts package added to Package.swift

## Key Insights

- KeyboardShortcuts is battle-tested, Mac App Store approved
- Built-in conflict detection saves implementation time
- NSPanel needed for floating quick-entry window
- Menu bar icon provides fallback access

## Requirements

### Shortcuts to Implement

| Shortcut | Action | Notes |
|----------|--------|-------|
| CMD+Shift+N | Quick Entry Panel | Float above all apps |
| CMD+Shift+T | Main Window | Focus/show main window |
| CMD+Shift+E | Enhance Me Panel | AI enhancement (Phase 3) |
| CMD+Shift+, | Settings Panel | App configuration |
| CMD+Shift+M | Cycle AI Mode | Switch modes (Phase 3) |

### Functional
- <200ms shortcut-to-panel display
- Work from any application
- Conflict detection with user notification
- User-customizable in settings
- Menu bar icon with dropdown

### Non-Functional
- Sandbox compatible (App Store)
- No Carbon API deprecated warnings
- Graceful degradation if shortcut conflicts

## Architecture

```
TaskManager/Sources/TaskManager/
├── Shortcuts/
│   ├── ShortcutNames.swift      # Define shortcut identifiers
│   ├── ShortcutManager.swift    # Register/handle shortcuts
│   └── ShortcutSettings.swift   # User customization
├── Windows/
│   ├── QuickEntryPanel.swift    # NSPanel subclass
│   ├── QuickEntryView.swift     # SwiftUI content
│   └── WindowManager.swift      # Window state management
├── MenuBar/
│   └── MenuBarController.swift  # Status bar icon + menu
└── TaskManagerApp.swift         # Register shortcuts on launch
```

## Related Code Files

### Create
- `TaskManager/Sources/TaskManager/Shortcuts/ShortcutNames.swift`
- `TaskManager/Sources/TaskManager/Shortcuts/ShortcutManager.swift`
- `TaskManager/Sources/TaskManager/Shortcuts/ShortcutSettings.swift`
- `TaskManager/Sources/TaskManager/Windows/QuickEntryPanel.swift`
- `TaskManager/Sources/TaskManager/Windows/QuickEntryView.swift`
- `TaskManager/Sources/TaskManager/Windows/WindowManager.swift`
- `TaskManager/Sources/TaskManager/MenuBar/MenuBarController.swift`

### Modify
- `TaskManager/Package.swift` - Add KeyboardShortcuts dependency
- `TaskManager/Sources/TaskManager/TaskManagerApp.swift` - Initialize shortcuts

## Implementation Steps

### Step 1: Add KeyboardShortcuts Package (Day 1)

**Package.swift**
```swift
dependencies: [
    .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    // ... other dependencies
],
targets: [
    .executableTarget(
        name: "TaskManager",
        dependencies: [
            "TaskManagerUIComponents",
            "KeyboardShortcuts"
        ]
    )
]
```

### Step 2: Define Shortcut Names (Day 1)

**ShortcutNames.swift**
```swift
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let quickEntry = Self("quickEntry")
    static let mainWindow = Self("mainWindow")
    static let enhanceMe = Self("enhanceMe")
    static let settings = Self("settings")
    static let cycleAIMode = Self("cycleAIMode")
}
```

### Step 3: Shortcut Manager (Day 1-2)

**ShortcutManager.swift**
```swift
import KeyboardShortcuts
import AppKit

@MainActor
final class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager()
    
    private init() {
        registerDefaultShortcuts()
        setupHandlers()
    }
    
    private func registerDefaultShortcuts() {
        KeyboardShortcuts.setShortcut(.init(.n, modifiers: [.command, .shift]), for: .quickEntry)
        KeyboardShortcuts.setShortcut(.init(.t, modifiers: [.command, .shift]), for: .mainWindow)
        KeyboardShortcuts.setShortcut(.init(.e, modifiers: [.command, .shift]), for: .enhanceMe)
        KeyboardShortcuts.setShortcut(.init(.comma, modifiers: [.command, .shift]), for: .settings)
        KeyboardShortcuts.setShortcut(.init(.m, modifiers: [.command, .shift]), for: .cycleAIMode)
    }
    
    private func setupHandlers() {
        KeyboardShortcuts.onKeyUp(for: .quickEntry) { [weak self] in
            self?.showQuickEntry()
        }
        
        KeyboardShortcuts.onKeyUp(for: .mainWindow) { [weak self] in
            self?.showMainWindow()
        }
        
        KeyboardShortcuts.onKeyUp(for: .enhanceMe) { [weak self] in
            self?.showEnhanceMe()
        }
        
        KeyboardShortcuts.onKeyUp(for: .settings) { [weak self] in
            self?.showSettings()
        }
    }
    
    func showQuickEntry() {
        WindowManager.shared.showQuickEntry()
    }
    
    func showMainWindow() {
        WindowManager.shared.showMainWindow()
    }
    
    func showEnhanceMe() {
        // Phase 3 implementation
        WindowManager.shared.showEnhanceMe()
    }
    
    func showSettings() {
        WindowManager.shared.showSettings()
    }
}
```

### Step 4: Quick Entry Panel (Day 2-3)

**QuickEntryPanel.swift** (NSPanel for floating window)
```swift
import AppKit
import SwiftUI

final class QuickEntryPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        
        // Center on screen
        self.center()
    }
    
    func setContent(_ view: some View) {
        self.contentView = NSHostingView(rootView: view)
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
```

**QuickEntryView.swift**
```swift
import SwiftUI
import SwiftData

struct QuickEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var description = ""
    @State private var dueDate: Date?
    @State private var priority: TaskPriority = .medium
    @State private var tags: [String] = []
    @State private var showSuccess = false
    
    var onDismiss: () -> Void
    var onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Title field (auto-focused)
            TextField("Task title", text: $title)
                .textFieldStyle(.plain)
                .font(.title2)
                .focused($titleFocused)
            
            // Description (expandable)
            TextEditor(text: $description)
                .frame(minHeight: 60, maxHeight: 120)
                .scrollContentBackground(.hidden)
            
            HStack {
                // Due date picker
                DatePicker("Due", selection: Binding(
                    get: { dueDate ?? Date() },
                    set: { dueDate = $0 }
                ), displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                
                // Priority picker
                Picker("Priority", selection: $priority) {
                    ForEach(TaskPriority.allCases, id: \.self) { p in
                        Text(p.rawValue.capitalized)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            
            // Tag input
            TagInputField(tags: $tags)
            
            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Add Task") {
                    saveTask()
                }
                .keyboardShortcut(.return)
                .disabled(title.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { titleFocused = true }
    }
    
    @FocusState private var titleFocused: Bool
    
    private func saveTask() {
        let task = TaskModel(
            title: title,
            taskDescription: description,
            dueDate: dueDate,
            priority: priority,
            tags: tags
        )
        modelContext.insert(task)
        
        showSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onSave()
        }
    }
}
```

### Step 5: Window Manager (Day 3-4)

**WindowManager.swift**
```swift
import AppKit
import SwiftUI
import SwiftData

@MainActor
final class WindowManager: ObservableObject {
    static let shared = WindowManager()
    
    private var quickEntryPanel: QuickEntryPanel?
    private var modelContainer: ModelContainer?
    
    func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    func showQuickEntry() {
        if quickEntryPanel == nil {
            quickEntryPanel = QuickEntryPanel()
        }
        
        guard let panel = quickEntryPanel, let container = modelContainer else { return }
        
        let view = QuickEntryView(
            onDismiss: { [weak self] in self?.hideQuickEntry() },
            onSave: { [weak self] in self?.hideQuickEntry() }
        )
        .modelContainer(container)
        
        panel.setContent(view)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hideQuickEntry() {
        quickEntryPanel?.orderOut(nil)
    }
    
    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main-window" }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    func showEnhanceMe() {
        // Phase 3
    }
    
    func showSettings() {
        // Phase 4
    }
}
```

### Step 6: Menu Bar Controller (Day 4-5)

**MenuBarController.swift**
```swift
import AppKit
import SwiftUI

final class MenuBarController {
    private var statusItem: NSStatusItem?
    
    init() {
        setupMenuBar()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "TaskFlow Pro")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "New Task", action: #selector(newTask), keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "Show TaskFlow Pro", action: #selector(showMain), keyEquivalent: "t"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Enhance Me", action: #selector(enhanceMe), keyEquivalent: "e"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc private func newTask() {
        Task { @MainActor in
            ShortcutManager.shared.showQuickEntry()
        }
    }
    
    @objc private func showMain() {
        Task { @MainActor in
            ShortcutManager.shared.showMainWindow()
        }
    }
    
    @objc private func enhanceMe() {
        Task { @MainActor in
            ShortcutManager.shared.showEnhanceMe()
        }
    }
    
    @objc private func showSettings() {
        Task { @MainActor in
            ShortcutManager.shared.showSettings()
        }
    }
    
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
```

### Step 7: App Integration (Day 5)

**TaskManagerApp.swift** updates:
```swift
@main
struct TaskManagerApp: App {
    let container: ModelContainer
    @StateObject private var shortcutManager = ShortcutManager.shared
    private let menuBarController: MenuBarController
    
    init() {
        do {
            container = try ModelContainer.configured()
            WindowManager.shared.configure(modelContainer: container)
            seedDefaultAIModes(container: container)
        } catch {
            fatalError("Failed to configure SwiftData: \(error)")
        }
        
        menuBarController = MenuBarController()
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

## Todo List

- [ ] Add KeyboardShortcuts to Package.swift
- [ ] Create ShortcutNames.swift
- [ ] Create ShortcutManager.swift
- [ ] Create QuickEntryPanel.swift (NSPanel)
- [ ] Create QuickEntryView.swift (SwiftUI)
- [ ] Create WindowManager.swift
- [ ] Create MenuBarController.swift
- [ ] Integrate shortcuts in TaskManagerApp
- [ ] Test CMD+Shift+N from other apps
- [ ] Test <200ms response time
- [ ] Test conflict detection
- [ ] Add success animation to quick entry

## Success Criteria

- [ ] CMD+Shift+N opens quick entry in <200ms
- [ ] CMD+Shift+T focuses main window
- [ ] Quick entry creates real task in SwiftData
- [ ] Menu bar icon works as fallback
- [ ] Shortcuts work from any application
- [ ] Panel auto-dismisses after save

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Shortcut conflicts | High | Medium | KeyboardShortcuts conflict detection |
| NSPanel focus issues | Medium | Medium | Test with multiple desktops/fullscreen |
| Sandbox restrictions | Low | High | KeyboardShortcuts is App Store approved |

## Security Considerations

- No sensitive data in shortcut handling
- Panel doesn't expose any API keys

## Next Steps

→ Phase 3: AI Integration (Enhance Me shortcut placeholder ready)
