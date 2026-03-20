import Foundation

/// Thin wrapper around OpenAICompatibleProvider for the z.ai endpoint
final class ZAIProvider: AIProviderProtocol, @unchecked Sendable {
    var name: String { "z.ai" }

    private let keychain = KeychainService.shared
    private lazy var inner = OpenAICompatibleProvider(
        name: "z.ai",
        baseURL: "https://api.z.ai/v1",
        apiKeyProvider: { [weak self] in self?.keychain.get(.zaiAPIKey) }
    )

    var isConfigured: Bool { inner.isConfigured }

    func enhance(text: String, attachments: [AIAttachment], mode: AIModeData) async throws -> AIEnhancementResult {
        try await inner.enhance(text: text, attachments: attachments, mode: mode)
    }

    func streamChat(messages: [ChatMessage], mode: AIModeData) async throws -> AsyncThrowingStream<ChatStreamChunk, Error> {
        try await inner.streamChat(messages: messages, mode: mode)
    }

    func testConnection() async throws -> Bool {
        try await inner.testConnection()
    }
}
