# Phase 1 — Data Models & Schema Migration

## Context
- [plan.md](plan.md)
- [SchemaVersioning.swift](../../TaskManager/Sources/TaskManager/Data/SchemaVersioning.swift)
- [ModelContainer+Config.swift](../../TaskManager/Sources/TaskManager/Data/ModelContainer+Config.swift)
- [AIModeModel.swift](../../TaskManager/Sources/TaskManager/Data/Models/AIModeModel.swift)
- [AIModeRepository.swift](../../TaskManager/Sources/TaskManager/Data/Repositories/AIModeRepository.swift)

## Overview
- **Priority:** P1 (blocks phases 3, 4, 6)
- **Status:** complete
- **Effort:** 3h

Create SwiftData models for chat sessions and messages, add V2 schema with additive migration, create repositories, and seed the built-in "Chat" AI mode.

## Key Insights

- Current schema is V1 with 5 models. V2 adds 2 new models + 1 new nullable column (`customBaseURL`) on AIModeModel.
- Lightweight migration (additive) handles both: new tables + new nullable columns require no custom `MigrationStage` logic.
- Repository pattern is well-established: `@MainActor final class`, `ObservableObject`, private `saveContext()`.
- Seed data pattern: check if exists → skip; otherwise insert. See `seedExplainModeIfNeeded()` for reference.

## New Files

### `Data/Models/ChatSessionModel.swift`

```swift
@Model
final class ChatSessionModel: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var aiModeId: UUID?          // optional — user can pick any mode
    var providerRaw: String      // snapshot at creation time
    var modelName: String        // snapshot at creation time
    var createdAt: Date
    var updatedAt: Date
    var lastMessageAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \ChatMessageModel.session)
    var messages: [ChatMessageModel]

    var provider: AIProviderType {
        get { AIProviderType(rawValue: providerRaw) ?? .gemini }
        set { providerRaw = newValue.rawValue }
    }

    func touch() { updatedAt = Date() }
}
```

**Notes:**
- `aiModeId` is UUID? not a relationship — avoids coupling to AIModeModel lifecycle (mode deletion shouldn't cascade to sessions).
- `providerRaw`/`modelName` are snapshots so session history reflects what was actually used, even if user changes default model later.
- `@Relationship(deleteRule: .cascade)` on messages — deleting a session deletes all its messages.

### `Data/Models/ChatMessageModel.swift`

```swift
enum ChatMessageRole: String, Codable, Sendable {
    case system
    case user
    case assistant
}

@Model
final class ChatMessageModel: Identifiable {
    @Attribute(.unique) var id: UUID
    var session: ChatSessionModel?
    var roleRaw: String
    var content: String
    var attachmentPaths: [String]  // reuse PhotoStorageService pattern
    var tokensUsed: Int?
    var createdAt: Date

    var role: ChatMessageRole {
        get { ChatMessageRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }
}
```

**Notes:**
- `attachmentPaths` stores file paths (same pattern as task photos). Empty array = no attachments.
- `tokensUsed` is optional — only populated when provider returns usage data.
- `session` is the inverse side of the relationship.

### `Data/Repositories/ChatSessionRepository.swift`

Follow existing `AIModeRepository` pattern:

```swift
@MainActor
final class ChatSessionRepository: ObservableObject {
    private let modelContext: ModelContext

    func fetchAll() throws -> [ChatSessionModel]  // sorted by lastMessageAt desc
    func fetch(id: UUID) throws -> ChatSessionModel?
    func create(title:provider:modelName:aiModeId:) -> ChatSessionModel
    func update(_ session: ChatSessionModel)
    func delete(_ session: ChatSessionModel)
    func search(query: String) throws -> [ChatSessionModel]  // title contains query
    private func saveContext()
}
```

### `Data/Repositories/ChatMessageRepository.swift`

```swift
@MainActor
final class ChatMessageRepository: ObservableObject {
    private let modelContext: ModelContext

    func fetchForSession(_ sessionId: UUID) throws -> [ChatMessageModel]  // sorted by createdAt asc
    func create(sessionId:role:content:attachmentPaths:) -> ChatMessageModel
    func deleteAll(forSession sessionId: UUID)  // bulk delete
    private func saveContext()
}
```

## Modified Files

### `Data/SchemaVersioning.swift`

Add V2 schema and migration stage:

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
        StrataSchemaV2.self         // ADD
    ]
    nonisolated(unsafe) static var stages: [MigrationStage] = [
        .lightweight(fromVersion: StrataSchemaV1.self, toVersion: StrataSchemaV2.self)
    ]
}
```

### `Data/ModelContainer+Config.swift`

1. Update `configured()` to use `StrataSchemaV2.models` instead of `StrataSchemaV1.models`:

```swift
let schema = Schema(StrataSchemaV2.models)  // was StrataSchemaV1.models
```

2. Add seed function for Chat mode:

```swift
@MainActor
private func seedChatModeIfNeeded(context: ModelContext) throws {
    let descriptor = FetchDescriptor<AIModeModel>(
        predicate: #Predicate { $0.isBuiltIn && $0.name == "Chat" }
    )
    guard try context.fetch(descriptor).isEmpty else { return }

    let allModes = try context.fetch(FetchDescriptor<AIModeModel>())
    let maxOrder = allModes.map(\.sortOrder).max() ?? -1

    let chatMode = AIModeModel(
        name: "Chat",
        systemPrompt: "You are a helpful, knowledgeable assistant. Respond conversationally. Use markdown formatting for code blocks, lists, and emphasis when appropriate.",
        provider: .gemini,
        isBuiltIn: true,
        supportsAttachments: true
    )
    chatMode.sortOrder = maxOrder + 1
    context.insert(chatMode)
}
```

3. Call `seedChatModeIfNeeded` from `seedDefaultData()`.

4. Update `inMemoryForTesting()` to use `StrataSchemaV2.models`.

## Implementation Steps

1. Create `ChatMessageModel.swift` (includes `ChatMessageRole` enum)
2. Create `ChatSessionModel.swift` with relationship to ChatMessageModel
3. Add `customBaseURL: String?` property to `AIModeModel` (nullable = migration-safe)
4. Update `AIModeData` to carry `customBaseURL`
5. Update `SchemaVersioning.swift` — add V2 + migration stage
6. Update `ModelContainer+Config.swift` — schema ref + seed function + test helper
7. Create `ChatSessionRepository.swift`
8. Create `ChatMessageRepository.swift`
9. Run `./scripts/build-debug.sh` to verify compile

## Todo

- [x] ChatMessageModel with role enum
- [x] ChatSessionModel with cascade relationship
- [x] AIModeModel: add `customBaseURL: String?` property
- [x] AIModeData: add `customBaseURL` field
- [x] StrataSchemaV2 + lightweight migration
- [x] ModelContainer schema reference update
- [x] Seed "Chat" built-in AI mode
- [x] ChatSessionRepository
- [x] ChatMessageRepository
- [x] Build verification

## Success Criteria

- App launches with existing V1 store and migrates to V2 without data loss
- "Chat" mode appears in AI mode list after seed
- Repositories can CRUD sessions and messages
- All existing tests still pass

## Risk Assessment

- **Migration failure on existing stores** — Mitigated by: additive-only changes (new tables), pre-migration backup already in place.
- **Relationship inverse correctness** — Must test that deleting a session cascades to messages.

## Security Considerations

- Chat messages stored locally in SwiftData — same security posture as tasks.
- `attachmentPaths` stores file references, not file contents — same as photo storage.
