import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class AIService {
    static let shared = AIService()

    private(set) var currentMode: AIModeModel?
    private(set) var isProcessing = false
    private(set) var lastError: AIError?

    private let geminiProvider = GeminiProvider()
    private let anthropicProvider = AnthropicProvider()

    private init() {}

    /// Resolve provider from legacy enum + optional base URL (backward compat)
    func providerFor(_ type: AIProviderType, customBaseURL: String? = nil) -> AIProviderProtocol {
        switch type {
        case .gemini: return geminiProvider
        case .anthropic: return anthropicProvider
        case .openai:
            guard let baseURL = customBaseURL, !baseURL.isEmpty else {
                // No base URL for OpenAI-compatible → not configured
                return anthropicProvider
            }
            return OpenAICompatibleProvider(
                name: "OpenAI Compatible",
                baseURL: baseURL,
                apiKeyProvider: { KeychainService.shared.get(.openaiAPIKey) }
            )
        }
    }

    /// Resolve provider from AIProviderModel (new dynamic system)
    func providerFor(_ model: AIProviderModel) -> AIProviderProtocol {
        switch model.providerType {
        case .gemini:
            return GeminiProvider(apiKeyRef: model.apiKeyRef)
        case .anthropic:
            return AnthropicProvider(apiKeyRef: model.apiKeyRef)
        case .openai:
            let provider = OpenAICompatibleProvider(
                name: model.name,
                baseURL: model.baseURL ?? "",
                apiKeyRef: model.apiKeyRef
            )
            provider.testModelName = model.defaultModelName ?? model.models.first
            return provider
        }
    }

    func isConfigured(for provider: AIProviderType) -> Bool {
        providerFor(provider).isConfigured
    }

    var hasAnyProviderConfigured: Bool {
        geminiProvider.isConfigured || anthropicProvider.isConfigured || KeychainService.shared.hasKey(.openaiAPIKey)
    }

    func setMode(_ mode: AIModeModel) {
        currentMode = mode
    }

    private func persistSelectedMode(_ modeId: UUID?, in context: ModelContext) {
        do {
            if let settings = try context.fetch(FetchDescriptor<SettingsModel>()).first {
                settings.selectedAIModeId = modeId
                settings.touch()
                try context.save()
            }
        } catch {
            return
        }
    }

    func cycleMode(in context: ModelContext) {
        let descriptor = FetchDescriptor<AIModeModel>(sortBy: [SortDescriptor(\.sortOrder)])
        do {
            let modes = try context.fetch(descriptor)
            guard !modes.isEmpty else { return }

            if let current = currentMode,
               let currentIndex = modes.firstIndex(where: { $0.id == current.id }) {
                let nextIndex = (currentIndex + 1) % modes.count
                currentMode = modes[nextIndex]
            } else {
                currentMode = modes.first
            }

            persistSelectedMode(currentMode?.id, in: context)
        } catch {
            return
        }
    }

    func loadDefaultMode(from context: ModelContext) {
        guard currentMode == nil else { return }

        let descriptor = FetchDescriptor<AIModeModel>(sortBy: [SortDescriptor(\.sortOrder)])
        do {
            let modes = try context.fetch(descriptor)
            if let settings = try context.fetch(FetchDescriptor<SettingsModel>()).first,
               let selectedModeId = settings.selectedAIModeId,
               let selected = modes.first(where: { $0.id == selectedModeId }) {
                currentMode = selected
                return
            }

            currentMode = modes.first
            persistSelectedMode(currentMode?.id, in: context)
        } catch {
            return
        }
    }

    func enhance(text: String, attachments: [AIAttachment] = [], mode: AIModeModel) async throws -> AIEnhancementResult {
        let modeData = AIModeData(from: mode)
        let provider = providerFor(modeData.provider, customBaseURL: modeData.customBaseURL)

        guard provider.isConfigured else {
            throw AIError.notConfigured
        }

        isProcessing = true
        lastError = nil

        defer { isProcessing = false }

        do {
            let result = try await provider.enhance(text: text, attachments: attachments, mode: modeData)
            return result
        } catch let error as AIError {
            lastError = error
            throw error
        } catch {
            let aiError = AIError.networkError(error.localizedDescription)
            lastError = aiError
            throw aiError
        }
    }

    func testProvider(_ type: AIProviderType) async throws -> Bool {
        try await providerFor(type).testConnection()
    }
}
