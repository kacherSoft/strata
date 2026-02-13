# Code Review: EnhanceMe Shortcut Handler

**Date:** 2026-02-11
**Files Reviewed:**
- `TaskManager/Sources/TaskManager/Windows/EnhanceMeView.swift`
- `TaskManager/Sources/TaskManager/TaskManagerApp.swift` (for comparison)
- `TaskManager/Sources/TaskManager/Shortcuts/ShortcutManager.swift`
- `TaskManager/Sources/TaskManager/Shortcuts/ShortcutNames.swift`

**Lines Added/Modified:** ~60 lines
**Review Focus:** New `EnhanceMeShortcutHandler`/`EnhanceMeShortcutNSView` for local event monitoring

---

## Executive Summary

The new `EnhanceMeShortcutHandler` implements local keyboard event monitoring for the cycle mode shortcut (Tab). While functionally correct, there are **CRITICAL memory management issues** and significant **code duplication** that must be addressed.

**Overall Grade:** C+ (Critical issues present)

---

## Critical Issues

### 1. Memory Leak: Double Monitor Removal
**Severity:** Critical

**Location:** `EnhanceMeShortcutNSView` lines 313-317

```swift
override func viewDidMoveToSuperview() {
    super.viewDidMoveToSuperview()
    if superview == nil, let monitor = monitor {
        NSEvent.removeMonitor(monitor)
        self.monitor = nil  // First nil set
    }
}

deinit {
    if let monitor = monitor {
        NSEvent.removeMonitor(monitor)  // Double removal!
    }
}
```

**Problem:** When view is removed from superview, monitor is removed and set to nil. Then `deinit` attempts removal again on nil monitor. `NSEvent.removeMonitor(nil)` may crash or cause undefined behavior.

**Fix:**
```swift
deinit {
    if let monitor = monitor {
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }
}
```

### 2. Race Condition: View Removal Before Monitor Setup
**Severity:** High

**Location:** `EnhanceMeShortcutNSView` lines 298-309

If `viewDidMoveToWindow()` adds monitor but view is immediately removed before returning, the monitor may not be cleaned up properly.

**Recommendation:** Combine monitor cleanup into single method with proper synchronization.

---

## High Priority Findings

### 1. Code Duplication (90% duplicate of `LocalShortcutHandler`)
**Severity:** High

`EnhanceMeShortcutNSView` is nearly identical to `LocalShortcutNSView` in `TaskManagerApp.swift`:

| Component | EnhanceMeShortcutNSView | LocalShortcutNSView |
|-----------|------------------------|---------------------|
| Monitor storage | `private nonisolated(unsafe) var monitor: Any?` | Same |
| viewDidMoveToWindow | Same logic, different shortcut check | Same |
| viewDidMoveToSuperview | Identical | Identical |
| deinit | Identical | Identical |
| matchesShortcut | Different shortcuts | Same pattern |

**Impact:** Maintenance burden, bug fixes need to be applied twice.

**Recommendation:** Extract to reusable base class:

```swift
// Shared/LocalShortcutMonitorBase.swift
class LocalShortcutMonitorBase: NSView {
    private nonisolated(unsafe) var monitor: Any?
    var onShortcutTriggered: ((KeyboardShortcuts.Name) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil && monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                return self?.handleEvent(event) ?? event
            }
        }
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        cleanupMonitor()
    }

    private func cleanupMonitor() {
        if superview == nil, let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    func handleEvent(_ event: NSEvent) -> NSEvent? {
        // Subclass implements specific logic
        return event
    }

    deinit {
        cleanupMonitor()
    }
}
```

### 2. Thread Safety for onCycleMode Callback
**Severity:** Medium-High

**Location:** `EnhanceMeShortcutNSView` line 304

```swift
DispatchQueue.main.async {
    self?.onCycleMode?()
}
```

The callback is already dispatched to main queue, but `onCycleMode` property itself is not thread-safe. If SwiftUI updates the binding while the event monitor is active, there could be a race.

**Recommendation:** Use `@MainActor` isolation for the entire view class.

### 3. Hardcoded Shortcut Name Lookup
**Severity:** Medium

**Location:** `EnhanceMeShortcutNSView` line 322

```swift
guard let shortcut = KeyboardShortcuts.getShortcut(for: .cycleAIMode) else { return false }
```

The shortcut name `.cycleAIMode` is hardcoded. This works but reduces flexibility. Consider passing shortcut name as init parameter.

---

## Medium Priority Improvements

### 1. Inconsistent Event Handling
`LocalShortcutNSView` returns nil for consumed events but doesn't dispatch to main queue. `EnhanceMeShortcutNSView` does dispatch. Inconsistent behavior.

**Recommendation:** Standardize - either both dispatch to main queue or neither should. Given SwiftUI updates should be on main actor, prefer main actor dispatch.

### 2. Missing Documentation
No comments explaining why `addLocalMonitorForEvents` is used vs global shortcuts. Clarify that Tab is a LOCAL shortcut for EnhanceMe window only.

### 3. UI Hint Inconsistency
Button now shows "Tab" but the actual shortcut is stored in `KeyboardShortcuts` and could be customized. If user changes the shortcut, button label becomes incorrect.

**Fix:** Fetch current shortcut dynamically:

```swift
Text(cycleModeShortcutLabel())
    .font(.caption)
    .foregroundStyle(.secondary)

// Elsewhere:
func cycleModeShortcutLabel() -> String {
    guard let shortcut = KeyboardShortcuts.getShortcut(for: .cycleAIMode) else {
        return "Tab" // default
    }
    // Convert CarbonKeyCode/modifiers to display string
    return "Tab" // Simplified for now
}
```

---

## Low Priority Suggestions

### 1. Extract Shortcut Matching Logic
The `matchesCycleModeShortcut` method is duplicated. Could be static utility:

```swift
extension NSEvent {
    func matchesShortcut(_ name: KeyboardShortcuts.Name) -> Bool {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: name) else { return false }
        let eventMods = modifierFlags.intersection(.deviceIndependentFlagsMask)
        return keyCode == shortcut.carbonKeyCode && eventMods == shortcut.modifiers
    }
}
```

### 2. Use `nonisolated(unsafe)` Appropriateness
The monitor is marked `nonisolated(unsafe)` because `NSEvent.addLocalMonitorForEvents` is not actor-isolated. This is correct but should be documented with comments.

---

## Positive Observations

1. **Correct use of `[weak self]`** in event monitor closure prevents retain cycles
2. **Proper use of `addLocalMonitorForEvents`** for window-scoped shortcuts (Tab key)
3. **Nil-coalescing for optional shortcut** gracefully handles unset shortcuts
4. **Event consumption** (`return nil`) correctly prevents event from propagating

---

## Security Considerations

No security issues identified. Local event monitoring only affects the app's own window context.

---

## Recommended Actions (Priority Order)

1. **[CRITICAL]** Fix double monitor removal in deinit (Critical issue #1)
2. **[HIGH]** Extract shared `LocalShortcutMonitorBase` class to eliminate duplication
3. **[MEDIUM]** Add `@MainActor` isolation to callback handling
4. **[MEDIUM]** Make shortcut label dynamic from `KeyboardShortcuts` storage
5. **[LOW]** Add documentation comments explaining local vs global shortcut patterns

---

## Suggested Refactor

Create shared component in `TaskManager/Sources/TaskManager/Shortcuts/LocalShortcutMonitor.swift`:

```swift
import AppKit
import KeyboardShortcuts

@MainActor
class LocalShortcutMonitor: NSView {
    private nonisolated(unsafe) var monitor: Any?
    var shortcutName: KeyboardShortcuts.Name?
    var onTrigger: (() -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, monitor == nil, let name = shortcutName else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self,
                  event.matchesShortcut(name) else { return event }
            self.onTrigger?()
            return nil // Consume event
        }
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if superview == nil {
            cleanup()
        }
    }

    private func cleanup() {
        guard let monitor = monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }

    deinit {
        cleanup()
    }
}

extension NSEvent {
    func matchesShortcut(_ name: KeyboardShortcuts.Name) -> Bool {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: name) else { return false }
        let eventMods = modifierFlags.intersection(.deviceIndependentFlagsMask)
        return keyCode == shortcut.carbonKeyCode && eventMods == shortcut.modifiers
    }
}
```

Then both `EnhanceMeShortcutHandler` and `LocalShortcutHandler` use this shared class.

---

## Unresolved Questions

1. Why is Tab key implemented as a local event monitor instead of using standard SwiftUI `.keyboardShortcut()` modifier?
2. Should cycle mode work when text editor has focus (Tab is usually for focus navigation)?
3. Is the duplicate `LocalShortcutHandler` in `TaskManagerApp` intentional or temporary?

---

## Metrics

| Metric | Value |
|--------|-------|
| Code Duplication | ~90% with LocalShortcutNSView |
| Thread Safety | Partial (main queue dispatch used) |
| Memory Safety | **Issue present** (double removal) |
| Lines of Code | 60 new lines |
| Test Coverage | Not verified (no tests present) |

---

**Status:** Requires critical fixes before merge.
