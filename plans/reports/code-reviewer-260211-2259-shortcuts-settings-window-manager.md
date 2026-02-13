# Code Review Report: Shortcuts Settings & Window Manager Changes

**Date:** 2026-02-11 22:59
**Files Reviewed:**
- `TaskManager/Sources/TaskManager/Views/Settings/ShortcutsSettingsView.swift`
- `TaskManager/Sources/TaskManager/Windows/WindowManager.swift`
- `TaskManager/Sources/TaskManager/Shortcuts/ShortcutNames.swift` (related)
- `TaskManager/Sources/TaskManager/Windows/EnhanceMeView.swift` (related)

---

## Overall Assessment

**Quality:** Good. UI reorganization improves clarity. Window management fallback is pragmatic but needs validation.

**Risk Level:** Low-Medium

---

## Critical Issues

None identified.

---

## High Priority Findings

### 1. Selector Naming in WindowManager (WindowManager.swift:86)

**Issue:** Using `Selector(("newWindowForTab:"))` with double-parens is a workaround for deprecated API warnings.

```swift
NSApp.sendAction(Selector(("newWindowForTab:")), to: nil, from: nil)
```

**Impact:**
- This selector is for tabbed windows, not standard window creation
- May not work as expected for main window creation
- Potential runtime issues if app doesn't support tabbed windows

**Recommendation:**
Consider using NSApplication's `newDocument:` or creating window programmatically:
```swift
if let window = getMainWindow() {
    window.makeKeyAndOrderFront(nil)
} else {
    // Alternative: Create window through Scene phase or delegate
    NSApp.mainWindow?.makeKeyAndOrderFront(nil)
}
```

---

### 2. UI Inconsistency - Reset Button Placement (ShortcutsSettingsView.swift:87-95)

**Issue:** Reset button appears at end of all shortcuts without clear visual separation from Local Shortcuts section.

**Impact:**
- User may think reset only applies to local shortcuts
- No confirmation dialog for destructive action
- Could accidentally reset all shortcuts

**Recommendation:**
Add section header or move reset button:
```swift
// Add visual separation
Divider()
    .padding(.top, 16)
    .padding(.horizontal, 20)

HStack {
    Spacer()
    Button("Reset All to Defaults") {
        if confirmReset() {
            ShortcutManager.resetAllToDefaults()
        }
    }
}
```

---

## Medium Priority Improvements

### 3. Helper Text Clarity

**Good:** Added helper text explaining global vs local behavior:
- "Work system-wide, even when the app is not focused"
- "Work only when the app is focused"

**Suggestion:** Consider adding inline icons for visual reinforcement:
```swift
HStack(spacing: 4) {
    Image(systemName: "globe")
    Text("Work system-wide, even when the app is not focused")
}
```

### 4. Shortcut Reordering Rationale

**Change:** Enhance Me moved to top of Global Shortcuts, Quick Entry second.

**Analysis:** This makes sense - Enhance Me is the primary AI feature. However, consider that Quick Entry is more frequently used for task capture. Consider user testing to validate ordering.

### 5. Description Consistency (Line 82)

**Issue:** "Switch between AI modes (Tab in Enhance Me)" - parenthetical hints inconsistency.

**Observation:** Other shortcuts don't show keyboard hints inline. Either:
1. Show hints for all shortcuts consistently
2. Remove hints from descriptions (rely on UI affordances)

**Current state** (Enhance Me button) already shows Tab hint in UI (line 87-95 of EnhanceMeView), making description hint redundant.

---

## Low Priority Suggestions

### 6. Code Style - Trailing Whitespace (ShortcutsSettingsView.swift:134-137)

```swift
}


```

Remove empty lines at end of file.

### 7. Section Header Styling

Consider adding icons to section headers for visual hierarchy:
```swift
HStack(spacing: 6) {
    Image(systemName: "globe.americas")
    Text("Global Shortcuts")
}
```

---

## Security Considerations

None identified. No new data handling, permissions, or API interactions.

---

## Performance Analysis

No performance concerns. UI changes are purely declarative.

---

## Positive Observations

1. **Excellent UI Organization**: Global vs Local shortcut separation matches mental model
2. **Clear Helper Text**: Explains behavior difference effectively
3. **Consistent Pattern**: ShortcutRow component reused well
4. **Good Visual Hierarchy**: Proper font weights, colors, spacing
5. **Backward Compatible**: Existing shortcuts preserved, just reorganized

---

## Test Coverage Gaps

**Uncovered Scenarios:**
1. Window creation when `getMainWindow()` returns nil
2. Reset button functionality
3. Global shortcut registration persistence
4. Local shortcut handling when app not focused

**Recommendation:** Add unit tests for:
- `WindowManager.showMainWindow()` with no existing windows
- Shortcut registration defaults
- Reset functionality restoration

---

## Recommended Actions

### Immediate (Before Merge)
1. Verify `Selector(("newWindowForTab:"))` fallback works in testing
2. Add confirmation dialog for Reset All button

### Short Term (Next Sprint)
3. Consider adding inline icons to section headers
4. Validate shortcut ordering with user testing
5. Add unit tests for window creation fallback

### Long Term
6. Consider adding keyboard shortcut hints consistently across all shortcuts
7. Document global vs local shortcut behavior in user-facing help

---

## Metrics

- **Lines Changed:** ~40 lines modified
- **Files Modified:** 2 main files
- **New Components:** 0
- **Breaking Changes:** 0
- **Type Coverage:** N/A (SwiftUI views)
- **Test Coverage:** No tests added

---

## Unresolved Questions

1. **Window Creation Fallback:** Does `newWindowForTab:` actually work for creating main window, or should we use a different approach?

2. **Shortcut Ordering:** Is there user research supporting Enhance Me > Quick Entry ordering, or was this arbitrary?

3. **Reset Confirmation:** Should there be a confirmation dialog for the destructive Reset All action?

---

**Conclusion:** Changes are good overall. UI organization significantly improves clarity. Window creation fallback needs verification before production deployment. Reset button should have confirmation to prevent accidental data loss.
