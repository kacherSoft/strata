---
title: SwiftUI ChatGPT-like Chat Interface Patterns for macOS (2025-2026)
date: 2026-03-17
scope: Research report on modern chat UI implementation patterns, streaming text, persistence, markdown rendering, and file handling in SwiftUI for macOS.
---

# SwiftUI ChatGPT-like Chat Interface Research Report

## Executive Summary

Building modern chat interfaces in SwiftUI for macOS requires mastering six core technical areas: async streaming, persistent storage, markdown rendering, UI patterns, file handling, and scroll behavior. This report synthesizes 2025-2026 best practices across each domain.

**Key Finding:** Modern SwiftUI chat apps use AsyncSequence for streaming, SwiftData for persistence, MarkdownUI for rich text, ScrollViewReader for auto-scroll, and the Transferable protocol for file handling. WWDC 2025 introduced SwiftData inheritance, simplifying chat message modeling.

---

## 1. Streaming Text Display in SwiftUI

### Pattern: AsyncSequence + @Observable + onChange

**Core Approach:**
- Use `URLSession.bytes()` (iOS 15+) to receive streaming HTTP responses
- Leverage `.lines` property for automatic newline-based buffering
- Apply `for try await` loops to process tokens sequentially
- Update UI via @Observable properties with onChange tracking

**Implementation Pattern:**

```swift
@Observable
final class ChatViewModel {
    var messages: [Message] = []
    var currentMessage: String = ""

    func streamResponse(prompt: String) async throws {
        var (bytes, _) = try await URLSession.shared.bytes(from: url)

        for try await line in bytes.lines {
            if line.hasPrefix("data: ") {
                let jsonStr = String(line.dropFirst(6))
                if let data = jsonStr.data(using: .utf8),
                   let decoded = try? JSONDecoder().decode(StreamChunk.self, from: data) {
                    currentMessage += decoded.choices[0].delta.content
                    // UI updates automatically via @Observable
                }
            }
        }

        messages.append(Message(role: .assistant, content: currentMessage))
        currentMessage = ""
    }
}
```

**Key Advantages:**
- `AsyncSequence` pattern is memory efficient (no buffering entire response)
- `@Observable` macro (Swift 5.5+) provides reactive updates without @State complexity
- `.lines` property handles SSE format automatically
- Error propagation is explicit and testable

**Trade-offs:**
- Server-Sent Events (SSE) only; WebSocket requires custom AsyncSequence wrapper
- Token-by-token updates can cause frequent re-renders; use `.debounce()` for smooth display
- Must handle connection errors explicitly

**Throttling for Smooth Rendering:**
Token updates should be throttled to avoid excessive re-renders. Debounce incoming tokens to batches (every 50-100ms) for smoother visual presentation.

---

## 2. SwiftData for Chat Persistence

### WWDC 2025 Updates
SwiftData now supports class inheritance (new in iOS 26), simplifying polymorphic chat models.

### Recommended Schema Design

**Core Models:**

```swift
@Model
final class ChatSession {
    @Attribute(.unique) var id: String
    var title: String
    var messages: [ChatMessage] = []
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString, title: String) {
        self.id = id
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class ChatMessage {
    @Attribute(.unique) var id: String
    var sessionID: String // Foreign key reference
    var role: MessageRole // enum: user, assistant, system
    var content: String
    var timestamp: Date
    var isEdited: Bool = false
    var attachments: [FileAttachment] = []

    init(id: String = UUID().uuidString, sessionID: String,
         role: MessageRole, content: String) {
        self.id = id
        self.sessionID = sessionID
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

@Model
final class FileAttachment {
    @Attribute(.unique) var id: String
    var fileName: String
    var filePath: String // Store relative path in app sandbox
    var fileType: String // UTType representation
    var fileSize: Int
    var uploadedAt: Date

    init(fileName: String, filePath: String, fileType: String, fileSize: Int) {
        self.id = UUID().uuidString
        self.fileName = fileName
        self.filePath = filePath
        self.fileType = fileType
        self.fileSize = fileSize
        self.uploadedAt = Date()
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}
```

### Query Patterns

**Fetch recent sessions:**
```swift
@Query(sort: [SortDescriptor(\.updatedAt, order: .reverse)])
var sessions: [ChatSession]
```

**Fetch messages for session (ordered by timestamp):**
```swift
let sessionMessages = session.messages.sorted(by: { $0.timestamp < $1.timestamp })
```

### Best Practices

1. **Use `@Unique` on IDs:** Prevents duplicate messages during sync errors
2. **Store relative paths for files:** Absolute paths break when app relocates
3. **Batch insertions:** Add multiple messages in single transaction
4. **Index by timestamp:** Queries on `timestamp` improve chat history performance
5. **Avoid large BLOB storage:** Keep message text <100KB; handle large files separately

### Migration Concerns
WWDC 2025 simplified migrations via inheritance. When schema changes, use lightweight migration if only adding optional properties. For structural changes (deleting properties), implement custom migration logic.

---

## 3. Markdown Rendering in SwiftUI

### Library Comparison (2025)

| Library | Status | CommonMark | Code Blocks | Tables | Notes |
|---------|--------|-----------|------------|--------|-------|
| **MarkdownUI** | Active | ✓ Full | ✓ Syntax highlighting via customization | ✓ Yes | Recommended for chat (used by X/Grok, Hugging Face) |
| **swift-markdown-ui** | Maintenance | ✓ GFM | ✓ Basic | ✓ Limited | Transitioning to Textual library |
| **Textual** | New (2025) | ✓ GFM | ✓ Advanced | ✓ Yes | Modern successor to MarkdownUI |
| Native SwiftUI Text | Built-in | Partial | ✗ None | ✗ None | Bold/italic/links only; insufficient for chat |

### Recommended: MarkdownUI Library

**Installation:**
```swift
.package(url: "https://github.com/markiv/MarkdownUI.git", from: "0.3.0")
```

**Basic Usage:**
```swift
import MarkdownUI

VStack(alignment: .leading, spacing: 12) {
    Markdown(message.content)
        .markdownStyle(MarkdownStyle(
            code: InlineCodeStyle(
                backgroundColor: Color(.controlBackgroundColor),
                cornerRadius: 4,
                padding: EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
            ),
            codeBlock: CodeBlockStyle(
                backgroundColor: Color(red: 0.1, green: 0.1, blue: 0.12),
                textColor: Color.green,
                fontSize: 12,
                fontFamily: "Menlo"
            )
        ))
        .lineLimit(nil)
}
```

### Custom Syntax Highlighting

MarkdownUI doesn't include syntax highlighting by default. Implement via `CodeBlockStyle.textStyle`:

```swift
func syntaxHighlightCode(_ code: String, language: String) -> AttributedString {
    // Use tree-sitter or Highlight.js wrapper for parsing
    // For simple cases, use regex for keywords
    var attributed = AttributedString(code)

    // Example: highlight Swift keywords
    let keywords = ["func", "var", "let", "class", "struct", "enum"]
    for keyword in keywords {
        let pattern = "\\b\(keyword)\\b"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(code.startIndex..., in: code)
            let matches = regex.matches(in: code, range: range)

            for match in matches {
                if let range = Range(match.range, in: code) {
                    if let attrRange = attributed.range(of: String(code[range])) {
                        attributed[attrRange].foregroundColor = .blue
                        attributed[attrRange].font = .system(.body, design: .monospaced).bold()
                    }
                }
            }
        }
    }
    return attributed
}
```

### Chat Bubble Integration

```swift
struct ChatBubble: View {
    let message: ChatMessage
    let isUserMessage: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isUserMessage { Spacer() }

            VStack(alignment: isUserMessage ? .trailing : .leading) {
                Markdown(message.content)
                    .markdownStyle(customMarkdownStyle())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isUserMessage ? Color.blue : Color(.controlBackgroundColor))
                    .cornerRadius(12)
            }
            .frame(maxWidth: .infinity, alignment: isUserMessage ? .trailing : .leading)

            if !isUserMessage { Spacer() }
        }
        .padding(.horizontal, 12)
    }
}
```

### Code Block Styling
- Use monospace font (Menlo, Monaco, Courier New)
- Dark background (#1e1e1e or similar) for readability
- Line numbers optional but recommended for large blocks
- Copy-to-clipboard button highly recommended

---

## 4. Modern Chat UI Patterns for macOS

### Architecture: MVVM with Sidebar

```swift
// Main app structure
struct ChatApp: App {
    @StateObject var store = ChatStore()

    var body: some Scene {
        WindowGroup {
            HStack(spacing: 0) {
                // Sidebar: Session list
                ChatSessionSidebar(store: store)
                    .frame(minWidth: 200, maxWidth: 300)
                    .background(Color(.controlBackgroundColor))

                Divider()

                // Main: Chat view
                if let selectedSession = store.selectedSession {
                    ChatMainView(session: selectedSession, store: store)
                } else {
                    EmptyStateView()
                }
            }
        }
    }
}
```

### Session Management Patterns

**Sidebar Features:**
- List of sessions sorted by `updatedAt` (newest first)
- Quick search/filter by title
- Right-click context menu: rename, delete, export
- Keyboard shortcut: Cmd+N for new chat, Cmd+Shift+D for delete

```swift
struct ChatSessionSidebar: View {
    @ObservedRealmObject var store: ChatStore
    @State private var searchText = ""
    @State private var selectedSessionID: String?

    var filteredSessions: [ChatSession] {
        searchText.isEmpty ? store.sessions :
            store.sessions.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack {
            SearchField(text: $searchText, placeholder: "Search chats...")

            List(filteredSessions, id: \.id, selection: $selectedSessionID) { session in
                ChatSessionRow(session: session, store: store)
                    .contextMenu {
                        Button("Rename") { store.startRenaming(session) }
                        Divider()
                        Button("Delete", role: .destructive) { store.delete(session) }
                    }
            }

            Spacer()

            Button(action: { store.createNewSession() }) {
                Label("New Chat", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
        }
        .padding(.vertical, 8)
    }
}
```

### Chat Main View

```swift
struct ChatMainView: View {
    @ObservedRealmObject var session: ChatSession
    @StateObject var viewModel: ChatViewModel
    @State private var inputText = ""
    @FocusState private var inputFocused

    var body: some View {
        VStack(spacing: 0) {
            // Chat history
            ChatMessageList(messages: session.messages, viewModel: viewModel)

            Divider()

            // Input area
            ChatInputView(
                text: $inputText,
                isFocused: $inputFocused,
                onSubmit: {
                    viewModel.send(inputText, to: session)
                    inputText = ""
                }
            )
        }
    }
}
```

### Key UX Patterns

1. **New Chat:** Immediate focus on empty input field, show placeholder: "Type a message..."
2. **Rename:** In-line editing with Cmd+R shortcut, auto-blur on Return
3. **Delete:** Confirmation dialog; shift-select for batch delete
4. **Search:** Filter by title; consider adding full-text search on message content (SwiftData supports this)
5. **Session info:** Show message count, creation date, last modified in sidebar tooltip

---

## 5. File Attachment in Chat

### Drag-Drop Implementation

**Core Pattern:** Use `dropDestination()` modifier with Transferable protocol.

```swift
struct ChatInputView: View {
    @State private var attachedFiles: [AttachedFile] = []
    @State private var isDragOverInput = false

    var body: some View {
        VStack(spacing: 8) {
            // File preview area
            if !attachedFiles.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(attachedFiles, id: \.id) { file in
                            FilePreviewCard(file: file) {
                                attachedFiles.removeAll { $0.id == file.id }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(height: 80)
            }

            // Text input with drag-drop target
            HStack(spacing: 8) {
                TextEditor(text: $inputText)
                    .frame(minHeight: 44)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                    .dropDestination(
                        for: URL.self,
                        action: { urls, location in
                            handleDroppedFiles(urls)
                            return true
                        },
                        isTargeted: { isDragOverInput = $0 }
                    )
                    .border(isDragOverInput ? Color.blue : Color.clear, width: 2)

                Button(action: { showFilePicker() }) {
                    Image(systemName: "paperclip")
                }
            }
            .padding(8)
        }
    }

    private func handleDroppedFiles(_ urls: [URL]) {
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }

            let filename = url.lastPathComponent
            let filesize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let fileType = url.pathExtension

            let file = AttachedFile(
                fileName: filename,
                fileType: fileType,
                fileSize: filesize,
                sourceURL: url
            )
            attachedFiles.append(file)
        }
    }
}
```

### File Preview Card

```swift
struct FilePreviewCard: View {
    let file: AttachedFile
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                // Preview thumbnail
                if file.fileType.lowercased() == "pdf" {
                    Image(systemName: "doc.pdf.fill")
                        .resizable()
                        .foregroundColor(.red)
                        .frame(width: 40, height: 40)
                } else if ["jpg", "jpeg", "png", "gif"].contains(file.fileType.lowercased()) {
                    AsyncImage(url: file.sourceURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.gray
                    }
                    .frame(width: 60, height: 60)
                    .clipped()
                } else {
                    Image(systemName: "doc.fill")
                        .resizable()
                        .foregroundColor(.gray)
                        .frame(width: 40, height: 40)
                }

                // Remove button
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 12))
                }
                .offset(x: 5, y: -5)
            }

            // Filename + size
            VStack(alignment: .center, spacing: 2) {
                Text(file.fileName)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(ByteCountFormatter.string(fromByteCount: Int64(file.fileSize), countStyle: .file))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 70)
    }
}
```

### File Handling Best Practices

1. **Security scoped resources:** Use `startAccessingSecurityScopedResource()` when reading dropped files
2. **Copy to app sandbox:** Never store source URL directly; copy file to app's document directory
3. **File size limits:** Validate before upload (e.g., max 25MB per file)
4. **MIME type validation:** Check `UTType` against allowed types
5. **Virus scanning:** Integrate with ClamAV API for uploaded files (backend responsibility)

### Message with Attachments

```swift
struct Message {
    let id: String
    let role: MessageRole
    let content: String
    let attachments: [FileAttachment]
    let timestamp: Date
}

// When sending message with attachments:
func sendMessageWithFiles(_ text: String, files: [AttachedFile]) async throws {
    // 1. Copy files to app sandbox
    let savedAttachments = try files.map { file in
        let destURL = FileManager.appSandboxURL.appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: file.sourceURL, to: destURL)
        return FileAttachment(
            fileName: file.fileName,
            filePath: destURL.relativePath,
            fileType: file.fileType,
            fileSize: file.fileSize
        )
    }

    // 2. Create message with attachments
    let message = Message(
        id: UUID().uuidString,
        role: .user,
        content: text,
        attachments: savedAttachments,
        timestamp: Date()
    )

    // 3. Send to backend with multipart upload
    try await apiClient.sendMessage(message, attachments: savedAttachments)
}
```

---

## 6. ScrollView Auto-Scroll Behavior

### Pattern: defaultScrollAnchor() + Manual Override

**iOS 17+ / macOS 14+ Approach (RECOMMENDED):**

```swift
struct ChatMessageList: View {
    let messages: [ChatMessage]
    @State private var userHasScrolledUp = false

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages, id: \.id) { message in
                        ChatBubble(message: message)
                            .id(message.id) // Required for scroll tracking
                    }

                    // Invisible anchor at bottom
                    Color.clear
                        .frame(height: 0)
                        .id("bottom")
                }
                .padding(.vertical, 12)
            }
            .defaultScrollAnchor(.bottom) // Start scrolled to bottom
            .onChange(of: messages.count) { _, newCount in
                // Auto-scroll when new message arrives (if user hasn't scrolled up)
                if !userHasScrolledUp {
                    withAnimation {
                        scrollProxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                // Detect if user has manually scrolled away from bottom
                let offset = geometry.contentOffset.y
                let contentHeight = geometry.contentSize.height
                let viewHeight = geometry.containerSize.height

                return offset < (contentHeight - viewHeight - 50) // 50pt buffer
            } action: { didScrollUp in
                userHasScrolledUp = didScrollUp
            }
        }
    }
}
```

### iOS 16 / macOS 13 Fallback (ScrollViewReader only)

```swift
struct ChatMessageList: View {
    let messages: [ChatMessage]
    @State private var shouldAutoScroll = true

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(messages, id: \.id) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _, _ in
                if shouldAutoScroll {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        scrollProxy.scrollTo(messages.last?.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}
```

### Smooth Scrolling for Streaming Messages

When a message is streaming (being updated token-by-token), avoid constant scrolls. Instead:

1. **Buffer tokens:** Batch updates every 50ms
2. **Scroll only on new message:** Not on content updates
3. **Maintain scroll position:** If user scrolls up, don't auto-scroll to bottom

```swift
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var streamingBuffer = ""

    func streamResponse(prompt: String) async throws {
        let newMessage = ChatMessage(id: UUID().uuidString, role: .assistant, content: "")
        messages.append(newMessage)

        // Tokens arrive rapidly; batch them
        var timer: Timer?
        var tokenBuffer = ""

        for try await token in streamTokens(prompt) {
            tokenBuffer += token

            // Flush buffer every 50ms
            if timer == nil {
                timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { _ in
                    if let lastIdx = messages.count - 1 {
                        messages[lastIdx].content += tokenBuffer
                        tokenBuffer = ""
                    }
                }
            }
        }

        // Final flush
        if !tokenBuffer.isEmpty, let lastIdx = messages.count - 1 {
            messages[lastIdx].content += tokenBuffer
        }
    }
}
```

### Performance Optimization

For large chat histories (100+ messages):

```swift
struct ChatMessageList: View {
    let messages: [ChatMessage]

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    // Only render visible messages + buffer
                    ForEach(messages, id: \.id) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.vertical, 12)
            }
            .defaultScrollAnchor(.bottom)
        }
    }
}
```

Use `LazyVStack` instead of `VStack` to defer rendering until messages are visible. Combine with `.onAppear` to load message history incrementally.

---

## Architecture Recommendation: Complete Example

### Project Structure

```
ChatApp/
├── Models/
│   ├── ChatSession.swift        (SwiftData model)
│   ├── ChatMessage.swift        (SwiftData model)
│   └── MessageRole.swift        (enum)
├── ViewModels/
│   ├── ChatViewModel.swift      (@Observable, streaming logic)
│   └── ChatStore.swift          (session management)
├── Views/
│   ├── ChatApp.swift            (root)
│   ├── ChatMainView.swift       (chat area + input)
│   ├── ChatSessionSidebar.swift (session list)
│   ├── ChatMessageList.swift    (scrollable messages)
│   ├── ChatBubble.swift         (individual message + markdown)
│   ├── ChatInputView.swift      (input + file drop)
│   └── FilePreviewCard.swift    (attached file preview)
└── Utilities/
    ├── APIClient.swift          (OpenAI/Claude API)
    └── FileManager+Sandbox.swift (safe file handling)
```

### Complete ViewModel Pattern

```swift
@Observable
final class ChatViewModel {
    var currentSession: ChatSession?
    var isLoading = false
    var error: Error?
    private var cancelBag: [AnyCancellable] = []

    @MainActor
    func streamResponse(prompt: String, to session: ChatSession) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Create assistant message placeholder
            let assistantMsg = ChatMessage(
                id: UUID().uuidString,
                sessionID: session.id,
                role: .assistant,
                content: ""
            )
            session.messages.append(assistantMsg)

            // Stream tokens
            let stream = try await apiClient.streamCompletion(
                messages: session.messages.map { $0.toAPIMessage() },
                model: "gpt-4"
            )

            var buffer = ""
            for try await chunk in stream {
                buffer += chunk.delta

                // Batch updates every 50ms
                if buffer.count > 20 || chunk.isFinal {
                    assistantMsg.content += buffer
                    buffer = ""
                }
            }
        } catch {
            self.error = error
        }
    }
}
```

---

## Unresolved Questions & Considerations

1. **WebSocket vs SSE:** Report assumes SSE (simpler for request-response). WebSocket needed for real-time collaborative editing—requires custom AsyncSequence wrapper.

2. **Syntax highlighting library:** MarkdownUI doesn't include built-in syntax highlighting. Integration with tree-sitter or highlight.js requires custom implementation or separate library (recommend evaluating Textual library for 2025 option).

3. **Cloud sync:** Report covers local SwiftData only. CloudKit sync requires additional ModelConfiguration setup; recommend researching `ModelConfiguration.cloudKitDatabase` for cross-device persistence.

4. **Message search:** Full-text search on SwiftData query layer not documented in 2025 resources; may require SQLite integration or post-fetch filtering.

5. **Offline mode:** No authoritative guidance found on queue-then-sync pattern for chat messages sent offline; recommend implementing local queue with CloudKit push notifications.

6. **Voice input:** Report assumes text-only. Voice-to-text (Whisper) streaming requires separate AsyncSequence pattern not covered here.

---

## Summary Table: Technology Stack Recommendation

| Component | Recommended | Rationale |
|-----------|------------|-----------|
| **Streaming** | AsyncSequence + URLSession.bytes() | Native, memory-efficient, simple error handling |
| **Persistence** | SwiftData | WWDC 2025 inheritance support; seamless SwiftUI integration |
| **Markdown** | MarkdownUI (markiv/MarkdownUI) | CommonMark compliance, used by X/Grok, active maintenance |
| **Syntax highlighting** | Custom regex + AttributedString | No 1st-party library; tree-sitter overkill for most cases |
| **Scroll behavior** | defaultScrollAnchor(.bottom) | iOS 17+ native; smooth, respects user scroll |
| **File handling** | Transferable + dropDestination() | iOS 16+ standard; security-scoped resource handling built-in |
| **Input UI** | TextEditor + custom formatting | Standard for macOS chat apps; avoid third-party text editors |
| **Session management** | MVVM with @Observable | Swift 5.5+ standard; cleaner than @StateObject |

---

## Sources

- [Advanced Swift Concurrency: AsyncStream - by Jacob Bartlett](https://blog.jacobstechtavern.com/p/async-stream)
- [AsyncStream and AsyncSequence for Swift Concurrency](https://matteomanferdini.com/swift-asyncstream/)
- [Streaming messages from ChatGPT using Swift AsyncSequence • Zach Waugh](https://zachwaugh.com/posts/streaming-messages-chatgpt-swift-asyncsequence)
- [From Stream to Screen: Handling GenAI Rich Responses in SwiftUI](https://medium.com/safe-engineering/from-stream-to-screen-handling-genai-rich-responses-in-swiftui-da138acfaa05)
- [SwiftUI Data Persistence in 2025 (DEV Community)](https://dev.to/swift_pal/swiftui-data-persistence-in-2025-swiftdata-core-data-appstorage-scenestorage-explained-with-5g2c)
- [The Art of SwiftData in 2025 (Medium)](https://medium.com/@matgnt/the-art-of-swiftdata-in-2025-from-scattered-pieces-to-a-masterpiece-1fd0cefd8d87)
- [WWDC 2025 - SwiftData iOS 26 - Class Inheritance & Migration](https://dev.to/arshtechpro/wwdc-2025-swiftdata-ios-26-class-inheritance-migration-issues-30bh)
- [MarkdownUI GitHub](https://github.com/markiv/MarkdownUI)
- [How to support drag and drop in SwiftUI (Hacking with Swift)](https://www.hackingwithswift.com/quick-start/swiftui/how-to-support-drag-and-drop-in-swiftui)
- [Drag and Drop in SwiftUI - The SwiftUI Lab](https://swiftui-lab.com/drag-drop-with-swiftui/)
- [SwiftUI: Reliable Ways to Auto-Scroll ScrollView to Bottom (Medium)](https://medium.com/@itsuki.enjoy/swiftui-2-5-reliable-ways-to-automatically-scroll-to-the-bottom-of-scrollview-1581711e957c)
- [Auto-Scrolling with ScrollViewReader in SwiftUI (Medium)](https://medium.com/@mikeusru/auto-scrolling-with-scrollviewreader-in-swiftui-10f16dce7dbb)
- [AutoScrollingScrollView GitHub](https://github.com/drewster99/swiftui-auto-scrolling-scrollview)
