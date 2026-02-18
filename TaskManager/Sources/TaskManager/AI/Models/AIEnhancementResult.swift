import Foundation

struct AIAttachment: Identifiable, Sendable {
    enum Kind: String, Sendable {
        case image
        case pdf
    }

    let id: UUID
    let kind: Kind
    let fileURL: URL
    let mimeType: String
    let fileName: String
    let byteCount: Int

    func loadData() throws -> Data {
        try Data(contentsOf: fileURL)
    }

    static let supportedImageTypes = ["public.png", "public.jpeg", "public.tiff"]
    static let supportedPDFType = "com.adobe.pdf"

    static let maxFileSizeBytes = 10 * 1024 * 1024
    static let maxAttachmentCount = 4
}

struct AIEnhancementResult: Sendable {
    let originalText: String
    let enhancedText: String
    let modeName: String
    let provider: String
    let tokensUsed: Int?
    let processingTime: TimeInterval
}

struct AIModeData: Sendable {
    let name: String
    let systemPrompt: String
    let provider: AIProviderType
    let modelName: String
    let supportsAttachments: Bool

    init(from mode: AIModeModel) {
        self.name = mode.name
        self.systemPrompt = mode.systemPrompt
        self.provider = mode.provider
        self.modelName = mode.modelName
        self.supportsAttachments = mode.supportsAttachments
    }
}
