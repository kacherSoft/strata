# Edge Case Scout Report: Chat Mode Feature
**Date:** 2026-03-18 | **Scope:** All 36 chat-related files (20 new, 16 modified)

---

## Critical Issues

### 1. CRITICAL: `streamTask` set AFTER Task spawned -- race with cancellation
**File:** `ChatView.swift:229-255`
```swift
let task = Task { ... }          // Task starts running immediately
chatService.streamTask = task    // Assignment happens AFTER task is already in flight
```
If user taps Stop immediately after Send, `cancelStream()` reads `streamTask` which is still `nil` from the previous call. The cancel is silently dropped and streaming continues uninterrupted.

**Fix:** Set `streamTask` inside `ChatService.sendMessage()` or assign it before the Task body executes.

### 2. CRITICAL: `defer { isStreaming = false }` fires on wrong path when Task is cancelled
**File:** `ChatService.swift:32`
The `defer` in `sendMessage()` sets `isStreaming = false`. But `cancelStream()` also sets `isStreaming = false` (line 57). When a Task is cancelled:
1. `cancelStream()` sets `isStreaming = false`
2. The `for try await` loop throws `CancellationError`
3. `sendMessage()` propagates it, `defer` fires, sets `isStreaming = false` again

This is benign for `isStreaming`, BUT the real problem is: `sendMessage()` throws `CancellationError` while the caller (`ChatView.sendMessage()`) catches it at line 243 to save partial text. However `currentStreamText` was NOT cleared by `cancelStream()` (intentionally), so partial save works. **Actually safe but fragile** -- any refactor could break this implicit contract.

### 3. CRITICAL: Attachments sent to ChatService but NEVER forwarded to Gemini
**File:** `ChatService.swift:34-35` builds `ChatMessage` with attachments, then `GeminiProvider.streamChat()` (line 111-156) **completely ignores** `msg.attachments`. The prompt is built purely from `msg.content` strings. Attachments are silently dropped.

Same for `OpenAICompatibleProvider.streamChat()` -- line 79 only sends `msg.content`, ignoring attachments.

The default fallback `streamChat` in `AIProvider.swift:18-29` also uses only text.

**Impact:** User attaches images/PDFs, sees them in UI, but AI never receives them. Silent data loss.

---

## High Priority

### 4. HIGH: No conversation history size limit -- unbounded token usage
**File:** `ChatView.swift:196-199`
All messages are sent as history every turn. A 100-message conversation sends all 100 messages to the API. For Gemini's single-prompt approach, this means a massive prompt string with no truncation.

**Impact:** API errors (token limit exceeded), slow responses, high cost. No sliding window or token counting.

### 5. HIGH: `sessions` array in ChatView stale after sidebar operations
**File:** `ChatView.swift:9,60,187`
`ChatView` keeps its own `@State private var sessions` array. `ChatSessionListView` keeps a separate `@State private var sessions` array (line 9). They are loaded independently via separate `loadSessions()` calls. The toolbar title lookup `sessions.first(where: { $0.id == sessionId })` (line 60) uses ChatView's array, which may not include sessions created by the sidebar.

After renaming a session in the sidebar, ChatView's `sessions` array still has the old title. Toolbar shows stale title until next `loadSessions()` call.

### 6. HIGH: OpenAI streaming doesn't handle multi-line SSE data fields
**File:** `OpenAICompatibleProvider.swift:99-117`
The SSE parser iterates `bytes.lines` and checks `line.hasPrefix("data: ")`. Per the SSE spec, a single event can have multiple `data:` lines that should be concatenated with newlines. The current parser treats each `data:` line independently.

In practice most OpenAI-compatible APIs send single-line data, but Ollama and some proxies use multi-line. Edge case but real.

### 7. HIGH: `OpenAICompatibleProvider` creates new instance on every `providerFor(.openai)` call
**File:** `AIService.swift:27-31`
```swift
case .openai:
    return OpenAICompatibleProvider(
        name: "OpenAI Compatible",
        baseURL: baseURL,
        apiKeyProvider: { KeychainService.shared.get(.openaiAPIKey) }
    )
```
Every call to `providerFor(.openai)` allocates a new provider. During streaming, `ChatView.sendMessage()` calls `providerFor()` once (via ChatService), but `isConfigured` checks elsewhere will also allocate throwaway instances.

Not a memory leak (no retain cycles), but wasteful and inconsistent with how Gemini/ZAI providers work (singletons).

### 8. HIGH: `ChatTextInput` text clearing race condition
**File:** `ChatView.swift:190` clears `inputText = ""` but `ChatTextInput.updateNSView()` (line 34-38) only updates `textView.string` when `textView.string != text`. If the coordinator's `textDidChange` fires between the SwiftUI state update and the AppKit sync, the text field could show stale content.

In practice SwiftUI batches updates so this is unlikely, but the NSViewRepresentable bridge is inherently asynchronous.

---

## Medium Priority

### 9. MEDIUM: Markdown renderer crashes on unmatched triple-backtick
**File:** `ChatMarkdownRenderer.swift:53-69`
`splitCodeBlocks` splits on "```" and treats odd-indexed segments as code. If AI response has an odd number of "```" delimiters (common during streaming when response is mid-code-block), the last segment is incorrectly treated as a code block.

During streaming, `ChatMessageBubble` renders `currentStreamText` which frequently has unclosed code blocks.

### 10. MEDIUM: `ensureSessionExists()` finds blank by title string match
**File:** `ChatView.swift:142`
```swift
if let blank = sessions.first(where: { $0.title == "New Chat" })
```
If user manually renames a session to "New Chat", this treats it as a blank reusable session. The auto-title logic (line 206-213) also matches on "New Chat". User loses their intentionally-named session.

### 11. MEDIUM: Deleting active session while streaming causes orphaned state
**File:** `ChatSessionListView.swift:131-139`
User can right-click and delete a session that is actively streaming. `deleteSession` removes the session from DB and selects a different one. But `ChatView.chatService` keeps streaming into the now-deleted session. The catch block (ChatView:237) tries to save the response to a deleted session.

SwiftData delete cascade removes messages, but `msgRepo.create(session:...)` may try to insert into a deleted session.

### 12. MEDIUM: `lastMessageAt` sort with nil values
**File:** `ChatSessionRepository.swift:14-15`
Sort by `lastMessageAt` descending, then `createdAt` descending. New sessions have `lastMessageAt = nil`. SwiftData sorts nil values inconsistently across platforms. Brand-new sessions may appear at top or bottom depending on SQLite's NULL handling.

### 13. MEDIUM: `TypingIndicatorView` timer never invalidated
**File:** `TypingIndicatorView.swift:7`
```swift
private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
```
The `autoconnect()` starts the timer immediately on init. When the view is removed from hierarchy, the timer publisher continues firing. While the `.onReceive` subscription is removed, the underlying `Timer.TimerPublisher` keeps its `Cancellable` alive.

In practice SwiftUI manages this, but if the view is conditionally shown/hidden rapidly, multiple timer instances could exist simultaneously.

### 14. MEDIUM: `closeAllFloatingWindows()` does NOT close chat panel
**File:** `WindowManager.swift:25-29`
```swift
private func closeAllFloatingWindows() {
    hideQuickEntry()
    hideSettings()
    hideEnhanceMe()
    // hideChat() is NOT called
}
```
This is intentional per the comment on line 331 (`showChat` doesn't call `closeAllFloatingWindows`), but it means opening QuickEntry/Settings/EnhanceMe does NOT close the chat panel. Chat can remain visible behind other panels. Inconsistent UX.

### 15. MEDIUM: `ChatPanel.maxSize` limits window to 1400x900
**File:** `ChatPanel.swift:19`
Hard max size means users with large displays cannot expand chat beyond 1400x900. For a chat interface that renders long code blocks, this is limiting.

### 16. MEDIUM: No retry mechanism for failed sends
When `sendMessage` fails (network error, rate limit), the user message is already persisted to DB (line 203) but there's no way to retry. The error banner shows but the message sits in history with no response. User must retype.

---

## Low Priority

### 17. LOW: `AttachmentChip` hardcodes dark background color
**File:** `AttachmentChip.swift:30`
```swift
.background(Color(red: 0.122, green: 0.161, blue: 0.216)) // #1F2937
```
Uses hardcoded dark color. In light mode this looks out of place.

### 18. LOW: `ChatMarkdownRenderer` hardcodes dark code background
**File:** `ChatMarkdownRenderer.swift:29`
```swift
code.backgroundColor = Color(red: 0.067, green: 0.094, blue: 0.153)
```
Same issue -- dark code block background hardcoded regardless of system appearance.

### 19. LOW: Search only on session title, not message content
**File:** `ChatSessionRepository.swift:54-59`
Session search matches only `title.localizedStandardContains(query)`. Users searching for content within messages won't find results. The sidebar search (ChatSessionListView:104-107) also only filters on title.

### 20. LOW: `GeminiProvider` logs prompt content at info level
**File:** `GeminiProvider.swift:114,126`
```swift
chatLog.info("streamChat: model=\(modelName), messages=\(messages.count)")
chatLog.info("streamChat: prompt length=\(prompt.count)")
```
Not logging content directly, but prompt length at info level leaks metadata. Debug-level chunk logging (line 139) logs first 50 chars of each response. In production builds, `os.Logger` at debug level is not persisted, but info level is.

### 21. LOW: `ChatNSTextView.keyDown` swallows Enter on empty input
**File:** `ChatTextInput.swift:62-63`
```swift
guard !trimmed.isEmpty else { return }
```
When text is empty and user presses Enter, the event is swallowed (no newline inserted, no send triggered). This is correct behavior but means the key event doesn't propagate -- system accessibility features expecting key events may not work.

---

## Data Flow Trace

```
User types text -> inputText @State binding
  -> Enter key -> ChatNSTextView.keyDown -> onSend closure
    -> ChatView.sendMessage()
      -> Trims text, guards not empty/streaming
      -> Clears inputText, captures attachments
      -> Builds history from existing messages (BEFORE persist)
      -> Persists user ChatMessageModel via repo
      -> Auto-titles session from first message
      -> Reloads messages to show user's message
      -> Resolves chat mode from DB (resolveChatMode)
      -> Creates Task for async streaming
        -> ChatService.sendMessage()
          -> Gets provider via AIService.providerFor()
          -> Sets isStreaming=true, clears currentStreamText
          -> Appends user message to history (DOUBLE: already in history param!)
          -> Calls provider.streamChat()
          -> Iterates stream chunks, appends to currentStreamText
          -> Returns full text
        -> Persists assistant ChatMessageModel
        -> Reloads messages + sessions
      -> Sets chatService.streamTask = task (AFTER task starts!)
```

**Double-send bug (line 34-35 of ChatService):** ChatService appends the user message to the history parameter, but ChatView already built history from persisted messages. If the user's message was already in `history`, it would be doubled. BUT: history is built BEFORE persisting (line 196), so the user message is NOT in history yet. ChatService then adds it. **Correct, but only because of careful ordering.**

---

## Security Notes

- API keys read from Keychain per-request, never cached in memory beyond closure scope. Good.
- `OpenAICompatibleProvider.isValidBaseURL` allows HTTP for localhost only. Good.
- No sanitization of user input before sending to AI -- expected for chat, but system prompt injection is possible if user messages contain "System:" prefixes in Gemini's single-prompt format.
- Attachment file paths stored as strings in `attachmentPaths` but never actually used after persist. The field exists in the model but nothing reads it back.

---

## Summary

| Severity | Count | Key Themes |
|----------|-------|------------|
| Critical | 3     | Attachments silently dropped, streamTask race, cancel timing |
| High     | 5     | Unbounded history, stale state, SSE parsing, provider allocation |
| Medium   | 8     | Markdown streaming, delete-while-streaming, nil sort, timer leak |
| Low      | 5     | Hardcoded colors, search scope, logging |

**Top 3 fixes needed before ship:**
1. Attachments are never sent to providers -- either implement multimodal streaming or hide attachment button in chat mode
2. `streamTask` assignment race -- move Task creation inside ChatService or assign before spawn
3. Add conversation history truncation (sliding window or token budget)
