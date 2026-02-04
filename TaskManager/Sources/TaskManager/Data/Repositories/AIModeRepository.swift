import SwiftData
import Foundation

@MainActor
final class AIModeRepository: ObservableObject {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchAll() throws -> [AIModeModel] {
        let descriptor = FetchDescriptor<AIModeModel>(
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func fetch(id: UUID) throws -> AIModeModel? {
        var descriptor = FetchDescriptor<AIModeModel>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
    
    @discardableResult
    func create(name: String, systemPrompt: String) -> AIModeModel {
        let mode = AIModeModel(name: name, systemPrompt: systemPrompt, isBuiltIn: false)
        
        if let maxOrder = try? fetchAll().map(\.sortOrder).max() {
            mode.sortOrder = maxOrder + 1
        }
        
        modelContext.insert(mode)
        try? modelContext.save()
        return mode
    }
    
    func update(_ mode: AIModeModel) {
        try? modelContext.save()
    }
    
    func delete(_ mode: AIModeModel) {
        guard !mode.isBuiltIn else { return }
        modelContext.delete(mode)
        try? modelContext.save()
    }
    
    func reorder(_ modes: [AIModeModel]) {
        for (index, mode) in modes.enumerated() {
            mode.sortOrder = index
        }
        try? modelContext.save()
    }
}
