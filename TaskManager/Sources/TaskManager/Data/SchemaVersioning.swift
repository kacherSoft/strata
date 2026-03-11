import SwiftData

// MARK: - V1 Schema (current schema as of 2026-03)
// All 5 models match the live SQLite store exactly.
// When the next schema change is needed, define StrataSchemaV2 here
// and add a lightweight/custom MigrationStage to StrataMigrationPlan.stages.

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

// MARK: - Migration Plan

enum StrataMigrationPlan: SchemaMigrationPlan {
    nonisolated(unsafe) static var schemas: [any VersionedSchema.Type] = [StrataSchemaV1.self]

    /// No migration stages needed yet — V1 is the current schema.
    /// Future schema changes: add V2 enum and append a MigrationStage here.
    nonisolated(unsafe) static var stages: [MigrationStage] = []
}
