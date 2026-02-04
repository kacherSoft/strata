# Phase 4: Polish & Advanced Features

**Priority:** MEDIUM | **Status:** Pending | **Effort:** 1 week

## Overview

Complete settings panel, liquid glass UI refinement, always-on-top mode, notifications, and data export/import. Final polish for production readiness.

## Context Links

- [PRD - Settings & UI](../../docs/product-requirements-document.md)
- [Brainstorm - Tahoe Considerations](../reports/brainstorm-260204-0942-taskflow-pro-implementation.md)
- [Existing UI Components](../../TaskManagerUIComponents/)

## Dependencies

- Phase 1-3 complete
- AI configuration views from Phase 3

## Key Insights

- macOS 26 Tahoe "Liquid Glass" uses SwiftUI materials
- Always-on-top via NSWindow.level
- UserNotifications framework for reminders
- Codable export for task backup

## Requirements

### Settings Panel Tabs
1. **General:** Always on top, reduced motion, appearance
2. **AI Configuration:** Provider, API keys, test connection
3. **Shortcuts:** Visual editor with conflict detection
4. **AI Modes:** CRUD for custom modes

### Advanced Features
- Always-on-top window toggle
- macOS notifications for due tasks
- Interactive notification actions
- Data export (JSON)
- Data import (JSON)
- First-run onboarding wizard

## Architecture

```
TaskManager/Sources/TaskManager/
├── Views/
│   └── Settings/
│       ├── SettingsView.swift           # Main settings window
│       ├── GeneralSettingsView.swift    # General tab
│       ├── AIConfigurationView.swift    # AI config tab
│       ├── ShortcutsSettingsView.swift  # Shortcuts tab
│       └── AIModeManagerView.swift      # AI modes tab
├── Services/
│   ├── NotificationService.swift        # Task reminders
│   └── DataExportService.swift          # Import/export
├── Views/
│   └── Onboarding/
│       └── OnboardingView.swift         # First-run wizard
└── Extensions/
    └── NSWindow+AlwaysOnTop.swift
```

## Related Code Files

### Create
- `TaskManager/Sources/TaskManager/Views/Settings/SettingsView.swift`
- `TaskManager/Sources/TaskManager/Views/Settings/GeneralSettingsView.swift`
- `TaskManager/Sources/TaskManager/Views/Settings/ShortcutsSettingsView.swift`
- `TaskManager/Sources/TaskManager/Services/NotificationService.swift`
- `TaskManager/Sources/TaskManager/Services/DataExportService.swift`
- `TaskManager/Sources/TaskManager/Views/Onboarding/OnboardingView.swift`
- `TaskManager/Sources/TaskManager/Extensions/NSWindow+AlwaysOnTop.swift`

### Modify
- `TaskManager/Sources/TaskManager/Windows/WindowManager.swift` - Add settings window, always-on-top
- `TaskManager/Sources/TaskManager/TaskManagerApp.swift` - Add settings scene, onboarding check

## Implementation Steps

### Step 1: Settings View Structure (Day 1)

**SettingsView.swift**
```swift
import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @State private var selectedTab = SettingsTab.general
    
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case aiConfig = "AI Configuration"
        case shortcuts = "Shortcuts"
        case aiModes = "AI Modes"
        
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .aiConfig: return "brain"
            case .shortcuts: return "keyboard"
            case .aiModes: return "wand.and.stars"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
            }
            .listStyle(.sidebar)
            .frame(width: 180)
        } detail: {
            switch selectedTab {
            case .general:
                GeneralSettingsView()
            case .aiConfig:
                AIConfigurationView()
            case .shortcuts:
                ShortcutsSettingsView()
            case .aiModes:
                AIModeManagerView()
            }
        }
        .frame(width: 650, height: 450)
    }
}
```

### Step 2: General Settings (Day 1-2)

**GeneralSettingsView.swift**
```swift
import SwiftUI
import SwiftData

struct GeneralSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [SettingsModel]
    
    private var currentSettings: SettingsModel {
        settings.first ?? SettingsModel()
    }
    
    var body: some View {
        Form {
            Section("Window") {
                Toggle("Always on Top", isOn: Binding(
                    get: { currentSettings.alwaysOnTop },
                    set: { newValue in
                        currentSettings.alwaysOnTop = newValue
                        WindowManager.shared.setAlwaysOnTop(newValue)
                    }
                ))
                .help("Keep TaskFlow Pro above other windows")
            }
            
            Section("Appearance") {
                Toggle("Reduce Motion", isOn: Binding(
                    get: { currentSettings.reducedMotion },
                    set: { currentSettings.reducedMotion = $0 }
                ))
                .help("Reduce animations for accessibility")
            }
            
            Section("Data") {
                Button("Export Tasks...") {
                    exportTasks()
                }
                
                Button("Import Tasks...") {
                    importTasks()
                }
                
                Divider()
                
                Button("Delete All Tasks", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .confirmationDialog("Delete All Tasks?", isPresented: $showDeleteConfirmation) {
            Button("Delete All", role: .destructive) { deleteAllTasks() }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    @State private var showDeleteConfirmation = false
    
    private func exportTasks() {
        DataExportService.shared.exportTasks(context: modelContext)
    }
    
    private func importTasks() {
        DataExportService.shared.importTasks(context: modelContext)
    }
    
    private func deleteAllTasks() {
        try? modelContext.delete(model: TaskModel.self)
    }
}
```

### Step 3: Shortcuts Settings (Day 2)

**ShortcutsSettingsView.swift**
```swift
import SwiftUI
import KeyboardShortcuts

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section("Global Shortcuts") {
                KeyboardShortcuts.Recorder("Quick Entry (New Task):", name: .quickEntry)
                KeyboardShortcuts.Recorder("Show Main Window:", name: .mainWindow)
                KeyboardShortcuts.Recorder("Enhance Me:", name: .enhanceMe)
                KeyboardShortcuts.Recorder("Settings:", name: .settings)
                KeyboardShortcuts.Recorder("Cycle AI Mode:", name: .cycleAIMode)
            }
            
            Section {
                Button("Reset to Defaults") {
                    resetDefaults()
                }
            }
            
            Section {
                Text("Click a shortcut field, then press your desired key combination. Conflicts with system shortcuts or other apps will be detected automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func resetDefaults() {
        KeyboardShortcuts.setShortcut(.init(.n, modifiers: [.command, .shift]), for: .quickEntry)
        KeyboardShortcuts.setShortcut(.init(.t, modifiers: [.command, .shift]), for: .mainWindow)
        KeyboardShortcuts.setShortcut(.init(.e, modifiers: [.command, .shift]), for: .enhanceMe)
        KeyboardShortcuts.setShortcut(.init(.comma, modifiers: [.command, .shift]), for: .settings)
        KeyboardShortcuts.setShortcut(.init(.m, modifiers: [.command, .shift]), for: .cycleAIMode)
    }
}
```

### Step 4: Always-on-Top Implementation (Day 2)

**NSWindow+AlwaysOnTop.swift**
```swift
import AppKit

extension NSWindow {
    func setAlwaysOnTop(_ enabled: Bool) {
        self.level = enabled ? .floating : .normal
    }
}
```

**WindowManager.swift** addition:
```swift
func setAlwaysOnTop(_ enabled: Bool) {
    if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main-window" }) {
        window.setAlwaysOnTop(enabled)
    }
}
```

### Step 5: Notification Service (Day 3)

**NotificationService.swift**
```swift
import UserNotifications
import SwiftData

final class NotificationService {
    static let shared = NotificationService()
    
    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }
    
    func scheduleReminder(for task: TaskModel) {
        guard let dueDate = task.dueDate else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Task Due"
        content.body = task.title
        content.sound = .default
        content.categoryIdentifier = "TASK_REMINDER"
        
        // Add priority badge
        switch task.priority {
        case .critical: content.interruptionLevel = .critical
        case .high: content.interruptionLevel = .timeSensitive
        default: content.interruptionLevel = .active
        }
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: task.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelReminder(for task: TaskModel) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
    }
    
    func setupCategories() {
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE",
            title: "Mark Complete",
            options: []
        )
        
        let viewAction = UNNotificationAction(
            identifier: "VIEW",
            title: "View",
            options: [.foreground]
        )
        
        let category = UNNotificationCategory(
            identifier: "TASK_REMINDER",
            actions: [completeAction, viewAction],
            intentIdentifiers: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}
```

### Step 6: Data Export Service (Day 4)

**DataExportService.swift**
```swift
import Foundation
import SwiftData
import AppKit

final class DataExportService {
    static let shared = DataExportService()
    
    struct ExportData: Codable {
        let version: Int
        let exportDate: Date
        let tasks: [ExportTask]
    }
    
    struct ExportTask: Codable {
        let id: UUID
        let title: String
        let description: String
        let dueDate: Date?
        let priority: String
        let tags: [String]
        let isCompleted: Bool
        let createdAt: Date
    }
    
    @MainActor
    func exportTasks(context: ModelContext) {
        let descriptor = FetchDescriptor<TaskModel>()
        guard let tasks = try? context.fetch(descriptor) else { return }
        
        let exportTasks = tasks.map { task in
            ExportTask(
                id: task.id,
                title: task.title,
                description: task.taskDescription,
                dueDate: task.dueDate,
                priority: task.priority.rawValue,
                tags: task.tags,
                isCompleted: task.isCompleted,
                createdAt: task.createdAt
            )
        }
        
        let exportData = ExportData(
            version: 1,
            exportDate: Date(),
            tasks: exportTasks
        )
        
        guard let jsonData = try? JSONEncoder().encode(exportData) else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "taskflow-export-\(Date().formatted(.dateTime.year().month().day())).json"
        
        if panel.runModal() == .OK, let url = panel.url {
            try? jsonData.write(to: url)
        }
    }
    
    @MainActor
    func importTasks(context: ModelContext) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            guard let data = try? Data(contentsOf: url),
                  let exportData = try? JSONDecoder().decode(ExportData.self, from: data) else {
                return
            }
            
            for exportTask in exportData.tasks {
                let task = TaskModel(
                    title: exportTask.title,
                    taskDescription: exportTask.description,
                    dueDate: exportTask.dueDate,
                    priority: TaskPriority(rawValue: exportTask.priority) ?? .medium,
                    tags: exportTask.tags
                )
                task.isCompleted = exportTask.isCompleted
                task.createdAt = exportTask.createdAt
                context.insert(task)
            }
            
            try? context.save()
        }
    }
}
```

### Step 7: Onboarding Wizard (Day 5)

**OnboardingView.swift**
```swift
import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentStep) {
                // Step 1: Welcome
                OnboardingStep(
                    icon: "checkmark.circle.fill",
                    title: "Welcome to TaskFlow Pro",
                    description: "The fast, AI-powered task manager for macOS."
                )
                .tag(0)
                
                // Step 2: AI Setup
                OnboardingStep(
                    icon: "brain",
                    title: "AI Enhancement",
                    description: "Add your Gemini or z.ai API key in Settings to unlock AI-powered task enhancement.",
                    showSkipNote: true
                )
                .tag(1)
                
                // Step 3: Shortcuts
                OnboardingStep(
                    icon: "keyboard",
                    title: "Global Shortcuts",
                    description: "Press ⌘⇧N from anywhere to quickly add a task.\nPress ⌘⇧T to show the main window."
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // Navigation dots
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(currentStep == index ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding()
            
            // Buttons
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation { currentStep -= 1 }
                    }
                }
                
                Spacer()
                
                Button(currentStep < 2 ? "Next" : "Get Started") {
                    if currentStep < 2 {
                        withAnimation { currentStep += 1 }
                    } else {
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .background(.ultraThickMaterial)
    }
}

struct OnboardingStep: View {
    let icon: String
    let title: String
    let description: String
    var showSkipNote: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text(title)
                .font(.title)
                .bold()
            
            Text(description)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            if showSkipNote {
                Text("(You can skip this and add later)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(40)
    }
}
```

### Step 8: Liquid Glass UI Polish (Day 5-6)

Apply consistent materials across all views:
```swift
// Main window
.background(.regularMaterial)

// Panels/sheets
.background(.ultraThickMaterial)

// Headers
.background(.thinMaterial)

// Selected rows
.background(.ultraThinMaterial)

// Buttons/tags
.background(.ultraThinMaterial)
```

Add micro-interactions:
```swift
// Task completion
.transition(.asymmetric(
    insertion: .scale.combined(with: .opacity),
    removal: .move(edge: .trailing).combined(with: .opacity)
))

// Panel appearance
.transition(.move(edge: .top).combined(with: .opacity))
```

### Step 9: App Integration (Day 6)

**TaskManagerApp.swift** additions:
```swift
@main
struct TaskManagerApp: App {
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    
    var body: some Scene {
        WindowGroup("Task Manager", id: "main-window") {
            ContentView()
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView()
                }
        }
        .modelContainer(container)
        .windowStyle(.hiddenTitleBar)
        
        Settings {
            SettingsView()
                .modelContainer(container)
        }
    }
}
```

## Todo List

- [ ] Create SettingsView with tab navigation
- [ ] Create GeneralSettingsView
- [ ] Complete AIConfigurationView (from Phase 3)
- [ ] Create ShortcutsSettingsView with KeyboardShortcuts.Recorder
- [ ] Complete AIModeManagerView (from Phase 3)
- [ ] Implement always-on-top toggle
- [ ] Create NotificationService
- [ ] Register notification categories with actions
- [ ] Create DataExportService
- [ ] Implement JSON export
- [ ] Implement JSON import
- [ ] Create OnboardingView wizard
- [ ] Apply liquid glass materials consistently
- [ ] Add micro-interactions and animations
- [ ] Wire Settings scene in TaskManagerApp
- [ ] Test onboarding flow
- [ ] Test notification scheduling and actions
- [ ] Test export/import round-trip

## Success Criteria

- [ ] All 4 settings tabs functional
- [ ] Shortcuts customizable with conflict detection
- [ ] Always-on-top works correctly
- [ ] Notifications fire at due time
- [ ] Export creates valid JSON
- [ ] Import restores all task data
- [ ] Onboarding shows on first launch only
- [ ] Liquid glass effects consistent across app

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Notification permission denied | Medium | Low | Graceful degradation, show in-app reminders |
| Always-on-top fullscreen conflicts | Medium | Low | Test with various fullscreen apps |
| Import data corruption | Low | Medium | Validate JSON schema, version field |

## Security Considerations

- Export does NOT include API keys
- Import validates data before inserting

## Next Steps

→ Phase 5: Testing & Launch
