import SwiftData
import Foundation

/// Persistent AI provider configuration. Each provider stores its own API key reference,
/// base URL, and editable model list. Users can have up to 10 providers (2 default + 8 custom).
@Model
final class AIProviderModel: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var providerTypeRaw: String
    var baseURL: String?
    var apiKeyRef: String
    var modelsRaw: String
    var defaultModelName: String?
    var isDefault: Bool
    var isEnabled: Bool
    var sortOrder: Int
    var createdAt: Date

    // MARK: - Computed Properties

    var providerType: AIProviderType {
        get { AIProviderType(rawValue: providerTypeRaw) ?? .gemini }
        set { providerTypeRaw = newValue.rawValue }
    }

    var models: [String] {
        get {
            guard let data = modelsRaw.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return arr
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let str = String(data: data, encoding: .utf8) else {
                modelsRaw = "[]"
                return
            }
            modelsRaw = str
        }
    }

    var isConfigured: Bool {
        KeychainService.shared.getValue(forRef: apiKeyRef) != nil
    }

    /// Whether this provider type requires a user-supplied base URL
    var requiresBaseURL: Bool { providerType == .openai }

    /// Whether this provider supports image/PDF attachments
    var supportsAttachments: Bool { providerType.supportsAnyAttachments }

    // MARK: - Limits

    static let maxProviderCount = 10

    // MARK: - Init

    init(
        name: String,
        providerType: AIProviderType,
        baseURL: String? = nil,
        apiKeyRef: String,
        models: [String],
        defaultModelName: String? = nil,
        isDefault: Bool = false,
        isEnabled: Bool = true,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.providerTypeRaw = providerType.rawValue
        self.baseURL = baseURL
        self.apiKeyRef = apiKeyRef
        self.defaultModelName = defaultModelName ?? models.first
        self.isDefault = isDefault
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.createdAt = Date()

        // Encode models to JSON string
        if let data = try? JSONEncoder().encode(models),
           let str = String(data: data, encoding: .utf8) {
            self.modelsRaw = str
        } else {
            self.modelsRaw = "[]"
        }
    }
}
