import Foundation

/// Thin wrapper around OpenAICompatibleProvider for the z.ai endpoint
final class ZAIProvider: AIProviderProtocol, @unchecked Sendable {
    var name: String { "z.ai" }

    private let keychain = KeychainService.shared
    private let apiKeyRef: String?
    private lazy var inner: OpenAICompatibleProvider = {
        let provider: () -> String? = if let ref = apiKeyRef {
            { KeychainService.shared.getValue(forRef: ref) }
        } else {
            { [weak self] in self?.keychain.get(.zaiAPIKey) }
        }
        return OpenAICompatibleProvider(
            name: "z.ai",
            baseURL: "https://api.z.ai/api/paas/v4",
            apiKeyProvider: provider
        )
    }()

    init(apiKeyRef: String? = nil) {
        self.apiKeyRef = apiKeyRef
    }

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
