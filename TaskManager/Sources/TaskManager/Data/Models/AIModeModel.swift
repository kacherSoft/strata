import SwiftData
import Foundation

enum AIProviderType: String, Codable, CaseIterable, Sendable {
    case gemini = "gemini"
    case zai = "zai"
    case openai = "openai"

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
        case .zai: return ["GLM-4.7", "GLM-4.5-air"]
        case .openai: return []
        }
    }

    var defaultModel: String {
        availableModels.first ?? ""
    }

    var supportsImageAttachments: Bool {
        switch self {
        case .gemini: return true
        case .zai: return false
        case .openai: return false
        }
    }

    var supportsPDFAttachments: Bool {
        switch self {
        case .gemini: return true
        case .zai: return false
        case .openai: return false
        }
    }

    var supportsAnyAttachments: Bool {
        supportsImageAttachments || supportsPDFAttachments
    }

    /// Provider allows user to type a custom model name (not limited to availableModels list)
    var supportsCustomModel: Bool { self == .openai }

    /// Provider requires a base URL to be configured
    var requiresBaseURL: Bool { self == .openai }
}

@Model
final class AIModeModel: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var systemPrompt: String
    var providerRaw: String
    var modelName: String
    var sortOrder: Int
    var isBuiltIn: Bool
    var supportsAttachments: Bool = false
    var customBaseURL: String?
    var aiProviderId: UUID?
    var createdAt: Date
    
    var provider: AIProviderType {
        get {
            guard let valid = AIProviderType(rawValue: providerRaw) else {
                // Invalid providerRaw — reset both provider AND model to prevent mismatch
                // (e.g. providerRaw="custom" with modelName="gpt-5.4" would route to Gemini with wrong model)
                providerRaw = AIProviderType.gemini.rawValue
                modelName = AIProviderType.gemini.defaultModel
                return .gemini
            }
            return valid
        }
        set { providerRaw = newValue.rawValue }
    }
    
    init(name: String, systemPrompt: String, provider: AIProviderType = .gemini, modelName: String? = nil, isBuiltIn: Bool = false, supportsAttachments: Bool = false, customBaseURL: String? = nil) {
        self.id = UUID()
        self.name = name
        self.systemPrompt = systemPrompt
        self.providerRaw = provider.rawValue
        self.modelName = modelName ?? provider.defaultModel
        self.sortOrder = 0
        self.isBuiltIn = isBuiltIn
        self.supportsAttachments = supportsAttachments
        self.customBaseURL = customBaseURL
        self.createdAt = Date()
    }
    
    static func createDefaultModes() -> [AIModeModel] {
        [
            AIModeModel(
                name: "Correct Me",
                systemPrompt: "You are an expert editor. Correct grammar, spelling, and improve fluency while maintaining the original meaning and tone. Only output the corrected text, nothing else.",
                provider: .gemini,
                isBuiltIn: true
            ),
            AIModeModel(
                name: "Enhance Prompt",
                systemPrompt: "You are an expert at writing clear, detailed descriptions. Expand this text with more specific details, actionable steps, and context. Make it clearer and more comprehensive. Only output the enhanced text, nothing else.",
                provider: .gemini,
                isBuiltIn: true
            ),
            AIModeModel(
                name: "Explain",
                systemPrompt: "You are an expert explainer. If an image or document is attached, analyze and explain it clearly and concisely. Otherwise, analyze the provided text. Break down complex concepts into understandable language. Only output the explanation, nothing else.",
                provider: .gemini,
                isBuiltIn: true,
                supportsAttachments: true
            )
        ]
    }
}
