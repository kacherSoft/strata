import SwiftData
import Foundation

// MARK: - Store URL & Backup helpers

extension ModelContainer {

    /// Explicit store path: ~/Library/Application Support/Strata/strata.store
    static var storeURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport
            .appendingPathComponent("Strata", isDirectory: true)
            .appendingPathComponent("strata.store")
    }

    /// Moves store files from the legacy default-location to the explicit Strata/ path.
    /// Runs before backup + container init so the correct file is in place.
    static func migrateFromDefaultLocation() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let legacyStoreURL = appSupport.appendingPathComponent("default.store")
        let targetBase = storeURL

        // Nothing to migrate if legacy store does not exist
        guard fm.fileExists(atPath: legacyStoreURL.path) else { return }

        // Skip if explicit store already exists — keep it, ignore legacy
        if fm.fileExists(atPath: targetBase.path) {
            print("[Strata] Legacy store found but explicit store already exists — skipping migration")
            return
        }

        // Create destination directory
        let targetDir = targetBase.deletingLastPathComponent()
        try? fm.createDirectory(at: targetDir, withIntermediateDirectories: true)

        // Move .store, .store-wal, .store-shm from legacy to explicit path
        for suffix in ["", "-wal", "-shm"] {
            let srcURL = appSupport.appendingPathComponent("default.store\(suffix)")
            let dstPath = URL(fileURLWithPath: targetBase.path + suffix)
            guard fm.fileExists(atPath: srcURL.path) else { continue }
            do {
                try fm.moveItem(at: srcURL, to: dstPath)
                print("[Strata] Migrated \(srcURL.lastPathComponent) → \(dstPath.lastPathComponent)")
            } catch {
                print("[Strata] Failed to migrate \(srcURL.lastPathComponent): \(error)")
            }
        }
    }

    /// Copies store + WAL + SHM sidecars into a timestamped Backups/ file.
    /// Keeps the newest 5 backups; deletes older ones.
    static func backupStore(at storeBase: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storeBase.path) else { return }

        let backupsDir = storeBase.deletingLastPathComponent()
            .appendingPathComponent("Backups", isDirectory: true)
        try? fm.createDirectory(at: backupsDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())

        let sidecars = ["", "-wal", "-shm"]
        for suffix in sidecars {
            let srcURL = URL(fileURLWithPath: storeBase.path + suffix)
            guard fm.fileExists(atPath: srcURL.path) else { continue }
            let backupName = "store_\(timestamp).store\(suffix)"
            let dstURL = backupsDir.appendingPathComponent(backupName)
            do {
                try fm.copyItem(at: srcURL, to: dstURL)
            } catch {
                print("[Strata] Backup copy failed for \(srcURL.lastPathComponent): \(error)")
            }
        }

        // Rotate: keep newest 5 primary backup files (ignore .wal/.shm for counting)
        rotateBackups(in: backupsDir, keepNewest: 5)
    }

    private static func rotateBackups(in backupsDir: URL, keepNewest maxCount: Int) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: backupsDir, includingPropertiesForKeys: [.creationDateKey]) else { return }

        // Only count primary .store files (not sidecars)
        let primaryFiles = entries.filter {
            $0.pathExtension == "store" && !$0.lastPathComponent.hasSuffix("-wal") && !$0.lastPathComponent.hasSuffix("-shm")
        }

        guard primaryFiles.count > maxCount else { return }

        let sorted = primaryFiles.sorted {
            let d0 = (try? $0.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            let d1 = (try? $1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            return d0 < d1 // oldest first
        }

        let toDelete = sorted.prefix(primaryFiles.count - maxCount)
        for primary in toDelete {
            // Remove primary + sidecars
            for suffix in ["", "-wal", "-shm"] {
                let candidate = URL(fileURLWithPath: primary.path + suffix)
                try? fm.removeItem(at: candidate)
            }
        }
    }

    // MARK: - Container Init

    /// Configures the production ModelContainer:
    /// 1. Migrates legacy default.store → Strata/strata.store
    /// 2. Backs up existing store
    /// 3. Initialises container with StrataMigrationPlan
    /// 4. Runs a lightweight integrity check
    ///
    /// Throws on any failure — callers MUST handle the error (no silent fallback).
    static func configured() throws -> ModelContainer {
        // Step 1 — Ensure Strata/ directory exists
        let storeDir = storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)

        // Step 2 — Migrate from legacy location if needed
        migrateFromDefaultLocation()

        // Step 3 — Pre-migration backup
        backupStore(at: storeURL)

        // Step 4 — Initialise container with explicit URL + migration plan
        let config = ModelConfiguration(url: storeURL)
        let schema = Schema(StrataSchemaV3.models)
        // No explicit migrationPlan — all V1→V2→V3 changes are purely additive
        // (new tables + nullable columns), so SwiftData's automatic lightweight migration handles it.
        let container = try ModelContainer(
            for: schema,
            configurations: [config]
        )

        // Step 5 — Lightweight integrity check
        let context = ModelContext(container)
        let taskCount = (try? context.fetchCount(FetchDescriptor<TaskModel>())) ?? 0
        if taskCount == 0 {
            checkForDataLossWarning(storeURL: storeURL, taskCount: taskCount)
        }

        return container
    }

    /// Posts a notification if zero tasks are found but a non-empty backup exists,
    /// which may indicate accidental data loss.
    private static func checkForDataLossWarning(storeURL: URL, taskCount: Int) {
        let backupsDir = storeURL.deletingLastPathComponent().appendingPathComponent("Backups")
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: backupsDir,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return }

        let hasSubstantialBackup = entries.contains {
            let size = (try? $0.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return size > 8192 // larger than a near-empty SQLite file
        }

        if hasSubstantialBackup {
            print("[Strata] WARNING: 0 tasks found but backup exists — possible data loss. Backup dir: \(backupsDir.path)")
            NotificationCenter.default.post(name: .strataDataLossWarning, object: nil)
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let strataDataLossWarning = Notification.Name("strataDataLossWarning")
}

// MARK: - In-Memory (tests only)

extension ModelContainer {
    static func inMemoryForTesting() throws -> ModelContainer {
        let schema = Schema(StrataSchemaV3.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}

// MARK: - Seed Data

@MainActor
func seedDefaultData(container: ModelContainer) throws {
    let context = ModelContext(container)

    ChatAttachmentHelper.cleanupTempFiles()
    try seedDefaultAIProviders(context: context)
    try seedDefaultAIModes(context: context)
    try removeDeprecatedBuiltInModesIfNeeded(context: context)
    try seedExplainModeIfNeeded(context: context)
    try seedChatModeIfNeeded(context: context)
    try repairInvalidAIModeProviders(context: context)
    try seedDefaultSettings(context: context)
    try seedDefaultCustomFieldDefinitions(context: context)
    try migrateExistingCustomFieldValues(context: context)

    try context.save()
}

/// Seed 2 default AI providers (Gemini + Anthropic) on first launch.
/// Uses existing Keychain keys so users don't lose their configured API keys.
@MainActor
private func seedDefaultAIProviders(context: ModelContext) throws {
    let descriptor = FetchDescriptor<AIProviderModel>()
    guard try context.fetchCount(descriptor) == 0 else { return }

    let gemini = AIProviderModel(
        name: "Google Gemini",
        providerType: .gemini,
        apiKeyRef: KeychainService.Key.geminiAPIKey.rawValue,
        models: ["gemini-flash-lite-latest", "gemini-flash-latest", "gemini-3-flash-preview"],
        defaultModelName: "gemini-flash-lite-latest",
        isDefault: true,
        sortOrder: 0
    )
    context.insert(gemini)

    let anthropic = AIProviderModel(
        name: "Anthropic",
        providerType: .anthropic,
        apiKeyRef: KeychainService.Key.anthropicAPIKey.rawValue,
        models: ["claude-sonnet-4-20250514", "claude-haiku-4-5-20251001"],
        defaultModelName: "claude-sonnet-4-20250514",
        isDefault: true,
        sortOrder: 1
    )
    context.insert(anthropic)
}

@MainActor
private func seedDefaultAIModes(context: ModelContext) throws {
    let descriptor = FetchDescriptor<AIModeModel>()
    guard try context.fetchCount(descriptor) == 0 else { return }

    for (index, mode) in AIModeModel.createDefaultModes().enumerated() {
        mode.sortOrder = index
        context.insert(mode)
    }
}

@MainActor
private func removeDeprecatedBuiltInModesIfNeeded(context: ModelContext) throws {
    let modesToRemove: Set<String> = ["Simplify", "Break Down"]
    let builtInModes = try context.fetch(FetchDescriptor<AIModeModel>(predicate: #Predicate { $0.isBuiltIn }))
    for mode in builtInModes where modesToRemove.contains(mode.name) {
        context.delete(mode)
    }
}

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

/// Fix modes with invalid providerRaw values (e.g. "custom" from old code).
/// When providerRaw is unrecognized, the computed `provider` property silently defaults to .gemini,
/// but the modelName can be stale (e.g. "gpt-5.4"). This repairs both fields.
@MainActor
private func repairInvalidAIModeProviders(context: ModelContext) throws {
    let validRaw = Set(AIProviderType.allCases.map(\.rawValue))
    let allModes = try context.fetch(FetchDescriptor<AIModeModel>())
    for mode in allModes {
        guard !validRaw.contains(mode.providerRaw) else { continue }
        // Invalid providerRaw — reset to gemini with default model
        mode.providerRaw = AIProviderType.gemini.rawValue
        mode.modelName = AIProviderType.gemini.defaultModel
    }
}

@MainActor
private func seedExplainModeIfNeeded(context: ModelContext) throws {
    let descriptor = FetchDescriptor<AIModeModel>(
        predicate: #Predicate { $0.isBuiltIn && $0.name == "Explain" }
    )
    let explainModes = try context.fetch(descriptor)

    if let explainMode = explainModes.first {
        if !explainMode.supportsAttachments {
            explainMode.supportsAttachments = true
        }
        return
    }

    let allModes = try context.fetch(FetchDescriptor<AIModeModel>())
    let maxOrder = allModes.map(\.sortOrder).max() ?? -1

    let explainMode = AIModeModel(
        name: "Explain",
        systemPrompt: "You are an expert explainer. If an image or document is attached, analyze and explain it clearly and concisely. Otherwise, analyze the provided text. Break down complex concepts into understandable language. Only output the explanation, nothing else.",
        provider: .gemini,
        isBuiltIn: true,
        supportsAttachments: true
    )
    explainMode.sortOrder = maxOrder + 1
    context.insert(explainMode)
}

@MainActor
private func seedDefaultSettings(context: ModelContext) throws {
    let descriptor = FetchDescriptor<SettingsModel>()
    guard try context.fetchCount(descriptor) == 0 else { return }

    let settings = SettingsModel()
    context.insert(settings)
}

@MainActor
private func seedDefaultCustomFieldDefinitions(context: ModelContext) throws {
    let descriptor = FetchDescriptor<CustomFieldDefinitionModel>()
    guard try context.fetchCount(descriptor) == 0 else { return }

    let defaults: [(String, CustomFieldValueType, Int)] = [
        ("Budget", .currency, 0),
        ("Client", .text, 1),
        ("Effort", .number, 2)
    ]
    for (name, valueType, order) in defaults {
        let definition = CustomFieldDefinitionModel(name: name, valueType: valueType, isActive: true, sortOrder: order)
        context.insert(definition)
    }
}

@MainActor
private func migrateExistingCustomFieldValues(context: ModelContext) throws {
    // One-time migration: convert legacy budget/client/effort to CustomFieldValueModel rows
    let definitions = try context.fetch(FetchDescriptor<CustomFieldDefinitionModel>())
    guard !definitions.isEmpty else { return }

    let budgetDef = definitions.first { $0.name == "Budget" && $0.valueType == .currency }
    let clientDef = definitions.first { $0.name == "Client" && $0.valueType == .text }
    let effortDef = definitions.first { $0.name == "Effort" && $0.valueType == .number }

    let existingValues = try context.fetch(FetchDescriptor<CustomFieldValueModel>())
    guard existingValues.isEmpty else { return } // already migrated

    let tasks = try context.fetch(FetchDescriptor<TaskModel>())
    for task in tasks {
        if let budget = task.budget, let def = budgetDef {
            let value = CustomFieldValueModel(definitionId: def.id, taskId: task.id, decimalValue: budget)
            context.insert(value)
        }
        if let client = task.client, !client.isEmpty, let def = clientDef {
            let value = CustomFieldValueModel(definitionId: def.id, taskId: task.id, stringValue: client)
            context.insert(value)
        }
        if let effort = task.effort, let def = effortDef {
            let value = CustomFieldValueModel(definitionId: def.id, taskId: task.id, numberValue: effort)
            context.insert(value)
        }
    }
}
