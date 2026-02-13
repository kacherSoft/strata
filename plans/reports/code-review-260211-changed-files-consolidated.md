# Code Review: Changed Files (Consolidated)

**Date:** 2026-02-11  
**Build:** PASS  
**Files:** 6 modified | +221 / -63 lines

---

## Change Summary

Refactor splits shortcuts into **global** (system-wide: Quick Entry, Enhance Me) and **local** (app-focused: Main Window, Settings, Cycle AI Mode). Removes `cycleAIMode` from global `KeyboardShortcuts`, replaces with Tab key via `NSEvent.addLocalMonitorForEvents`. Fixes photo storage to copy files instead of storing ephemeral URLs. Adds `WindowManager.showMainWindow()` fallback for missing window.

---

## Bugs Found

### BUG-1: `WindowManager.createTask()` still uses `absoluteString` (P1)
**File:** `WindowManager.swift:73`  
Tasks created via **Quick Entry** store raw URL strings instead of copying to app storage. Breaks after sandbox scope expires. Inconsistent with `ContentView.createTask()` which now uses `storePhotos`.

**Fix:** Replace `photos: photos.map { $0.absoluteString }` with:
```swift
let storedPaths = photos.isEmpty ? [] : PhotoStorageService.shared.storePhotos(photos)
// photos: storedPaths
```

### BUG-2: `ContentView.updateTask()` uses `.path` without copying (P2)
**File:** `TaskManagerApp.swift:208`  
`photos.map { $0.path }` stores source paths without copying to Application Support. Original files could be moved/deleted.

### BUG-3: Tab key swallowed when `self` is nil (P3)
**File:** `EnhanceMeView.swift:291-298`  
If `EnhanceMeShortcutNSView` is deallocated but monitor still active, Tab keypress returns `nil` (consumed) even though no handler ran. Should return `event` when `self` is nil.

---

## DRY Violation — ~68% Code Duplication

`LocalShortcutNSView` and `EnhanceMeShortcutNSView` share identical: monitor property, `viewDidMoveToWindow` scaffolding, `viewDidMoveToSuperview` teardown, `deinit`. Only event-handling body differs.

**Recommendation:** Extract `KeyEventMonitorNSView` base class with `removeMonitor()` centralized, subclasses override `handleKeyEvent(_:)`.

---

## Tab Key Conflict (P2)

Intercepting bare Tab (keyCode 48, no modifiers) **globally** breaks standard focus navigation for all views while EnhanceMeView is displayed. Text fields, buttons, and accessibility focus rings stop working.

**Fix:** Add `window?.isKeyWindow == true` guard, or use Option+Tab / Ctrl+Tab.

---

## Other Findings

| # | Issue | Severity | File |
|---|-------|----------|------|
| 4 | `Selector(("newWindowForTab:"))` — private API, silent failure, potential App Store rejection | Med | WindowManager.swift:86 |
| 5 | Double monitor removal: `viewDidMoveToSuperview` + `deinit` both call `removeMonitor` | Low | TaskManagerApp.swift, EnhanceMeView.swift |
| 6 | `DispatchQueue.main.async` in EnhanceMeShortcutNSView unnecessary (monitors already run on main) | Low | EnhanceMeView.swift:294 |
| 7 | `@MainActor` on `handleKeyEvent` redundant (NSView lifecycle is main thread) | Low | TaskManagerApp.swift:280 |
| 8 | `try? save()` silently swallows errors in 7 locations | Low | Multiple |
| 9 | No reset confirmation dialog for destructive "Reset All" button | Low | ShortcutsSettingsView.swift:89 |

---

## Positives

- Clean global/local separation in UI and code
- Correct `[weak self]` usage in closures
- Photo storage fix addresses real persistence bug
- Settings view clearly labels shortcut scopes with helper text
- Build passes clean

---

## Recommended Priority

1. **Fix BUG-1** — WindowManager.createTask photo storage
2. **Fix BUG-2** — updateTask photo path handling
3. **Fix BUG-3** — nil-self Tab event consumption
4. **Add isKeyWindow guard** for Tab shortcut scope
5. **Extract base class** to eliminate DRY violation
