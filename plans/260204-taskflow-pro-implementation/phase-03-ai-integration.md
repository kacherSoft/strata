# Phase 3: AI Integration

**Priority:** HIGH | **Status:** Pending | **Effort:** 1.5 weeks

## Overview

Implement AI enhancement system with Gemini SDK and z.ai REST client. Create Enhance Me panel with two-column diff view and custom AI mode management.

## Context Links

- [PRD - AI Enhancement](../../docs/product-requirements-document.md)
- [Brainstorm - AI Integration](../reports/brainstorm-260204-0942-taskflow-pro-implementation.md)
- [Gemini Swift SDK Guide](https://www.appcoda.com/swiftui-google-gemini-ai/)
- [z.ai API Docs](https://docs.z.ai/guides/overview/quick-start)

## Dependencies

- Phase 1 complete (AIModeModel, SettingsModel)
- Phase 2 complete (Enhance Me shortcut registered)
- Google GenerativeAI Swift package
- macOS Keychain for API key storage

## Key Insights

- **Gemini:** Official Swift SDK from Google
- **z.ai:** Standard HTTP REST API, no SDK - build URLSession client
- User brings own API keys (BYOK model)
- Built-in modes: Correct Me, Enhance Prompt, Simplify, Break Down
- Side-by-side diff view for before/after comparison

## Requirements

### Functional
- AI provider abstraction (protocol-based)
- Gemini SDK integration
- z.ai REST client
- Secure API key storage (Keychain)
- Enhance Me panel with two-column view
- Custom AI mode CRUD in settings
- Mode switching with CMD+Shift+M
- Current mode label display
- Request timeout + retry logic

### Non-Functional
- 2-3s enhancement response time
- Graceful error handling
- Clear cost visibility guidance

## Architecture

```
TaskManager/Sources/TaskManager/
├── AI/
│   ├── Protocols/
│   │   └── AIProvider.swift         # Abstract interface
│   ├── Providers/
│   │   ├── GeminiProvider.swift     # Google Gemini SDK
│   │   └── ZAIProvider.swift        # z.ai REST client
│   ├── Services/
│   │   ├── AIService.swift          # Orchestration layer
│   │   └── KeychainService.swift    # Secure key storage
│   └── Models/
│       └── AIEnhancementResult.swift
├── Windows/
│   ├── EnhanceMePanel.swift         # Floating panel
│   └── EnhanceMeView.swift          # Two-column diff UI
├── ViewModels/
│   └── EnhanceMeViewModel.swift
└── Views/
    └── Settings/
        ├── AIConfigurationView.swift
        └── AIModeManagerView.swift
```

## Related Code Files

### Create
- `TaskManager/Sources/TaskManager/AI/Protocols/AIProvider.swift`
- `TaskManager/Sources/TaskManager/AI/Providers/GeminiProvider.swift`
- `TaskManager/Sources/TaskManager/AI/Providers/ZAIProvider.swift`
- `TaskManager/Sources/TaskManager/AI/Services/AIService.swift`
- `TaskManager/Sources/TaskManager/AI/Services/KeychainService.swift`
- `TaskManager/Sources/TaskManager/AI/Models/AIEnhancementResult.swift`
- `TaskManager/Sources/TaskManager/Windows/EnhanceMePanel.swift`
- `TaskManager/Sources/TaskManager/Windows/EnhanceMeView.swift`
- `TaskManager/Sources/TaskManager/ViewModels/EnhanceMeViewModel.swift`
- `TaskManager/Sources/TaskManager/Views/Settings/AIConfigurationView.swift`
- `TaskManager/Sources/TaskManager/Views/Settings/AIModeManagerView.swift`

### Modify
- `TaskManager/Package.swift` - Add GoogleGenerativeAI
- `TaskManager/Sources/TaskManager/Windows/WindowManager.swift` - Implement showEnhanceMe()
- `TaskManager/Sources/TaskManager/Shortcuts/ShortcutManager.swift` - Implement cycleAIMode

## Implementation Steps

### Step 1: Add Google AI Package (Day 1)

**Package.swift**
```swift
dependencies: [
    .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    .package(url: "https://github.com/google/generative-ai-swift", from: "0.5.0"),
],
targets: [
    .executableTarget(
        name: "TaskManager",
        dependencies: [
            "TaskManagerUIComponents",
            "KeyboardShortcuts",
            .product(name: "GoogleGenerativeAI", package: "generative-ai-swift")
        ]
    )
]
```

### Step 2: AI Provider Protocol (Day 1)

**AIProvider.swift**
```swift
import Foundation

protocol AIProvider {
    var name: String { get }
    var isConfigured: Bool { get }
    
    func enhance(text: String, mode: AIModeModel) async throws -> AIEnhancementResult
    func testConnection() async throws -> Bool
}

struct AIEnhancementResult {
    let originalText: String
    let enhancedText: String
    let modeName: String
    let provider: String
    let tokensUsed: Int?
    let processingTime: TimeInterval
}

enum AIError: LocalizedError {
    case notConfigured
    case invalidAPIKey
    case rateLimited
    case networkError(Error)
    case invalidResponse
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .notConfigured: return "AI provider not configured. Add API key in Settings."
        case .invalidAPIKey: return "Invalid API key. Check your key in Settings."
        case .rateLimited: return "Rate limited. Please wait and try again."
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .invalidResponse: return "Invalid response from AI provider."
        case .timeout: return "Request timed out. Please try again."
        }
    }
}
```

### Step 3: Keychain Service (Day 1-2)

**KeychainService.swift**
```swift
import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()
    private let service = "com.taskflowpro.api-keys"
    
    enum Key: String {
        case geminiAPIKey = "gemini-api-key"
        case zaiAPIKey = "zai-api-key"
    }
    
    func save(_ value: String, for key: Key) throws {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    func get(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    func delete(_ key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: Error {
    case saveFailed(OSStatus)
}
```

### Step 4: Gemini Provider (Day 2-3)

**GeminiProvider.swift**
```swift
import Foundation
import GoogleGenerativeAI

final class GeminiProvider: AIProvider {
    var name: String { "Google Gemini" }
    
    private var model: GenerativeModel?
    private let keychain = KeychainService.shared
    
    var isConfigured: Bool {
        keychain.get(.geminiAPIKey) != nil
    }
    
    func enhance(text: String, mode: AIModeModel) async throws -> AIEnhancementResult {
        guard let apiKey = keychain.get(.geminiAPIKey) else {
            throw AIError.notConfigured
        }
        
        let startTime = Date()
        
        let model = GenerativeModel(
            name: "gemini-1.5-flash",
            apiKey: apiKey
        )
        
        let prompt = """
        \(mode.systemPrompt)
        
        Text to enhance:
        \(text)
        
        Enhanced text:
        """
        
        do {
            let response = try await model.generateContent(prompt)
            
            guard let enhancedText = response.text else {
                throw AIError.invalidResponse
            }
            
            return AIEnhancementResult(
                originalText: text,
                enhancedText: enhancedText.trimmingCharacters(in: .whitespacesAndNewlines),
                modeName: mode.name,
                provider: name,
                tokensUsed: response.usageMetadata?.totalTokenCount,
                processingTime: Date().timeIntervalSince(startTime)
            )
        } catch let error as GenerateContentError {
            throw AIError.networkError(error)
        }
    }
    
    func testConnection() async throws -> Bool {
        guard let apiKey = keychain.get(.geminiAPIKey) else {
            throw AIError.notConfigured
        }
        
        let model = GenerativeModel(name: "gemini-1.5-flash", apiKey: apiKey)
        
        do {
            _ = try await model.generateContent("Hello")
            return true
        } catch {
            throw AIError.invalidAPIKey
        }
    }
}
```

### Step 5: z.ai Provider (Day 3-4)

**ZAIProvider.swift**
```swift
import Foundation

final class ZAIProvider: AIProvider {
    var name: String { "z.ai (GLM 4.6)" }
    
    private let keychain = KeychainService.shared
    private let baseURL = "https://api.z.ai/v1/chat/completions"
    private let timeout: TimeInterval = 30
    
    var isConfigured: Bool {
        keychain.get(.zaiAPIKey) != nil
    }
    
    func enhance(text: String, mode: AIModeModel) async throws -> AIEnhancementResult {
        guard let apiKey = keychain.get(.zaiAPIKey) else {
            throw AIError.notConfigured
        }
        
        let startTime = Date()
        
        let request = ZAIRequest(
            model: "glm-4.6",
            messages: [
                ZAIMessage(role: "system", content: mode.systemPrompt),
                ZAIMessage(role: "user", content: text)
            ],
            temperature: 0.7,
            maxTokens: 2048
        )
        
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = timeout
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                let decoded = try JSONDecoder().decode(ZAIResponse.self, from: data)
                guard let content = decoded.choices.first?.message.content else {
                    throw AIError.invalidResponse
                }
                
                return AIEnhancementResult(
                    originalText: text,
                    enhancedText: content,
                    modeName: mode.name,
                    provider: name,
                    tokensUsed: decoded.usage?.totalTokens,
                    processingTime: Date().timeIntervalSince(startTime)
                )
            case 401:
                throw AIError.invalidAPIKey
            case 429:
                throw AIError.rateLimited
            default:
                throw AIError.invalidResponse
            }
        } catch let error as URLError where error.code == .timedOut {
            throw AIError.timeout
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.networkError(error)
        }
    }
    
    func testConnection() async throws -> Bool {
        guard let apiKey = keychain.get(.zaiAPIKey) else {
            throw AIError.notConfigured
        }
        
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let testRequest = ZAIRequest(
            model: "glm-4.6",
            messages: [ZAIMessage(role: "user", content: "Hi")],
            maxTokens: 5
        )
        urlRequest.httpBody = try JSONEncoder().encode(testRequest)
        
        let (_, response) = try await URLSession.shared.data(for: urlRequest)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }
}

// MARK: - z.ai Request/Response Models
struct ZAIRequest: Encodable {
    let model: String
    let messages: [ZAIMessage]
    var temperature: Double = 0.7
    var maxTokens: Int = 2048
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

struct ZAIMessage: Codable {
    let role: String
    let content: String
}

struct ZAIResponse: Decodable {
    let choices: [ZAIChoice]
    let usage: ZAIUsage?
}

struct ZAIChoice: Decodable {
    let message: ZAIMessage
}

struct ZAIUsage: Decodable {
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case totalTokens = "total_tokens"
    }
}
```

### Step 6: AI Service (Day 4)

**AIService.swift**
```swift
import Foundation
import SwiftData

@MainActor
final class AIService: ObservableObject {
    static let shared = AIService()
    
    @Published var currentMode: AIModeModel?
    @Published var isEnhancing = false
    @Published var lastError: AIError?
    
    private let gemini = GeminiProvider()
    private let zai = ZAIProvider()
    
    var activeProvider: AIProvider {
        // Check settings for preferred provider
        // Default to Gemini if both configured, or whichever is available
        if gemini.isConfigured { return gemini }
        if zai.isConfigured { return zai }
        return gemini // Will throw notConfigured error
    }
    
    func enhance(text: String, mode: AIModeModel) async throws -> AIEnhancementResult {
        isEnhancing = true
        defer { isEnhancing = false }
        
        do {
            let result = try await activeProvider.enhance(text: text, mode: mode)
            lastError = nil
            return result
        } catch let error as AIError {
            lastError = error
            throw error
        }
    }
    
    func cycleMode(in context: ModelContext) {
        // Fetch all modes sorted by sortOrder
        let descriptor = FetchDescriptor<AIModeModel>(sortBy: [SortDescriptor(\.sortOrder)])
        guard let modes = try? context.fetch(descriptor), !modes.isEmpty else { return }
        
        if let current = currentMode,
           let index = modes.firstIndex(where: { $0.id == current.id }) {
            let nextIndex = (index + 1) % modes.count
            currentMode = modes[nextIndex]
        } else {
            currentMode = modes.first
        }
    }
}
```

### Step 7: Enhance Me View (Day 5-6)

**EnhanceMeView.swift**
```swift
import SwiftUI
import SwiftData

struct EnhanceMeView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var aiService = AIService.shared
    
    @State private var originalText: String
    @State private var enhancedText = ""
    @State private var isLoading = false
    @State private var error: AIError?
    
    let taskToEnhance: TaskModel?
    var onDismiss: () -> Void
    var onApply: (String) -> Void
    
    init(taskToEnhance: TaskModel? = nil, onDismiss: @escaping () -> Void, onApply: @escaping (String) -> Void) {
        self.taskToEnhance = taskToEnhance
        self._originalText = State(initialValue: taskToEnhance?.taskDescription ?? "")
        self.onDismiss = onDismiss
        self.onApply = onApply
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with mode selector
            HStack {
                Text("Enhance Me")
                    .font(.headline)
                
                Spacer()
                
                // Current mode label
                if let mode = aiService.currentMode {
                    Text("Mode: \(mode.name)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
                
                Button(action: { aiService.cycleMode(in: modelContext) }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .help("Cycle Mode (⌘⇧M)")
            }
            .padding()
            
            Divider()
            
            // Two-column diff view
            HStack(spacing: 0) {
                // Original text column
                VStack(alignment: .leading) {
                    Text("Original")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextEditor(text: $originalText)
                        .scrollContentBackground(.hidden)
                        .font(.body)
                }
                .padding()
                .frame(maxWidth: .infinity)
                
                Divider()
                
                // Enhanced text column
                VStack(alignment: .leading) {
                    Text("Enhanced")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = error {
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundStyle(.red)
                            Text(error.localizedDescription)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        TextEditor(text: $enhancedText)
                            .scrollContentBackground(.hidden)
                            .font(.body)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            
            Divider()
            
            // Action buttons
            HStack {
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Enhance") { enhance() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(originalText.isEmpty || isLoading || aiService.currentMode == nil)
                
                Button("Copy") {
                    NSPasteboard.general.setString(enhancedText, forType: .string)
                }
                .disabled(enhancedText.isEmpty)
                
                Button("Apply") {
                    onApply(enhancedText)
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(enhancedText.isEmpty)
            }
            .padding()
        }
        .frame(width: 700, height: 500)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            loadDefaultMode()
        }
    }
    
    private func loadDefaultMode() {
        let descriptor = FetchDescriptor<AIModeModel>(sortBy: [SortDescriptor(\.sortOrder)])
        if let modes = try? modelContext.fetch(descriptor), let first = modes.first {
            aiService.currentMode = first
        }
    }
    
    private func enhance() {
        guard let mode = aiService.currentMode else { return }
        
        isLoading = true
        error = nil
        
        Task {
            do {
                let result = try await aiService.enhance(text: originalText, mode: mode)
                enhancedText = result.enhancedText
            } catch let e as AIError {
                error = e
            }
            isLoading = false
        }
    }
}
```

### Step 8: Default AI Modes Seeding (Day 6)

Add to TaskManagerApp initialization:
```swift
func seedDefaultAIModes(container: ModelContainer) {
    let context = ModelContext(container)
    
    let descriptor = FetchDescriptor<AIModeModel>()
    guard (try? context.fetchCount(descriptor)) == 0 else { return }
    
    let defaultModes = [
        AIModeModel(
            name: "Correct Me",
            systemPrompt: "You are an expert editor. Correct grammar, spelling, and improve fluency while maintaining the original meaning and tone. Only output the corrected text.",
            isBuiltIn: true
        ),
        AIModeModel(
            name: "Enhance Prompt",
            systemPrompt: "You are an expert at writing clear, detailed descriptions. Expand this text with more specific details, actionable steps, and context. Make it clearer and more comprehensive. Only output the enhanced text.",
            isBuiltIn: true
        ),
        AIModeModel(
            name: "Simplify",
            systemPrompt: "You are an expert at concise communication. Rewrite this text to be shorter and clearer while keeping the essential meaning. Remove unnecessary words. Only output the simplified text.",
            isBuiltIn: true
        ),
        AIModeModel(
            name: "Break Down",
            systemPrompt: "You are a project manager expert. Break this task into smaller, actionable subtasks. Format as a numbered list. Only output the subtask list.",
            isBuiltIn: true
        )
    ]
    
    for (index, mode) in defaultModes.enumerated() {
        mode.sortOrder = index
        context.insert(mode)
    }
    
    try? context.save()
}
```

## Todo List

- [ ] Add GoogleGenerativeAI to Package.swift
- [ ] Create AIProvider protocol
- [ ] Create KeychainService for secure API key storage
- [ ] Implement GeminiProvider with SDK
- [ ] Implement ZAIProvider with URLSession
- [ ] Create AIService orchestration layer
- [ ] Create EnhanceMePanel (NSPanel)
- [ ] Create EnhanceMeView with two-column diff
- [ ] Implement mode cycling (CMD+Shift+M)
- [ ] Seed default AI modes on first launch
- [ ] Wire up WindowManager.showEnhanceMe()
- [ ] Create AIConfigurationView for settings
- [ ] Create AIModeManagerView for custom modes
- [ ] Test Gemini integration
- [ ] Test z.ai integration
- [ ] Test error handling (timeout, rate limit, invalid key)

## Success Criteria

- [ ] Gemini enhancement works with valid API key
- [ ] z.ai enhancement works with valid API key
- [ ] Mode cycling updates label immediately
- [ ] Side-by-side diff shows original and enhanced
- [ ] Apply button updates task description
- [ ] API keys stored securely in Keychain
- [ ] Error messages are user-friendly
- [ ] Enhancement completes in 2-3s

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| API rate limits | Medium | Medium | Queue system, 1 req/sec max |
| API costs | Low | Low | User's own API key (BYOK) |
| z.ai API changes | Low | Medium | Standard REST, easy to update |
| Gemini SDK breaking changes | Low | Low | Pin version in Package.swift |

## Security Considerations

- API keys ONLY in Keychain (never SwiftData, never logs)
- Never log request/response content
- Clear API key on app uninstall consideration (future)

## Next Steps

→ Phase 4: Polish & Advanced Features (Settings panel needs AI config views)
