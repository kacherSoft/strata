import SwiftData
import Foundation

@MainActor
final class ChatSessionRepository: ObservableObject {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() throws -> [ChatSessionModel] {
        let descriptor = FetchDescriptor<ChatSessionModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let all = try modelContext.fetch(descriptor)
        // Sort: nil lastMessageAt (new chats) first, then by most recent activity
        return all.sorted { a, b in
            let dateA = a.lastMessageAt ?? .distantFuture
            let dateB = b.lastMessageAt ?? .distantFuture
            return dateA > dateB
        }
    }

    func fetch(id: UUID) throws -> ChatSessionModel? {
        var descriptor = FetchDescriptor<ChatSessionModel>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    @discardableResult
    func create(title: String, provider: AIProviderType, modelName: String, aiModeId: UUID? = nil, customBaseURL: String? = nil) -> ChatSessionModel {
        let session = ChatSessionModel(
            title: title,
            provider: provider,
            modelName: modelName,
            aiModeId: aiModeId,
            customBaseURL: customBaseURL
        )
        modelContext.insert(session)
        saveContext()
        return session
    }

    func update(_ session: ChatSessionModel) {
        session.touch()
        saveContext()
    }

    func delete(_ session: ChatSessionModel) {
        modelContext.delete(session)
        saveContext()
    }

    func search(query: String) throws -> [ChatSessionModel] {
        let descriptor = FetchDescriptor<ChatSessionModel>(
            predicate: #Predicate { $0.title.localizedStandardContains(query) },
            sortBy: [SortDescriptor(\.lastMessageAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func saveContext() {
        do { try modelContext.save() } catch {
            print("[Strata] ChatSessionRepository save failed: \(error)")
        }
    }
}
