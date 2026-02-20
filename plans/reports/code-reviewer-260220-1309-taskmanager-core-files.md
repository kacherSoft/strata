# Code Review Report: TaskManager Core Files

**Date:** 2026-02-20
**Reviewer:** code-reviewer agent
**Scope:** 7 core files (TaskManagerApp.swift, ViewModels, Services)

---

## Scope

| File | Lines | Purpose |
|------|-------|---------|
| TaskManagerApp.swift | 765 | Main app entry, ContentView, business logic |
| TaskListViewModel.swift | 119 | Task list management ViewModel |
| TaskDetailViewModel.swift | 95 | Task detail editing ViewModel |
| DataExportService.swift | 146 | JSON export/import service |
| NotificationService.swift | 261 | User notifications & alarms |
| PhotoStorageService.swift | 132 | Photo file management |
| SubscriptionService.swift | 177 | StoreKit subscription handling |

**Total LOC:** ~1,695 lines

---

## Executive Summary

The codebase demonstrates **solid SwiftUI/SwiftData architecture** with proper use of `@MainActor`, MVVM patterns, and reactive programming. However, there are **significant concerns** around the monolithic ContentView size (765 lines), inconsistent error handling, and some memory management patterns that need attention.

**Overall Grade:** B+ (Good with notable improvement areas)

---

## Critical Issues

### 1. [CRITICAL] Monolithic View with Business Logic (TaskManagerApp.swift)

**Location:** `TaskManagerApp.swift:118-764` (646 lines in ContentView)

**Problem:** The `ContentView` struct contains:
- 21+ computed properties
- 20+ private functions with business logic
- Direct model manipulation
- Timer management
- Notification handling

**Impact:**
- Violates Single Responsibility Principle
- Difficult to test
- Hard to maintain
- Exceeds 200-line guideline by 3x

**Recommendation:** Extract into separate components:
```
ContentView.swift           (~100 lines) - View composition only
TaskBusinessLogic.swift     - Task CRUD operations
ReminderCoordinator.swift   - Reminder/alarm management
TaskFilterService.swift     - Filtering logic
```

---

### 2. [CRITICAL] Silent Error Swallowing in DataExportService

**Location:** `DataExportService.swift:88-89`

```swift
} catch {
    continue  // Silent failure - no logging
}
```

**Problem:** Photo copy failures are silently ignored during export/import.

**Impact:**
- Users may lose attachments without warning
- Debugging impossible without logs
- Data integrity compromised

**Recommendation:** Add error collection and reporting:
```swift
var errors: [ExportError] = []
// ... in loop
errors.append(.photoCopyFailed(sourceURL.path))
// ... after loop
if !errors.isEmpty { /* report to user */ }
```

---

### 3. [CRITICAL] Repository Save Errors Not Propagated

**Location:** `TaskRepository.swift:173-180`

```swift
private func saveContext() {
    do {
        try modelContext.save()
        lastSaveError = nil
    } catch {
        lastSaveError = error  // Stored but never checked
    }
}
```

**Problem:** Save errors are stored in `lastSaveError` but never exposed or checked by consumers.

**Impact:** Data loss - operations appear successful but data may not persist.

**Recommendation:** Either throw errors or expose via `@Published`:
```swift
@Published var lastSaveError: Error?
// Or change methods to throw
```

---

## High Priority Issues

### 4. [HIGH] Duplicate Code: Task Creation Logic

**Locations:**
- `TaskManagerApp.swift:423-467` - `createTask()`
- `WindowManager.swift:117-206` - `createTask()`

**Problem:** Nearly identical task creation logic duplicated between ContentView and WindowManager.

**Impact:** DRY violation, maintenance burden, potential for inconsistent behavior.

**Recommendation:** Extract to shared `TaskCreationService` or extend `TaskRepository`.

---

### 5. [HIGH] Combine Memory Management

**Location:** `TaskListViewModel.swift:94-100`

```swift
private func setupSearchDebounce() {
    $searchText
        .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            self?.refresh()
        }
        .store(in: &cancellables)
}
```

**Status:** GOOD - Uses `[weak self]` correctly.

**However:** The `cancellables` set is never cleared manually. While it will be deallocated with the ViewModel, long-lived ViewModels could accumulate subscriptions if `setupSearchDebounce` is called multiple times.

---

### 6. [HIGH] Nonisolated Delegate Methods Access MainActor State

**Location:** `NotificationService.swift:203-234`

```swift
nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    ...
) {
    // ...
    Task { @MainActor in
        NotificationCenter.default.post(...)
    }
}
```

**Problem:** Delegate methods are `nonisolated` but access `@MainActor` isolated properties indirectly.

**Status:** Correctly wrapped in `Task { @MainActor in }` - this is acceptable.

---

### 7. [HIGH] SubscriptionService Deinit May Not Run

**Location:** `SubscriptionService.swift:61-63`

```swift
deinit {
    transactionListenerTask?.cancel()
}
```

**Problem:** `SubscriptionService` is a singleton (`static let shared`), so `deinit` will never run in practice. The task cancellation in deinit is unreachable code.

**Impact:** Minimal (singleton lives for app lifetime), but misleading.

**Recommendation:** Either:
- Remove the dead code
- Add a `cleanup()` method for testing scenarios

---

### 8. [HIGH] Implicitly Unwrapped Optional ModelContainer

**Location:** `TaskManagerApp.swift:71`

```swift
let container: ModelContainer?
```

**Problem:** Optional container handled with fallback to in-memory, but `ContentView` just shows error text if nil.

**Impact:** Poor user experience - no guidance on fixing storage issues.

**Recommendation:** Add actionable error message or retry mechanism.

---

## Medium Priority Issues

### 9. [MEDIUM] Hardcoded Magic Values

**Locations:**
- `TaskManagerApp.swift:139` - Timer interval `every: 1`
- `TaskManagerApp.swift:16` - `deadline: .now() + 0.5`
- `SubscriptionService.swift:47` - Product IDs hardcoded

**Recommendation:** Extract to named constants:
```swift
private enum Constants {
    static let reminderCheckInterval: TimeInterval = 1
    static let settingsApplyDelay: TimeInterval = 0.5
}
```

---

### 10. [MEDIUM] Unused ViewModel Pattern

**Location:** `TaskDetailViewModel.swift`

**Problem:** `TaskDetailViewModel` exists but `ContentView` directly manipulates `TaskModel` without using ViewModels.

**Impact:** Inconsistent architecture - some views use ViewModels, others bypass them.

**Recommendation:** Either:
- Use ViewModels consistently
- Remove unused ViewModels
- Document when each pattern applies

---

### 11. [MEDIUM] Notification.Name Extensions in Wrong File

**Location:** `NotificationService.swift:256-260`

```swift
extension Notification.Name {
    static let taskCompletedFromNotification = ...
}
```

**Problem:** Notification names defined in service file, but used across multiple files.

**Recommendation:** Move to `Notification+Names.swift` in a shared location.

---

### 12. [MEDIUM] Security: File Path Validation

**Location:** `PhotoStorageService.swift:97-102`

```swift
func deletePhoto(at path: String) {
    let url = URL(fileURLWithPath: path)
    try fileManager.removeItem(at: url)
}
```

**Problem:** No validation that path is within expected photos directory.

**Impact:** Potential for path traversal if called with arbitrary paths.

**Recommendation:** Add path validation:
```swift
guard url.standardizedFileURL.path.hasPrefix(photosDirectory.path) else { return }
```

---

### 13. [MEDIUM] Inconsistent Error Handling Patterns

**Problem:** Three different patterns used:
1. `try?` silently ignores errors
2. `do-catch` stores errors
3. `throws` propagates errors

**Examples:**
- `PhotoStorageService.swift:87-89` - Silent `continue`
- `TaskRepository.swift:173-179` - Store in property
- `DataExportService.swift:39` - Throw to caller

**Recommendation:** Standardize on a consistent error handling strategy.

---

## Low Priority Issues

### 14. [LOW] Missing Access Control

**Locations:**
- `TaskModel.swift:30-33` - `status` computed property could be private setter
- `NotificationService.swift:20-26` - `availableSounds` should be `static let`

---

### 15. [LOW] TaskPriority Mapping Inconsistency

**Location:** `TaskModel+TaskItem.swift:96-103`

```swift
func toUIComponentPriority() -> TaskItem.Priority {
    switch self {
    case .critical, .high: return .high  // Critical maps to high
    case .medium: return .medium
    case .low: return .low
    case .none: return .none
    }
}
```

**Problem:** `.critical` is collapsed to `.high`, losing granularity in the UI layer.

**Impact:** Minor - critical tasks don't display distinctively.

---

### 16. [LOW] Verbose onChange Syntax

**Location:** `TaskManagerApp.swift:160-188`

```swift
.onChange(of: selectedTag) { _, newValue in
```

**Problem:** Using old/new syntax but ignoring old value consistently.

**Recommendation:** Simplify to `.onChange(of: selectedTag) { newValue in` when old value unused.

---

## Edge Cases Found by Scout

### E1. Race Condition: Reminder Timer vs Task Completion

**Location:** `TaskManagerApp.swift:713-742` vs `toggleComplete()`

**Scenario:**
1. Reminder fires at `t=0`
2. User completes task at `t=0.1`
3. `monitorReminderTimers()` still sees task as incomplete momentarily

**Impact:** Alarm may start after task is completed.

**Recommendation:** Check completion status inside `startAlarm` or add synchronization.

---

### E2. Photo Storage Directory Fallback

**Location:** `PhotoStorageService.swift:11-24`

```swift
if !fileManager.fileExists(atPath: photosDir.path) {
    do {
        try fileManager.createDirectory(...)
    } catch {
        return fileManager.temporaryDirectory  // Silent fallback
    }
}
```

**Problem:** Falls back to temporary directory without warning - photos may be lost on app termination.

**Impact:** Data loss risk.

---

### E3. Import Overwrites Without Confirmation

**Location:** `DataExportService.swift:92-106`

**Problem:** Importing data overwrites existing tasks with matching IDs without user confirmation.

**Impact:** Unintentional data overwrite.

---

### E4. Recurring Task Spawn Logic

**Location:** `TaskManagerApp.swift:499-524`

**Edge Case:** If task is moved from completed back to in-progress multiple times, `isRecurring = false` prevents duplicate spawns, but what if user wants to re-enable recurrence?

---

## Positive Observations

1. **Excellent @MainActor Usage** - All UI-bound services and ViewModels properly isolated
2. **Proper Singleton Pattern** - Services use `static let shared` with `private init()`
3. **SwiftData Integration** - Clean use of `@Query`, `@Model`, and `FetchDescriptor`
4. **StoreKit Best Practices** - Transaction verification, proper finishing
5. **Combine Integration** - Search debounce with proper memory management
6. **Security-Scoped Resources** - Proper sandbox access for photos
7. **Type Safety** - Enums for priority, status, filter types
8. **Codable DTOs** - Clean export/import structure with versioning

---

## Metrics

| Metric | Value |
|--------|-------|
| Files Reviewed | 7 |
| Total Lines | ~1,695 |
| Critical Issues | 3 |
| High Issues | 5 |
| Medium Issues | 5 |
| Low Issues | 4 |
| Edge Cases | 4 |
| Files > 200 Lines | 1 (TaskManagerApp.swift: 765) |

---

## Recommended Actions

### Immediate (Critical - Fix This Sprint)
1. Refactor ContentView into smaller components (break down 646-line view)
2. Fix silent error swallowing in DataExportService
3. Expose Repository save errors to callers

### Short-term (High - Next Sprint)
4. Extract duplicate task creation logic to shared service
5. Add path validation in PhotoStorageService.deletePhoto
6. Standardize error handling pattern

### Medium-term (Medium - Backlog)
7. Move Notification.Name extensions to shared file
8. Extract magic values to constants
9. Document ViewModel usage pattern

### Low Priority (Technical Debt)
10. Add access control modifiers
11. Consider adding `.critical` support in UI
12. Clean up dead code in SubscriptionService deinit

---

## File Size Analysis

| File | Lines | Status | Action |
|------|-------|--------|--------|
| TaskManagerApp.swift | 765 | **Exceeds limit** | Refactor |
| NotificationService.swift | 261 | OK | - |
| TaskListViewModel.swift | 119 | OK | - |
| SubscriptionService.swift | 177 | OK | - |
| PhotoStorageService.swift | 132 | OK | - |
| DataExportService.swift | 146 | OK | - |
| TaskDetailViewModel.swift | 95 | OK | - |

---

## Unresolved Questions

1. Should `TaskDetailViewModel` be used or removed? Currently exists but not used in ContentView.
2. What is the intended behavior for re-enabling recurrence on completed recurring tasks?
3. Should import overwrite require explicit user confirmation?
4. Is the 0.5s delay for settings application intentional or a workaround for a timing issue?

---

## Conclusion

The TaskManager codebase shows **competent SwiftUI/SwiftData development** with proper architectural patterns. The main concern is the **monolithic ContentView** which has grown beyond reasonable maintainability. The services are well-structured as singletons with proper actor isolation.

Priority should be given to:
1. **Breaking down ContentView** into smaller, focused components
2. **Improving error visibility** rather than silent swallowing
3. **Reducing code duplication** between ContentView and WindowManager

The code is **production-ready** but would benefit from refactoring to improve maintainability and testability.
