# Phase 2 — Streaming Provider Protocol + OpenAI-Compatible Provider

## Context
- [plan.md](plan.md)
- [AIProvider.swift](../../TaskManager/Sources/TaskManager/AI/Protocols/AIProvider.swift)
- [GeminiProvider.swift](../../TaskManager/Sources/TaskManager/AI/Providers/GeminiProvider.swift)
- [ZAIProvider.swift](../../TaskManager/Sources/TaskManager/AI/Providers/ZAIProvider.swift)
- [AIModeModel.swift](../../TaskManager/Sources/TaskManager/Data/Models/AIModeModel.swift)
- [AIService.swift](../../TaskManager/Sources/TaskManager/AI/Services/AIService.swift)

## Overview
- **Priority:** P1 (blocks phase 4)
- **Status:** completed
- **Effort:** 5h

Extend AIProviderProtocol with streaming. Extract OpenAI-compatible SSE streaming into a reusable provider so ANY OpenAI-compatible endpoint works (not just z.ai). Add `.openai` provider type with user-configurable base URL.

## Key Insights

- z.ai is OpenAI-compatible (`/chat/completions`, SSE with `stream: true`). Same protocol as OpenRouter, Groq, Together AI, Ollama, etc.
- Hardcoding SSE logic in ZAIProvider wastes it. Extract into `OpenAICompatibleProvider` that takes `baseURL` + `apiKey` at init.
- ZAIProvider becomes a thin wrapper: `OpenAICompatibleProvider(baseURL: "https://api.z.ai/v1", keychainKey: .zaiAPIKey)`.
- New `AIProviderType.openai` case lets users configure custom endpoints in Settings → AI Modes.
- `AIModeModel` needs `customBaseURL: String?` field — only used when provider is `.openai`.
- Gemini stays separate (SDK-based, not OpenAI-compatible).

## Architecture

```
AIProviderProtocol
├── GeminiProvider (SDK-based, streaming via Chat.sendMessageStream())
├── ZAIProvider (delegates to OpenAICompatibleProvider with hardcoded baseURL)
└── OpenAICompatibleProvider (reusable, configurable baseURL + apiKey)
     ↑ Used directly for .openai provider type
     ↑ Used by ZAIProvider internally
```

## New Files

### `AI/Providers/OpenAICompatibleProvider.swift`

Generic provider for any OpenAI-compatible API endpoint.

```swift
/// Reusable provider for any OpenAI-compatible API (z.ai, OpenRouter, Groq, Ollama, etc.)
final class OpenAICompatibleProvider: AIProviderProtocol, @unchecked Sendable {
    let name: String
    private let baseURL: String
    private let apiKeyProvider: () -> String?  // closure to fetch API key
    private let timeout: TimeInterval

    init(name: String, baseURL: String, apiKeyProvider: @escaping () -> String?, timeout: TimeInterval = 30) {
        self.name = name
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.apiKeyProvider = apiKeyProvider
        self.timeout = timeout
    }

    var isConfigured: Bool {
        apiKeyProvider() != nil && !baseURL.isEmpty
    }

    // MARK: - Single-shot (existing enhance pattern)

    func enhance(text: String, attachments: [AIAttachment], mode: AIModeData) async throws -> AIEnhancementResult {
        guard let apiKey = apiKeyProvider() else { throw AIError.notConfigured }
        let startTime = Date()
        let modelName = mode.modelName.isEmpty ? "gpt-4o-mini" : mode.modelName

        let requestBody: [String: Any] = [
            "model": modelName,
            "messages": [
                ["role": "system", "content": mode.systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.7,
            "max_tokens": 2048
        ]

        let (data, _) = try await executeRequest(body: requestBody, apiKey: apiKey, stream: false)
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
        let modelName = mode.modelName.isEmpty ? "gpt-4o-mini" : mode.modelName

        // Build messages array in OpenAI format
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

                    // Parse SSE stream
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

    func testConnection() async throws -> Bool {
        guard let apiKey = apiKeyProvider() else { throw AIError.notConfigured }
        guard let url = URL(string: "\(baseURL)/models") else { throw AIError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.invalidResponse }
        if http.statusCode == 401 { throw AIError.invalidAPIKey }
        return (200...299).contains(http.statusCode)
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

    private func executeRequest(body: [String: Any], apiKey: String, stream: Bool) async throws -> (Data, HTTPURLResponse) {
        let request = try buildRequest(body: body, apiKey: apiKey)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.invalidResponse }
        try Self.validateHTTPResponse(http)
        return (data, http)
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
```

**This single class replaces ALL OpenAI-compatible endpoint logic.** Works with z.ai, OpenRouter, Groq, Together AI, Ollama (`http://localhost:11434/v1`), etc.

### `AI/Models/ChatStreamTypes.swift`

```swift
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
```

### `AI/Services/ChatService.swift`

```swift
@MainActor
@Observable
final class ChatService {
    private(set) var isStreaming = false
    private(set) var currentStreamText = ""
    private(set) var lastError: AIError?
    private var streamTask: Task<Void, Never>?

    private let aiService = AIService.shared

    func sendMessage(
        userMessage: String,
        attachments: [AIAttachment],
        history: [ChatMessage],
        mode: AIModeData
    ) async throws -> String {
        let provider = aiService.providerFor(mode.provider, customBaseURL: mode.customBaseURL)
        guard provider.isConfigured else { throw AIError.notConfigured }

        isStreaming = true
        currentStreamText = ""
        lastError = nil
        defer { isStreaming = false }

        var messages = history
        messages.append(ChatMessage(role: .user, content: userMessage, attachments: attachments))

        let stream = try await provider.streamChat(messages: messages, mode: mode)
        for try await chunk in stream {
            switch chunk {
            case .text(let token): currentStreamText += token
            case .done: break
            case .error(let error):
                lastError = error
                throw error
            }
        }
        return currentStreamText
    }

    func cancelStream() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }
}
```

## Modified Files

### `Data/Models/AIModeModel.swift`

**1. Add `.openai` case to `AIProviderType`:**

```swift
enum AIProviderType: String, Codable, CaseIterable, Sendable {
    case gemini = "gemini"
    case zai = "zai"
    case openai = "openai"  // NEW — any OpenAI-compatible endpoint

    var displayName: String {
        switch self {
        case .gemini: return "Google Gemini"
        case .zai: return "z.ai"
        case .openai: return "OpenAI Compatible"
        }
    }

    var availableModels: [String] {
        switch self {
        case .gemini: return ["gemini-flash-lite-latest", "gemini-flash-latest", "gemini-3-flash-preview"]
        case .zai: return ["GLM-4.6", "GLM-4.7"]
        case .openai: return []  // user types model name manually
        }
    }

    var supportsCustomModel: Bool { self == .openai }  // NEW
    var requiresBaseURL: Bool { self == .openai }       // NEW

    var supportsImageAttachments: Bool {
        switch self {
        case .gemini: return true
        case .zai, .openai: return false  // conservative default
        }
    }

    var supportsPDFAttachments: Bool {
        switch self {
        case .gemini: return true
        case .zai, .openai: return false
        }
    }
}
```

**2. Add `customBaseURL` to AIModeModel:**

```swift
@Model
final class AIModeModel: Identifiable {
    // ... existing properties ...
    var customBaseURL: String?  // NEW — only used when provider == .openai
}
```

**3. Update `AIModeData` to carry the base URL:**

```swift
struct AIModeData: Sendable {
    let name: String
    let systemPrompt: String
    let provider: AIProviderType
    let modelName: String
    let supportsAttachments: Bool
    let customBaseURL: String?  // NEW

    init(from mode: AIModeModel) {
        self.name = mode.name
        self.systemPrompt = mode.systemPrompt
        self.provider = mode.provider
        self.modelName = mode.modelName
        self.supportsAttachments = mode.supportsAttachments
        self.customBaseURL = mode.customBaseURL  // NEW
    }
}
```

### `AI/Services/AIService.swift`

Update `providerFor()` to handle `.openai`:

```swift
func providerFor(_ type: AIProviderType, customBaseURL: String? = nil) -> AIProviderProtocol {
    switch type {
    case .gemini: return geminiProvider
    case .zai: return zaiProvider
    case .openai:
        guard let baseURL = customBaseURL, !baseURL.isEmpty else {
            return zaiProvider  // fallback — shouldn't happen if UI validates
        }
        // Create on-demand with user's base URL + openai API key from keychain
        return OpenAICompatibleProvider(
            name: "OpenAI Compatible",
            baseURL: baseURL,
            apiKeyProvider: { [weak self] in self?.keychain.get(.openaiAPIKey) }
        )
    }
}
```

**Add `.openaiAPIKey` to KeychainService** (follow existing `.geminiAPIKey`/`.zaiAPIKey` pattern).

### `AI/Providers/ZAIProvider.swift`

Simplify by delegating to `OpenAICompatibleProvider`:

```swift
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
```

**Much simpler.** All SSE/HTTP logic lives in one place.

### `AI/Protocols/AIProvider.swift`

Add streaming method with default fallback (unchanged from before):

```swift
protocol AIProviderProtocol: Sendable {
    var name: String { get }
    var isConfigured: Bool { get }
    func enhance(text: String, attachments: [AIAttachment], mode: AIModeData) async throws -> AIEnhancementResult
    func testConnection() async throws -> Bool
    func streamChat(messages: [ChatMessage], mode: AIModeData) async throws -> AsyncThrowingStream<ChatStreamChunk, Error>
}

extension AIProviderProtocol {
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
```

### `AI/Providers/GeminiProvider.swift`

Add `streamChat()` using SDK Chat class (same as previous plan — no changes):

```swift
func streamChat(messages: [ChatMessage], mode: AIModeData) async throws -> AsyncThrowingStream<ChatStreamChunk, Error> {
    guard let apiKey = keychain.get(.geminiAPIKey) else { throw AIError.notConfigured }
    let modelName = mode.modelName.isEmpty ? defaultModel : mode.modelName
    let model = GenerativeModel(
        name: modelName, apiKey: apiKey,
        systemInstruction: ModelContent(role: "system", parts: [.text(mode.systemPrompt)])
    )

    let historyContent = messages.dropLast().compactMap { msg -> ModelContent? in
        guard msg.role != .system else { return nil }
        return ModelContent(role: msg.role == .user ? "user" : "model", parts: [.text(msg.content)])
    }

    let chat = model.startChat(history: historyContent)
    guard let lastMessage = messages.last else { throw AIError.invalidResponse }

    var parts: [ModelContent.Part] = [.text(lastMessage.content)]
    for attachment in lastMessage.attachments {
        parts.append(.data(mimetype: attachment.mimeType, try attachment.loadData()))
    }

    return AsyncThrowingStream { continuation in
        let task = Task {
            do {
                let stream = try chat.sendMessageStream(parts)
                for try await response in stream {
                    if Task.isCancelled { break }
                    if let text = response.text { continuation.yield(.text(text)) }
                }
                continuation.yield(.done(tokensUsed: nil))
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}
```

### `Views/Settings/AIModesSettingsView.swift`

Update `ModeEditorSheet` to show base URL field when `.openai` is selected and allow custom model name:

```swift
// Add State
@State private var customBaseURL = ""

// In Form, after Model picker:
if selectedProvider.requiresBaseURL {
    Section("Endpoint") {
        TextField("Base URL", text: $customBaseURL, prompt: Text("https://api.openai.com/v1"))
            .textFieldStyle(.roundedBorder)
        Text("OpenAI-compatible endpoint (OpenRouter, Groq, Ollama, etc.)")
            .font(.caption).foregroundStyle(.secondary)
    }
}

if selectedProvider.supportsCustomModel {
    Section("Model") {
        TextField("Model name", text: $selectedModel, prompt: Text("gpt-4o-mini"))
            .textFieldStyle(.roundedBorder)
    }
} else {
    // Existing Picker for Gemini/z.ai
}
```

## Implementation Steps

1. Create `ChatStreamTypes.swift`
2. Create `OpenAICompatibleProvider.swift`
3. Add `.openai` case to `AIProviderType` + `customBaseURL` to AIModeModel + AIModeData
4. Add `streamChat()` to AIProviderProtocol with default extension
5. Implement `GeminiProvider.streamChat()`
6. Refactor `ZAIProvider` to delegate to `OpenAICompatibleProvider`
7. Update `AIService.providerFor()` to handle `.openai`
8. Add `.openaiAPIKey` to KeychainService
9. Create `ChatService.swift`
10. Update `ModeEditorSheet` for base URL / custom model fields
11. Build and verify compile
12. Manual test: z.ai still works (regression check)
13. Manual test: Gemini streaming works
14. Manual test: custom OpenAI endpoint (e.g., OpenRouter)

## Todo

- [x] ChatStreamTypes (ChatMessage, ChatStreamChunk)
- [x] OpenAICompatibleProvider (reusable SSE streaming)
- [x] AIProviderType.openai + customBaseURL on AIModeModel/AIModeData
- [x] Protocol extension with streamChat + default fallback
- [x] Gemini streaming via Chat.sendMessageStream()
- [x] Refactor ZAIProvider → delegate to OpenAICompatibleProvider
- [x] AIService.providerFor() handles .openai
- [x] KeychainService: .openaiAPIKey
- [x] ChatService with observable streaming state
- [ ] Settings UI: base URL field for .openai (deferred to phase 3/4 — UI work)
- [x] Build verification
- [ ] Regression test: existing z.ai/Gemini enhance() unaffected (manual test)

## Success Criteria

- `streamChat()` emits text chunks incrementally (not all at once)
- z.ai enhance + streaming works same as before (no regression)
- User can create a custom mode with `.openai` provider, enter any base URL + model name
- Custom OpenAI-compatible endpoint works for both enhance() and streamChat()
- Cancellation stops streaming mid-response
- Default fallback works if a provider doesn't override `streamChat()`
- Settings UI shows base URL field only for `.openai` provider

## Risk Assessment

- **Gemini SDK Chat API surface** — Verify `systemInstruction` param in 0.5.x. Fallback: prepend system prompt as first message.
- **OpenAI-compatible API variations** — Some providers (Ollama) may have slightly different SSE format or auth. The parser is tolerant (skips non-data lines, ignores malformed chunks).
- **API key management** — Single `.openaiAPIKey` in keychain for all custom providers. If user needs different keys per endpoint, would need per-mode key storage (YAGNI for v1 — revisit if requested).
- **Lazy init in ZAIProvider** — `lazy var` with `@unchecked Sendable` is fine since `OpenAICompatibleProvider` is itself Sendable.

## Security Considerations

- API keys stored in Keychain (same as existing Gemini/z.ai keys)
- Custom base URLs are user-provided — no validation beyond URL format. User responsibility.
- No credentials in app binary — all keys from Keychain at runtime.
