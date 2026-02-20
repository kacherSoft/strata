# TaskManagerUIComponents Code Quality Review

**Review Date:** 2026-02-20
**Package:** TaskManagerUIComponents
**Files Reviewed:** 33 Swift files
**Total LOC:** ~8,900 lines

---

## Executive Summary

The TaskManagerUIComponents package demonstrates solid SwiftUI architecture with a consistent design system (LiquidGlass) and reasonable separation of concerns. However, there are significant issues around file size violations, missing preview coverage, code duplication, and limited accessibility support that should be addressed.

**Overall Assessment:** Moderate quality with room for improvement

**Key Strengths:**
- Consistent LiquidGlass design system with light/dark mode adaptation
- Clean API design for most public components
- Proper use of `Sendable` conformance for thread safety
- Good use of SwiftUI patterns (bindings, environment, state)

**Critical Issues to Address:**
- 6 files exceed 200-line guideline (max: 462 lines)
- Zero preview providers for component development/testing
- Code duplication (priorityColor function defined twice)
- Limited accessibility support (2 accessibility labels total)

---

## Issues Found (Categorized by Severity)

### Critical Issues

#### 1. File Size Violations - Multiple Files Exceed 200 Lines

| File | Lines | Severity |
|------|-------|----------|
| `TaskRow.swift` | 462 | Critical |
| `TaskFormContent.swift` | 444 | Critical |
| `LiquidGlassModifier.swift` | 354 | High |
| `DetailPanelView.swift` | 265 | High |
| `SidebarView.swift` | 264 | High |
| `CalendarGridView.swift` | 232 | Medium |
| `PhotoViewer.swift` | 223 | Medium |
| `TaskItem.swift` | 204 | Medium |

**Impact:** Harder to maintain, review, and test. LLM tools struggle with context.

**Recommendation:** Extract sub-components and helpers into separate files.

---

### High Priority Issues

#### 2. Code Duplication: `priorityColor` Function

**Files Affected:**
- `TaskItem.swift:197` - Public function
- `PriorityIndicator.swift:19` - Private method (duplicate implementation)

```swift
// TaskItem.swift:197
public func priorityColor(_ priority: TaskItem.Priority) -> Color {
    switch priority {
    case .high: return .red
    case .medium: return .orange
    case .low: return .blue
    case .none: return .secondary.opacity(0.5)
    }
}

// PriorityIndicator.swift:19 - DUPLICATE
private func priorityColor(_ priority: TaskItem.Priority) -> Color {
    switch priority {
    case .high: return .red
    case .medium: return .orange
    case .low: return .blue
    case .none: return .clear  // Note: Different from public version!
    }
}
```

**Issue:** Inconsistent return for `.none` case (`.secondary.opacity(0.5)` vs `.clear`)

**Recommendation:** Remove private duplicate, use public function consistently.

---

#### 3. Missing Preview Providers

**Files Checked:** All 33 files
**Preview Providers Found:** 0

**Impact:** No visual regression testing during development; harder to iterate on UI components.

**Recommendation:** Add `#Preview` blocks to all public components:

```swift
#Preview {
    TaskRow(
        task: TaskItem.sampleTasks[0],
        isSelected: true
    )
}
```

---

#### 4. Complex Initializer Proliferation in TaskRow

**File:** `TaskRow.swift`

Three public initializers with overlapping parameters:
- Lines 34-63: Basic init (11 params)
- Lines 66-100: With callbacks v1 (12 params)
- Lines 102-143: With callbacks v2 (18 params)

**Issue:** 13+ closure parameters, 3 different init patterns. Unmaintainable API surface.

**Recommendation:** Use a configuration struct or builder pattern:

```swift
public struct TaskRowActions {
    var onToggleComplete: (() -> Void)?
    var onStatusChange: ((TaskItem.Status) -> Void)?
    var onEdit: ((...) -> Void)?
    // ...
}

public init(
    task: TaskItem,
    isSelected: Bool,
    actions: TaskRowActions = .init(),
    configuration: TaskRowConfiguration = .init()
)
```

---

#### 5. Accessibility Gaps

**Current Coverage:**
- `TaskFormContent.swift:216,221`: Only 2 `.accessibilityLabel` modifiers
- No `.accessibilityHint`, `.accessibilityValue`, or `.accessibilityAction`
- No accessibility identifiers for UI testing

**Files Missing Accessibility:**
- `TaskRow.swift` - Interactive status/priority buttons
- `ActionButton.swift` - Icon-only buttons need labels
- `FloatingActionButton.swift` - No accessibility label
- `SidebarRow.swift` - No accessibility for navigation
- `CalendarGridView.swift` - Date cells not accessible

**Recommendation:** Add comprehensive accessibility support:

```swift
// ActionButton.swift
Image(systemName: icon)
    .accessibilityLabel(icon) // At minimum
    .accessibilityHint("Double tap to activate")
```

---

### Medium Priority Issues

#### 6. Callback Tuple Types Are Unreadable

**Files Affected:**
- `TaskListView.swift:63`
- `TaskRow.swift:9`
- `DetailPanelView.swift:16`
- `EditTaskSheet.swift:24`
- `NewTaskSheet.swift:22`

**Example:**
```swift
let onEdit: ((TaskItem, String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL], Bool, RecurrenceRule, Int, [UUID: CustomFieldEditValue]) -> Void)?
```

**13 parameters** in a closure type. Impossible to read at call sites.

**Recommendation:** Define a struct for task edit data:

```swift
public struct TaskEditData {
    public var title: String
    public var notes: String
    public var dueDate: Date?
    public var hasReminder: Bool
    public var reminderDuration: TimeInterval
    public var priority: TaskItem.Priority
    public var tags: [String]
    public var photos: [URL]
    public var isRecurring: Bool
    public var recurrenceRule: RecurrenceRule
    public var recurrenceInterval: Int
    public var customFieldValues: [UUID: CustomFieldEditValue]
}

// Usage:
let onEdit: ((TaskItem, TaskEditData) -> Void)?
```

---

#### 7. Legacy Initializer in TaskItem

**File:** `TaskItem.swift:85-119`

Two initializers with overlapping functionality. The "legacy" init converts `isCompleted` to `status` but is not deprecated.

**Recommendation:** Mark with `@available(*, deprecated)`:

```swift
@available(*, deprecated, message: "Use init with status parameter instead")
public init(
    id: UUID = UUID(),
    ...
    isCompleted: Bool,
    ...
)
```

---

#### 8. Timer Not Cleaned Up in TaskRow

**File:** `TaskRow.swift:32`

```swift
private let countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
```

Timer runs continuously even when view is not visible.

**Recommendation:** Use `.onAppear`/`.onDisappear` to manage timer lifecycle, or use a view model.

---

#### 9. DateFormatter Created Repeatedly

**Files Affected:**
- `CalendarGridView.swift:101-104` - Inside computed property
- `CustomFieldTypes.swift:76-78,82-85` - Inside `displayValue` computed
- `DetailPanelView.swift:201-202` - Inside computed property

**Impact:** Performance hit, DateFormatter creation is expensive.

**Recommendation:** Use static formatters or inject via environment.

---

#### 10. Hardcoded Strings for UI Labels

**Examples:**
- `RecurrenceRule.displayName` - Could use `NSLocalizedString`
- `SidebarItem.title` - Hardcoded English strings
- `CalendarGridView.daysOfWeek` - Hardcoded weekday abbreviations

**Recommendation:** Use `LocalizedStringKey` for internationalization support.

---

### Low Priority Issues

#### 11. Unused `@Namespace` in PriorityPicker

**File:** `PriorityPicker.swift:20`

```swift
@Namespace private var animation
```

Namespace declared but never used in animations.

---

#### 12. Magic Numbers Without Constants

**Examples:**
- `TaskRow.swift:254`: `.font(.system(size: 20))`
- `TaskRow.swift:273`: `.font(.system(size: 13))`
- `CalendarGridView.swift:22`: `["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]`

**Recommendation:** Extract to design tokens or constants.

---

#### 13. Inconsistent Access Control

**PriorityOption** (`PriorityPicker.swift:78`) is `struct` without access modifier (internal by default), but used only internally. Consider marking `private` explicitly.

---

## Component Design Recommendations

### Reusability Improvements

1. **Extract TaskRow Sub-components:**
   - `TaskStatusButton` - Status cycle button
   - `TaskPriorityButton` - Priority cycle button
   - `TaskReminderButton` - Reminder indicator with popover
   - `TaskPhotoStrip` - Photo thumbnails display

2. **Create Configuration Types:**
   - `TaskRowStyle` - Selected/normal/compact variants
   - `TaskFormConfiguration` - Feature flags for form sections

3. **Use Environment for Shared State:**
   - `TaskManagerTheme` - Color scheme, typography
   - `DateFormatterEnvironment` - Shared date formatters

---

## Accessibility Gaps

### Components Requiring Immediate Attention

| Component | Issue | Fix |
|-----------|-------|-----|
| `ActionButton` | No accessibility label | Add label parameter |
| `FloatingActionButton` | No label | Add `accessibilityLabel` |
| `TaskRow` status button | No hint | "Cycles: Todo, In Progress, Completed" |
| `TaskRow` priority button | No hint | "Cycles priority levels" |
| `CalendarGridView` cells | Not identified | Add `accessibilityLabel` with date |
| `TagChip` | No identifier | Add accessibility identifier |
| `SidebarRow` | Navigation not accessible | Add `accessibilityAddTraits(.isButton)` |

### Recommended Accessibility Audit

```swift
// Example fix for ActionButton
public struct ActionButton: View {
    let icon: String
    var accessibilityLabel: String?
    var action: () -> Void

    public var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                // ...
        }
        .accessibilityLabel(accessibilityLabel ?? icon)
        .accessibilityHint("Double tap to activate")
    }
}
```

---

## File Size Refactoring Plan

### TaskRow.swift (462 lines) -> Split into:

```
Views/TaskList/
  TaskRow.swift           (~100 lines) - Main composition
  TaskRowStatusButton.swift   (~50 lines)
  TaskRowPriorityButton.swift (~50 lines)
  TaskRowReminderButton.swift (~100 lines)
  TaskRowMetadataView.swift   (~80 lines)
```

### TaskFormContent.swift (444 lines) -> Split into:

```
Views/Sheets/
  TaskFormContent.swift       (~100 lines) - Main form
  TaskFormCustomFields.swift  (~100 lines) - Custom field rows
  TaskFormRecurrenceSection.swift (~80 lines)
  TaskFormTagsSection.swift   (~80 lines)
```

### LiquidGlassModifier.swift (354 lines) -> Split into:

```
Modifiers/
  LiquidGlassStyle.swift      (~140 lines)
  LiquidGlassModifier.swift   (~140 lines)
  LiquidGlassStyles+Convenience.swift (~70 lines)
```

---

## Metrics Summary

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Files over 200 lines | 8 | 0 | Needs Work |
| Preview providers | 0 | 33+ | Critical |
| Accessibility coverage | ~2 labels | All interactive elements | Critical |
| Code duplication | 1 major instance | 0 | Needs Work |
| Public API consistency | Moderate | High | Needs Work |
| Type coverage | 100% | 100% | Pass |
| Sendable conformance | 100% models | 100% | Pass |

---

## Recommended Actions (Prioritized)

### Immediate (Sprint 1)
1. Add `#Preview` blocks to all 33 components
2. Remove duplicate `priorityColor` function; fix inconsistency
3. Add accessibility labels to interactive buttons

### Short Term (Sprint 2-3)
4. Refactor `TaskRow.swift` into sub-components
5. Create `TaskEditData` struct to replace 13-parameter closures
6. Add accessibility hints to complex interactions

### Medium Term (Sprint 4-6)
7. Refactor `TaskFormContent.swift` into sections
8. Extract date formatters to shared utilities
9. Add localization support for UI strings
10. Create design token constants for magic numbers

---

## Unresolved Questions

1. Should `PriorityOption` be public for external styling, or remain internal?
2. Is the timer in `TaskRow` intentional for real-time reminder countdown, or should it be event-driven?
3. Should `LiquidGlassStyle.shape` be exposed publicly for custom shapes?
4. What is the intended behavior difference between `onToggleComplete` and `onStatusChange` in TaskRow?

---

## Files Reviewed

### Models (5 files)
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Models/TaskItem.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Models/SidebarItem.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Models/RecurrenceRule.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Models/CustomFieldTypes.swift`

### Modifiers & Extensions (2 files)
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Modifiers/LiquidGlassModifier.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Extensions/View+LiquidGlass.swift`

### Components/Buttons (3 files)
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Components/Buttons/PrimaryButton.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Components/Buttons/ActionButton.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Components/Buttons/FloatingActionButton.swift`

### Components/Display (7 files)
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Components/Display/ToastView.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Components/Display/PhotoViewer.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Components/Display/PriorityIndicator.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Components/Display/CalendarGridView.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Components/Display/ProgressIndicator.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Components/Display/EmptyStateView.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Components/Display/TagChip.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Components/Display/TagCloud.swift`

### Components/Inputs (4 files)
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Components/Inputs/SearchBar.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Components/Inputs/TextareaField.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Components/Inputs/PriorityPicker.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Components/Inputs/ReminderDurationPicker.swift`

### Components/Misc (2 files)
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Components/ReminderActionPopover.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Components/Misc/MenuButton.swift`

### Main Views (8 files)
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/TaskList/TaskListView.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/TaskList/TaskRow.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Sidebar/SidebarView.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Sidebar/SidebarRow.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Detail/DetailPanelView.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Detail/HeaderView.swift`

### Sheets (4 files)
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Sheets/NewTaskSheet.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Sheets/EditTaskSheet.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Sheets/TaskFormContent.swift`
- `/TaskManagerUIComponents/Sources/TaskManagerUIComponents/Views/Sheets/QuickEntryContent.swift`
