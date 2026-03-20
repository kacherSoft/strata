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

// MARK: - Migration Plan

enum StrataMigrationPlan: SchemaMigrationPlan {
    nonisolated(unsafe) static var schemas: [any VersionedSchema.Type] = [
        StrataSchemaV1.self,
        StrataSchemaV2.self
    ]

    /// Lightweight migration: V1→V2 is purely additive (new tables + nullable column).
    nonisolated(unsafe) static var stages: [MigrationStage] = [
        .lightweight(fromVersion: StrataSchemaV1.self, toVersion: StrataSchemaV2.self)
    ]
}
