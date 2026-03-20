import Foundation

/// Reusable provider for any OpenAI-compatible API (z.ai, OpenRouter, Groq, Ollama, etc.)
final class OpenAICompatibleProvider: AIProviderProtocol, @unchecked Sendable {
    let name: String
    private let baseURL: String
    private let apiKeyProvider: () -> String?
    private let timeout: TimeInterval
    private let defaultModel = "gpt-4o-mini"

    init(name: String, baseURL: String, apiKeyProvider: @escaping () -> String?, timeout: TimeInterval = 30) {
        self.name = name
        let trimmed = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.baseURL = trimmed
        self.apiKeyProvider = apiKeyProvider
        self.timeout = timeout
    }

    /// Convenience init using a Keychain ref string instead of a closure
    convenience init(name: String, baseURL: String, apiKeyRef: String, timeout: TimeInterval = 30) {
        self.init(
            name: name,
            baseURL: baseURL,
            apiKeyProvider: { KeychainService.shared.getValue(forRef: apiKeyRef) },
            timeout: timeout
        )
    }

    var isConfigured: Bool {
        guard let key = apiKeyProvider() else { return false }
        return !key.isEmpty && Self.isValidBaseURL(baseURL)
    }

    /// Validate base URL: must be https (or http for localhost dev), no file/ftp schemes
    static func isValidBaseURL(_ urlString: String) -> Bool {
        guard !urlString.isEmpty,
              let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              let host = url.host?.lowercased() else { return false }
        // Allow http only for localhost (local dev with Ollama etc.)
        if scheme == "http" { return host == "localhost" || host == "127.0.0.1" }
        return scheme == "https" && !host.isEmpty
    }

    // MARK: - Single-shot enhance

    func enhance(text: String, attachments: [AIAttachment], mode: AIModeData) async throws -> AIEnhancementResult {
        guard let apiKey = apiKeyProvider() else { throw AIError.notConfigured }
        let startTime = Date()
        let modelName = mode.modelName.isEmpty ? defaultModel : mode.modelName

        let requestBody: [String: Any] = [
            "model": modelName,
            "messages": [
                ["role": "system", "content": mode.systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.7,
            "max_tokens": 2048
        ]

        let request = try buildRequest(body: requestBody, apiKey: apiKey)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.invalidResponse }
        try Self.validateHTTPResponse(http)

        let content = try parseCompletionResponse(data)
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
        guard let apiKey = apiKeyProvider() else { throw AIError.notConfigured }
        let modelName = mode.modelName.isEmpty ? defaultModel : mode.modelName

        var apiMessages: [[String: String]] = [
            ["role": "system", "content": mode.systemPrompt]
        ]
        for msg in messages where msg.role != .system {
            apiMessages.append(["role": msg.role.rawValue, "content": msg.content])
        }

        let requestBody: [String: Any] = [
            "model": modelName,
            "messages": apiMessages,
            "temperature": 0.7,
            "max_tokens": 4096,
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
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))

                        if payload == "[DONE]" {
                            continuation.yield(.done(tokensUsed: nil))
                            break
                        }

                        guard let jsonData = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let content = delta["content"] as? String else {
                            continue
                        }
                        continuation.yield(.text(content))
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
        guard let apiKey = apiKeyProvider() else { throw AIError.notConfigured }

        // Use a minimal chat completion (some providers like z.ai don't have /models endpoint)
        let requestBody: [String: Any] = [
            "model": defaultModel,
            "messages": [["role": "user", "content": "hi"]],
            "max_tokens": 5
        ]

        let request = try buildRequest(body: requestBody, apiKey: apiKey)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.invalidResponse }
        if http.statusCode == 401 { throw AIError.invalidAPIKey }
        // 402/403 (insufficient balance) still means connection works, key is valid
        return (200...403).contains(http.statusCode)
    }

    // MARK: - Private helpers

    private func buildRequest(body: [String: Any], apiKey: String) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw AIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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

    private func parseCompletionResponse(_ data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.invalidResponse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
