# Code Review: TaskManagerApp.swift - Local Shortcuts & Photo Storage

**Date**: 2026-02-11
**Reviewer**: code-reviewer
**Files Reviewed**:
- `TaskManager/Sources/TaskManager/TaskManagerApp.swift`
- `TaskManager/Sources/TaskManager/Windows/WindowManager.swift`
- `TaskManager/Sources/TaskManager/Shortcuts/ShortcutManager.swift`
- `TaskManager/Sources/TaskManager/Services/PhotoStorageService.swift`
- `TaskManager/Sources/TaskManager/Views/Settings/ShortcutsSettingsView.swift`
- `TaskManager/Sources/TaskManager/Windows/EnhanceMeView.swift`

**Lines of Code**: ~350 (changes only)

---

## Summary

Review focuses on:
1. Photo storage fix (storing file paths instead of URLs)
2. New `LocalShortcutHandler` NSViewRepresentable
3. New `LocalShortcutNSView` with NSEvent local monitoring
4. Key event matching logic for local shortcuts

---

## Critical Issues

### 1. Memory Leak in LocalShortcutNSView - Event Monitor Cleanup Race Condition

**Severity**: HIGH
**Location**: `LocalShortcutNSView` (lines 259-304)

**Problem**: Monitor cleanup has race conditions. The `viewDidMoveToSuperview()` cleanup runs when `superview == nil`, but the view might be re-added to a different window/superview before `deinit` runs. Monitor won't be re-registered in the new context.

```swift
override func viewDidMoveToSuperview() {
    super.viewDidMoveToSuperview()
    if superview == nil, let monitor = monitor {
        NSEvent.removeMonitor(monitor)
        self.monitor = nil  // Monitor nil, but view might be re-added
    }
}
```

**Impact**: If SwiftUI reuses the NSView (which it can do), shortcuts stop working.

**Fix**:
```swift
override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    // Cleanup when removed from window
    if window == nil {
        cleanupMonitor()
    }
    // Setup when added to window
    else if monitor == nil {
        setupMonitor()
    }
}

private func cleanupMonitor() {
    if let monitor = monitor {
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }
}

private func setupMonitor() {
    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        return self?.handleKeyEvent(event) ?? event
    }
}
```

---

### 2. Thread Safety - nonisolated(unsafe) Without Proper Synchronization

**Severity**: HIGH
**Location**: `LocalShortcutNSView.monitor` (line 260)

**Problem**: `nonisolated(unsafe)` removes actor isolation but provides no synchronization. The monitor is:
- Set in `viewDidMoveToWindow()` (main thread via AppKit)
- Accessed in `deinit` (could be on any thread)
- Accessed in `viewDidMoveToSuperview()` (main thread via AppKit)

```swift
private nonisolated(unsafe) var monitor: Any?
```

**Impact**: Potential data race on monitor access/assignment.

**Why `nonisolated(unsafe)`?** `NSEvent.addLocalMonitorForEvents` returns non-Sendable `Any?`. Using it from `@MainActor` class requires this workaround.

**Mitigation**: All access is effectively on main thread via AppKit lifecycle, but not guaranteed. Consider using `Unmanaged` or `OSAllocatedUnmanagedLock` if this becomes problematic.

**Recommendation**: Add documentation:
```swift
/// Event monitor for local shortcuts.
/// - WARNING: nonisolated(unsafe) required because NSEvent returns non-Sendable Any?
/// - All access must be on main thread (enforced by NSView lifecycle)
private nonisolated(unsafe) var monitor: Any?
```

---

### 3. Duplicate Monitor Cleanup in deinit

**Severity**: MEDIUM
**Location**: `LocalShortcutNSView.deinit` (lines 299-303)

**Problem**: `deinit` cleans up the monitor, but `viewDidMoveToSuperview()` already does this when `superview == nil`. Double-cleanup is redundant and `NSEvent.removeMonitor` might throw if called twice (though current behavior is safe - it's a no-op for invalid tokens).

```swift
deinit {
    if let monitor = monitor {
        NSEvent.removeMonitor(monitor)  // Potentially redundant
    }
}
```

**Fix**: Keep `deinit` as safety net but document:

```swift
/// Safety net cleanup in case view lifecycle methods didn't run
deinit {
    cleanupMonitor()  // No-op if already cleaned
}
```

---

## High Priority Findings

### 4. Weak Self Not Needed in Monitor Closure

**Severity**: MEDIUM
**Location**: `LocalShortcutNSView.viewDidMoveToWindow()` (line 266)

**Problem**: `[weak self]` in monitor closure is unnecessary. The closure captures `self` weakly, but the view owns the monitor, so deinit would break the cycle. Strong capture is actually safer here.

```swift
monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
    return self?.handleKeyEvent(event) ?? event  // Returns nil if self gone
}
```

**Issue**: If `self` is deallocated while callback is pending, returns `nil` (consumes event) even though no handler ran.

**Fix**: Use strong capture or handle nil case explicitly:

```swift
monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
    guard let self else { return event }  // Don't consume if deallocated
    return self.handleKeyEvent(event)
}
```

---

### 5. MainActor Annotation on handleKeyEvent is Redundant

**Severity**: LOW
**Location**: `LocalShortcutNSView.handleKeyEvent()` (line 280)

**Problem**: Method marked `@MainActor` but entire class is already implicitly on main thread (NSView subclasses). The annotation is redundant but not harmful.

```swift
@MainActor
private func handleKeyEvent(_ event: NSEvent) -> NEvent? {
```

**Recommendation**: Remove annotation, add comment:

```swift
/// Runs on main thread (called from NSEvent monitor on main thread)
private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
```

---

### 6. Key Code Matching Logic Issue

**Severity**: MEDIUM
**Location**: `matchesShortcut(_:name:)` (line 293-296)

**Problem**: `event.keyCode` and `carbonKeyCode` comparison may not match all keys. Carbon key codes are deprecated and don't cover all modern keyboard layouts.

```swift
private func matchesShortcut(_ event: NSEvent, name: KeyboardShortcuts.Name) -> Bool {
    guard let shortcut = KeyboardShortcuts.getShortcut(for: name) else { return false }
    let eventMods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    return event.keyCode == shortcut.carbonKeyCode && eventMods == shortcut.modifiers
}
```

**Risk**: May fail on non-QWERTY layouts or special keys.

**Recommendation**: This is the KeyboardShortcuts library's provided API, so it's acceptable. Document limitation:

```swift
/// NOTE: Uses carbonKeyCode which may have limitations on non-QWERTY keyboards
/// KeyboardShortcuts library manages this internally
```

---

## Medium Priority Issues

### 7. Photo Storage - Empty Array Handling Inconsistent

**Severity**: MEDIUM
**Location**: `ContentView.createTask()` (lines 161-169)

**Problem**: Photo storage called with empty array check, but `storePhotos` already handles empty input. The check is redundant.

```swift
let storedPaths = photos.isEmpty ? [] : PhotoStorageService.shared.storePhotos(photos)
```

**Fix**: Let `storePhotos` handle it:

```swift
let storedPaths = PhotoStorageService.shared.storePhotos(photos)
```

And update `storePhotos` to be more efficient with empty input:

```swift
func storePhotos(_ sourceURLs: [URL]) -> [String] {
    guard !sourceURLs.isEmpty else { return [] }
    // ... rest of implementation
}
```

---

### 8. addPhotos Has Empty URL Handling That Doesn't Match Caller Intent

**Severity**: LOW
**Location**: `ContentView.addPhotos()` (lines 227-244)

**Problem**: Function accepts `urls` parameter but if empty, calls `pickPhotos`. This conflates two responsibilities: adding provided URLs vs picking new ones.

```swift
private func addPhotos(taskItem: TaskItem, urls: [URL]) {
    guard let task = findTaskModel(for: taskItem) else { return }

    if urls.isEmpty {
        PhotoStorageService.shared.pickPhotos { ... }  // Pick mode
    } else {
        let storedPaths = PhotoStorageService.shared.storePhotos(urls)  // Add mode
        // ...
    }
}
```

**Call site**: `DetailPanelView.onAddPhotos` passes empty array to trigger picker.

**Recommendation**: Split into two methods:

```swift
private func pickAndAddPhotos(taskItem: TaskItem) {
    PhotoStorageService.shared.pickPhotos { pickedURLs in
        // ...
    }
}

private func addPhotos(taskItem: TaskItem, urls: [URL]) {
    guard !urls.isEmpty else { return }
    // ... store and add
}
```

---

### 9. Error Handling Silent in Photo Storage

**Severity**: MEDIUM
**Location**: `PhotoStorageService.storePhotos()` (lines 68-89)

**Problem**: Errors are only printed, not propagated. Caller has no way to know which photos failed.

```swift
} catch {
    print("Failed to copy photo: \(error)")
}
```

**Impact**: User sees no feedback if photo storage fails.

**Fix**: Return result:

```swift
func storePhotos(_ sourceURLs: [URL]) -> [Result<String, Error>] {
    // ...
}
```

Or at minimum, return partial success:

```swift
func storePhotos(_ sourceURLs: [URL]) -> (success: [String], failed: [URL])
```

---

### 10. Security Scoped Resource Not Stopped on All Code Paths

**Severity**: LOW
**Location**: `PhotoStorageService.storePhotos()` (lines 72-75)

**Problem**: `defer` ensures cleanup, but if `copyItem` throws early, resource is released. This is actually correct, but the implementation could be clearer:

```swift
let accessing = sourceURL.startAccessingSecurityScopedResource()
defer {
    if accessing { sourceURL.stopAccessingSecurityScopedResource() }
}
```

**Recommendation**: Add early exit for safety:

```swift
guard sourceURL.startAccessingSecurityScopedResource() else {
    print("Failed to access security-scoped resource")
    continue
}
defer { sourceURL.stopAccessingSecurityScopedResource() }
```

---

## Low Priority Suggestions

### 11. makeFirstResponder Timing Issue

**Severity**: LOW
**Location**: `LocalShortcutHandler.makeNSView()` (lines 250-252)

**Problem**: `DispatchQueue.main.async` for first responder is a timing hack. The view might not be in the view hierarchy yet.

```swift
DispatchQueue.main.async {
    view.window?.makeFirstResponder(view)
}
```

**Better**: Use `NSView.didMoveToWindow()` callback in the NSView itself, not from SwiftUI side.

---

### 12. WindowManager Fallback Using String Selector

**Severity**: LOW
**Location**: `WindowManager.showMainWindow()` (line 86)

**Problem**: Using string selector is unsafe and might crash if selector doesn't exist.

```swift
NSApp.sendAction(Selector(("newWindowForTab:")), to: nil, from: nil)
```

**Better**: Check if exists first:

```swift
if let selector = Selector(("newWindowForTab:")) as? Selector {
    NSApp.sendAction(selector, to: nil, from: nil)
}
```

Or use `NSApp.mainWindow?.makeKeyAndOrderFront(nil)` directly.

---

### 13. EnhanceMeView Has Duplicate Local Shortcut Handler Pattern

**Severity**: LOW
**Location**: `EnhanceMeShortcutHandler` (lines 270-323)

**Observation**: Same pattern as `LocalShortcutHandler` but for Tab key. Consider extracting base class:

```swift
class BaseShortcutNSView: NSView {
    private nonisolated(unsafe) var monitor: Any?
    // ... common setup/cleanup
}

final class LocalShortcutNSView: BaseShortcutNSView {
    // ... main window shortcuts
}

final class EnhanceMeShortcutNSView: BaseShortcutNSView {
    // ... cycle mode shortcut
}
```

---

## Positive Observations

1. **Photo storage fix correct**: Now stores file paths instead of URL strings, which is more reliable for persistence
2. **Proper use of `[weak self]`** in most closure captures
3. **Clean separation**: Global vs local shortcuts clearly documented in UI
4. **Security scoped resources**: Properly handled in `PhotoStorageService`
5. **MainActor usage**: Appropriate for UI-related classes
6. **Defensive coding**: Empty array checks in multiple places
7. **Comprehensive shortcut support**: Both global and local shortcuts implemented

---

## Recommended Actions

1. **Fix monitor cleanup race condition** (Issue #1) - HIGH PRIORITY
2. **Add synchronization documentation** for `nonisolated(unsafe)` (Issue #2)
3. **Remove redundant deinit cleanup** or document as safety net (Issue #3)
4. **Fix weak self nil handling** in monitor closure (Issue #4)
5. **Propagate photo storage errors** to caller (Issue #9)
6. **Split `addPhotos`** into two methods (Issue #8)
7. **Remove empty array check** in `createTask` (Issue #7)
8. **Document Carbon keyCode limitations** (Issue #6)

---

## Metrics

- **Type Coverage**: N/A (Swift code, no type report generated)
- **Test Coverage**: N/A (no tests provided)
- **Linting Issues**: 0 (code compiles)
- **Memory Leaks**: 1 potential (monitor cleanup)
- **Thread Safety Issues**: 1 (nonisolated unsafe)
- **Critical Issues**: 2
- **High Priority**: 4
- **Medium Priority**: 5
- **Low Priority**: 4

---

## Unresolved Questions

1. Why does `LocalShortcutHandler` need to set `makeFirstResponder`? Is it required for key event capture, or is it for something else?
2. Are there tests for the shortcut matching logic with different keyboard layouts?
3. What happens if `PhotoStorageService.storePhotos` fails partially? Should we retry?
4. Should `EnhanceMeShortcutNSView` and `LocalShortcutNSView` share a common base class to reduce duplication?
5. Why is `WindowManager.showMainWindow()` using `newWindowForTab:` selector as fallback? Is this SwiftUI-specific behavior?

---

## Conclusion

The photo storage fix is correct and addresses the URL persistence issue. The local shortcuts implementation is functional but has a monitor cleanup race condition that could cause shortcuts to stop working if SwiftUI reuses the NSView. The `nonisolated(unsafe)` usage is acceptable but should be documented. Overall, code quality is good with minor issues to address.
