import Foundation

protocol AIProviderProtocol: Sendable {
    var name: String { get }
    var isConfigured: Bool { get }

    func enhance(text: String, attachments: [AIAttachment], mode: AIModeData) async throws -> AIEnhancementResult
    func testConnection() async throws -> Bool
}

extension AIProviderProtocol {
    func enhance(text: String, mode: AIModeData) async throws -> AIEnhancementResult {
        try await enhance(text: text, attachments: [], mode: mode)
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
