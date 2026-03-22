import Foundation

/// Provider for the Anthropic Messages API (Claude models).
/// Uses x-api-key auth and /v1/messages endpoint — NOT OpenAI-compatible.
final class AnthropicProvider: AIProviderProtocol, @unchecked Sendable {
    var name: String { "Anthropic" }

    private let baseURL = "https://api.anthropic.com"
    private let apiVersion = "2023-06-01"
    private let defaultModel = "claude-sonnet-4-20250514"
    private let keychain = KeychainService.shared
    private let apiKeyRef: String?

    init(apiKeyRef: String? = nil) {
        self.apiKeyRef = apiKeyRef
    }

    var isConfigured: Bool {
        resolveAPIKey() != nil
    }

    private func resolveAPIKey() -> String? {
        if let ref = apiKeyRef { return keychain.getValue(forRef: ref) }
        return keychain.get(.anthropicAPIKey)
    }

    // MARK: - Single-shot enhance

    func enhance(text: String, attachments: [AIAttachment], mode: AIModeData) async throws -> AIEnhancementResult {
        guard let apiKey = resolveAPIKey() else { throw AIError.notConfigured }
        let startTime = Date()
        let modelName = mode.modelName.isEmpty ? defaultModel : mode.modelName

        let requestBody: [String: Any] = [
            "model": modelName,
            "max_tokens": 2048,
            "system": mode.systemPrompt,
            "messages": [["role": "user", "content": text]]
        ]

        let request = try buildRequest(body: requestBody, apiKey: apiKey)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validateHTTPResponse(response)

        let content = try parseMessageResponse(data)
        let processingTime = Date().timeIntervalSince(startTime)

        return AIEnhancementResult(
            originalText: text,
            enhancedText: content,
            modeName: mode.name,
            provider: "\(name) (\(modelName))",
            tokensUsed: nil,
            processingTime: processingTime
        )
    }

    // MARK: - Streaming chat

    func streamChat(messages: [ChatMessage], mode: AIModeData) async throws -> AsyncThrowingStream<ChatStreamChunk, Error> {
        guard let apiKey = resolveAPIKey() else { throw AIError.notConfigured }
        let modelName = mode.modelName.isEmpty ? defaultModel : mode.modelName

        var apiMessages: [[String: String]] = []
        for msg in messages where msg.role != .system {
            apiMessages.append(["role": msg.role.rawValue, "content": msg.content])
        }

        let requestBody: [String: Any] = [
            "model": modelName,
            "max_tokens": 4096,
            "system": mode.systemPrompt,
            "messages": apiMessages,
            "stream": true
        ]

        let request = try buildRequest(body: requestBody, apiKey: apiKey)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    try Self.validateHTTPResponse(response)

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        // Anthropic SSE: "event: content_block_delta" then "data: {...}"
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))

                        guard let jsonData = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                              let type = json["type"] as? String else { continue }

                        switch type {
                        case "content_block_delta":
                            if let delta = json["delta"] as? [String: Any],
                               let text = delta["text"] as? String {
                                continuation.yield(.text(text))
                            }
                        case "message_stop":
                            continuation.yield(.done(tokensUsed: nil))
                        case "error":
                            if let error = json["error"] as? [String: Any],
                               let message = error["message"] as? String {
                                continuation.finish(throwing: AIError.providerError("Anthropic: \(message)"))
                                return
                            }
                        default:
                            continue
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Test connection

    func testConnection() async throws -> Bool {
        guard let apiKey = resolveAPIKey() else { throw AIError.notConfigured }

        let requestBody: [String: Any] = [
            "model": defaultModel,
            "max_tokens": 5,
            "messages": [["role": "user", "content": "hi"]]
        ]

        let request = try buildRequest(body: requestBody, apiKey: apiKey)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.invalidResponse }
        if http.statusCode == 401 { throw AIError.invalidAPIKey }
        return (200...299).contains(http.statusCode)
    }

    // MARK: - Private helpers

    private func buildRequest(body: [String: Any], apiKey: String) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/v1/messages") else {
            throw AIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private static func validateHTTPResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw AIError.invalidResponse }
        switch http.statusCode {
        case 200...299: return
        case 401: throw AIError.invalidAPIKey
        case 429: throw AIError.rateLimited
        default: throw AIError.providerError("HTTP \(http.statusCode)")
        }
    }

    private func parseMessageResponse(_ data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw AIError.invalidResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
