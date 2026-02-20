# TaskManager Comprehensive Code Review

**Date:** 2026-02-20
**Review Type:** Full Codebase Review
**Scope:** 81 Swift files, ~12,000+ LOC
**Agents Used:** 5 code-reviewer + 2 researcher agents

---

## Executive Summary

The TaskManager codebase demonstrates **solid SwiftUI/SwiftData architecture** with proper actor isolation, clean provider patterns, and reasonable separation of concerns. However, there are several critical areas requiring immediate attention.

| Category | Score |
|----------|-------|
| Architecture | 8/10 |
| Code Quality | 6/10 |
| Security | 7/10 |
| Performance | 5.5/10 |
| Testability | 2/10 |
| Accessibility | 2/10 |
| **Overall** | **5.5/10** |

*Validated by Oracle review - scores adjusted for accuracy.*

---

## Critical Issues (Fix Immediately)

### 1. Monolithic Files Violating 200-Line Guideline

| File | Lines | Action |
|------|-------|--------|
| `EnhanceMeView.swift` | **921** | Split into 5+ files |
| `TaskManagerApp.swift` | **765** | Extract ContentView (~646 lines) |
| `TaskRow.swift` | **462** | Extract sub-components |
| `TaskFormContent.swift` | **444** | Modularize form sections |
| `LiquidGlassModifier.swift` | **354** | Extract helpers |

**Impact:** Unmaintainable, difficult to test, poor LLM tool compatibility.

### 2. Silent Error Swallowing (Data Loss Risk)

**Locations:**
- `TaskRepository.swift:173-180` - Save errors stored but never exposed
- `AIModeRepository.swift:62-69` - Same issue
- `DataExportService.swift:88-89` - Photo copy failures ignored
- `AIService.swift:38-48, 65-67, 85-87` - Mode persistence failures silent
- `WindowManager.swift:201-205` - Task save failures silent

**Fix:**
```swift
// Add to repositories
@Published var lastSaveError: Error?

// Or change methods to throw
func save() throws { ... }
```

### 3. Duplicate Enum Definition (DRY Violation)

**Files:**
- `SettingsModel.swift:34-44` - `AIProvider`
- `AIModeModel.swift:4-43` - `AIProviderType`

Both enums have identical raw values (`gemini`, `zai`) but different capabilities.

**Fix:** Consolidate to single `AIProviderType` enum.

---

## High Priority Issues

### 4. In-Memory Filtering Performance

**File:** `TaskRepository.swift:31-51`

All tasks fetched then filtered in-memory - scales poorly.

**Fix:** Use `#Predicate` for database-level filtering:
```swift
var descriptor = FetchDescriptor<TaskModel>(
    predicate: #Predicate { task in
        task.status == filter.status
    }
)
```

### 5. Missing SwiftData Relationships

`CustomFieldValueModel` uses UUID references instead of `@Relationship`:
- No cascade delete
- No referential integrity
- Manual join logic required

### 6. Timer/Task Memory Leaks

**Files:**
- `TaskRow.swift:32` - `countdownTimer` autoconnects but has no `onDisappear` cleanup
- `WindowManager.swift:10-12` - NSPanels retained indefinitely

**Fix:** Add `.onDisappear { }` to cancel timers and add NSWindowDelegate.

### 7. Zero Test Coverage

- AI Module: **0%**
- UI Components: **No preview providers**
- No unit tests found

### 8. Duplicate Code

| Code | Locations |
|------|-----------|
| Task creation logic | `TaskManagerApp.swift:423-467`, `WindowManager.swift:117-206` |
| `priorityColor` function | `TaskItem.swift:197`, `PriorityIndicator.swift:19` |
| Settings row pattern | 10+ occurrences across settings views |

---

## Medium Priority Issues

### 9. Security: Path Traversal Risk

**File:** `PhotoStorageService.swift:97-102`

```swift
func deletePhoto(at path: String) {
    // No validation that path is within photos directory
    // Note: isStoredPhoto() method exists but is NOT called here
}
```

**Fix:**
```swift
func deletePhoto(at path: String) {
    let url = URL(fileURLWithPath: path)
    guard isStoredPhoto(url) else { return }  // One-line fix
    try? fileManager.removeItem(at: url)
}
```

### 10. Missing Input Validation

- Empty task titles allowed
- Negative recurrence intervals possible
- No text length validation before AI API calls

### 11. @unchecked Sendable Risk

Both AI providers use `@unchecked Sendable` with mutable state via KeychainService.

### 12. Legacy Properties Not Removed

`TaskModel.budget`, `TaskModel.client`, `TaskModel.effort` remain after migration to CustomFieldValueModel.

### 13. Missing Rate Limiting

No proactive throttling for AI API calls - only reactive 429 handling.

---

## Low Priority Issues

| Issue | Location |
|-------|----------|
| Hardcoded magic values | Multiple files |
| Unused ViewModel | `TaskDetailViewModel.swift` |
| Dead code | `GeminiProvider.swift:122-141` (extractPDFText) |
| Singleton deinit unreachable | `SubscriptionService.swift:61-63` |
| Missing accessibility labels | 5 labels across 33 UI files (still critical) |
| Hardcoded UserDefaults keys | `appearanceMode`, `hasCompletedOnboarding`, `debug_vip_granted` |

---

## Positive Observations

1. **Excellent @MainActor usage** - Proper actor isolation throughout
2. **Clean provider pattern** - Easy to add new AI providers
3. **Secure Keychain implementation** - API keys properly protected
4. **SwiftData integration** - Clean @Query, @Model usage
5. **StoreKit best practices** - Transaction verification, proper finishing
6. **Type safety** - Enums for priority, status, filters
7. **Codable DTOs** - Clean export/import with versioning
8. **Consistent code style** - Naming conventions uniform

---

## Recommended Actions

### Immediate (This Sprint)
1. [x] Refactor `EnhanceMeView.swift` (921 → 200 lines) ✅ DONE
2. [x] Refactor `TaskManagerApp.swift` ContentView (646 → separate components) ✅ DONE
3. [ ] Expose repository save errors to callers
4. [ ] Consolidate `AIProvider`/`AIProviderType` enums
5. [ ] Add path validation to `PhotoStorageService.deletePhoto()`
6. [ ] Add timer cleanup to `TaskRow.swift`
7. [ ] Extract UserDefaults keys to constants

### Short-term (Next Sprint)
5. [ ] Add predicates for database-level filtering
6. [ ] Add path validation in PhotoStorageService
7. [ ] Extract duplicate task creation logic
8. [ ] Add rate limiting to AI providers
9. [ ] Add preview providers to UI components

### Medium-term (Backlog)
10. [ ] Migrate to SwiftData relationships (from UUID refs)
11. [ ] Remove legacy budget/client/effort properties
12. [ ] Add comprehensive accessibility support
13. [ ] Create repository protocols for testability
14. [ ] Add unit tests for critical paths

---

## Metrics Summary

| Metric | Value |
|--------|-------|
| Total Files Reviewed | 81 |
| Total LOC | ~12,000+ |
| Files > 200 Lines | 8 |
| Critical Issues | 3 |
| High Priority Issues | 8 |
| Medium Priority Issues | 6 |
| Low Priority Issues | 5+ |
| Test Coverage | ~0% |
| Preview Coverage | 0% |

---

## Unresolved Questions

1. Should `CustomFieldValueModel` use SwiftData relationships or keep UUID refs?
2. Is priority simplification (losing `.critical`) intentional?
3. When should legacy properties be removed from TaskModel?
4. Should import overwrite require explicit user confirmation?

---

## Generated Reports

| Report | Path |
|--------|------|
| Core Files Review | `plans/reports/code-reviewer-260220-1309-taskmanager-core-files.md` |
| Data Layer Review | `plans/reports/code-reviewer-260220-1309-data-layer-review.md` |
| AI Module Review | `plans/reports/code-reviewer-260220-1309-ai-module-review.md` |
| UI Components Review | `plans/reports/code-reviewer-260220-1309-uicomponents-quality-review.md` |
| Views & Windows Review | `plans/reports/code-reviewer-260220-1309-views-windows-quality-review.md` |
| SwiftUI Best Practices | `plans/reports/researcher-260220-1309-swiftui-macos-best-practices.md` |
| SwiftData Patterns | `plans/reports/researcher-260220-1309-swifdata-patterns.md` |

---

## Conclusion

The TaskManager codebase shows **competent SwiftUI/SwiftData development** with proper architectural patterns. The main concerns are:

1. **File size violations** - Several files severely exceed 200-line guideline
2. **Silent error handling** - Risk of data loss without user awareness
3. **Zero test coverage** - No automated quality gates (score: 2/10)
4. **Limited accessibility** - 5 labels across entire UI package (score: 2/10)
5. **Security gaps** - Path traversal risk, hardcoded keys

Priority should be given to refactoring large files and fixing silent error handling before adding new features.

**Production-ready but needs refactoring for maintainability.**
