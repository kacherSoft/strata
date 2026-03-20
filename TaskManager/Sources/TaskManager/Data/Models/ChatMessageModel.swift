import SwiftData
import Foundation

enum ChatMessageRole: String, Codable, Sendable {
    case system
    case user
    case assistant
}

@Model
final class ChatMessageModel: Identifiable {
    @Attribute(.unique) var id: UUID
    var session: ChatSessionModel?
    var roleRaw: String
    var content: String
    var attachmentPaths: [String]
    var tokensUsed: Int?
    var createdAt: Date

    var role: ChatMessageRole {
        get { ChatMessageRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    init(role: ChatMessageRole, content: String, attachmentPaths: [String] = [], tokensUsed: Int? = nil) {
        self.id = UUID()
        self.roleRaw = role.rawValue
        self.content = content
        self.attachmentPaths = attachmentPaths
        self.tokensUsed = tokensUsed
        self.createdAt = Date()
    }
}
