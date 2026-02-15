import SwiftData
import Foundation

@MainActor
final class AIModeRepository: ObservableObject {
    private let modelContext: ModelContext
    private var lastSaveError: Error?
    
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

        do {
            if let maxOrder = try fetchAll().map(\.sortOrder).max() {
                mode.sortOrder = maxOrder + 1
            }
        } catch {
            lastSaveError = error
        }

        modelContext.insert(mode)
        saveContext()
        return mode
    }
    
    func update(_ mode: AIModeModel) {
        saveContext()
    }
    
    func delete(_ mode: AIModeModel) {
        guard !mode.isBuiltIn else { return }
        modelContext.delete(mode)
        saveContext()
    }
    
    func reorder(_ modes: [AIModeModel]) {
        for (index, mode) in modes.enumerated() {
            mode.sortOrder = index
        }
        saveContext()
    }

    private func saveContext() {
        do {
            try modelContext.save()
            lastSaveError = nil
        } catch {
            lastSaveError = error
        }
    }
}
