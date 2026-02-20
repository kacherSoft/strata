# Code Review: TaskManager Views & Windows

**Review Date:** 2026-02-20
**Scope:** Views, Windows, MenuBar, Shortcuts, Extensions
**Files Reviewed:** 24 files
**Total LOC:** ~2,100 lines (excluding EnhanceMeView)
**Focus:** SwiftUI best practices, window lifecycle, state management, modularity

---

## Executive Summary

The TaskManager codebase demonstrates solid SwiftUI fundamentals with generally well-structured views and window management. However, there are several critical areas requiring attention:

1. **EnhanceMeView.swift is 921 lines** - severe violation of the 200-line guideline, needs modularization
2. **Memory leaks potential** in window/panel lifecycle management
3. **State management inconsistencies** across settings views
4. **Missing error handling** in several areas
5. **Code duplication** in settings row components

**Overall Quality Score:** 6.5/10

---

## Critical Issues

### 1. EnhanceMeView.swift - File Size Violation (921 lines)

**File:** `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Windows/EnhanceMeView.swift`

This single file contains:
- `EnhanceMeView` struct (main view - ~450 lines)
- `AttachmentPill` view
- `EnhanceMeShortcutHandler` NSViewRepresentable
- `EnhanceMeShortcutNSView` class
- `EnhanceDragClipView` class
- `EnhanceNSTextView` class (~200 lines)
- `EnhanceTextEditor` NSViewRepresentable (~120 lines)

**Impact:** Unmaintainable, difficult to test, poor separation of concerns

**Recommendation:** Split into:
- `EnhanceMeView.swift` - Main view only (~200 lines)
- `EnhanceMeComponents/AttachmentPill.swift`
- `EnhanceMeComponents/EnhanceTextEditor.swift`
- `EnhanceMeComponents/EnhanceNSTextView.swift`
- `EnhanceMeComponents/EnhanceMeShortcutHandler.swift`

---

### 2. Timer Memory Leak in EnhanceMeView

**File:** `EnhanceMeView.swift:22`
```swift
@State private var typewriterTimer: Timer?
```

**Issue:** Timer not invalidated in `onDisappear` before reassignment in `startTypewriterAnimation`

**Location:** Lines 390-413

```swift
private func startTypewriterAnimation(for text: String) {
    typewriterTimer?.invalidate()
    typewriterTimer = nil  // Good - invalidation exists
    displayedText = ""

    Task { @MainActor in
        // ...but this Task continues running after view disappears
    }
}
```

**Problem:** The `Task` in `startTypewriterAnimation` continues after `onDisappear`. While not a traditional leak, it wastes resources.

**Fix:** Add cancellation token:
```swift
@State private var animationTask: Task<Void, Never>?

private func startTypewriterAnimation(for text: String) {
    animationTask?.cancel()
    animationTask = Task { @MainActor in
        // ...animation code with Task.checkCancellation()
    }
}
```

---

### 3. NSPanel Memory Retention in WindowManager

**File:** `WindowManager.swift:10-12`

```swift
private var quickEntryPanel: QuickEntryPanel?
private var settingsWindow: SettingsWindow?
private var enhanceMePanel: EnhanceMePanel?
```

**Issue:** Panels are retained indefinitely once created. If panels are closed via window close button (not via `hide*` methods), they remain in memory.

**Potential Fix:** Use `NSWindow.delegate` to detect close and nil the reference:
```swift
extension WindowManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? QuickEntryPanel {
            if quickEntryPanel === window { quickEntryPanel = nil }
        }
        // ...similar for others
    }
}
```

---

## High Priority Issues

### 4. Silent Error Swallowing in WindowManager

**File:** `WindowManager.swift:201-205`

```swift
do {
    try context.save()
} catch {
    return  // Silent failure - user gets no feedback
}
```

**Impact:** Task creation appears successful but data may not persist

**Fix:** Add error handling:
```swift
do {
    try context.save()
} catch {
    // Post notification or call error handler
    NotificationCenter.default.post(name: .taskCreationFailed, object: error)
}
```

---

### 5. Missing `@MainActor` on SettingsToggleRow

**File:** `GeneralSettingsView.swift:345-373`

```swift
struct SettingsToggleRow: View {  // Missing @MainActor
    let title: String
    let description: String
    let icon: String
    @Binding var isOn: Bool
    // ...
}
```

**Issue:** Bindings that modify model objects should be on MainActor

---

### 6. Duplicated Settings Row Pattern

**Files:** `GeneralSettingsView.swift`, `CustomFieldsSettingsView.swift`, `ShortcutsSettingsView.swift`

Same pattern repeated 10+ times:
```swift
HStack {
    Image(systemName: icon)
        .foregroundStyle(.secondary)
        .frame(width: 24)
    VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.body)
        Text(description).font(.caption).foregroundStyle(.secondary)
    }
    Spacer()
    // ...control
}
```

**Recommendation:** Extract to shared component in TaskManagerUIComponents:
```swift
struct SettingsRow<Control: View>: View {
    let icon: String
    let title: String
    let description: String
    @ViewBuilder let control: () -> Control
}
```

---

### 7. DispatchQueue Usage in SwiftUI Views

**File:** `EnhanceMeView.swift:424-428`

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
    withAnimation {
        showCopiedIndicator = false
    }
}
```

**Issue:** `DispatchQueue.main.asyncAfter` can cause issues if view is dismissed before callback fires

**Better approach:**
```swift
Task { @MainActor in
    try? await Task.sleep(nanoseconds: 2_000_000_000)
    showCopiedIndicator = false
}
```

Same issue at lines 444-450 (toast dismissal)

---

### 8. Unsafe Array Subscript in OnboardingView

**File:** `OnboardingView.swift:75`

```swift
if let backgroundView = pages[safe: currentStep]?.backgroundView {
```

Good - uses safe subscript extension. However, the extension is marked `private` and duplicated in the same file.

**Issue:** The safe subscript extension (lines 179-182) should be in a shared extensions file, not duplicated per-view.

---

### 9. Missing Error Handling in CustomFieldsSettingsView

**File:** `CustomFieldsSettingsView.swift:157`

```swift
try? modelContext.save()  // Silent failure
```

Same at line 170

**Impact:** Field creation/deletion may silently fail

---

## Medium Priority Issues

### 10. Hardcoded Product IDs in PremiumUpsellView

**File:** `PremiumUpsellView.swift:51-55`

```swift
let subscriptionProducts = subscriptionService.products.filter {
    ["taskmanager_monthly", "taskmanager_yearly"].contains($0.id)
}
let vipProduct = subscriptionService.products.first {
    $0.id == "taskmanager_vip_purchase"
}
```

**Recommendation:** Move to constants or SubscriptionService

---

### 11. Duplicate onAppear Logic in ModeEditorSheet

**File:** `AIModesSettingsView.swift:293-305`

The `onAppear` duplicates initialization logic that's already in the `init` (lines 195-209).

```swift
.onAppear {
    if let mode {
        name = mode.name  // Already set in init
        // ...
    }
}
```

**Recommendation:** Remove the `onAppear` block entirely - init handles setup

---

### 12. Non-Weak Self in Captures

**File:** `WindowManager.swift:81-96`

```swift
onCreate: { [weak self] title, notes, ... in
    self?.createTask(...)  // Good - uses weak self
    self?.hideQuickEntry()  // Good
```

**Positive:** Correct capture semantics. However, verify in other closures.

**Issue found in EnhanceMeView.swift:159-177:**
```swift
onPasteAttachment: { attachment in  // Missing [weak self]
    // Uses errorMessage directly - should use self?.errorMessage
}
```

---

### 13. NSViewRepresentable Coordinator Retention

**File:** `EnhanceMeView.swift:893-920`

```swift
class Coordinator: NSObject, NSTextViewDelegate {
    @Binding var text: String
    var onSubmit: () -> Void
    weak var textView: NSTextView?  // Good - weak reference
    var hasFocused = false
    // ...
}
```

**Positive:** Uses weak reference for textView. Pattern is correct.

---

### 14. Missing Accessibility in Some Views

**File:** `KanbanBoardView.swift`, `KanbanCardView.swift`, `KanbanColumnView.swift`

No accessibility modifiers found. Should add:
```swift
.accessibilityLabel("Task: \(task.title)")
.accessibilityHint("Double tap to view details")
```

---

### 15. Constants Scattered Throughout Codebase

**Examples:**
- `EnhanceMeView.swift:398`: `let batchSize = 5`
- `EnhanceMeView.swift:407`: `8_000_000` (8ms in nanoseconds)
- `QuickEntryPanel.swift:7`: `width: 520, height: 650`
- `SettingsWindow.swift:8`: `width: 650, height: 480`

**Recommendation:** Create `AppConstants.swift` with organized constants

---

## Low Priority Issues

### 16. Preview Code in Production Files

**File:** `OnboardingView.swift:185-187`
**File:** `PremiumUpsellView.swift:140-146`

```swift
#Preview {
    OnboardingView()
}
```

**Recommendation:** These are fine for SwiftUI but ensure they're stripped in release builds (they typically are)

---

### 17. Inconsistent Button Styles

**File:** `ShortcutsSettingsView.swift:88-94`

```swift
Button("Reset All to Defaults") {
    ShortcutManager.resetAllToDefaults()
}
.foregroundStyle(.red)
```

**vs.** `SettingsView.swift:87`

```swift
.buttonStyle(.plain)
```

**Recommendation:** Standardize destructive action styling

---

### 18. Missing Localized Strings

All UI strings are hardcoded in English:
- "To Do", "In Progress", "Done" in `KanbanBoardView.swift`
- "Welcome to TaskFlow Pro" in `OnboardingView.swift`
- All settings labels

**Recommendation:** Use `LocalizedStringKey` for internationalization support

---

## View Architecture Assessment

### Positive Patterns

1. **Clean separation of NSPanel subclasses** - QuickEntryPanel, EnhanceMePanel, SettingsWindow are well-structured
2. **Proper use of @Query** for SwiftData in views
3. **EnvironmentObject usage** for SubscriptionService is consistent
4. **withAppEnvironment modifier** provides clean DI pattern
5. **WindowActivator** pattern for window activation is clever and reusable
6. **KeyEventMonitorNSView** provides clean keyboard handling abstraction

### Areas for Improvement

1. **Missing ViewModel layer** - Views directly access SwiftData and services
2. **No proper error state management** - Scattered @State for error messages
3. **Inconsistent state ownership** - Some state in views, some in singletons

---

## Window Management Patterns

### Current Pattern
```
WindowManager (singleton)
    -> Creates/owns NSPanel instances
    -> Manages visibility
    -> Delegates to ShortcutManager

ShortcutManager (singleton)
    -> Handles keyboard events
    -> Calls WindowManager methods
```

### Issues
1. **Tight coupling** between WindowManager and view content
2. **No window state persistence** - positions reset on hide
3. **Race conditions possible** when rapidly toggling windows

### Recommended Pattern
```
WindowController protocol
    -> each window has its own controller
    -> controllers manage lifecycle
    -> WindowManager coordinates
```

---

## Keyboard Shortcut Implementation

### Current Implementation
- Global shortcuts via KeyboardShortcuts library
- Local shortcuts via NSEvent.addLocalMonitorForEvents
- Tab handling via custom KeyEventMonitorNSView

### Assessment
- **Good:** Clean abstraction with KeyboardShortcuts.Name extension
- **Good:** Proper cleanup in KeyEventMonitorNSView.viewDidMoveToWindow
- **Issue:** Escape key handling (lines 76-105 in ShortcutManager) is complex and fragile

---

## File Size Summary

| File | Lines | Status |
|------|-------|--------|
| EnhanceMeView.swift | 921 | **CRITICAL** |
| GeneralSettingsView.swift | 374 | OK |
| AIModesSettingsView.swift | 308 | OK |
| WindowManager.swift | 286 | OK |
| CustomFieldsSettingsView.swift | 196 | OK |
| AIConfigSettingsView.swift | 204 | OK |
| OnboardingView.swift | 188 | OK |
| ShortcutsSettingsView.swift | 171 | OK |
| PremiumUpsellView.swift | 147 | OK |
| MenuBarController.swift | 87 | OK |
| SettingsView.swift | 91 | OK |
| ShortcutManager.swift | 156 | OK |
| Other files | <100 each | OK |

---

## Metrics Summary

| Metric | Value |
|--------|-------|
| Files Reviewed | 24 |
| Total Lines | ~2,100 |
| Critical Issues | 3 |
| High Priority Issues | 6 |
| Medium Priority Issues | 6 |
| Low Priority Issues | 3 |
| Files Over 200 Lines | 2 |
| Type Safety Score | 8/10 |
| Memory Safety Score | 6/10 |
| Code Duplication Score | 6/10 |

---

## Recommended Actions (Priority Order)

### Immediate (Critical)
1. **Split EnhanceMeView.swift** into 4-5 modular files
2. **Add Task cancellation** for typewriter animation
3. **Add NSWindowDelegate** to WindowManager for proper cleanup

### Short-term (High Priority)
4. **Add error handling** in WindowManager.createTask
5. **Extract shared SettingsRow** component
6. **Replace DispatchQueue.main.asyncAfter** with Task.sleep
7. **Move safe array subscript** to shared extensions

### Medium-term
8. **Extract product IDs** to constants
9. **Remove duplicate onAppear** in ModeEditorSheet
10. **Add accessibility labels** to Kanban views
11. **Create AppConstants.swift** for magic numbers

### Long-term
12. **Introduce ViewModels** for complex views
13. **Add localization support**
14. **Standardize error handling pattern**

---

## Positive Observations

1. **Clean modifier pattern** - `PremiumFeatureModifier` and `liquidGlass` show good SwiftUI composition
2. **Proper EnvironmentObject usage** - SubscriptionService injected consistently
3. **Good keyboard shortcut architecture** - Clean separation of global/local shortcuts
4. **NSPanel subclassing done correctly** - Proper styleMasks and level settings
5. **Memory-conscious closures** - Most use `[weak self]` appropriately
6. **SwiftUI preview support** - Previews available for key views

---

## Unresolved Questions

1. Should EnhanceMeView use a proper ViewModel for AI service interaction?
2. Is the current window singleton pattern (WindowManager.shared) appropriate, or should dependency injection be used?
3. Should settings views share a base protocol for common functionality?
4. What is the intended behavior when a panel is closed via window close button vs. Escape key?
