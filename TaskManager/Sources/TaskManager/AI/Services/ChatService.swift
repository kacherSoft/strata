import Foundation
import SwiftData
import Observation

/// Manages a single streaming chat exchange with an AI provider.
/// Holds observable state (isStreaming, currentStreamText) for UI binding.
@MainActor
@Observable
final class ChatService {
    private(set) var isStreaming = false
    private(set) var currentStreamText = ""
    private(set) var lastError: AIError?
    var streamTask: Task<Void, Never>?

    private let aiService = AIService.shared

    /// Send a user message and stream the response, returning the full assistant reply.
    func sendMessage(
        userMessage: String,
        attachments: [AIAttachment],
        history: [ChatMessage],
        mode: AIModeData
    ) async throws -> String {
        guard !isStreaming else { throw AIError.providerError("Already streaming") }

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
            if Task.isCancelled { break }
            switch chunk {
            case .text(let token):
                currentStreamText += token
            case .done:
                break
            case .error(let error):
                lastError = error
                throw error
            }
        }
        return currentStreamText
    }

    /// Cancel the in-flight streaming request
    func cancelStream() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        // Don't clear currentStreamText — caller reads it to save partial response.
        // It's cleared at the start of the next sendMessage() call.
    }
}
