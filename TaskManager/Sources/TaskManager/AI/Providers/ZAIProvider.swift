import Foundation

final class ZAIProvider: AIProviderProtocol, @unchecked Sendable {
    var name: String { "z.ai" }
    
    private let keychain = KeychainService.shared
    private let baseURL = "https://api.z.ai/v1"
    private let timeout: TimeInterval = 30
    private let defaultModel = "GLM-4.6"
    
    var isConfigured: Bool {
        keychain.hasKey(.zaiAPIKey)
    }
    
    func enhance(text: String, mode: AIModeData) async throws -> AIEnhancementResult {
        guard let apiKey = keychain.get(.zaiAPIKey) else {
            throw AIError.notConfigured
        }
        
        let startTime = Date()
        let modelName = mode.modelName.isEmpty ? defaultModel : mode.modelName
        
        let requestBody: [String: Any] = [
            "model": modelName,
            "messages": [
                ["role": "system", "content": mode.systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.7,
            "max_tokens": 2048
        ]
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw AIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                break
            case 401:
                throw AIError.invalidAPIKey
            case 429:
                throw AIError.rateLimited
            default:
                throw AIError.providerError("HTTP \(httpResponse.statusCode)")
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw AIError.invalidResponse
            }
            
            let tokensUsed: Int?
            if let usage = json["usage"] as? [String: Any],
               let total = usage["total_tokens"] as? Int {
                tokensUsed = total
            } else {
                tokensUsed = nil
            }
            
            let processingTime = Date().timeIntervalSince(startTime)
            
            return AIEnhancementResult(
                originalText: text,
                enhancedText: content.trimmingCharacters(in: .whitespacesAndNewlines),
                modeName: mode.name,
                provider: "\(name) (\(modelName))",
                tokensUsed: tokensUsed,
                processingTime: processingTime
            )
        } catch let error as AIError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw AIError.timeout
        } catch {
            throw AIError.networkError(error.localizedDescription)
        }
    }
    
    func testConnection() async throws -> Bool {
        guard let apiKey = keychain.get(.zaiAPIKey) else {
            throw AIError.notConfigured
        }
        
        guard let url = URL(string: "\(baseURL)/models") else {
            throw AIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw AIError.invalidAPIKey
        }
        
        return httpResponse.statusCode >= 200 && httpResponse.statusCode < 300
    }
}
