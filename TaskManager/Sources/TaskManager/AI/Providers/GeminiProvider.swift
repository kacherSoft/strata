import Foundation
import GoogleGenerativeAI
import PDFKit

final class GeminiProvider: AIProviderProtocol, @unchecked Sendable {
    var name: String { "Google Gemini" }
    
    private let keychain = KeychainService.shared
    private let defaultModel = "gemini-flash-lite-latest"
    
    var isConfigured: Bool {
        keychain.hasKey(.geminiAPIKey)
    }
    
    func enhance(text: String, attachments: [AIAttachment], mode: AIModeData) async throws -> AIEnhancementResult {
        guard let apiKey = keychain.get(.geminiAPIKey) else {
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
    
    func testConnection() async throws -> Bool {
        guard let apiKey = keychain.get(.geminiAPIKey) else {
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

    private static func extractPDFText(from attachment: AIAttachment) throws -> String {
        guard let document = PDFDocument(url: attachment.fileURL) else { return "" }

        let maxPages = 20
        let pageCount = min(document.pageCount, maxPages)
        var text = ""

        for i in 0..<pageCount {
            if let page = document.page(at: i), let pageText = page.string {
                text += pageText + "\n"
            }
        }

        let maxChars = 50_000
        if text.count > maxChars {
            text = String(text.prefix(maxChars)) + "\n[... truncated ...]"
        }

        return text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    private func mapGeminiError(_ error: GenerateContentError) -> AIError {
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
        default:
            return AIError.providerError("Gemini error: \(error.localizedDescription)")
        }
    }
}
