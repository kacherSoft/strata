# AI Layer System Exploration Report

**Date:** 2026-03-17 | **Scope:** Complete AI architecture analysis for Chat Mode planning

---

## 1. AIProvider Protocol (Streaming Capability Status: NO STREAMING)

**File:** `AI/Protocols/AIProvider.swift`

### Current Protocol Definition
```swift
protocol AIProviderProtocol: Sendable {
    var name: String { get }
    var isConfigured: Bool { get }
    
    func enhance(text: String, attachments: [AIAttachment], mode: AIModeData) async throws -> AIEnhancementResult
    func testConnection() async throws -> Bool
}
```

### Key Observations
- **Single-shot only**: `enhance()` returns complete `AIEnhancementResult` - no streaming support
- **Sendable**: All providers marked `@unchecked Sendable` (thread-safe)
- **Two methods**: Enhancement + connection testing
- **Attachment support**: Protocol supports file attachments, but only Gemini implements it
- **Error handling**: Returns `AIError` enum with 7 error cases

### Required Changes for Chat Mode
- Add `func streamingEnhance(...) async throws -> AsyncThrowingStream<...>` method
- Consider adding `func sendChatMessage(...) async throws -> AsyncThrowingStream<...>`
- May need separate protocol for chat vs. enhancement modes

---

## 2. AIService (Mode Selection & Coordination)

**File:** `AI/Services/AIService.swift` (122 lines)

### Architecture
```swift
@MainActor
@Observable
final class AIService {
    private(set) var currentMode: AIModeModel?
    private(set) var isProcessing = false
    private(set) var lastError: AIError?
    
    private let geminiProvider = GeminiProvider()
    private let zaiProvider = ZAIProvider()
    private let customProvider = CustomOpenAIProvider()
}
```

### Key Responsibilities
1. **Provider Management**
   - `providerFor(_ type: AIProviderType) -> AIProviderProtocol` - returns concrete provider
   - `isConfigured(for provider:) -> Bool` - checks API key setup
   - `hasAnyProviderConfigured` - checks if any provider ready

2. **Mode Selection**
   - `setMode(_ mode: AIModeModel)` - sets current AI mode
   - `cycleMode(in context:)` - cycles through modes (used by Tab key)
   - `loadDefaultMode(from context:)` - loads last selected mode from SettingsModel

3. **Persistence**
   - `persistSelectedMode(_ modeId:)` - saves mode selection to SettingsModel.selectedAIModeId

4. **Enhancement Execution**
   - `enhance(text:attachments:mode:)` - wraps provider.enhance() with state management
   - Sets `isProcessing = true`, captures `lastError`, handles AIError propagation

### For Chat Mode
- **Leverage**: Mode selection, error tracking, provider routing all work well
- **Extend**: Add chat-specific service methods, consider separate ChatService or mode parameter
- **Watch**: `@MainActor` required - all chat updates must be on main thread

---

## 3. AIModeModel (Data Model)

**File:** `Data/Models/AIModeModel.swift` (107 lines)

### Structure
```swift
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
}
```

### Default Built-In Modes
1. **"Correct Me"** - Grammar/spelling correction
2. **"Enhance Prompt"** - Expand text with details
3. **"Explain"** - Analysis & explanation (supports attachments)

### Extensibility
- Fully swappable: custom modes created via AIModeRepository
- Built-in modes: protected from deletion (`guard !mode.isBuiltIn else { return }`)
- Attachment support: boolean flag allows per-mode control
- Provider-aware: each mode stores provider & model name

### For Chat Mode
- **Add field**: `supportsConversation: Bool` to enable/disable history per mode
- **Or** create separate ChatModeModel extending AIModeModel
- Current model works fine for chat modes too

---

## 4. AIProviderType Enum

**File:** `Data/Models/AIModeModel.swift` (lines 4-52)

### Available Providers
```swift
enum AIProviderType: String, Codable, CaseIterable, Sendable {
    case gemini = "gemini"
    case zai = "zai"
    case custom = "custom"
}
```

### Provider Capabilities Matrix
| Provider | Images | PDFs | Models | Notes |
|----------|--------|------|--------|-------|
| **Gemini** | ✅ Yes | ✅ Yes | gemini-flash-lite-latest, gemini-flash-latest, gemini-3-flash-preview | Full multimodal support |
| **z.ai** | ❌ No | ❌ No | GLM-4.6, GLM-4.7 | Text-only, REST-based |
| **Custom (OpenAI)** | ❌ No | ❌ No | gpt-4o or custom | Configurable base URL, works with Ollama/local |

### Key Implementation Details
- `supportsImageAttachments` property
- `supportsPDFAttachments` property
- `supportsAnyAttachments` computed property
- `defaultModel` - falls back to first available model

---

## 5. File Attachment Handling

**File:** `AI/Models/AIEnhancementResult.swift` (lines 1-25)

### AIAttachment Structure
```swift
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
    
    func loadData() throws -> Data
    
    static let maxFileSizeBytes = 10 * 1024 * 1024      // 10MB
    static let maxAttachmentCount = 4                    // Up to 4 files
}
```

### Implementation Details
- **Storage**: Temporary directory (`/tmp/EnhanceMeAttachments`)
- **Validation**: File size checked before loading, file count limited to 4
- **Cleanup**: Automatic in EnhanceMeView.onDisappear and when switching modes
- **Types**: PNG, JPEG, TIFF, HEIC (images) + PDF

### EnhanceMe Drag-and-Drop Implementation
- `EnhanceNSTextView` handles drag operations
- `performDragOperation()` and `paste()` support files + clipboard images
- TIFF from screenshots auto-converted to PNG
- PDFs loaded as binary data

---

## 6. Provider Implementations (No Streaming)

### 6a. GeminiProvider
**File:** `AI/Providers/GeminiProvider.swift` (161 lines)

**Uses Google SDK:** `GoogleGenerativeAI` package (v0.5.0+)

#### Single-Shot Approach
```swift
let response = try await model.generateContent(prompt)
// or with attachments:
let response = try await model.generateContent([ModelContent(parts: parts)])
```

#### Streaming Available in Gemini SDK
The underlying `GenerativeModel` class supports:
```swift
model.generateContentStream(_ content: ...) -> AsyncThrowingStream<GenerateContentResponse, Error>
```

**BUT** current GeminiProvider does NOT use it. **Enhancement opportunity for Chat Mode.**

#### Attachment Handling
- Images: passed as `ModelContent.Part.data(mimetype:_:)`
- PDFs: also passed as binary data (Gemini accepts both)
- PDF text extraction: implemented via PDFKit (20 page limit, 50K char limit)
- Text + attachments combined in single `ModelContent`

#### Error Mapping
- `invalidAPIKey` -> AIError.invalidAPIKey
- `promptBlocked` -> AIError.providerError (with safety reason)
- `responseStoppedEarly` -> AIError.providerError
- `unsupportedUserLocation` -> AIError.providerError

### 6b. ZAIProvider
**File:** `AI/Providers/ZAIProvider.swift` (152 lines)

**Uses REST API:** POST to `https://api.z.ai/v1/chat/completions`

#### Chat Completions Format
```swift
let requestBody: [String: Any] = [
    "model": modelName,
    "messages": [
        ["role": "system", "content": mode.systemPrompt],
        ["role": "user", "content": text]
    ],
    "temperature": 0.7,
    "max_tokens": 2048
]
```

**Hard-coded parameters** - no customization exposed.

#### Response Parsing
```swift
let choices = json["choices"] as? [[String: Any]]
let content = message["content"] as? String
```

#### Token Usage
- Extracts `usage.total_tokens` from response

#### Streaming NOT Implemented
- API likely supports `"stream": true` but not utilized
- Would need line-by-line JSON parsing of SSE events

### 6c. CustomOpenAIProvider
**File:** `AI/Providers/CustomOpenAIProvider.swift` (169 lines)

**Uses REST API:** POST to configurable base URL (e.g., local Ollama, OpenRouter)

#### Configuration
- Base URL: stored in Keychain (`customProviderBaseURL`)
- API Key: stored in Keychain (`customProviderAPIKey`)
- Model Name: stored in Keychain (`customProviderModelName`)
- Security: requires http/https scheme, blocks invalid URLs

#### Request Format (OpenAI-Compatible)
```swift
let requestBody: [String: Any] = [
    "model": modelName,
    "messages": [...],
    "temperature": 0.7,
    "max_tokens": 2048
]
```

**Identical to z.ai format** - both use OpenAI standard.

#### Streaming NOT Implemented
- Local providers like Ollama support streaming
- Would need SSE parsing identical to z.ai

---

## 7. EnhanceMe Panel & View

### Panel Wrapper
**File:** `Windows/EnhanceMePanel.swift` (30 lines)

- NSPanel subclass, 700x500 default
- Resizable (500-1200 width, 400-800 height)
- Uses NSHostingView for SwiftUI content

### EnhanceMeView (Main UI)
**File:** `Windows/EnhanceMeView.swift` (986 lines)

#### State Management
```swift
@State private var originalText: String
@State private var enhancedText = ""
@State private var displayedText = ""           // Typewriter animation
@State private var isLoading = false
@State private var errorMessage: String?
@State private var showCopiedIndicator = false
@State private var attachments: [AIAttachment] = []
@State private var toastMessage: String?
@State private var typewriterTimer: Timer?
```

#### Key Features
1. **Typewriter Animation**
   - Simulates streaming via batched character display
   - 8ms delay between 5-character chunks
   - Not actual streaming - data arrives complete, then animated

2. **Mode Cycling**
   - Tab key triggers `cycleMode()` - hotkey handled by custom NSView
   - Modes cycle in sort order

3. **Attachment Management**
   - Drag-and-drop files into text editor
   - Paste images from clipboard
   - Validates against provider capabilities
   - Shows attachment pills with thumbnail preview
   - Auto-cleanup on dismiss or mode switch

4. **UI States**
   - Loading spinner + "Enhancing..." message
   - Error state with retry button
   - Empty state with "Press Enter or ⌘↩"
   - Copy confirmation badge

5. **Auto-copy**
   - Result automatically copied to clipboard
   - Shows "Copied!" indicator for 2 seconds

#### Keyboard Handling
- **Enter** (in text field) = trigger enhance
- **Cmd+Enter** = trigger enhance (button shortcut)
- **Tab** = cycle mode (captured by EnhanceMeShortcutNSView)

#### Custom NSTextView Integration
- `EnhanceNSTextView` handles drag/drop + paste
- `EnhanceDragClipView` wraps for proper drag handling
- `EnhanceNSTextEditor` NSViewRepresentable adapter
- Supports multiple image formats + PDF

---

## 8. AIModeRepository (CRUD Operations)

**File:** `Data/Repositories/AIModeRepository.swift` (71 lines)

### Operations
| Operation | Method | Notes |
|-----------|--------|-------|
| **Read All** | `fetchAll()` | Sorted by sortOrder |
| **Read One** | `fetch(id:)` | Returns optional |
| **Create** | `create(name:systemPrompt:)` | Auto-assigns sort order |
| **Update** | `update(_:)` | Just calls saveContext() |
| **Delete** | `delete(_:)` | Protected: guards against built-in deletion |
| **Reorder** | `reorder(_:)` | Batch update sort orders |

### Architecture
- `@MainActor` for SwiftUI thread safety
- `ModelContext` passed in constructor
- `lastSaveError` tracked privately
- Uses SwiftData FetchDescriptor + Predicate

---

## 9. KeychainService

**File:** `AI/Services/KeychainService.swift` (102 lines)

### API Key Storage
```swift
enum Key: String, Sendable {
    case geminiAPIKey = "gemini-api-key"
    case zaiAPIKey = "zai-api-key"
    case customProviderAPIKey = "custom-provider-api-key"
    case customProviderBaseURL = "custom-provider-base-url"
    case customProviderModelName = "custom-provider-model-name"
    // ... also session/entitlement keys
}
```

### Methods
- `save(_ value: String, for key: Key)` - overwrites existing
- `get(_ key: Key) -> String?` - returns optional
- `delete(_ key: Key)` - removes key
- `hasKey(_ key: Key) -> Bool` - existence check

### Service ID
- Hardcoded: `"com.kachersoft.strata"` (Strata bundle ID)

---

## 10. Streaming in Google Generative AI SDK

**Available but NOT used in current codebase**

**File:** `.build/checkouts/generative-ai-swift/Sources/GoogleAI/Chat.swift`

### Chat Class
```swift
public class Chat {
    public var history: [ModelContent]
    
    public func sendMessage(...) async throws -> GenerateContentResponse
    
    @available(macOS 12.0, *)
    public func sendMessageStream(...) 
        -> AsyncThrowingStream<GenerateContentResponse, Error>
}
```

### Streaming Implementation
```swift
public func sendMessageStream(_ content: @autoclosure () throws -> [ModelContent])
    -> AsyncThrowingStream<GenerateContentResponse, Error> {
    return AsyncThrowingStream { continuation in
        Task {
            var aggregatedContent: [ModelContent] = []
            let stream = model.generateContentStream(request)
            
            do {
                for try await chunk in stream {
                    if let chunkContent = chunk.candidates.first?.content {
                        aggregatedContent.append(chunkContent)
                    }
                    continuation.yield(chunk)
                }
            } catch {
                continuation.finish(throwing: error)
                return
            }
            
            // Auto-aggregates chunks & adds to history
            history.append(contentsOf: newContent)
            let aggregated = aggregatedChunks(aggregatedContent)
            history.append(aggregated)
            continuation.finish()
        }
    }
}
```

### Key Points
- **Automatic history management** - sends history + new message, appends response
- **Chunk aggregation** - collects content parts before storing
- **Error handling** - stops on error, doesn't mutate history on failure
- **Available in macOS 12.0+** (target is 15, so compatible)

### Stream Response Structure
```swift
public struct GenerateContentResponse {
    public let candidates: [CandidateResponse]
    public let promptFeedback: PromptFeedback?
    public let usageMetadata: UsageMetadata?
    
    public var text: String? { ... }        // Extracts text from first candidate
}
```

Each chunk yields partial `GenerateContentResponse` with incremental text.

---

## 11. Current Gaps for Chat Mode

| Requirement | Current Status | Work Needed |
|-------------|----------------|------------|
| **Streaming** | No streaming at all | Add to all 3 providers |
| **Conversation History** | Not implemented | Create MessageModel + HistoryRepository |
| **Chat API Methods** | Enhancement-only protocol | Extend AIProviderProtocol or create ChatProvider |
| **Message Storage** | No data model exists | Create MessageModel with role/content/attachments |
| **Stateful Chat** | No session tracking | Add to AIService or new ChatService |
| **Stream UI** | Typewriter animation only | Implement real streaming display |
| **z.ai Streaming** | Not implemented | Add SSE parsing for /v1/chat/completions?stream=true |
| **Custom Streaming** | Not implemented | Add SSE parsing for OpenAI-compatible endpoints |

---

## 12. Architecture Summary

```
┌─────────────────────────────────────┐
│          EnhanceMeView              │
│  (Single-shot enhancement UI)       │
├─────────────────────────────────────┤
│          AIService                  │
│  (Mode selection, error tracking)   │
├──────────────┬──────────────────────┤
│  AIProvider  │    AIModeRepository  │
│  Protocol    │    (CRUD modes)      │
├──────────────┴──────────────────────┤
│  GeminiProvider                      │
│  ZAIProvider                         │
│  CustomOpenAIProvider                │
├──────────────────────────────────────┤
│  KeychainService                     │
│  (API key storage)                   │
└──────────────────────────────────────┘
```

**Missing for Chat:**
- ChatHistoryRepository
- MessageModel (SwiftData)
- Real streaming support in all providers
- ChatService or extended AIService
- Chat UI (new window/view)

---

## Unresolved Questions

1. **Should Chat Mode be a separate AIModeModel type** or use existing mode structure?
2. **How to persist conversation history?** SwiftData MessageModel + separate table, or store in file?
3. **Multi-conversation support** needed, or single active chat?
4. **Provider-specific streaming format differences:**
   - Gemini SDK handles streaming natively via Chat class
   - z.ai/Custom need manual SSE parsing from `/chat/completions?stream=true`
   - Should wrapper handle this transparently?
5. **Should streaming be optional per-mode?** Some users may prefer no streaming.
6. **Token counting** - Gemini returns usage metadata, z.ai/Custom may not. Standardize?
7. **Conversation context limits** - how many messages to keep? Rolling window strategy?
8. **File attachment lifecycle in chats** - keep references forever or auto-expire?

---

## Recommendations

### For Chat Mode Implementation
1. **Extend AIProviderProtocol** with streaming method(s)
2. **Create ChatProvider protocol** separate from enhancement-focused AIProvider
3. **Implement message history** via SwiftData MessageModel + timestamp
4. **Use Gemini's native Chat class** for Gemini provider (handles history auto)
5. **Add SSE parsing** for z.ai & Custom providers (streaming support)
6. **New ChatService** wrapping AIService with conversation state management
7. **Real streaming UI** replacing typewriter animation
8. **Entitlements check** - chat mode may require Premium like attachments do

