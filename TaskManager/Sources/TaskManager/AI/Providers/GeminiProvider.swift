import Foundation
import GoogleGenerativeAI
import PDFKit
import os

/// Boxes a non-Sendable value for use in @Sendable closures where exclusive access is guaranteed.
private struct SendableBox<T>: @unchecked Sendable { let value: T }

private let chatLog = Logger(subsystem: "com.strata.app", category: "GeminiChat")

final class GeminiProvider: AIProviderProtocol, @unchecked Sendable {
    var name: String { "Google Gemini" }

    private let keychain = KeychainService.shared
    private let defaultModel = "gemini-flash-lite-latest"
    private let apiKeyRef: String?

    init(apiKeyRef: String? = nil) {
        self.apiKeyRef = apiKeyRef
    }

    var isConfigured: Bool {
        resolveAPIKey() != nil
    }

    /// Resolve API key: prefer dynamic ref, fallback to legacy Keychain key
    private func resolveAPIKey() -> String? {
        if let ref = apiKeyRef { return keychain.getValue(forRef: ref) }
        return keychain.get(.geminiAPIKey)
    }

    func enhance(text: String, attachments: [AIAttachment], mode: AIModeData) async throws -> AIEnhancementResult {
        guard let apiKey = resolveAPIKey() else {
            throw AIError.notConfigured
        }

        let startTime = Date()
        let modelName = mode.modelName.isEmpty ? defaultModel : mode.modelName
        let model = GenerativeModel(name: modelName, apiKey: apiKey)

        if attachments.isEmpty {
            let prompt = """
            \(mode.systemPrompt)

            Text to process:
            \(text)
            """

            do {
                let response = try await model.generateContent(prompt)

                guard let enhancedText = response.text else {
                    throw AIError.invalidResponse
                }

                let processingTime = Date().timeIntervalSince(startTime)

                return AIEnhancementResult(
                    originalText: text,
                    enhancedText: enhancedText.trimmingCharacters(in: .whitespacesAndNewlines),
                    modeName: mode.name,
                    provider: "\(name) (\(modelName))",
                    tokensUsed: nil,
                    processingTime: processingTime
                )
            } catch let error as GenerateContentError {
                throw mapGeminiError(error)
            } catch {
                throw AIError.networkError(error.localizedDescription)
            }
        }

        let prepared = try await Task.detached(priority: .userInitiated) { () -> (images: [(mimeType: String, data: Data)], textContent: String) in
            var images: [(mimeType: String, data: Data)] = []
            var textContent = mode.systemPrompt + "\n\n"

            if !text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                textContent += "User's text:\n\(text)\n\n"
            }

            for attachment in attachments {
                switch attachment.kind {
                case .image:
                    images.append((attachment.mimeType, try attachment.loadData()))
                    textContent += "An image has been attached.\n"
                case .pdf:
                    images.append((attachment.mimeType, try attachment.loadData()))
                    textContent += "A PDF has been attached (\(attachment.fileName)).\n"
                }
            }

            return (images, textContent)
        }.value

        var parts = prepared.images.map { ModelContent.Part.data(mimetype: $0.mimeType, $0.data) }
        parts.insert(.text(prepared.textContent), at: 0)

        do {
            let response = try await model.generateContent([ModelContent(parts: parts)])

            guard let enhancedText = response.text else {
                throw AIError.invalidResponse
            }

            let processingTime = Date().timeIntervalSince(startTime)

            return AIEnhancementResult(
                originalText: text,
                enhancedText: enhancedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
                modeName: mode.name,
                provider: "\(name) (\(modelName))",
                tokensUsed: nil,
                processingTime: processingTime
            )
        } catch let error as GenerateContentError {
            throw mapGeminiError(error)
        } catch {
            throw AIError.networkError(error.localizedDescription)
        }
    }

    func streamChat(messages: [ChatMessage], mode: AIModeData) async throws -> AsyncThrowingStream<ChatStreamChunk, Error> {
        guard let apiKey = resolveAPIKey() else { throw AIError.notConfigured }
        let modelName = mode.modelName.isEmpty ? defaultModel : mode.modelName
        chatLog.info("streamChat: model=\(modelName), messages=\(messages.count)")

        let model = GenerativeModel(name: modelName, apiKey: apiKey)

        // Build prompt text from conversation history
        var prompt = mode.systemPrompt + "\n\n"
        for msg in messages {
            guard msg.role != .system else { continue }
            let label = msg.role == .user ? "User" : "Assistant"
            prompt += "\(label): \(msg.content)\n\n"
        }
        prompt += "Assistant:"

        // Build parts: text prompt + attachments from the last message (multimodal support)
        var parts: [ModelContent.Part] = [.text(prompt)]
        if let lastMsg = messages.last, !lastMsg.attachments.isEmpty {
            for attachment in lastMsg.attachments {
                parts.append(.data(mimetype: attachment.mimeType, try attachment.loadData()))
            }
            chatLog.info("streamChat: \(lastMsg.attachments.count) attachment(s) included")
        }
        chatLog.info("streamChat: prompt length=\(prompt.count), parts=\(parts.count)")

        let boxedModel = SendableBox(value: model)
        let boxedParts = SendableBox(value: parts)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let content = [ModelContent(parts: boxedParts.value)]
                    let stream = boxedModel.value.generateContentStream(content)
                    for try await response in stream {
                        if Task.isCancelled { break }
                        if let text = response.text {
                            chatLog.debug("streamChat: chunk: \(text.prefix(50))")
                            continuation.yield(.text(text))
                        }
                    }
                    chatLog.info("streamChat: stream complete")
                    continuation.yield(.done(tokensUsed: nil))
                    continuation.finish()
                } catch let error as GenerateContentError {
                    chatLog.error("streamChat: stream error: \(error)")
                    continuation.finish(throwing: GeminiProvider.geminiErrorToAIError(error))
                } catch {
                    chatLog.error("streamChat: stream error: \(error)")
                    continuation.finish(throwing: AIError.networkError(error.localizedDescription))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func testConnection() async throws -> Bool {
        guard let apiKey = resolveAPIKey() else {
            throw AIError.notConfigured
        }

        let model = GenerativeModel(name: defaultModel, apiKey: apiKey)

        do {
            _ = try await model.generateContent("Say hello")
            return true
        } catch let error as GenerateContentError {
            throw mapGeminiError(error)
        } catch {
            throw AIError.networkError(error.localizedDescription)
        }
    }

    private func mapGeminiError(_ error: GenerateContentError) -> AIError {
        Self.geminiErrorToAIError(error)
    }

    /// Static form used in closures where self capture is not allowed (sending context)
    private static func geminiErrorToAIError(_ error: GenerateContentError) -> AIError {
        switch error {
        case .promptBlocked(let response):
            if let feedback = response.promptFeedback {
                return AIError.providerError("Content blocked: \(feedback.blockReason?.rawValue ?? "safety")")
            }
            return AIError.providerError("Content was blocked by safety filters")
        case .responseStoppedEarly(let reason, _):
            return AIError.providerError("Response stopped: \(reason.rawValue)")
        case .invalidAPIKey:
            return AIError.invalidAPIKey
        case .unsupportedUserLocation:
            return AIError.providerError("Gemini is not available in your region")
        case .internalError(let underlying):
            return AIError.providerError("Gemini internal: \(underlying)")
        default:
            return AIError.providerError("Gemini error: \(error)")
        }
    }
}
