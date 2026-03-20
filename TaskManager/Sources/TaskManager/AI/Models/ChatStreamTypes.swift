import Foundation

/// Single message in chat history for provider consumption
struct ChatMessage: Sendable {
    let role: ChatMessageRole
    let content: String
    let attachments: [AIAttachment]

    init(role: ChatMessageRole, content: String, attachments: [AIAttachment] = []) {
        self.role = role
        self.content = content
        self.attachments = attachments
    }
}

/// Chunk emitted during streaming
enum ChatStreamChunk: Sendable {
    case text(String)           // partial text token
    case done(tokensUsed: Int?) // stream complete
    case error(AIError)         // recoverable error mid-stream
}
