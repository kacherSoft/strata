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
private func seedDefaultSettings(context: ModelContext) throws {
    let descriptor = FetchDescriptor<SettingsModel>()
    guard try context.fetchCount(descriptor) == 0 else { return }

    let settings = SettingsModel()
    context.insert(settings)
}
