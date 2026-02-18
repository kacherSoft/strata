import SwiftData
import Foundation

extension ModelContainer {
    static var appSchema: Schema {
        Schema([
            TaskModel.self,
            AIModeModel.self,
            SettingsModel.self
        ])
    }

    static func configured() throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: appSchema,
            isStoredInMemoryOnly: false
        )

        return try ModelContainer(for: appSchema, configurations: [config])
    }

    static func inMemoryFallback() throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: appSchema,
            isStoredInMemoryOnly: true
        )

        return try ModelContainer(for: appSchema, configurations: [config])
    }
}

@MainActor
func seedDefaultData(container: ModelContainer) throws {
    let context = ModelContext(container)

    try seedDefaultAIModes(context: context)
    try removeDeprecatedBuiltInModesIfNeeded(context: context)
    try seedExplainModeIfNeeded(context: context)
    try seedDefaultSettings(context: context)

    try context.save()
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
