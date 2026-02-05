# Phase 2: Global Shortcuts, Quick Entry & Settings

**Priority:** HIGH | **Status:** Pending | **Effort:** 1 week

## Overview

Implement global keyboard shortcuts using KeyboardShortcuts package, create quick-entry floating panel for instant task capture, and build Settings window with shortcut customization.

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
│   ├── SettingsWindow.swift     # Settings NSWindow
│   └── WindowManager.swift      # Window state management
├── Views/
│   ├── Settings/
│   │   ├── SettingsView.swift           # Main settings container
│   │   ├── GeneralSettingsView.swift    # General tab content
│   │   ├── ShortcutsSettingsView.swift  # Shortcuts tab content
│   │   ├── AIConfigSettingsView.swift   # AI config (placeholder)
│   │   └── AIModesSettingsView.swift    # AI modes (placeholder)
│   └── Components/
│       └── SettingsSidebar.swift        # Sidebar navigation
├── MenuBar/
│   └── MenuBarController.swift  # Status bar icon + menu
└── TaskManagerApp.swift         # Register shortcuts on launch
```

## Settings Window Design

### Layout (Sidebar Navigation - macOS 26 Style)

```
┌─────────────────────────────────────────────────────────────┐
│  Settings                                              ─ □ x│
├─────────────┬───────────────────────────────────────────────┤
│             │                                               │
│  ○ General  │   General Settings                           │
│             │   ─────────────────────────────────────────   │
│  ○ Shortcuts│   ☑ Always on Top                            │
│             │     Keep window above other applications      │
│  ○ AI Config│                                               │
│             │   ☑ Show Completed Tasks                      │
│  ○ AI Modes │     Display completed tasks in list           │
│             │                                               │
│             │   ☐ Reduced Motion                            │
│             │     Minimize animations                       │
│             │                                               │
│             │   Default Priority                            │
│             │   ┌──────────────────────────────────────┐   │
│             │   │ Medium                            ▾  │   │
│             │   └──────────────────────────────────────┘   │
│             │                                               │
└─────────────┴───────────────────────────────────────────────┘
```

### Tabs Content

| Tab | Phase 2 Status | Content |
|-----|----------------|---------|
| General | ✅ Full | Always on Top, Show Completed, Reduced Motion, Default Priority |
| Shortcuts | ✅ Full | KeyboardShortcuts.Recorder for each shortcut, Reset buttons |
| AI Config | 🔜 Placeholder | "Coming in Phase 3" message |
| AI Modes | 🔜 Placeholder | "Coming in Phase 3" message |

### Window Specifications

- **Size:** 650 × 480 (fixed, non-resizable)
- **Style:** `.ultraThinMaterial` background (liquid glass)
- **Sidebar:** 180px width, icons + labels
- **Content:** Remaining width with 24px padding

## Related Code Files

### Create
- `TaskManager/Sources/TaskManager/Shortcuts/ShortcutNames.swift`
- `TaskManager/Sources/TaskManager/Shortcuts/ShortcutManager.swift`
- `TaskManager/Sources/TaskManager/Windows/QuickEntryPanel.swift`
- `TaskManager/Sources/TaskManager/Windows/QuickEntryView.swift`
- `TaskManager/Sources/TaskManager/Windows/SettingsWindow.swift`
- `TaskManager/Sources/TaskManager/Windows/WindowManager.swift`
- `TaskManager/Sources/TaskManager/Views/Settings/SettingsView.swift`
- `TaskManager/Sources/TaskManager/Views/Settings/GeneralSettingsView.swift`
- `TaskManager/Sources/TaskManager/Views/Settings/ShortcutsSettingsView.swift`
- `TaskManager/Sources/TaskManager/Views/Settings/AIConfigSettingsView.swift`
- `TaskManager/Sources/TaskManager/Views/Settings/AIModesSettingsView.swift`
- `TaskManager/Sources/TaskManager/MenuBar/MenuBarController.swift`

### Modify
- `TaskManager/Package.swift` - Add KeyboardShortcuts dependency
- `TaskManager/Sources/TaskManager/TaskManagerApp.swift` - Initialize shortcuts
- `TaskManager/Sources/TaskManager/Data/Models/SettingsModel.swift` - Add shortcut storage fields if needed

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

### Step 7: Settings Window & Views (Day 5-6)

**SettingsWindow.swift**
```swift
import AppKit
import SwiftUI
import SwiftData

final class SettingsWindow: NSWindow {
    init(modelContainer: ModelContainer) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "Settings"
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.center()
        
        let settingsView = SettingsView()
            .modelContainer(modelContainer)
        
        self.contentView = NSHostingView(rootView: settingsView)
    }
}
```

**SettingsView.swift**
```swift
import SwiftUI
import KeyboardShortcuts

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case shortcuts = "Shortcuts"
    case aiConfig = "AI Config"
    case aiModes = "AI Modes"
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .shortcuts: return "keyboard"
        case .aiConfig: return "cpu"
        case .aiModes: return "sparkles"
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    
    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
            }
            .listStyle(.sidebar)
            .frame(width: 180)
        } detail: {
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .shortcuts:
                    ShortcutsSettingsView()
                case .aiConfig:
                    AIConfigSettingsView()
                case .aiModes:
                    AIModesSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
        }
        .frame(width: 650, height: 480)
    }
}
```

**GeneralSettingsView.swift**
```swift
import SwiftUI
import SwiftData

struct GeneralSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [SettingsModel]
    
    private var currentSettings: SettingsModel? { settings.first }
    
    var body: some View {
        Form {
            Section {
                Toggle("Always on Top", isOn: Binding(
                    get: { currentSettings?.alwaysOnTop ?? false },
                    set: { newValue in
                        currentSettings?.alwaysOnTop = newValue
                        currentSettings?.touch()
                    }
                ))
                Text("Keep window above other applications")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section {
                Toggle("Show Completed Tasks", isOn: Binding(
                    get: { currentSettings?.showCompletedTasks ?? true },
                    set: { newValue in
                        currentSettings?.showCompletedTasks = newValue
                        currentSettings?.touch()
                    }
                ))
                Text("Display completed tasks in the list")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section {
                Toggle("Reduced Motion", isOn: Binding(
                    get: { currentSettings?.reducedMotion ?? false },
                    set: { newValue in
                        currentSettings?.reducedMotion = newValue
                        currentSettings?.touch()
                    }
                ))
                Text("Minimize animations throughout the app")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section {
                Picker("Default Priority", selection: Binding(
                    get: { currentSettings?.defaultPriority ?? .medium },
                    set: { newValue in
                        currentSettings?.defaultPriority = newValue
                        currentSettings?.touch()
                    }
                )) {
                    ForEach(TaskPriority.allCases, id: \.self) { priority in
                        Text(priority.rawValue.capitalized)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .padding()
    }
}
```

**ShortcutsSettingsView.swift**
```swift
import SwiftUI
import KeyboardShortcuts

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section("Task Shortcuts") {
                ShortcutRow(
                    name: .quickEntry,
                    title: "Quick Entry",
                    description: "Open quick task entry panel"
                )
                
                ShortcutRow(
                    name: .mainWindow,
                    title: "Show Main Window",
                    description: "Focus the main task list"
                )
            }
            
            Section("AI Shortcuts") {
                ShortcutRow(
                    name: .enhanceMe,
                    title: "Enhance Me",
                    description: "Open AI enhancement panel"
                )
                
                ShortcutRow(
                    name: .cycleAIMode,
                    title: "Cycle AI Mode",
                    description: "Switch between AI modes"
                )
            }
            
            Section("App Shortcuts") {
                ShortcutRow(
                    name: .settings,
                    title: "Settings",
                    description: "Open settings window"
                )
            }
            
            Section {
                Button("Reset All to Defaults") {
                    resetAllShortcuts()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Shortcuts")
        .padding()
    }
    
    private func resetAllShortcuts() {
        KeyboardShortcuts.reset(.quickEntry, .mainWindow, .enhanceMe, .settings, .cycleAIMode)
        // Re-register defaults
        KeyboardShortcuts.setShortcut(.init(.n, modifiers: [.command, .shift]), for: .quickEntry)
        KeyboardShortcuts.setShortcut(.init(.t, modifiers: [.command, .shift]), for: .mainWindow)
        KeyboardShortcuts.setShortcut(.init(.e, modifiers: [.command, .shift]), for: .enhanceMe)
        KeyboardShortcuts.setShortcut(.init(.comma, modifiers: [.command, .shift]), for: .settings)
        KeyboardShortcuts.setShortcut(.init(.m, modifiers: [.command, .shift]), for: .cycleAIMode)
    }
}

struct ShortcutRow: View {
    let name: KeyboardShortcuts.Name
    let title: String
    let description: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            KeyboardShortcuts.Recorder(for: name)
                .frame(width: 150)
        }
        .padding(.vertical, 4)
    }
}
```

**AIConfigSettingsView.swift** (Placeholder)
```swift
import SwiftUI

struct AIConfigSettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("AI Configuration")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Coming in Phase 3")
                .foregroundStyle(.secondary)
            
            Text("Configure AI providers, API keys, and model settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
```

**AIModesSettingsView.swift** (Placeholder)
```swift
import SwiftUI

struct AIModesSettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("AI Modes")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Coming in Phase 3")
                .foregroundStyle(.secondary)
            
            Text("Create custom AI enhancement modes with your own prompts.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
```

### Step 8: App Integration (Day 6-7)

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

**WindowManager.swift** - Add settings window support:
```swift
func showSettings() {
    if settingsWindow == nil {
        guard let container = modelContainer else { return }
        settingsWindow = SettingsWindow(modelContainer: container)
    }
    
    settingsWindow?.center()
    settingsWindow?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
}
```

## Todo List

### Shortcuts & Quick Entry
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

### Settings Window
- [ ] Create SettingsWindow.swift (NSWindow)
- [ ] Create SettingsView.swift (main container with sidebar)
- [ ] Create GeneralSettingsView.swift (toggles + picker)
- [ ] Create ShortcutsSettingsView.swift (KeyboardShortcuts.Recorder)
- [ ] Create AIConfigSettingsView.swift (placeholder)
- [ ] Create AIModesSettingsView.swift (placeholder)
- [ ] Add showSettings() to WindowManager
- [ ] Test CMD+Shift+, opens settings
- [ ] Test shortcut customization works
- [ ] Test Reset All to Defaults

## Success Criteria

- [ ] CMD+Shift+N opens quick entry in <200ms
- [ ] CMD+Shift+T focuses main window
- [ ] CMD+Shift+, opens settings window
- [ ] Quick entry creates real task in SwiftData
- [ ] Menu bar icon works as fallback
- [ ] Shortcuts work from any application
- [ ] Panel auto-dismisses after save
- [ ] Settings window displays with liquid glass style
- [ ] Shortcut recorder allows customization
- [ ] Settings persist between app launches

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
