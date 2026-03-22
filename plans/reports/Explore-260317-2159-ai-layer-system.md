# AI Layer & Mode System Exploration Report

**Project:** Strata — AI Productivity Utility for Mac  
**Scope:** Swift/SwiftUI frontend AI integration  
**Date:** 2026-03-17  
**Explored:** AIProvider protocol, AIService orchestration, AIModeModel persistence, EnhanceMe UI, streaming patterns

---

## 1. AIProvider Protocol & Implementations

### Protocol Definition
**File:** `AI/Protocols/AIProvider.swift`

```swift
protocol AIProviderProtocol: Sendable {
    var name: String { get }
    var isConfigured: Bool { get }
    
    func enhance(text: String, attachments: [AIAttachment], mode: AIModeData) async throws -> AIEnhancementResult
    func testConnection() async throws -> Bool
}
```

**Key Points:**
- Async/await based with proper error handling
- Sendable protocol for thread-safety
- Two variants: with attachments (primary) and without (convenience extension)
- Error enum `AIError` defines 8 cases (notConfigured, invalidAPIKey, rateLimited, networkError, invalidResponse, timeout, providerError)

### Provider Implementations

#### GeminiProvider
**File:** `AI/Providers/GeminiProvider.swift` (161 lines)

**Capabilities:**
- Uses Google's `GenerativeAI` framework
- Supports image & PDF attachments (max 4 files, 10MB each)
- Model selection: gemini-flash-lite-latest, gemini-flash-latest, gemini-3-flash-preview
- **Streaming:** Not implemented (uses single `generateContent()` call with await)

**Attachment Handling:**
- Images: Direct attachment via `ModelContent.Part.data(mimetype:_:)`
- PDFs: Extracts text (max 20 pages, 50K chars) and sends as text + PDF data
- Text content is always included as context

**Error Mapping:**
- Maps GenerateContentError to AIError (safety blocks, invalid keys, regional restrictions)

**Flow:**
1. Load API key from keychain
2. Create model instance
3. For attachments: prepare images/text in background task, build ModelContent parts
4. Single generateContent call
5. Parse response.text, measure processingTime
6. Return AIEnhancementResult

#### ZAIProvider
**File:** `AI/Providers/ZAIProvider.swift` (124 lines)

**Capabilities:**
- REST API over HTTPS (`https://api.z.ai/v1`)
- Models: GLM-4.6, GLM-4.7
- **No attachment support** (only text processing)
- **Streaming:** Not implemented (single POST to /chat/completions endpoint)

**Request Structure:**
- Bearer token auth
- JSON body with messages array (system + user roles)
- Temperature: 0.7, max_tokens: 2048

**Error Handling:**
- HTTP status codes: 200=success, 401=invalid key, 429=rate limited, others=provider error
- Parses JSON response: choices[0].message.content
- Extracts token usage from response

---

## 2. AIService Class Orchestration

**File:** `AI/Services/AIService.swift` (120 lines)

### Architecture
```swift
@MainActor @Observable
final class AIService {
    static let shared = AIService()
    
    private(set) var currentMode: AIModeModel?
    private(set) var isProcessing = false
    private(set) var lastError: AIError?
    
    private let geminiProvider = GeminiProvider()
    private let zaiProvider = ZAIProvider()
}
```

**Key Responsibilities:**

1. **Provider Management**
   - Singleton instance (shared)
   - Routes to correct provider via `providerFor(_ type: AIProviderType)`
   - Checks configuration status

2. **Mode Lifecycle**
   - `setMode(_ mode: AIModeModel)` - sets currentMode
   - `loadDefaultMode(from context:)` - on app launch, loads from SettingsModel.selectedAIModeId
   - `cycleMode(in context:)` - rotates through modes by sortOrder
   - Persists selected mode to SettingsModel

3. **Enhancement Flow**
   ```swift
   func enhance(text: String, attachments: [AIAttachment] = [], mode: AIModeModel) async throws -> AIEnhancementResult
   ```
   - Creates AIModeData struct from AIModeModel
   - Sets isProcessing = true
   - Calls provider.enhance()
   - Wraps AIError for consistent error handling
   - Stores lastError for UI access

4. **Testing**
   - `testProvider(_ type:)` - delegates to provider.testConnection()

**Observable Pattern:**
- @Observable makes it SwiftUI-native (no @Published properties)
- MainActor ensures UI updates happen on main thread
- isProcessing drives loading states
- lastError surfaces error messages to views

---

## 3. AIModeModel @Model Class

**File:** `Data/Models/AIModeModel.swift` (98 lines)

### SwiftData Persistence
```swift
@Model
final class AIModeModel: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var systemPrompt: String
    var providerRaw: String  // Stored, computed property wraps
    var modelName: String
    var sortOrder: Int
    var isBuiltIn: Bool
    var supportsAttachments: Bool = false
    var createdAt: Date
    
    var provider: AIProviderType {  // Computed
        get { AIProviderType(rawValue: providerRaw) ?? .gemini }
        set { providerRaw = newValue.rawValue }
    }
}
```

### Built-in Modes
Three default modes created on first app launch:
1. **"Correct Me"** - Grammar/spelling/fluency without attachment support
2. **"Enhance Prompt"** - Expand with details/steps/context, no attachments
3. **"Explain"** - Break down concepts, **supports attachments** (Gemini only)

### Initialization
```swift
init(name: String, systemPrompt: String, provider: AIProviderType = .gemini, 
     modelName: String? = nil, isBuiltIn: Bool = false, supportsAttachments: Bool = false)
```
- Auto-generates UUID, createdAt, sortOrder defaults
- Defaults to Gemini + latest flash model
- supportsAttachments gated by provider capability

---

## 4. AIModeRepository Data Access

**File:** `Data/Repositories/AIModeRepository.swift` (71 lines)

### CRUD Operations
```swift
@MainActor
final class AIModeRepository: ObservableObject {
    func fetchAll() -> [AIModeModel]                          // Sorted by sortOrder
    func fetch(id: UUID) -> AIModeModel?                     // Single mode lookup
    func create(name, systemPrompt) -> AIModeModel           // Auto-assigns sortOrder
    func update(_ mode: AIModeModel)                         // Just saves context
    func delete(_ mode: AIModeModel)                         // Guards isBuiltIn (no delete)
    func reorder(_ modes: [AIModeModel])                     // Batch reorder
}
```

### Lifecycle
- Tracks lastSaveError but doesn't expose via properties
- saveContext() wraps modelContext.save() with error capture
- All operations save immediately (no batching)

---

## 5. EnhanceMe Panel & View Integration

### Window Container
**File:** `Windows/EnhanceMePanel.swift`

```swift
final class EnhanceMePanel: NSPanel {
    init() {
        // 700x500 default, resizable 500-1200 width, 400-800 height
        // Floating panel, non-modal, hidden on app deactivate
    }
    
    func setContent<V: View>(_ view: V)  // NSHostingView wrapper
}
```

### Main View Component
**File:** `Windows/EnhanceMeView.swift` (986 lines)

#### State Management
```swift
struct EnhanceMeView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(EntitlementService.self) var entitlementService
    @Query(sort: \AIModeModel.sortOrder) var modes: [AIModeModel]
    
    @State var aiService = AIService.shared
    @State var originalText: String
    @State var enhancedText = ""
    @State var displayedText = ""           // For typewriter animation
    @State var isLoading = false
    @State var errorMessage: String?
    @State var attachments: [AIAttachment] = []
    @State var showCopiedIndicator = false
}
```

#### Layout: Three-Column Structure
1. **Header** - Mode selector + cycle button (Tab key)
2. **Content** - Split view
   - **Left:** Original text editor + attachment bar
   - **Right:** Enhanced result + typewriter animation
3. **Footer** - Enhance button + config warning

#### Features

**Mode Selection:**
- Current mode displays name + provider + model
- Cycle button rotates through all modes
- Tab key as shortcut for cycling
- Warns if current provider not configured

**Text Input:**
- EnhanceTextEditor (custom NSTextView wrapper)
- Supports drag-drop and paste of images/PDFs
- onSubmit bound to enhance() action
- shouldFocus handles initial focus

**Attachment Handling:**
- Conditional on currentModeSupportsAttachments
- Validates mime type per mode support
- Max 4 files, 10MB each
- Displays AttachmentPill with preview + remove button
- Cleans up temp files on view disappear

**Enhancement Flow:**
```
enhance() -> isLoading=true -> aiService.enhance() -> 
  result arrives -> startTypewriterAnimation() -> copyToClipboard() ->
  isLoading=false
```

**Typewriter Animation:**
- Displays result character-by-character (5-char batches, 8ms per batch)
- Syncs back to enhancedText when complete
- Creates perception of streaming (not actual API streaming)

**Error Handling:**
- UIError displayed in large modal format on right column
- Try Again button clears error
- Configuration warnings in footer
- Toast messages for unsupported attachments

**Entitlement Integration:**
- Attachments gated by Pro tier (hasFullAccess)
- Mode cycling available to all
- Changes to entitlements cleanup attachments mid-session

#### Custom NSTextView Implementation

**EnhanceNSTextView** (300+ lines of drag-drop & paste handling)
- Registers drag types: PDF, PNG, TIFF, file URLs
- Drag entry/update/exit validates attachment support
- Paste override handles both keyboard and programmatic pastes
- File type detection: PNG, JPG, JPEG, TIFF, HEIC, PDF
- Image conversion: TIFF→PNG via NSBitmapImageRep
- PDF paste: direct data handling
- Temp file storage: `FileManager.temporary/EnhanceMeAttachments/`

**EnhanceTextEditor** (NSViewRepresentable)
- Wraps NSScrollView containing EnhanceNSTextView
- Binds text, manages focus, applies styling
- Coordinator handles text change & key events (Shift+Enter = newline, Enter = submit)

#### Keyboard Shortcuts
- **Cmd+Return:** Enhance (button action)
- **Tab:** Cycle mode (native key event at char code 48)
- **Shift+Enter:** Insert newline (in text field)
- **Escape:** Not bound (default behavior)

#### ToastView Integration
- Shows temporary messages (2s duration)
- Styles: .info, .error, .success (implied)
- Bottom-aligned with 12pt padding
- Animates in/out

---

## 6. Inline Enhance Coordinator

**File:** `Services/InlineEnhanceCoordinator.swift` (216 lines)

### Purpose
Enables "Enhance Me" as a system-wide hotkey (global shortcut in other apps)

### Flow Architecture
```
performInlineEnhance() 
├─ Check accessibility permission
├─ Capture text from focused app (TextCaptureEngine)
├─ Load AI mode from AIService
├─ Check Pro entitlement
├─ Show HUD near text field
├─ Call AIService.enhance()
├─ Replace text (TextReplacementEngine)
└─ Dismiss HUD (auto after 1-3s)
```

### HUD Lifecycle
- Uses InlineEnhanceHUDPanel (floating, position-independent)
- States: enhancing, success, error
- Auto-dismisses after 1s (success) or 3s (error)
- Positioned near source element (AXUIElement geometry)

### Integration Points
- TextCaptureEngine: Detects app type, extracts text from accessibility tree
- TextReplacementEngine: Verifies replacement succeeded
- EntitlementService: Pro gating
- ElectronSpecialist, AppCategoryDetector: Debug helpers

**Not fully detailed in this exploration** but orchestrates full inline workflow.

---

## 7. Data Structures

### AIAttachment
```swift
struct AIAttachment: Identifiable, Sendable {
    enum Kind: String, Sendable { case image, pdf }
    
    let id: UUID
    let kind: Kind
    let fileURL: URL
    let mimeType: String
    let fileName: String
    let byteCount: Int
    
    func loadData() throws -> Data
    
    static let supportedImageTypes = ["public.png", "public.jpeg", "public.tiff"]
    static let supportedPDFType = "com.adobe.pdf"
    static let maxFileSizeBytes = 10 * 1024 * 1024
    static let maxAttachmentCount = 4
}
```

### AIEnhancementResult
```swift
struct AIEnhancementResult: Sendable {
    let originalText: String
    let enhancedText: String
    let modeName: String
    let provider: String          // "Gemini (model-name)" format
    let tokensUsed: Int?
    let processingTime: TimeInterval
}
```

### AIModeData
```swift
struct AIModeData: Sendable {
    let name: String
    let systemPrompt: String
    let provider: AIProviderType
    let modelName: String
    let supportsAttachments: Bool
    
    init(from mode: AIModeModel)  // Converts @Model to sendable struct
}
```

### AIProviderType Enum
```swift
enum AIProviderType: String, Codable, CaseIterable, Sendable {
    case gemini, zai
    
    var displayName: String          // "Google Gemini" / "z.ai"
    var availableModels: [String]    // Provider-specific list
    var defaultModel: String
    var supportsImageAttachments: Bool
    var supportsPDFAttachments: Bool
    var supportsAnyAttachments: Bool
}
```

---

## 8. Streaming & Real-time Patterns

### Current State
**Neither provider implements streaming.**

Both providers use single async/await calls:
- GeminiProvider: `model.generateContent()` (waits for full response)
- ZAIProvider: `URLSession.shared.data()` (waits for full HTTP response)

### Typewriter Effect (Not Streaming)
EnhanceMeView simulates streaming with a client-side animation loop:
```swift
private func startTypewriterAnimation(for text: String) {
    let characters = Array(text)
    var index = 0
    let batchSize = 5  // Chars per update
    
    while index < characters.count {
        let endIndex = min(index + batchSize, characters.count)
        displayedText += String(characters[index..<endIndex])
        try? await Task.sleep(nanoseconds: 8_000_000)  // 8ms
    }
}
```

This creates visual feedback of "streaming" but is purely client-side animation after full response arrives.

### For Chat Mode (Future)
To implement actual streaming:
1. **Gemini:** Use `model.generateContentStream()` - returns AsyncSequence<StreamGenerateContentResponse>
2. **ZAI:** Use /chat/completions with `stream: true` - returns chunked transfer encoding (parse SSE format)

Both would require:
- Buffering incoming chunks
- Parsing delta content
- Updating displayedText incrementally
- Error handling for partial responses

---

## 9. Settings & Configuration

### AIConfigSettingsView
**File:** `Views/Settings/AIConfigSettingsView.swift`

Manages API key configuration:
- Input fields for Gemini & ZAI keys (SecureField)
- Save, Test, Remove buttons per provider
- Keychain integration (secure storage)
- Test result display (success/failure)
- Footer notes about pricing

### AIModesSettingsView
**File:** `Views/Settings/AIModesSettingsView.swift`

Manages mode CRUD:
- List of all modes (sorted by sortOrder)
- Built-in modes: read-only (no delete), editable name/prompt
- Custom modes: full CRUD
- Edit sheet: ModeEditorSheet form with name, provider, model, system prompt, attachments toggle
- Drag-to-reorder functionality
- Context menu: Edit, Delete

**ModeEditorSheet Form Fields:**
- Name (TextField)
- Provider picker (Gemini/z.ai with cascading model selection)
- Model picker (dynamic based on provider)
- Attachments toggle (disabled if provider doesn't support)
- System Prompt (large TextEditor, min 120pt height)

---

## 10. Integration Points & Dependencies

### Core Dependencies
- **SwiftData** - Persistence (AIModeModel, SettingsModel)
- **SwiftUI** - UI framework (Observable, @Query, environments)
- **GoogleGenerativeAI** - Gemini provider
- **Foundation** - URLSession, KeychainService
- **AppKit** - NSPanel, NSTextView, accessibility APIs (AXUIElement)

### Service Injection
- AIService: Singleton, accessed via `.shared`
- EntitlementService: Environment injection
- KeychainService: Shared singleton for API keys
- ModelContext: SwiftUI @Environment for SwiftData

### Feature Flags (in code)
- Pro tier gating: entitlementService.hasFullAccess controls attachments
- Attachment support per-mode: mode.supportsAttachments
- Provider capabilities: AIProviderType properties

---

## 11. Key Architectural Patterns

1. **Provider Pattern** - AIProviderProtocol for pluggable AI backends
2. **Singleton Services** - AIService.shared, KeychainService.shared
3. **Observable State** - AIService as @Observable for reactive UI updates
4. **Sendable Structs** - Thread-safe data passing (AIModeData, AIAttachment)
5. **Custom NSViewRepresentable** - Rich text input with attachment support
6. **SwiftData @Query** - Reactive mode list binding to database
7. **Error Wrapper** - AIError enum for consistent error handling across providers
8. **Capability Flags** - supportsAttachments, supportsImageAttachments gate features

---

## 12. Critical Observations for Chat Mode

### What Exists
✓ Multi-provider architecture (can add chat providers)  
✓ Mode system (chat can be another mode type or separate feature)  
✓ Attachment support (image/PDF) in place  
✓ Error handling patterns established  
✓ Pro tier gating ready  

### What's Missing for Chat
✗ Streaming API implementation (need provider-specific handling)  
✗ Conversation history tracking (no schema for chat messages)  
✗ Turn-based interaction (current architecture is single-request/response)  
✗ Incrementally-rendered output (only typewriter animation after full response)  
✗ Chat-specific UI (composition, history panel, etc.)  

### Design Decisions Needed
1. **Chat as mode or separate feature?**
   - Mode: Reuse EnhanceMeView, add history sidebar, modify UX flow
   - Separate: New ChatPanel.swift, ChatView.swift, dedicated architecture

2. **History persistence?**
   - In-memory per session only?
   - SwiftData model for persistent conversation storage?

3. **Streaming approach?**
   - Implement provider-specific streaming methods
   - Create new `streamEnhance()` function on AIProviderProtocol?
   - Handle delta rendering at service level or view level?

4. **Multi-turn context?**
   - Accumulate all messages in conversation?
   - System prompt + conversation array sent each turn?
   - Token budget awareness?

---

## Summary

The AI layer is well-structured with clean separation of concerns:
- **Protocols** define behavior (AIProviderProtocol)
- **Services** orchestrate (AIService)
- **Models** persist (AIModeModel)
- **Views** present (EnhanceMeView)

Both Gemini and z.ai providers are stable but lack streaming. The EnhanceMe UI is comprehensive but single-mode focused. The codebase is ready for Chat feature development—primary work would be adding streaming implementations and designing the conversation UI/data model.

