# Code Review: Shortcuts Refactor
**Date**: 2025-02-11 22:59
**Files**: ShortcutManager.swift, ShortcutNames.swift

## Scope
- `TaskManager/Sources/TaskManager/Shortcuts/ShortcutManager.swift` (85 lines)
- `TaskManager/Sources/TaskManager/Shortcuts/ShortcutNames.swift` (12 lines)
- `TaskManager/Sources/TaskManager/Views/Settings/ShortcutsSettingsView.swift` (137 lines)
- Build status: **PASS**

## Overall Assessment
Clean refactor. Separation of global vs local shortcuts is well-implemented. Build passes. Memory management correct with `[weak self]`. UI clearly reflects the distinction.

## Critical Issues
None.

## High Priority Findings

### 1. Potential UX Confusion on Local Shortcuts
**File**: `ShortcutManager.swift:30-39`

Local shortcuts (`mainWindow`, `settings`, `cycleAIMode`) have defaults registered but **no global handlers**. Users can customize them via UI, but they won't work system-wide.

**Impact**: Users may expect these to work like global shortcuts.

**Current state**:
- `mainWindow`: Cmd+T (local, no handler)
- `settings`: Cmd+, (local, no handler)
- `cycleAIMode`: Tab (local, no handler)

**Question**: Should these be handled elsewhere (e.g., menu items, local key handlers)?

### 2. Redundant Registration in `resetAllToDefaults()`
**File**: `ShortcutManager.swift:76-83`

The reset function calls `KeyboardShortcuts.reset()` then immediately re-sets defaults. The `reset()` call may be redundant since we're setting explicit values after.

**Current**:
```swift
KeyboardShortcuts.reset(.quickEntry, .enhanceMe, .mainWindow, .settings, .cycleAIMode)
KeyboardShortcuts.setShortcut(...repeated for all...)
```

**Simpler approach**:
```swift
// Just set defaults directly, reset is implicit
KeyboardShortcuts.setShortcut(.init(.n, modifiers: [.command, .shift]), for: .quickEntry)
// ... others
```

Or if reset is needed for cleanup, add comment explaining why.

## Medium Priority Improvements

### 3. Inconsistent Default Modifier Patterns
**File**: `ShortcutManager.swift:25-39`

Global shortcuts: `Cmd+Shift` (consistent)
Local shortcuts: Mixed patterns
- `mainWindow`: `Cmd+T`
- `settings`: `Cmd+,` (standard macOS convention)
- `cycleAIMode`: `Tab` only (no modifiers)

The `Tab`-only shortcut may conflict with standard focus navigation. Consider `Cmd+Tab` alternative (though this conflicts with app switching). `Option+Tab` or `Ctrl+Tab` might be safer.

### 4. Missing Documentation for Local Shortcut Usage
**File**: `ShortcutNames.swift:8`

Comment says "stored for customization, no global handler" but doesn't explain WHERE these shortcuts should be handled. Add:
```swift
// Local shortcuts (handled by focused views, see EnhanceMeView for Tab handler)
```

### 5. MARK Comment Placement
**File**: `ShortcutManager.swift:20`

MARK for "Global Shortcuts" appears above `registerDefaultShortcuts()` which registers BOTH global and local. Consider:
```swift
// MARK: - Registration
private func registerDefaultShortcuts() {
    // Global shortcuts
    ...
    // Local shortcuts (no global handlers)
    ...
}
```

## Low Priority Suggestions

### 6. Action Methods Could Be `internal` Instead of `public`
**File**: `ShortcutManager.swift:54-74`

Actions like `showMainWindow()`, `showSettings()`, `cycleAIMode()` are `internal` by default. If not used outside module, could explicitly mark `private` or document intended usage.

### 7. Magic Strings in Names
**File**: `ShortcutNames.swift:5-11`

Shortcut names use string literals ("quickEntry", "enhanceMe"). Consider static constants if reused elsewhere, but current approach is fine for KeyboardShortcuts library pattern.

## Positive Observations

1. **Proper `[weak self]` usage** in all closures prevents retain cycles
2. **Clean MARK organization** improves code navigation
3. **Consistent reset behavior** - all 5 shortcuts handled identically
4. **UI matches implementation** - ShortcutsSettingsView clearly labels global vs local
5. **Build passes** - no compilation errors
6. **Default shortcuts follow macOS conventions** (Cmd+Comma for settings is standard)

## Recommended Actions

1. **HIGH**: Clarify local shortcut handling - document where/how these shortcuts are activated (or remove if unused)
2. **MEDIUM**: Reconsider `Tab`-only shortcut for `cycleAIMode` - may interfere with focus navigation
3. **LOW**: Simplify `resetAllToDefaults()` by removing redundant `reset()` call
4. **LOW**: Add MARK comment for registration section vs actions section

## Security Considerations
No security issues identified. Shortcuts are UI-level controls with no direct data access.

## Metrics
- Type Coverage: N/A (no explicit types defined)
- Test Coverage: Not measured (no tests present)
- Linting Issues: None (build passes)
- Lines of Code: 97 (combined)

## Unresolved Questions
1. Where are local shortcuts (`mainWindow`, `settings`, `cycleAIMode`) supposed to be handled if not globally?
2. Is `Tab`-only for `cycleAIMode` intentional despite potential focus navigation conflicts?
