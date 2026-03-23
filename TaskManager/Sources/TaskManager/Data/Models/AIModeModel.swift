import SwiftData
import Foundation

enum AIProviderType: String, Codable, CaseIterable, Sendable {
    case gemini = "gemini"
    case anthropic = "anthropic"
    case openai = "openai"

    var displayName: String {
        switch self {
        case .gemini: return "Google Gemini"
        case .anthropic: return "Anthropic"
        case .openai: return "OpenAI Compatible"
        }
    }

    var availableModels: [String] {
        switch self {
        case .gemini: return ["gemini-flash-lite-latest", "gemini-flash-latest", "gemini-3-flash-preview"]
        case .anthropic: return ["claude-sonnet-4-20250514", "claude-haiku-4-5-20251001"]
        case .openai: return []
        }
    }

    var defaultModel: String {
        availableModels.first ?? ""
    }

    var supportsImageAttachments: Bool {
        switch self {
        case .gemini: return true
        case .anthropic: return false
        case .openai: return false
        }
    }

    var supportsPDFAttachments: Bool {
        switch self {
        case .gemini: return true
        case .anthropic: return false
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

// MARK: - View Type

enum AIModeViewType: String, Codable, CaseIterable, Sendable {
    case enhance = "enhance"
    case chat = "chat"

    var displayName: String {
        switch self {
        case .enhance: return "Enhance"
        case .chat: return "Chat"
        }
    }

    var iconName: String {
        switch self {
        case .enhance: return "wand.and.stars"
        case .chat: return "bubble.left.and.bubble.right"
        }
    }
}

// MARK: - AI Mode Model

@Model
final class AIModeModel: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var systemPrompt: String
    var providerRaw: String
    var modelName: String
    var sortOrder: Int
    var isBuiltIn: Bool
    var customBaseURL: String?
    var aiProviderId: UUID?
    var createdAt: Date

    // V4 fields
    var viewTypeRaw: String?
    var autoCopyOutput: Bool = false

    // Legacy field — kept for schema compatibility, no longer used
    var supportsAttachments: Bool = false

    // MARK: - Computed Properties

    var provider: AIProviderType {
        get {
            if providerRaw == "zai" {
                providerRaw = AIProviderType.anthropic.rawValue
                modelName = AIProviderType.anthropic.defaultModel
                return .anthropic
            }
            guard let valid = AIProviderType(rawValue: providerRaw) else {
                providerRaw = AIProviderType.gemini.rawValue
                modelName = AIProviderType.gemini.defaultModel
                return .gemini
            }
            return valid
        }
        set { providerRaw = newValue.rawValue }
    }

    var viewType: AIModeViewType {
        get {
            guard let raw = viewTypeRaw, let type = AIModeViewType(rawValue: raw) else {
                return .enhance
            }
            return type
        }
        set { viewTypeRaw = newValue.rawValue }
    }

    // MARK: - Init

    init(
        name: String,
        systemPrompt: String,
        provider: AIProviderType = .gemini,
        modelName: String? = nil,
        isBuiltIn: Bool = false,
        viewType: AIModeViewType = .enhance,
        autoCopyOutput: Bool = false,
        customBaseURL: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.systemPrompt = systemPrompt
        self.providerRaw = provider.rawValue
        self.modelName = modelName ?? provider.defaultModel
        self.sortOrder = 0
        self.isBuiltIn = isBuiltIn
        self.viewTypeRaw = viewType.rawValue
        self.autoCopyOutput = autoCopyOutput
        self.customBaseURL = customBaseURL
        self.createdAt = Date()
    }

    // MARK: - Built-in Defaults

    static func createDefaultModes() -> [AIModeModel] {
        [
            AIModeModel(
                name: "Correct Me",
                systemPrompt: "You are an expert editor. Correct grammar, spelling, and improve fluency while maintaining the original meaning and tone. Only output the corrected text, nothing else.",
                provider: .gemini,
                isBuiltIn: true,
                viewType: .enhance,
                autoCopyOutput: true
            ),
            AIModeModel(
                name: "Chat",
                systemPrompt: "You are a helpful, knowledgeable assistant. Respond conversationally. Use markdown formatting for code blocks, lists, and emphasis when appropriate.",
                provider: .gemini,
                isBuiltIn: true,
                viewType: .chat
            )
        ]
    }
}
