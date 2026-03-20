import SwiftData
import Foundation

@MainActor
final class ChatMessageRepository: ObservableObject {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchForSession(_ sessionId: UUID) throws -> [ChatMessageModel] {
        let descriptor = FetchDescriptor<ChatMessageModel>(
            predicate: #Predicate { $0.session?.id == sessionId },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    @discardableResult
    func create(session: ChatSessionModel, role: ChatMessageRole, content: String, attachmentPaths: [String] = []) -> ChatMessageModel {
        let message = ChatMessageModel(role: role, content: content, attachmentPaths: attachmentPaths)
        message.session = session
        session.lastMessageAt = Date()
        session.touch()
        modelContext.insert(message)
        saveContext()
        return message
    }

    func deleteAll(forSession sessionId: UUID) {
        do {
            let messages = try fetchForSession(sessionId)
            for message in messages { modelContext.delete(message) }
            saveContext()
        } catch { }
    }

    private func saveContext() {
        do { try modelContext.save() } catch {
            print("[Strata] ChatMessageRepository save failed: \(error)")
        }
    }
}
