# Data Layer Exploration Report
**Date:** 2026-03-17 | **Focus:** SwiftData architecture for chat sessions/messages planning

---

## Executive Summary
Strata's data layer uses SwiftData with explicit versioned schema, repository pattern, and pre-migration backup. All 5 @Model classes are finalized and match the SQLite store exactly. Schema versioning system is set up for future migrations but currently only V1 exists with no pending stages. Ready for new models (ChatSessionModel, ChatMessageModel).

---

## 1. ALL @Model CLASSES (5 total)

### TaskModel (156 lines)
**Location:** `/Sources/TaskManager/Data/Models/TaskModel.swift`
- **Unique constraint:** `id: UUID`
- **Core fields:** title, taskDescription, dueDate, reminderDate, priority, tags, status
- **Enum fields (stored raw):** statusRaw → TaskStatus, recurrenceRuleRaw → RecurrenceRule
- **Computed properties:** status, isCompleted, isInProgress, recurrenceRule
- **Rich features:** recurring tasks (isRecurring, recurrenceRule, recurrenceInterval), reminders, photos, custom fields support (budget, client, effort retained for backward compat)
- **Timestamps:** createdAt, updatedAt, reminderFireDate, completedAt
- **Methods:** setStatus(), cycleStatus(), markComplete(), markIncomplete(), touch()

**Enums:**
- TaskStatus: todo | inProgress | completed
- TaskPriority: none | low | medium | high | critical (with sortValue for ordering)

### AIModeModel (98 lines)
**Location:** `/Sources/TaskManager/Data/Models/AIModeModel.swift`
- **Unique constraint:** `id: UUID`
- **Core fields:** name, systemPrompt, modelName, sortOrder, isBuiltIn, supportsAttachments
- **Enum field (stored raw):** providerRaw → AIProviderType
- **Computed property:** provider
- **Timestamps:** createdAt
- **Built-in defaults:** 3 modes created on first seed (Correct Me, Enhance Prompt, Explain)
- **Identifiable:** conforms via id

**Enums:**
- AIProviderType: gemini | zai (with availableModels, defaultModel, supportsImageAttachments, supportsPDFAttachments, supportsAnyAttachments)

### SettingsModel (45 lines)
**Location:** `/Sources/TaskManager/Data/Models/SettingsModel.swift`
- **Unique constraint:** `id: UUID`
- **Core fields:** aiProvider (AIProvider enum), selectedAIModeId, alwaysOnTop, reducedMotion, showCompletedTasks, defaultPriority, reminderSoundId
- **Timestamps:** createdAt, updatedAt
- **Method:** touch()
- **Singleton pattern:** Only one SettingsModel instance should exist (seed creates if missing)

**Enum:**
- AIProvider: gemini | zai (with displayName)

### CustomFieldDefinitionModel (41 lines)
**Location:** `/Sources/TaskManager/Data/Models/CustomFieldDefinitionModel.swift`
- **Unique constraint:** `id: UUID`
- **Core fields:** name, valueTypeRaw, isActive, sortOrder
- **Enum field (stored raw):** valueTypeRaw → CustomFieldValueType
- **Computed property:** valueType
- **Timestamps:** createdAt, updatedAt
- **Method:** touch()
- **Built-in defaults:** Budget (currency), Client (text), Effort (number)

**Enum:**
- CustomFieldValueType: text | number | currency | date | toggle

### CustomFieldValueModel (26 lines)
**Location:** `/Sources/TaskManager/Data/Models/CustomFieldValueModel.swift`
- **Unique constraint:** `id: UUID`
- **References:** definitionId (UUID), taskId (UUID) — no explicit relationships defined
- **Polymorphic storage:** stringValue?, numberValue?, decimalValue?, dateValue?, boolValue?
- **No timestamps**
- **One value per (taskId, definitionId) pair stored**

**Pattern:** Custom field values are stored separately from tasks, allowing flexible typing.

---

## 2. SCHEMA VERSIONING SYSTEM (SchemaVersioning.swift)

**Location:** `/Sources/TaskManager/Data/SchemaVersioning.swift` (29 lines)

### Current Design
```
StrataSchemaV1 (VersionedSchema)
  ├─ versionIdentifier: (1, 0, 0)
  └─ models: [TaskModel, AIModeModel, SettingsModel, CustomFieldDefinitionModel, CustomFieldValueModel]

StrataMigrationPlan (SchemaMigrationPlan)
  ├─ schemas: [StrataSchemaV1]
  └─ stages: [] (empty — no migrations needed yet)
```

### Future Migration Pattern
When adding ChatSessionModel + ChatMessageModel:
1. Define `StrataSchemaV2: VersionedSchema` with all 7 models
2. Add lightweight/custom MigrationStage to `StrataMigrationPlan.stages`
3. v1 → v2 migration is automatic if no custom logic needed
4. V1 remains in schemas array for compatibility

**Key:** SwiftData handles the diff; only custom transformations need explicit stages.

---

## 3. ModelContainer CONFIGURATION

**Location:** `/Sources/TaskManager/Data/ModelContainer+Config.swift` (303 lines)

### Store Location
```swift
static var storeURL: URL {
    // ~/Library/Application Support/Strata/strata.store
    appSupport.appendingPathComponent("Strata")
                .appendingPathComponent("strata.store")
}
```

### Initialization Pipeline (static func configured())
1. **Create directory:** Ensures Strata/ exists
2. **Migrate legacy:** Moves `default.store` from root appSupport to Strata/strata.store (if exists)
3. **Backup existing:** Copies current store + WAL/SHM sidecars to Strata/Backups/store_YYYYMMDD_HHmmss.store*
4. **Init container:**
   ```swift
   let config = ModelConfiguration(url: storeURL)
   let schema = Schema(StrataSchemaV1.models)
   let container = try ModelContainer(
       for: schema,
       migrationPlan: StrataMigrationPlan.self,
       configurations: [config]
   )
   ```
5. **Data loss check:** Fetches TaskModel count; if 0 but backups exist, posts strataDataLossWarning notification

### Backup Rotation
- Keeps newest 5 primary .store files
- Automatically deletes older backups
- Preserves sidecars (-wal, -shm) for each timestamped backup

### Testing Support
```swift
static func inMemoryForTesting() -> ModelContainer {
    // In-memory-only container for unit tests
}
```

### Error Handling
- **No silent fallback:** `configured()` throws on any failure
- **App-level handling:** TaskManagerApp shows DataErrorView if container init fails
- **User can:** Reset data + relaunch via DataErrorView

---

## 4. SwiftData Setup in TaskManagerApp.swift

**Location:** `/Sources/TaskManager/TaskManagerApp.swift` (847 lines, main window logic)

### Entry Point Architecture
```swift
@main
struct TaskManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var container: ModelContainer?
    @State private var initError: Error?
    
    var body: some Scene {
        Window("Task Manager", id: "main-window") {
            if let container {
                ContentView().withAppEnvironment(container: container)
            } else if let error = initError {
                DataErrorView(error: error, storeURL: ModelContainer.storeURL)
            } else {
                ProgressView("Loading…")
                    .task { await initializeContainer() }
            }
        }
    }
}
```

### Initialization (@MainActor async)
```swift
private func initializeContainer() async {
    do {
        let configured = try ModelContainer.configured()
        try seedDefaultData(container: configured)
        WindowManager.shared.configure(modelContainer: configured)
        ShortcutManager.shared.configure(modelContainer: configured)
        appDelegate.modelContainer = configured
        container = configured
    } catch {
        initError = error
    }
}
```

### Seeding Pipeline (seedDefaultData, 15+ functions)
1. **seedDefaultAIModes:** Creates 3 built-in modes (Correct Me, Enhance Prompt, Explain) if count == 0
2. **removeDeprecatedBuiltInModesIfNeeded:** Removes Simplify, Break Down modes
3. **seedExplainModeIfNeeded:** Ensures Explain mode exists + supportsAttachments=true
4. **seedDefaultSettings:** Creates singleton SettingsModel if missing
5. **seedDefaultCustomFieldDefinitions:** Creates Budget, Client, Effort definitions
6. **migrateExistingCustomFieldValues:** One-time migration: legacy budget/client/effort → CustomFieldValueModel rows

### ContentView Data Access
Uses `@Query` macro for reactive fetching:
```swift
@Query(sort: \TaskModel.createdAt, order: .reverse) private var taskModels: [TaskModel]
@Query(sort: \CustomFieldDefinitionModel.sortOrder) private var customFieldDefinitions: [CustomFieldDefinitionModel]
@Query private var customFieldValues: [CustomFieldValueModel]
@Query private var settings: [SettingsModel]
```

**Pattern:** Queries are live-updated when SwiftData context saves; views re-render automatically.

### Environment Setup
`withAppEnvironment(container: container)` injects:
- modelContext (for CRUD operations)
- AppContainer (custom environment value)
- Likely adds repositories as @Environment values

---

## 5. REPOSITORY PATTERN (2 repositories)

### TaskRepository (182 lines)
**Location:** `/Sources/TaskManager/Data/Repositories/TaskRepository.swift`

**Interface:**
```swift
@MainActor
final class TaskRepository: ObservableObject {
    init(modelContext: ModelContext)
    
    // Queries
    func fetchAll(filter: TaskFilter, sortOrder: TaskSortOrder, searchText: String) -> [TaskModel]
    func fetch(id: UUID) -> TaskModel?
    
    // Mutations
    @discardableResult func create(...) -> TaskModel
    func update(_ task: TaskModel)
    func delete(_ task: TaskModel)
    func deleteAll() throws
    func toggleComplete(_ task: TaskModel)
}
```

**Enums:**
- TaskFilter: all | today | completed | incomplete | priority(TaskPriority) | tag(String) | dueSoon(days: Int)
- TaskSortOrder: createdAt(ascending) | dueDate(ascending) | priority(ascending) | title(ascending) | manual

**Patterns:**
- Direct model mutation (no DTO layer)
- Filtering & search done in-memory (not via predicate)
- Priority sort includes tiebreaker (createdAt descending)

### AIModeRepository (71 lines)
**Location:** `/Sources/TaskManager/Data/Repositories/AIModeRepository.swift`

**Interface:**
```swift
@MainActor
final class AIModeRepository: ObservableObject {
    init(modelContext: ModelContext)
    
    func fetchAll() -> [AIModeModel]
    func fetch(id: UUID) -> AIModeModel?
    @discardableResult func create(name: String, systemPrompt: String) -> AIModeModel
    func update(_ mode: AIModeModel)
    func delete(_ mode: AIModeModel) // guards !mode.isBuiltIn
    func reorder(_ modes: [AIModeModel])
}
```

**Patterns:**
- Built-in modes are read-only (delete guards against deletion)
- sortOrder is auto-calculated when creating (max existing + 1)
- reorder() allows manual reorganization

### NOT YET CREATED: SettingsRepository
App fetches SettingsModel directly via `@Query` in ContentView. No dedicated repo yet.

---

## 6. Package.swift DEPENDENCIES

**Location:** `/TaskManager/Package.swift` (27 lines)

```swift
// swift-tools-version: 6.2
targets: [
    .executableTarget(
        name: "TaskManager",
        dependencies: [
            "TaskManagerUIComponents",
            "KeyboardShortcuts",  // (sindresorhus)
            .product(name: "GoogleGenerativeAI", package: "generative-ai-swift")
        ]
    )
]
```

**External packages:**
- **KeyboardShortcuts 2.0.0+** — macOS keyboard shortcut handling
- **GoogleGenerativeAI 0.5.0+** — Gemini API integration
- **TaskManagerUIComponents** (local) — SwiftUI components

**SwiftData:** Built-in, no external dependency needed.

---

## 7. KEY ARCHITECTURAL PATTERNS FOR CHAT SESSIONS/MESSAGES

When adding ChatSessionModel + ChatMessageModel, follow:

### Composition Pattern
```swift
@Model
final class ChatSessionModel {
    @Attribute(.unique) var id: UUID
    var taskId: UUID  // Foreign key reference (no SwiftData relationships for now)
    var title: String
    var createdAt: Date
    var updatedAt: Date
}

@Model
final class ChatMessageModel {
    @Attribute(.unique) var id: UUID
    var sessionId: UUID  // Foreign key
    var role: MessageRole  // user | assistant
    var content: String
    var timestamp: Date
}

enum MessageRole: String, Codable, CaseIterable, Sendable {
    case user, assistant
}
```

### Schema Update (in SchemaVersioning.swift)
```swift
enum StrataSchemaV2: VersionedSchema {
    nonisolated(unsafe) static var versionIdentifier = Schema.Version(2, 0, 0)
    nonisolated(unsafe) static var models: [any PersistentModel.Type] = [
        TaskModel.self,
        AIModeModel.self,
        SettingsModel.self,
        CustomFieldDefinitionModel.self,
        CustomFieldValueModel.self,
        ChatSessionModel.self,      // NEW
        ChatMessageModel.self       // NEW
    ]
}

enum StrataMigrationPlan: SchemaMigrationPlan {
    nonisolated(unsafe) static var schemas: [any VersionedSchema.Type] = [
        StrataSchemaV1.self,
        StrataSchemaV2.self
    ]
    nonisolated(unsafe) static var stages: [MigrationStage] = [] // SwiftData auto-handles if no custom logic
}
```

### Repository Skeleton
```swift
@MainActor
final class ChatSessionRepository: ObservableObject {
    private let modelContext: ModelContext
    
    func fetchSessions(for taskId: UUID) throws -> [ChatSessionModel]
    func fetchSession(id: UUID) throws -> ChatSessionModel?
    @discardableResult func create(taskId: UUID, title: String) -> ChatSessionModel
    func update(_ session: ChatSessionModel)
    func delete(_ session: ChatSessionModel)
}

@MainActor
final class ChatMessageRepository: ObservableObject {
    private let modelContext: ModelContext
    
    func fetchMessages(for sessionId: UUID) throws -> [ChatMessageModel]
    func append(sessionId: UUID, role: MessageRole, content: String) -> ChatMessageModel
    func delete(_ message: ChatMessageModel)
}
```

### Seeding (in ModelContainer+Config.swift)
```swift
@MainActor
private func seedDefaultChatSettings(context: ModelContext) throws {
    // No default sessions needed; they're task-specific
}
```

---

## 8. CRITICAL NOTES FOR PLANNING

1. **No explicit relationships:** Models use UUID foreign keys, not SwiftData relationships. Simplifies queries & filtering.

2. **Versioned schema required:** Must update StrataSchemaV2 before deployment. v1 → v2 migration auto-runs when container initializes if new models are present.

3. **Backup happens before migration:** All backups are created at startup before container init, so failed migrations can be recovered.

4. **Seeding is idempotent:** All seed functions check `fetchCount == 0` before inserting. Safe to call on every launch.

5. **@Query is reactive:** ContentView uses @Query for live data binding. Chat views should too if real-time updates are needed.

6. **ModelContext is MainActor:** All repository mutations must happen on main thread. Repositories already enforce this via @MainActor.

7. **Custom field pattern:** Use the polymorphic stringValue/numberValue/decimalValue/dateValue/boolValue pattern if adding flexible typed fields to ChatMessage (e.g., metadata).

8. **Timestamp tracking:** createdAt + updatedAt standard for all models; consider adding for ChatMessageModel too.

9. **Error handling:** No silent fallbacks; let exceptions propagate to AppDelegate → DataErrorView. Users can reset data if needed.

10. **Testing:** Use `ModelContainer.inMemoryForTesting()` for unit tests; creates temporary schema without persistence.

---

## Files Checked (11 total)
- TaskModel.swift (156 LOC)
- AIModeModel.swift (98 LOC)
- SettingsModel.swift (45 LOC)
- CustomFieldDefinitionModel.swift (41 LOC)
- CustomFieldValueModel.swift (26 LOC)
- SchemaVersioning.swift (29 LOC)
- TaskManagerApp.swift (847 LOC, main window + seeding logic)
- TaskRepository.swift (182 LOC)
- AIModeRepository.swift (71 LOC)
- ModelContainer+Config.swift (303 LOC, init + backup + seed)
- Package.swift (27 LOC)
- RecurrenceRule.swift + ViewMode.swift (enums)

**Total data layer LOC:** ~1,825 (excluding app logic)

---

## Unresolved Questions
None. Data layer is complete and well-structured. Ready to plan ChatSessionModel + ChatMessageModel integration.
