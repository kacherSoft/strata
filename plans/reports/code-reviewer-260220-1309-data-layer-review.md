# Code Review: TaskManager Data Layer

**Review Date:** 2026-02-20
**Reviewer:** code-reviewer subagent
**Scope:** Data layer (models, repositories, extensions)

## Scope

| Files Reviewed | LOC |
|----------------|-----|
| ModelContainer+Config.swift | 149 |
| TaskModel.swift | 155 |
| SettingsModel.swift | 45 |
| AIModeModel.swift | 98 |
| CustomFieldDefinitionModel.swift | 41 |
| CustomFieldValueModel.swift | 26 |
| RecurrenceRule.swift | 57 |
| ViewMode.swift | 21 |
| TaskRepository.swift | 181 |
| AIModeRepository.swift | 71 |
| TaskModel+TaskItem.swift | 113 |
| **Total** | **957** |

## Executive Summary

The TaskManager data layer demonstrates **solid foundational architecture** with proper SwiftData model design, separation of concerns via repositories, and appropriate use of Swift conventions. The codebase is well-organized with reasonable file sizes (all under 200 LOC).

**Overall Quality Score: 7.5/10**

Key strengths:
- Clean separation between persistence models and UI models
- Proper use of raw value wrappers for enums in SwiftData
- Migration support for custom fields
- Sendable conformance for thread-safe value types

Key concerns:
- Silent error swallowing in repositories
- In-memory filtering inefficient for large datasets
- Duplicate enum definitions (AIProvider vs AIProviderType)
- Missing relationship definitions between models
- No query optimization for filtered fetches

---

## Critical Issues (Severity: High)

### 1. Silent Error Swallowing in Repositories

**Files:**
- `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Data/Repositories/TaskRepository.swift:173-180`
- `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Data/Repositories/AIModeRepository.swift:62-69`

**Problem:** The `saveContext()` method catches and stores errors but never surfaces them to callers. Operations appear to succeed even when persistence fails, risking silent data loss.

```swift
private func saveContext() {
    do {
        try modelContext.save()
        lastSaveError = nil
    } catch {
        lastSaveError = error  // Error stored but never exposed!
    }
}
```

**Impact:** Data loss, debugging difficulty, inconsistent state.

**Recommendation:**
1. Expose `lastSaveError` as `@Published` property
2. Add `throws` variants for critical operations
3. Consider adding `saveWithErrorLogging()` that logs to console in DEBUG

---

### 2. Duplicate Enum Definitions (AIProvider)

**Files:**
- `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Data/Models/SettingsModel.swift:34-44` (AIProvider)
- `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Data/Models/AIModeModel.swift:4-43` (AIProviderType)

**Problem:** Two nearly identical enums exist for AI providers. `AIProvider` in SettingsModel is simpler, while `AIProviderType` in AIModeModel has more capabilities. This violates DRY and creates maintenance burden.

```swift
// SettingsModel.swift
enum AIProvider: String, Codable, CaseIterable, Sendable {
    case gemini = "gemini"
    case zai = "zai"
    // displayName only
}

// AIModeModel.swift
enum AIProviderType: String, Codable, CaseIterable, Sendable {
    case gemini = "gemini"
    case zai = "zai"
    // displayName, availableModels, defaultModel, supports* methods
}
```

**Impact:** Confusion, potential inconsistency, maintenance overhead.

**Recommendation:** Consolidate to single `AIProviderType` enum. If SettingsModel needs simpler subset, add computed property or type alias.

---

## High Priority Issues

### 3. In-Memory Filtering Performance

**File:** `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Data/Repositories/TaskRepository.swift:31-51`

**Problem:** All tasks are fetched first, then filtered in-memory. This approach scales poorly and negates SwiftData's query optimization.

```swift
func fetchAll(...) throws -> [TaskModel] {
    var descriptor = FetchDescriptor<TaskModel>()
    descriptor.sortBy = sortDescriptors(for: sortOrder)
    var tasks = try modelContext.fetch(descriptor)  // ALL tasks fetched

    tasks = applyFilter(tasks, filter: filter)      // In-memory filter
    if !searchText.isEmpty {
        tasks = applySearch(tasks, searchText: searchText)  // In-memory search
    }
    // ...
}
```

**Impact:** Memory pressure, slow performance with many tasks.

**Recommendation:** Build predicates into FetchDescriptor where possible. For complex filters, consider:
1. Using `#Predicate` for database-level filtering
2. Compound predicates for combined conditions
3. Full-text search integration for text search

---

### 4. Missing Model Relationships

**Files:**
- TaskModel, CustomFieldDefinitionModel, CustomFieldValueModel

**Problem:** SwiftData relationships are not defined. The `CustomFieldValueModel` uses UUID references instead of proper relationships:

```swift
// CustomFieldValueModel.swift - uses IDs instead of relationships
var definitionId: UUID
var taskId: UUID
```

**Impact:** No cascade delete, no referential integrity, manual join logic required.

**Recommendation:** Consider adding SwiftData relationships:

```swift
@Model
final class CustomFieldValueModel {
    @Attribute(.unique) var id: UUID
    @Relationship(deleteRule: .cascade, inverse: \CustomFieldDefinitionModel.values)
    var definition: CustomFieldDefinitionModel?
    @Relationship(deleteRule: .cascade, inverse: \TaskModel.customFieldValues)
    var task: TaskModel?
    // ...
}
```

Note: This requires migration planning but improves data integrity.

---

### 5. Legacy Properties Remain After Migration

**File:** `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Data/Models/TaskModel.swift:23-25`

**Problem:** The migration in ModelContainer+Config moves data from `budget`, `client`, `effort` to CustomFieldValueModel, but the legacy properties remain on TaskModel:

```swift
var budget: Decimal?
var client: String?
var effort: Double?
```

**Impact:** Confusion, potential data inconsistency, storage overhead.

**Recommendation:** Either:
1. Remove these properties after migration is complete (requires version migration)
2. Mark as `@Attribute(.transient)` if kept for backward compatibility
3. Add deprecation comments and removal timeline

---

### 6. Priority Mapping Information Loss

**File:** `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Extensions/TaskModel+TaskItem.swift:95-103`

**Problem:** Converting from TaskPriority to UIComponentPriority loses distinction between `critical` and `high`:

```swift
func toUIComponentPriority() -> TaskItem.Priority {
    switch self {
    case .critical, .high: return .high  // Information lost!
    case .medium: return .medium
    case .low: return .low
    case .none: return .none
    }
}
```

And the reverse mapping never produces `.critical`:

```swift
static func from(_ priority: TaskItem.Priority) -> TaskPriority {
    switch priority {
    case .high: return .high  // Never produces .critical
    // ...
    }
}
```

**Impact:** Critical tasks lose priority distinction when round-tripping.

**Recommendation:** Either:
1. Add `.critical` to UIComponentPriority
2. Use separate flag for critical tasks
3. Document this as intentional simplification

---

## Medium Priority Issues

### 7. No Input Validation on Model Properties

**Files:**
- TaskModel.swift
- AIModeModel.swift
- CustomFieldDefinitionModel.swift

**Problem:** Models accept any input without validation. Examples:
- Empty task titles allowed
- Negative recurrence intervals
- Empty/whitespace-only names

**Current mitigation:** TaskModel.init handles `client` whitespace but not title:
```swift
// TaskModel.swift:80 - client is trimmed but title is not
self.client = client?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
    ? nil : client?.trimmingCharacters(in: .whitespacesAndNewlines)
```

**Recommendation:**
1. Add validation in initializers
2. Use SwiftData `@Attribute(.checks)` if available
3. Add `validate()` methods for pre-save checks

---

### 8. RecurrenceRule Weekdays Could Be Optimized

**File:** `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Data/Models/RecurrenceRule.swift:43-54`

**Problem:** The weekdays recurrence iterates day-by-day which is O(n) for interval days:

```swift
case .weekdays:
    var next = date
    var weekdayCount = 0
    while weekdayCount < safeInterval {
        next = calendar.date(byAdding: .day, value: 1, to: next) ?? next
        let weekday = calendar.component(.weekday, from: next)
        if weekday != 1 && weekday != 7 {  // Not Sat/Sun
            weekdayCount += 1
        }
    }
    return next
```

**Impact:** Minor performance issue for large intervals.

**Recommendation:** Optimize with calendar math:
```swift
// Calculate weeks needed then adjust for weekends
let weeksNeeded = safeInterval / 5
let remainingDays = safeInterval % 5
var next = calendar.date(byAdding: .weekOfYear, value: weeksNeeded, to: date) ?? date
// Then add remainingDays skipping weekends...
```

---

### 9. Repository Uses @MainActor Redundantly

**File:** `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Data/Repositories/TaskRepository.swift:22`

**Problem:** Repository is marked `@MainActor` but ModelContext is already MainActor-isolated in typical SwiftUI usage:

```swift
@MainActor
final class TaskRepository: ObservableObject {
```

**Impact:** Not a bug, but redundant and may restrict future architecture changes.

**Recommendation:** Consider making repository actor-agnostic and accepting MainActor context as parameter. This improves testability.

---

### 10. Hardcoded Model Names in Migration

**File:** `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Data/ModelContainer+Config.swift:127-129`

**Problem:** Migration uses hardcoded string comparisons:

```swift
let budgetDef = definitions.first { $0.name == "Budget" && $0.valueType == .currency }
let clientDef = definitions.first { $0.name == "Client" && $0.valueType == .text }
let effortDef = definitions.first { $0.name == "Effort" && $0.valueType == .number }
```

**Impact:** Brittle if field names change, localization issues.

**Recommendation:** Use constants or enum-backed identifiers for field definitions.

---

## Low Priority Issues

### 11. Inconsistent Timestamp Handling

**Files:**
- SettingsModel.swift:29-31
- TaskModel.swift:116-118
- CustomFieldDefinitionModel.swift:29-31

**Problem:** All have `touch()` method but implementations vary slightly in intent. SettingsModel has `createdAt` but it's always set to current date in init (semantically odd for "settings created at").

---

### 12. Magic Numbers in Code

**File:** `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Data/Models/TaskModel.swift:11`

```swift
var reminderDuration: Double = 1800  // What unit? Seconds? Minutes?
```

**Recommendation:** Add constant or comment clarifying it's seconds (30 minutes).

---

### 13. Unused Property in TaskRepository

**File:** `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Data/Repositories/TaskRepository.swift:25`

```swift
private var lastSaveError: Error?
```

**Problem:** Property stored but never read or exposed.

---

## Positive Observations

1. **Clean Enum Design:** Enums use raw values for persistence, computed properties for display, and proper Sendable conformance

2. **Proper SwiftData Patterns:** @Attribute(.unique) on IDs, computed property wrappers for enums, final class usage

3. **Mapping Layer:** Extension file cleanly separates persistence models from UI models, enabling future model changes without UI impact

4. **Migration Support:** One-time migration exists for custom fields, handling the transition from direct properties to flexible value model

5. **Testable Design:** In-memory fallback container provided for testing scenarios

6. **Consistent Code Style:** Naming conventions, indentation, and structure are consistent across all files

7. **Repository Pattern:** Clean separation of data access from business logic

---

## Repository Pattern Compliance

| Criterion | Status | Notes |
|-----------|--------|-------|
| Single Responsibility | Pass | Repositories handle only data operations |
| Abstraction | Partial | Direct SwiftData exposure, no protocol |
| Error Handling | Fail | Silent error swallowing |
| Testability | Partial | In-memory support exists, but no protocol |
| CRUD Operations | Pass | Create, Read, Update, Delete all present |
| Query Encapsulation | Partial | Some filtering done in-memory post-fetch |

**Recommendation:** Consider adding `TaskRepositoryProtocol` for dependency injection and testing.

---

## Metrics Summary

| Metric | Value |
|--------|-------|
| Total LOC | 957 |
| Largest File | TaskRepository.swift (181 lines) |
| Model Files | 6 |
| Repository Files | 2 |
| Enum Definitions | 6 |
| Silent Error Points | 2 |
| DRY Violations | 1 (AIProvider duplication) |

---

## Recommended Actions (Prioritized)

### Immediate (Critical)
1. [ ] Expose repository errors - add `@Published var lastError: Error?` and/or throwing variants
2. [ ] Consolidate AIProvider/AIProviderType into single enum

### Short-term (High)
3. [ ] Add predicates to FetchDescriptor for database-level filtering
4. [ ] Decide on model relationships vs UUID references (document decision)
5. [ ] Plan removal or deprecation of legacy budget/client/effort properties

### Medium-term
6. [ ] Add input validation to model initializers
7. [ ] Create repository protocols for testability
8. [ ] Optimize RecurrenceRule.weekdays calculation
9. [ ] Document priority mapping decision

### Low Priority
10. [ ] Extract magic numbers to constants
11. [ ] Remove or use `lastSaveError` property
12. [ ] Add deprecation comments to migration code

---

## Unresolved Questions

1. **Relationship Strategy:** Should the app migrate to proper SwiftData relationships, or is the UUID reference pattern intentional for some reason (e.g., cross-container references, specific performance needs)?

2. **Priority Simplification:** Is the loss of `.critical` priority when mapping to UI component intentional, or should the UI model support it?

3. **Legacy Property Timeline:** When should `budget`, `client`, `effort` properties be removed from TaskModel?

4. **Error Strategy:** Should repositories throw, publish errors, or use Result types? Current mix of `throws` on fetch but silent failure on save is inconsistent.

---

## Files Reviewed (Full Paths)

```
/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Data/ModelContainer+Config.swift
/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Data/Models/TaskModel.swift
/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Data/Models/SettingsModel.swift
/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Data/Models/AIModeModel.swift
/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Data/Models/CustomFieldDefinitionModel.swift
/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Data/Models/CustomFieldValueModel.swift
/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Data/Models/RecurrenceRule.swift
/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Data/Models/ViewMode.swift
/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Data/Repositories/TaskRepository.swift
/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Data/Repositories/AIModeRepository.swift
/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Extensions/TaskModel+TaskItem.swift
```
