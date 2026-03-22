import Foundation

protocol AIProviderProtocol: Sendable {
    var name: String { get }
    var isConfigured: Bool { get }

    func enhance(text: String, attachments: [AIAttachment], mode: AIModeData) async throws -> AIEnhancementResult
    func testConnection() async throws -> Bool
    func streamChat(messages: [ChatMessage], mode: AIModeData) async throws -> AsyncThrowingStream<ChatStreamChunk, Error>
}

extension AIProviderProtocol {
    func enhance(text: String, mode: AIModeData) async throws -> AIEnhancementResult {
        try await enhance(text: text, attachments: [], mode: mode)
    }

    /// Default fallback: wraps single-shot enhance() as a stream for providers that don't implement native streaming
    func streamChat(messages: [ChatMessage], mode: AIModeData) async throws -> AsyncThrowingStream<ChatStreamChunk, Error> {
        let combinedText = messages
            .filter { $0.role != .system }
            .map { "\($0.role.rawValue): \($0.content)" }
            .joined(separator: "\n\n")
        let result = try await enhance(text: combinedText, mode: mode)
        return AsyncThrowingStream { continuation in
            continuation.yield(.text(result.enhancedText))
            continuation.yield(.done(tokensUsed: result.tokensUsed))
            continuation.finish()
        }
    }
}

enum AIError: LocalizedError, Sendable {
    case notConfigured
    case invalidAPIKey
    case rateLimited
    case networkError(String)
    case invalidResponse
    case timeout
    case providerError(String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured: return "AI provider not configured. Add API key in Settings."
        case .invalidAPIKey: return "Invalid API key. Check your key in Settings."
        case .rateLimited: return "Rate limited. Please wait and try again."
        case .networkError(let msg): return "Network error: \(msg)"
        case .invalidResponse: return "Invalid response from AI provider."
        case .timeout: return "Request timed out. Please try again."
        case .providerError(let msg): return "Provider error: \(msg)"
        }
    }
}
