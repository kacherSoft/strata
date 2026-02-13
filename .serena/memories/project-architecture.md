# TaskManager Architecture

## Structure
- **TaskManager/** - Main app target (SwiftData, ViewModels, Services)
- **TaskManagerUIComponents/** - Reusable UI components package (SwiftUI views, models)

## Key Data Flow
- `TaskModel` (SwiftData `@Model`) → `toTaskItem()` → `TaskItem` (UI-facing struct)
- `ContentView` wires `SidebarView` ↔ `DetailPanelView` via bindings
- Callbacks flow: `ContentView` → `DetailPanelView` → `TaskListView` → `TaskRow`

## Callback Signature (onEdit)
`(TaskItem, String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL]) -> Void`
= (task, title, notes, dueDate, hasReminder, reminderDuration, priority, tags, photos)

## Key Files
- Models: `TaskModel.swift`, `TaskItem.swift`, `SidebarItem.swift`, `SettingsModel.swift`
- Views: `SidebarView.swift`, `DetailPanelView.swift`, `TaskRow.swift`, `HeaderView.swift`
- Forms: `TaskFormContent.swift`, `NewTaskSheet.swift`, `EditTaskSheet.swift`, `QuickEntryContent.swift`
- Services: `NotificationService.swift`, `PhotoStorageService.swift`
- App: `TaskManagerApp.swift` (contains `ContentView`)

## Features Added (Feb 2026)
- **Reminder timer**: Duration picker (max 24h), action button on TaskRow, configurable sound in settings
- **Priority filter**: Sidebar section below Tags
- **Search fix**: EmptyStateView no longer covers the search bar
