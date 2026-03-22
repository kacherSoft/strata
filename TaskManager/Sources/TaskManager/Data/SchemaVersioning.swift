import SwiftData

// MARK: - V1 Schema (baseline as of 2026-03)
// All 5 models match the live SQLite store exactly.

enum StrataSchemaV1: VersionedSchema {
    nonisolated(unsafe) static var versionIdentifier = Schema.Version(1, 0, 0)

    nonisolated(unsafe) static var models: [any PersistentModel.Type] = [
        TaskModel.self,
        AIModeModel.self,
        SettingsModel.self,
        CustomFieldDefinitionModel.self,
        CustomFieldValueModel.self
    ]
}

// MARK: - V2 Schema (2026-03 chat mode feature)
// Additive changes: +ChatSessionModel, +ChatMessageModel, +AIModeModel.customBaseURL (nullable)

enum StrataSchemaV2: VersionedSchema {
    nonisolated(unsafe) static var versionIdentifier = Schema.Version(2, 0, 0)

    nonisolated(unsafe) static var models: [any PersistentModel.Type] = [
        TaskModel.self,
        AIModeModel.self,
        SettingsModel.self,
        CustomFieldDefinitionModel.self,
        CustomFieldValueModel.self,
        ChatSessionModel.self,
        ChatMessageModel.self
    ]
}

// MARK: - V3 Schema (2026-03 AI provider pivot)
// Additive changes: +AIProviderModel, +AIModeModel.aiProviderId (nullable), +ChatSessionModel.aiProviderId (nullable)

enum StrataSchemaV3: VersionedSchema {
    nonisolated(unsafe) static var versionIdentifier = Schema.Version(3, 0, 0)

    nonisolated(unsafe) static var models: [any PersistentModel.Type] = [
        TaskModel.self,
        AIModeModel.self,
        SettingsModel.self,
        CustomFieldDefinitionModel.self,
        CustomFieldValueModel.self,
        ChatSessionModel.self,
        ChatMessageModel.self,
        AIProviderModel.self
    ]
}

// MARK: - V4 Schema (2026-03 AI mode redesign)
// Additive changes: +AIModeModel.viewTypeRaw (nullable), +AIModeModel.autoCopyOutput (default false)

enum StrataSchemaV4: VersionedSchema {
    nonisolated(unsafe) static var versionIdentifier = Schema.Version(4, 0, 0)

    nonisolated(unsafe) static var models: [any PersistentModel.Type] = [
        TaskModel.self,
        AIModeModel.self,
        SettingsModel.self,
        CustomFieldDefinitionModel.self,
        CustomFieldValueModel.self,
        ChatSessionModel.self,
        ChatMessageModel.self,
        AIProviderModel.self
    ]
}

// MARK: - Migration Plan

enum StrataMigrationPlan: SchemaMigrationPlan {
    nonisolated(unsafe) static var schemas: [any VersionedSchema.Type] = [
        StrataSchemaV1.self,
        StrataSchemaV2.self,
        StrataSchemaV3.self,
        StrataSchemaV4.self
    ]

    nonisolated(unsafe) static var stages: [MigrationStage] = [
        .lightweight(fromVersion: StrataSchemaV1.self, toVersion: StrataSchemaV2.self),
        .lightweight(fromVersion: StrataSchemaV2.self, toVersion: StrataSchemaV3.self),
        .lightweight(fromVersion: StrataSchemaV3.self, toVersion: StrataSchemaV4.self)
    ]
}
