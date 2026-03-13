# SwiftData VersionedSchema & SchemaMigrationPlan Research

**Date:** 2026-03-09
**Focus:** macOS app data migration best practices

---

## 1. VersionedSchema Definition (Multiple Versions)

**Pattern:** Use enum namespace for each schema version containing model definitions.

```swift
// V1: 3 models
enum MyAppSchemaV1: VersionedSchema {
    static var models: [any PersistentModel.Type] {
        [Task.self, Project.self, Tag.self]
    }
}

// V2: Add 2 more models
enum MyAppSchemaV2: VersionedSchema {
    static var models: [any PersistentModel.Type] {
        [Task.self, Project.self, Tag.self, Device.self, Subscription.self]
    }
}
```

**Key:** Each version is self-contained enum; SwiftData handles intermediate migrations automatically (v1→v5 works if v2,v3,v4 defined).

---

## 2. SchemaMigrationPlan Lightweight Steps

**Structure:** Define all schemas, then stages (lightweight auto-migrates simple changes).

```swift
enum MigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [
        MyAppSchemaV1.self,
        MyAppSchemaV2.self
    ]

    static var stages: [MigrationStage] = [
        MigrationStage.lightweight(
            fromVersion: MyAppSchemaV1.self,
            toVersion: MyAppSchemaV2.self
        )
    ]
}
```

**Lightweight auto-handles:** Add/remove properties, rename properties, change relationships, add uniqueness constraints.

---

## 3. Pre-Migration Store Backup

**Strategy:** Create backups before ModelContainer init, use explicit URL paths.

```swift
func backupStoreBeforeMigration(storeURL: URL) throws {
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: storeURL.path) else { return }

    let backupDir = storeURL.deletingLastPathComponent()
        .appendingPathComponent("Backups")
    try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd_HHmmss"
    let backupName = "store_\(formatter.string(from: Date())).store"
    let backupURL = backupDir.appendingPathComponent(backupName)

    try fileManager.copyItem(at: storeURL, to: backupURL)
}
```

**Best practice:** Call in AppDelegate or app initializer BEFORE creating ModelContainer.

---

## 4. Graceful ModelContainer Init Failure Handling

**Anti-pattern:** `fatalError()` → crashes app.
**Better:** Use `@State` for container + error state, show alert to user.

```swift
@main
struct App: SwiftUIApp {
    @State var modelContainer: ModelContainer?
    @State var initError: Error?

    var body: some Scene {
        WindowGroup {
            if let container = modelContainer {
                ContentView()
                    .modelContainer(container)
            } else if let error = initError {
                ErrorView(error: error, retry: initializeContainer)
            } else {
                ProgressView("Loading...")
                    .onAppear(perform: initializeContainer)
            }
        }
    }

    func initializeContainer() {
        Task {
            do {
                let config = ModelConfiguration(url: customStoreURL)
                modelContainer = try ModelContainer(
                    for: MyAppSchemaV2.self,
                    migrationPlan: MigrationPlan.self,
                    configurations: [config]
                )
            } catch {
                initError = error
            }
        }
    }
}
```

**Key:** Alert user to app restart, NOT silent fallback to in-memory data.

---

## 5. Explicit Store URL in ModelConfiguration

```swift
let appSupportURL = FileManager.default.urls(
    for: .applicationSupportDirectory,
    in: .userDomainMask
)[0]
let storeURL = appSupportURL
    .appendingPathComponent("TaskManager")
    .appendingPathComponent("store.db")

let config = ModelConfiguration(
    schema: MyAppSchemaV2.self,
    url: storeURL
)

let container = try ModelContainer(
    for: MyAppSchemaV2.self,
    migrationPlan: MigrationPlan.self,
    configurations: [config]
)
```

**Benefits:** Explicit path control, enables backup/restore, supports multiple stores.

---

## 6. Migration Failure Recovery Strategies

**Multi-tier approach:**

1. **Attempt migration** with defined SchemaMigrationPlan
2. **If fails:** Show error dialog with options:
   - Restart app (retry migration)
   - Delete database & start fresh (if data is re-loadable)
3. **Rollback option:** Keep dated backups for manual restore
4. **Never silent fallback** to in-memory or cached data

**Dangerous pattern:** Duplicates during uniqueness constraint enforcement will block migration entirely—validate data quality before upgrading.

---

## Key Takeaways

- Always version schema from day one
- Lightweight migrations cover 80% of changes automatically
- Explicit store URLs enable proper backup/recovery workflows
- User-facing errors > silent failures; provide recovery options
- Test migrations with real production-like data volumes
- Multi-version migration chains work automatically (v1→v5)

---

## Sources

- [SchemaMigrationPlan | Apple Developer Documentation](https://developer.apple.com/documentation/swiftdata/schemamigrationplan)
- [How to create a complex migration using VersionedSchema](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-a-complex-migration-using-versionedschema)
- [Lightweight vs complex migrations](https://www.hackingwithswift.com/quick-start/swiftdata/lightweight-vs-complex-migrations)
- [A Deep Dive into SwiftData migrations – Donny Wals](https://www.donnywals.com/a-deep-dive-into-swiftdata-migrations/)
- [Leveling Up SwiftData Error Handling in Xcode Templates](https://www.mikebuss.com/posts/swiftdata-template)
- [All the ways SwiftData's ModelContainer can Error on Creation](https://scottdriggers.com/blog/swiftdata-modelcontainer-creation-crash/)
- [Handling SwiftData Schema Migrations: A Practical Guide](https://medium.com/@manikantasirumalla5/handling-swiftdata-schema-migrations-a-practical-guide-e58e05bd3071)
- [How to configure a custom ModelContainer using ModelConfiguration](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-configure-a-custom-modelcontainer-using-modelconfiguration)
