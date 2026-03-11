# Phase 0 -- Data Loss Emergency Fix

Priority: **P0 -- Must be first**
Status: Complete
Depends on: None
Estimated effort: **3h**
Tasks: 4

## Context Links

- Research: [SwiftData Migration](./research/researcher-01-swiftdata-migration.md)
- Bug location: `TaskManagerApp.swift:96-111`
- Related: `ModelContainer+Config.swift`

## Overview
<!-- Updated: Validation Session 1 - Root cause corrected, scope simplified -->

**Root cause (verified 2026-03-10):** Destructive property rename on Feb 6 (`isCompleted` → removed/computed, `completedDate` → `completedAt`, new `statusRaw` added) broke existing SwiftData store. App used `fatalError()` at that time, forcing store recreation. Data was lost then, not from CustomField additions.

**Current state:** Store at `~/Library/Application Support/default.store` has ALL 5 tables with ALL current columns. No schema migration gap exists. The silent in-memory fallback (added Feb 15) remains a risk for future schema changes.

**This phase:** Set explicit store URL, add backup, remove in-memory fallback, define VersionedSchema V1 as current schema for future-proofing.

## Key Insights

- Current store schema **exactly matches** current Swift @Model definitions (verified via PRAGMA table_info)
- Store lives at `~/Library/Application Support/default.store` — NOT in a bundle ID subdirectory
- No V1→V2 migration needed — define V1 as current schema; future changes become V2
- Explicit store URL required for backup/restore and to avoid path ambiguity
- `ModelContainer` init try-catch currently swallows errors and creates in-memory container
- Pre-migration backup is cheap insurance for ~KB-sized SQLite stores

## Requirements

**Functional:**
- App must never silently fall back to in-memory container
- Schema migration V1->V2 must preserve existing task data
- Pre-migration backup created automatically before schema changes
- User sees clear error with recovery options if container init fails
- Data integrity validated on launch

**Non-functional:**
- Backup rotation keeps max 5 files (prevent disk bloat)
- Migration must complete in <2s for typical databases (<10K tasks)

## Architecture

```
Launch Flow:
1. Determine storeURL (~/Library/Application Support/Strata/strata.store)
2. Backup existing store file -> Backups/store_YYYYMMDD_HHmmss.store
3. Rotate backups (keep newest 5)
4. Init ModelContainer with StrataMigrationPlan
5. Run data integrity check (verify fetch works)
6. On failure -> show DataErrorView (retry/reset/contact support)
```

## Related Code Files

**Modify:**
- `TaskManager/Sources/TaskManager/TaskManagerApp.swift` -- remove in-memory fallback
- `TaskManager/Sources/TaskManager/Data/ModelContainer+Config.swift` -- explicit URL, backup, migration plan

**Create:**
- `TaskManager/Sources/TaskManager/Data/SchemaVersioning.swift` -- VersionedSchema + MigrationPlan

## Implementation Steps

### Task 0-1: Add VersionedSchema Definition
<!-- Updated: Validation Session 1 - V1 = current schema only, no V1→V2 migration -->
**File:** New `TaskManager/Sources/TaskManager/Data/SchemaVersioning.swift`

1. Define `StrataSchemaV1` enum conforming to `VersionedSchema`:
   - `static var versionIdentifier = Schema.Version(1, 0, 0)`
   - `static var models: [any PersistentModel.Type] = [TaskModel.self, AIModeModel.self, SettingsModel.self, CustomFieldDefinitionModel.self, CustomFieldValueModel.self]`
2. Define `StrataMigrationPlan` enum conforming to `SchemaMigrationPlan`:
   - `static var schemas: [any VersionedSchema.Type] = [StrataSchemaV1.self]`
   - `static var stages: [MigrationStage] = []` (no stages needed yet — V1 is current)
3. When the next schema change is needed, add V2 + lightweight/custom migration stage

### Task 0-2: Explicit Store URL + Pre-Migration Backup
**File:** `ModelContainer+Config.swift`

1. Add explicit `storeURL`:
   ```swift
   static var storeURL: URL {
       let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
       return appSupport.appendingPathComponent("Strata").appendingPathComponent("strata.store")
   }
   ```
2. Add `migrateFromDefaultLocation()` function:
   <!-- Updated: Validation Session 1 - Correct source path (no bundle ID subdirectory) -->
   - Check if store exists at `~/Library/Application Support/default.store` (verified actual location)
   - If yes AND no store at explicit `Strata/strata.store` path: move `.store`, `.store-wal`, `.store-shm` to explicit path
   - If both exist: keep explicit path, log warning
   - Call this BEFORE backup and container init
3. Add `backupStore(at:)` function:
   - Create `Backups/` directory if needed
   - Copy `.store`, `.store-wal`, `.store-shm` sidecars (all three files)
   - Name: `store_YYYYMMDD_HHmmss.store` (+ `.wal`, `.shm`)
   - List backups sorted by date, delete oldest if count > 5
4. Call `migrateFromDefaultLocation()` then `backupStore` before `ModelContainer` init

### Task 0-3: Remove Silent In-Memory Fallback
**File:** `TaskManagerApp.swift`

1. Replace the try-catch that creates in-memory container:
   ```swift
   // BEFORE (dangerous):
   // } catch { modelContainer = try! ModelContainer(..., isStoredInMemoryOnly: true) }

   // AFTER:
   @State private var modelContainer: ModelContainer?
   @State private var initError: Error?
   ```
2. In body, branch on state:
   <!-- Updated: Validation Session 1 - Simple error UI, no Try Again -->
   - `modelContainer != nil` -> normal `ContentView().modelContainer(container)`
   - `initError != nil` -> Simple error view with: error description, "Reset Data" button (with confirmation), "Contact Support" link. No "Try Again" (container init failure is deterministic).
   - neither -> `ProgressView("Loading...")` with `.onAppear { initializeContainer() }`
3. `initializeContainer()` calls `ModelContainerConfig.configured()` and sets state

### Task 0-4: Pass Migration Plan to ModelContainer + Data Integrity Check
<!-- Updated: Validation Session 1 - V1 schema, combined tasks 0-4 and 0-5 -->
**File:** `ModelContainer+Config.swift`

1. Update `configured()` method:
   ```swift
   static func configured() throws -> ModelContainer {
       let config = ModelConfiguration(url: storeURL)
       return try ModelContainer(
           for: StrataSchemaV1.self,
           migrationPlan: StrataMigrationPlan.self,
           configurations: [config]
       )
   }
   ```
2. After successful container init, run sanity check:
   ```swift
   let context = ModelContext(container)
   let taskCount = try context.fetchCount(FetchDescriptor<TaskModel>())
   // If 0 tasks and a backup exists with non-zero size, warn user
   ```
3. If potential data loss detected, log warning and set a flag for UI to show restore prompt
4. Keep check lightweight -- just a COUNT query, not full data load

## Todo List
<!-- Updated: Validation Session 1 - Simplified, 4 tasks, no V1→V2 migration -->

- [x] 0-1: Create `SchemaVersioning.swift` with V1 (current full schema) + empty MigrationPlan
- [x] 0-2: Add explicit storeURL + migration from `~/Library/Application Support/default.store` + WAL/shm sidecar backup to `ModelContainer+Config.swift`
- [x] 0-3: Remove in-memory fallback from `TaskManagerApp.swift`, add simple error view (Reset Data + Contact Support)
- [x] 0-4: Wire migration plan into `ModelContainer` init + post-init data integrity check
- [x] Verify: Build succeeds (debug + release)
- [ ] Verify: Fresh install works (no existing store)
- [ ] Verify: Existing `default.store` migrates to `Strata/strata.store` path
- [ ] Verify: Corrupted store shows error view with Reset option (not crash/blank data)

## Success Criteria
<!-- Updated: Validation Session 1 - No V1→V2 migration needed -->

- App never silently creates in-memory container
- Existing `default.store` automatically moved to `~/Library/Application Support/Strata/strata.store`
- Pre-migration backup file exists after first launch post-update
- Simple error view shown on container init failure with Reset Data + Contact Support
- Max 5 backup files maintained (oldest rotated out)
- Fresh install creates store at explicit Strata/ path

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Migration fails on edge-case data | HIGH | Pre-migration backup enables manual recovery |
| Existing users already lost data from in-memory fallback | MEDIUM | Cannot recover; backup prevents future loss |
| storeURL change loses access to old default-location store | HIGH | Check both default and explicit locations; migrate if needed |
| Large database slows backup | LOW | SQLite files are typically <1MB for task managers |

## Security Considerations

- Backup files stored in user's Application Support (sandboxed)
- No sensitive data exposed through error messages in DataErrorView
- Reset Data option should require confirmation dialog

## Next Steps

- After this phase, proceed with security hardening (Phases 1-3)
- Consider adding telemetry for migration success/failure rate (opt-in)
- Document store location in user-facing support docs
