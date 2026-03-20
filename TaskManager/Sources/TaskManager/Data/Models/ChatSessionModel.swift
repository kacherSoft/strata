import SwiftData
import Foundation

@Model
final class ChatSessionModel: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var aiModeId: UUID?
    var providerRaw: String
    var modelName: String
    var customBaseURL: String?
    var createdAt: Date
    var updatedAt: Date
    var lastMessageAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \ChatMessageModel.session)
    var messages: [ChatMessageModel]

    var provider: AIProviderType {
        get { AIProviderType(rawValue: providerRaw) ?? .gemini }
        set { providerRaw = newValue.rawValue }
    }

    func touch() { updatedAt = Date() }

    init(title: String, provider: AIProviderType = .gemini, modelName: String = "", aiModeId: UUID? = nil, customBaseURL: String? = nil) {
        self.id = UUID()
        self.title = title
        self.providerRaw = provider.rawValue
        self.modelName = modelName
        self.aiModeId = aiModeId
        self.customBaseURL = customBaseURL
        self.createdAt = Date()
        self.updatedAt = Date()
        self.messages = []
    }
}
