# Phase 3: Chat as Primary Window

**Priority:** Critical | **Effort:** Medium | **Status:** Pending
**Depends on:** Phase 1 (AI Provider Data Model)

---

## Context Links
- [Plan Overview](plan.md) | [Phase 1](phase-01-ai-provider-data-model.md)
- Current entry: `TaskManagerApp.swift` (852 LOC) — `Window("Task Manager")`
- Chat: `Views/Chat/ChatView.swift`, `Windows/ChatPanel.swift`
- Window mgr: `Windows/WindowManager.swift`
- Shortcuts: `Shortcuts/ShortcutManager.swift`

---

## Overview

Make Chat the app's primary interface shown on launch. Task view becomes a secondary window accessible via menu/shortcut. ChatView moves from NSPanel to the main app Window scene. TaskPanel replaces ChatPanel.

---

## Key Insights

- Currently: `TaskManagerApp` has `Window("Task Manager")` → `ContentView` (NavigationSplitView with task sidebar)
- ChatPanel is an `NSPanel` (floating, non-activating possible) — wrong for a primary window
- NSWindow (main window) supports standard window chrome, fullscreen, toolbar
- ContentView at ~650 LOC in TaskManagerApp.swift — needs extraction to own file
- `WindowManager.showChat()` creates ChatPanel lazily — needs to become `showTasks()` instead

---

## Requirements

### Functional
- App launches showing Chat UI (full window, not panel)
- Task view accessible via: menu bar item, Cmd+Shift+T shortcut, sidebar button
- Chat window supports: fullscreen, standard window controls, toolbar
- App title: "Strata" (not "Task Manager")
- Menu bar controller updated: "Show Tasks" instead of "Show TaskFlow Pro"
- Dock icon click re-shows Chat window (standard macOS behavior)

### Non-Functional
- No data loss — task data untouched
- Existing keyboard shortcuts still work
- EnhanceMe panel behavior unchanged (still floats)

---

## Architecture

### Window Hierarchy (Before → After)

```
BEFORE:
  Main Window (NSWindow) → ContentView (Tasks)
  ChatPanel (NSPanel)    → ChatView
  EnhanceMePanel         → EnhanceMeView
  QuickEntryPanel        → QuickEntryView
  SettingsWindow         → SettingsView

AFTER:
  Main Window (NSWindow) → ChatView (primary)
  TaskPanel (NSPanel)    → ContentView (Tasks, secondary)
  EnhanceMePanel         → EnhanceMeView (unchanged)
  QuickEntryPanel        → QuickEntryView (unchanged)
  SettingsWindow         → SettingsView (unchanged)
```

### TaskManagerApp Changes

```swift
// Before:
Window("Task Manager", id: "main") {
    ContentView()
}

// After:
Window("Strata", id: "main") {
    ChatView(onDismiss: {})  // No dismiss needed — it's the main window
}
```

### WindowManager Changes

```swift
// Remove: showChat(), hideChat(), chatPanel
// Add: showTasks(), hideTasks(), taskPanel (NSPanel)

func showTasks() {
    // Create TaskPanel (NSPanel) with ContentView
    // Similar pattern to current showChat()
}
```

### ShortcutManager Changes

```
Cmd+Shift+T → showTasks() (was: show main window)
Cmd+Shift+C → (removed — Chat IS the main window)
Cmd+Option+J → (removed — Chat IS the main window)
```

---

## Related Code Files

### Create
- `Windows/TaskPanel.swift` — NSPanel for task view (~30 LOC)
- `Views/ContentView.swift` — Extract from TaskManagerApp.swift (~400 LOC)

### Modify
- `TaskManagerApp.swift` — Main scene → ChatView, extract ContentView
- `Windows/WindowManager.swift` — Replace showChat with showTasks
- `Windows/ChatPanel.swift` — Delete (no longer needed)
- `Views/Chat/ChatView.swift` — Remove onDismiss for main window mode
- `Shortcuts/ShortcutManager.swift` — Update shortcut targets
- `Shortcuts/ShortcutNames.swift` — Rename/add task shortcut
- `Views/Chat/ChatSessionListView.swift` — Add "Tasks" button to sidebar footer
- `Windows/EnhanceMeView.swift` — Remove Chat mode skip logic (Chat is always available)
- `MenuBarController.swift` — Update menu items

### Delete
- `Windows/ChatPanel.swift` — Replaced by main window

---

## Implementation Steps

1. Extract `ContentView` from `TaskManagerApp.swift` → `Views/ContentView.swift`
2. Create `TaskPanel.swift` (NSPanel subclass, 900×700 default)
3. Update `TaskManagerApp.swift`: main Window scene → `ChatView`
4. Update `WindowManager`:
   - Remove `chatPanel`, `showChat()`, `hideChat()`
   - Add `taskPanel`, `showTasks()`, `hideTasks()`
5. Update `ChatView`: make `onDismiss` optional (nil when main window)
6. Update `ShortcutManager`: Cmd+Shift+T → `showTasks()`
7. Update `MenuBarController`: "Show Tasks" menu item
8. Update `EnhanceMeView`: remove Chat mode skip `onChange` handler
9. Add "Tasks" access button in Chat sidebar footer
10. Update app window title to "Strata"
11. Build and verify launch behavior

---

## Todo List

- [ ] Extract ContentView from TaskManagerApp.swift
- [ ] Create TaskPanel.swift
- [ ] Update TaskManagerApp main scene to ChatView
- [ ] Refactor WindowManager (showTasks replaces showChat)
- [ ] Update ChatView for main window mode
- [ ] Update ShortcutManager shortcuts
- [ ] Update MenuBarController
- [ ] Remove Chat mode skip from EnhanceMeView
- [ ] Add Tasks button to Chat sidebar
- [ ] Build verification

---

## Success Criteria

- [ ] App launches showing Chat UI
- [ ] Chat window is standard NSWindow (fullscreen capable)
- [ ] Cmd+Shift+T opens Task view as floating panel
- [ ] Menu bar "Show Tasks" works
- [ ] EnhanceMe still works via Cmd+Shift+E
- [ ] Quick Entry still works via Cmd+Shift+N
- [ ] Dock icon click shows Chat window
- [ ] App title shows "Strata" in menu bar

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Chat window lifecycle differs from NSPanel | Medium | Test window close/reopen, minimize, fullscreen |
| Task view as panel may lose some features | Medium | Test drag-drop, context menus, keyboard nav |
| Users expect task view on launch | Low | First-launch tooltip or setting to choose default |
