import SwiftData
import Foundation

extension ModelContainer {
    static func configured() throws -> ModelContainer {
        let schema = Schema([
            TaskModel.self,
            AIModeModel.self,
            SettingsModel.self
        ])
        
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        return try ModelContainer(for: schema, configurations: [config])
    }
}

@MainActor
func seedDefaultData(container: ModelContainer) {
    let context = ModelContext(container)
    
    seedDefaultAIModes(context: context)
    seedDefaultSettings(context: context)
    
    try? context.save()
}

@MainActor
private func seedDefaultAIModes(context: ModelContext) {
    let descriptor = FetchDescriptor<AIModeModel>()
    guard (try? context.fetchCount(descriptor)) == 0 else { return }
    
    for (index, mode) in AIModeModel.createDefaultModes().enumerated() {
        mode.sortOrder = index
        context.insert(mode)
    }
}

@MainActor
private func seedDefaultSettings(context: ModelContext) {
    let descriptor = FetchDescriptor<SettingsModel>()
    guard (try? context.fetchCount(descriptor)) == 0 else { return }
    
    let settings = SettingsModel()
    context.insert(settings)
}
