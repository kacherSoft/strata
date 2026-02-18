import SwiftData
import Foundation

enum AIProviderType: String, Codable, CaseIterable, Sendable {
    case gemini = "gemini"
    case zai = "zai"
    
    var displayName: String {
        switch self {
        case .gemini: return "Google Gemini"
        case .zai: return "z.ai"
        }
    }
    
    var availableModels: [String] {
        switch self {
        case .gemini: return ["gemini-flash-lite-latest", "gemini-flash-latest", "gemini-3-flash-preview"]
        case .zai: return ["GLM-4.6", "GLM-4.7"]
        }
    }
    
    var defaultModel: String {
        availableModels.first ?? ""
    }

    var supportsImageAttachments: Bool {
        switch self {
        case .gemini: return true
        case .zai: return false
        }
    }

    var supportsPDFAttachments: Bool {
        switch self {
        case .gemini: return true
        case .zai: return false
        }
    }

    var supportsAnyAttachments: Bool {
        supportsImageAttachments || supportsPDFAttachments
    }
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
    var createdAt: Date
    
    var provider: AIProviderType {
        get { AIProviderType(rawValue: providerRaw) ?? .gemini }
        set { providerRaw = newValue.rawValue }
    }
    
    init(name: String, systemPrompt: String, provider: AIProviderType = .gemini, modelName: String? = nil, isBuiltIn: Bool = false, supportsAttachments: Bool = false) {
        self.id = UUID()
        self.name = name
        self.systemPrompt = systemPrompt
        self.providerRaw = provider.rawValue
        self.modelName = modelName ?? provider.defaultModel
        self.sortOrder = 0
        self.isBuiltIn = isBuiltIn
        self.supportsAttachments = supportsAttachments
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
