# Data Loss Investigation Report
**Date:** 2026-03-10
**Scope:** Strata macOS app — complete data loss after ~3-4 weeks of use
**Investigator:** Debugger agent

---

## Executive Summary

The user lost ALL task data. There is not a single root cause — there are **two independent data loss vectors** that both hit within the same 4-day window (Feb 15–19). Either one alone could wipe the user's data. Together, they guarantee it.

**Root Cause 1 (PRIMARY — CONFIRMED DATA ERASURE):** The app bundle identifier changed from `com.kachersoft.TaskManager` → `com.kachersoft.CyberTasks` on Feb 18 (commit `254fb68`). SwiftData uses the bundle ID to locate the on-disk store. A new bundle ID means the app opens a brand-new, empty store at a different path. All prior data becomes invisible to the app — not deleted from disk, but permanently abandoned.

**Root Cause 2 (SECONDARY — SILENT IN-MEMORY FALLBACK):** On Feb 15 (commit `ff49299`), `fatalError()` on container init failure was replaced with a silent in-memory fallback. Combined with 4 unversioned schema changes between Feb 6–19, any app update that triggered a schema mismatch would silently boot into an empty in-memory store, losing ALL data from that session with no error shown to the user.

---

## Files Involved in Data Persistence

| File | Role |
|---|---|
| `TaskManager/Sources/TaskManager/Data/ModelContainer+Config.swift` | Container init, schema definition, seeding |
| `TaskManager/Sources/TaskManager/TaskManagerApp.swift` (lines 96–111) | Container creation with fallback logic |
| `TaskManager/Sources/TaskManager/Data/Models/TaskModel.swift` | Primary data model |
| `TaskManager/Sources/TaskManager/Data/Models/AIModeModel.swift` | AI mode data model |
| `TaskManager/Sources/TaskManager/Data/Models/SettingsModel.swift` | Settings model |
| `TaskManager/Sources/TaskManager/Data/Models/CustomFieldDefinitionModel.swift` | Custom fields model (added Feb 19) |
| `TaskManager/Sources/TaskManager/Data/Models/CustomFieldValueModel.swift` | Custom field values model (added Feb 19) |
| `TaskManager/project.yml` | Defines `PRODUCT_BUNDLE_IDENTIFIER` — controls store file location |

No `VersionedSchema`, no `SchemaMigrationPlan`, no `storeURL` override exists anywhere in the codebase.

---

## Git History Timeline — All Schema and Persistence Changes

### Feb 4 (dff15cb) — Initial SwiftData implementation
- `TaskModel` created with: `id, title, taskDescription, dueDate, reminderDate, priority, tags, isCompleted, completedDate, isToday, hasReminder, photos, createdAt, updatedAt, sortOrder`
- Schema: `[TaskModel, AIModeModel, SettingsModel]`
- Container init: `fatalError()` on failure (app crashes instead of silently losing data)
- **Store path:** No xcodeproj yet — app run via `swift run`, no bundle ID, data location varies

### Feb 6 (aa239f1) — SCHEMA BREAK #1
- `TaskModel` changes:
  - REMOVED: `isCompleted: Bool`, `completedDate: Date?`
  - ADDED: `statusRaw: String = TaskStatus.todo.rawValue`, `completedAt: Date?`
- No migration plan. SwiftData cannot automatically migrate column renames of this kind.
- **Impact:** Any existing store from Feb 4 is now incompatible. However, app likely ran via `swift run` at this point (no `.xcodeproj` yet), so store location may have been ephemeral.

### Feb 13 (e4f2b41) — SCHEMA BREAK #2
- `TaskModel` changes:
  - ADDED: `reminderDuration: Double = 1800`, `reminderFireDate: Date? = nil`
- SwiftData CAN add nullable/defaulted columns without migration, so this is low-risk for an existing store.

### Feb 15 (ff49299) — FALLBACK INTRODUCED + First xcodeproj
- **Critical behavior change in `TaskManagerApp.swift` lines 96–111:**
  ```swift
  // BEFORE (dff15cb):
  container = try ModelContainer.configured()  // fatalError() on failure

  // AFTER (ff49299):
  do {
      let configured = try ModelContainer.configured()
      resolvedContainer = configured
  } catch {
      // SILENT — falls back to in-memory store
      let fallback = try ModelContainer.inMemoryFallback()
      resolvedContainer = fallback
  }
  ```
- `project.yml` added with `PRODUCT_BUNDLE_IDENTIFIER: com.kachersoft.TaskManager`
- SwiftData store now at: `~/Library/Application Support/com.kachersoft.TaskManager/default.store`
- `inMemoryFallback()` added to `ModelContainer+Config.swift`

### Feb 18 (254fb68) — SCHEMA BREAK #3 + **BUNDLE ID CHANGE**
- `TaskModel` changes:
  - ADDED: `isRecurring: Bool = false`, `recurrenceRuleRaw: String?`, `recurrenceInterval: Int = 1`, `budget: Decimal?`, `client: String?`, `effort: Double?`
- `AIModeModel` changes:
  - ADDED: `supportsAttachments: Bool = false`
- **`project.yml` bundle ID changed:**
  ```yaml
  # BEFORE:
  PRODUCT_BUNDLE_IDENTIFIER: com.kachersoft.TaskManager
  # AFTER:
  PRODUCT_BUNDLE_IDENTIFIER: com.kachersoft.CyberTasks
  ```
- **New store path:** `~/Library/Application Support/com.kachersoft.CyberTasks/default.store`
- All data from `com.kachersoft.TaskManager` store is now inaccessible — app opens empty.

### Feb 19 (c501299) — SCHEMA BREAK #4
- `CustomFieldDefinitionModel` and `CustomFieldValueModel` added to schema
- Any store opened with the previous 3-model schema now fails to open with 5-model schema
- `ModelContainer+Config.swift` schema:
  ```swift
  // BEFORE: [TaskModel, AIModeModel, SettingsModel]
  // AFTER:  [TaskModel, AIModeModel, SettingsModel, CustomFieldDefinitionModel, CustomFieldValueModel]
  ```
- Combined with the silent fallback (from Feb 15), this triggers: container init throws → fallback to in-memory → user sees empty app, all new data is lost on quit.

---

## Root Cause Analysis

### Root Cause 1: Bundle ID Change (PRIMARY)

**Evidence:** `TaskManager/project.yml` diff in commit `254fb68` (Feb 18):
```
-    PRODUCT_BUNDLE_IDENTIFIER: com.kachersoft.TaskManager
+    PRODUCT_BUNDLE_IDENTIFIER: com.kachersoft.CyberTasks
```

**Mechanism:** SwiftData's default `ModelConfiguration` (no explicit `url:` override) derives the on-disk store location from the app's bundle identifier:
```
~/Library/Application Support/<BUNDLE_ID>/default.store
```

When the bundle ID changed, the app looked for (and created) a new empty store at the new path. The old data at `com.kachersoft.TaskManager/default.store` was never touched, never migrated, never deleted — just silently ignored.

**Current state:** The old data may still exist on disk at `~/Library/Application Support/com.kachersoft.TaskManager/` on the user's machine. **This data may be recoverable.**

### Root Cause 2: Unversioned Schema Changes + Silent In-Memory Fallback (SECONDARY)

**Evidence — The fallback code in `TaskManagerApp.swift` lines 103–110:**
```swift
} catch {
    do {
        let fallback = try ModelContainer.inMemoryFallback()
        try seedDefaultData(container: fallback)
        resolvedContainer = fallback
    } catch {
        resolvedContainer = nil
    }
}
```

**Evidence — 4 unversioned schema changes between Feb 6 and Feb 19, none with `VersionedSchema` or `SchemaMigrationPlan`.**

**Mechanism:** When SwiftData opens a store and the schema doesn't match, it throws. The catch block silently creates an in-memory container. The user sees the app working normally with default seed data. All data entered in that session evaporates on quit. No error shown, no warning.

**SwiftData schema change behavior:**
- Adding a nullable/defaulted property: usually handled automatically (lightweight migration)
- Renaming a property (e.g., `isCompleted` → `statusRaw`): requires explicit migration plan — SwiftData cannot infer this
- Adding new `@Model` types to schema: requires the container to be reconfigured — may throw on existing stores

The BREAK #1 rename (`isCompleted` → `statusRaw`) is the most dangerous — SwiftData treats these as unrelated columns and would drop `isCompleted` data when it can't match.

### Which Root Cause Actually Hit the User?

**Timeline relative to user's 3-4 weeks of use (from 2026-03-10):**
- User started around **Feb 10–17**
- Bundle ID changed on **Feb 18**
- Schema expanded (2 new models) on **Feb 19**

If the user installed a build from **before Feb 18**, their data lived at `com.kachersoft.TaskManager`. The Feb 18 update (first time they ran a build with the new bundle ID) made the app open a completely empty store. **This is the primary cause.**

If the user also continued using the app after Feb 19, the schema change + silent fallback would additionally have caused data entered on Feb 19+ to be lost on quit whenever the old store couldn't open due to schema mismatch.

---

## What Happened to the Data

1. **User's tasks from Feb 10–17** are sitting in `~/Library/Application Support/com.kachersoft.TaskManager/default.store` on the user's Mac. The app stopped reading this file after Feb 18. The file was never deleted.

2. **Tasks entered after Feb 18** (in the `com.kachersoft.CyberTasks` store) may have survived IF the schema was compatible. With the Feb 19 schema change adding 2 new model types, that store may have also triggered the fallback, causing those tasks to be written only to in-memory — lost on quit.

3. **No data was explicitly deleted** by any code. No `try? FileManager.default.removeItem(...)` on the store file was found anywhere.

---

## Data Recovery Possibility

**Check on user's machine:**
```bash
ls ~/Library/Application\ Support/ | grep -i kachersoft
ls ~/Library/Application\ Support/com.kachersoft.TaskManager/
ls ~/Library/Application\ Support/com.kachersoft.CyberTasks/
```

If `com.kachersoft.TaskManager/default.store` exists and is non-empty, the original data is recoverable by either:
- Temporarily reverting the bundle ID to `com.kachersoft.TaskManager` in `project.yml`, building, and running the app (risky without migration)
- Using a SQLite browser (`DB Browser for SQLite`) to directly read the `.store` file

**Note:** The `.store` is a SQLite database. SwiftData-managed SQLite files can be opened directly to read raw data even without the app.

---

## Secondary Findings

### No VersionedSchema or SchemaMigrationPlan
No migration infrastructure exists anywhere in the codebase. Every schema change since Feb 4 has been applied without any migration, relying on SwiftData's undocumented lightweight migration behavior. This is not safe for production use.

### Explicit Store URL Not Set
`ModelContainer+Config.swift` uses `ModelConfiguration(schema:, isStoredInMemoryOnly:)` with no `url:` parameter. This means SwiftData auto-derives the path from the bundle ID — which makes it vulnerable to exactly the bundle ID change that caused data loss.

### App Sandbox Disabled
`TaskManager.entitlements` has `com.apple.security.app-sandbox = false`. While this doesn't cause data loss, it means the app has no sandboxing protections and the store is in `~/Library/Application Support/` (not a sandboxed container). This makes the old data file directly accessible for recovery.

---

## Immediate Actions Required

1. **Data Recovery:** Guide the user to check `~/Library/Application Support/com.kachersoft.TaskManager/` for their old data store.

2. **Fix 1 — Explicit Store URL:** Set an explicit `url:` in `ModelConfiguration` that is stable regardless of bundle ID. Use the Application Support directory with a hardcoded file name:
   ```swift
   let storeURL = URL.applicationSupportDirectory
       .appending(path: "com.kachersoft.strata", directoryHint: .isDirectory)
       .appending(path: "default.store")
   let config = ModelConfiguration(schema: appSchema, url: storeURL, isStoredInMemoryOnly: false)
   ```

3. **Fix 2 — Remove Silent Fallback:** Replace the in-memory fallback with explicit error UI. Data loss is worse than a crash. Show an actionable error dialog instead of booting into an empty state.

4. **Fix 3 — Add VersionedSchema:** Implement `VersionedSchema` and `SchemaMigrationPlan` before ANY further schema changes. The `isCompleted → statusRaw` rename (Feb 6) that hit early users needs a migration.

5. **Fix 4 — Freeze Bundle ID:** Never change `PRODUCT_BUNDLE_IDENTIFIER` again without explicit data migration handling. Current value `com.kachersoft.CyberTasks` should be locked.

---

## Unresolved Questions

1. **What build did the user actually run?** Was it compiled from source (via `swift run` or build script) or distributed as a `.app`? This determines whether the xcodeproj bundle ID was in effect.

2. **When exactly did the user's data disappear?** If it was Feb 18 (bundle ID change), the old store at `com.kachersoft.TaskManager` likely has all their data. If it was Feb 19 (schema change triggering fallback), data may be in the CyberTasks store.

3. **Is the `com.kachersoft.TaskManager` directory still present on the user's Mac?** The entire recovery effort depends on this.

4. **Were the schema changes (BREAK #1 through #4) applied against a live user's store or only during development?** If the user never ran a build between Feb 4 and Feb 15 (before the xcodeproj), the `isCompleted → statusRaw` rename may not have been applied to a persisted store.
