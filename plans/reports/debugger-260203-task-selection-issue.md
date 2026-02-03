# Task Selection Issue - Debug Report

**Date**: 2026-02-03
**Agent**: debugger
**Issue**: Task row click doesn't select task, action buttons don't appear

---

## Executive Summary

**ROOT CAUSE IDENTIFIED**: Conflicting gesture handlers in TaskRow.swift

The task selection feature is broken due to **two competing `.onTapGesture` modifiers**:
1. TaskRow's internal gesture toggles `isExpanded` (line 93-97)
2. TaskListView's gesture sets `selectedTask` (line 18-20)

**Result**: TaskRow's internal gesture fires first, swallowing the tap event. Selection gesture never executes.

---

## Technical Analysis

### Issue 1: Task Selection Not Working

#### File: TaskManagerUIComponents/.../Views/TaskList/TaskRow.swift

**Lines 93-97 (PROBLEM CODE)**:
```swift
.onTapGesture {
    withAnimation(.spring(response: 0.3)) {
        isExpanded.toggle()
    }
}
```

**Why this breaks selection**:
- TaskRow attaches its own tap gesture to toggle expand/collapse
- SwiftUI gesture priority: Child views capture gestures before parents
- TaskListView's tap gesture (line 18-20) gets ignored/blocked

#### File: TaskManagerUIComponents/.../Views/TaskList/TaskListView.swift

**Lines 18-20 (INTENDED BEHAVIOR - BLOCKED)**:
```swift
.onTapGesture {
    selectedTask = task
}
```

**Expected flow**:
1. User clicks TaskRow
2. TaskListView's gesture sets `selectedTask = task`
3. TaskRow receives `isSelected: true` via binding
4. Action buttons appear (line 72-83 in TaskRow)

**Actual flow**:
1. User clicks TaskRow
2. TaskRow's gesture toggles `isExpanded`
3. TaskListView's gesture never fires
4. `selectedTask` remains nil
5. Action buttons hidden

#### Data Flow Verification

**Binding Chain** (working correctly):
```
TaskManagerApp.selectedTask
  └─> DetailPanelView.$selectedTask
      └─> TaskListView.$selectedTask
          └─> TaskRow.isSelected (computed value)
```

The binding infrastructure is correct. Only gesture conflict prevents selection.

---

### Issue 2: Multi-line Notes Sample Task

#### File: TaskManagerUIComponents/.../Models/TaskItem.swift

**Current sampleTasks** (lines 39-90):
- All notes are single-line strings
- No way to verify expand/collapse visual behavior

**Required**: Add sample task with multi-line notes containing newline characters (`\n`)

Example needed:
```swift
TaskItem(
    title: "Multi-line notes test",
    notes: "First paragraph of notes.\n\nSecond paragraph with more details.\n\n- Bullet point 1\n- Bullet point 2",
    // ...
)
```

---

## Root Causes

### Primary Issue
**Gesture Handler Conflict**: TaskRow implements its own tap gesture for expand/collapse, preventing TaskListView's selection gesture from executing.

### Secondary Issue
**Missing Test Data**: No sample task with multi-line notes to verify expand/collapse UX.

---

## Recommended Solutions

### Fix 1: Remove Conflicting Gesture (TaskRow.swift)

**Lines 93-97**: Delete the entire `.onTapGesture` block

**Before**:
```swift
.onTapGesture {
    withAnimation(.spring(response: 0.3)) {
        isExpanded.toggle()
    }
}
```

**After**: Remove completely

**Why**: TaskListView already handles tap for selection. Expand/collapse should either:
- Trigger on selection (auto-expand when selected)
- Use separate gesture (e.g., double-tap, long-press)
- Use dedicated expand button

---

### Fix 2: Alternative Approach - Combined Gesture

Replace TaskRow's gesture with selection + expand:

```swift
.onTapGesture {
    withAnimation(.spring(response: 0.3)) {
        // Let parent handle selection via existing gesture
        isExpanded.toggle()
    }
}
```

Then update TaskListView to NOT add gesture if TaskRow already handles it.

**Better approach**: Move all gesture logic to TaskListView, pass `isExpanded` binding to TaskRow.

---

### Fix 3: Add Multi-line Sample Task

**File**: TaskItem.swift, line 39

**Add to sampleTasks array**:
```swift
TaskItem(
    title: "Multi-line notes test",
    notes: "This task has multi-line notes to test expand/collapse.\n\nSecond paragraph here.\n\nKey points:\n- First item\n- Second item\n- Third item",
    isCompleted: false,
    isToday: false,
    priority: .medium,
    hasReminder: false,
    dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
    tags: ["testing"]
)
```

---

## Implementation Priority

| Priority | Fix | Impact | Effort |
|----------|-----|--------|--------|
| **CRITICAL** | Remove TaskRow tap gesture | Restores core selection feature | 1 line delete |
| **MEDIUM** | Add multi-line sample task | Enables expand/collapse testing | 10 lines add |
| **LOW** | Refactor gesture architecture | Cleaner long-term design | 30+ lines |

---

## Testing Recommendations

After fix, verify:

1. **Click selection**: Clicking task row selects it (background highlights, action buttons appear)
2. **Selection persistence**: Clicking different rows switches selection
3. **Expand/collapse**: Multi-line notes show/hide on click (if gesture kept)
4. **Action buttons**: All 5 buttons visible when task selected
5. **Checkbox independent**: Clicking checkbox doesn't affect selection

---

## Unresolved Questions

1. Should expand/collapse trigger on task selection, or require separate interaction?
2. Should clicking the checkbox area also select the task, or remain independent?
3. Is the current single-line `lineLimit(1)` collapse visual sufficient, or need different indicator?

---

## Files Requiring Changes

1. `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/TaskList/TaskRow.swift` (lines 93-97)
2. `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Models/TaskItem.swift` (line 39+)

---

## Related Code Locations

**Selection Flow**:
- `TaskManagerApp.swift:19` - selectedTask state
- `DetailPanelView.swift:6` - selectedTask binding
- `TaskListView.swift:6` - selectedTask binding
- `TaskListView.swift:18-20` - selection gesture (blocked)
- `TaskRow.swift:6` - isSelected computed prop
- `TaskRow.swift:72-83` - conditional action buttons

**Sample Data**:
- `TaskItem.swift:39-90` - sampleTasks array

---

**Report Generated**: 2026-02-03
**Analysis Agent**: debugger
**Status**: Root cause identified, awaiting fix implementation
