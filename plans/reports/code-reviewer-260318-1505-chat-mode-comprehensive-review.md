# Code Review: Chat Mode Feature — Comprehensive Review

**Reviewer:** code-reviewer | **Date:** 2026-03-18 | **Scope:** 26 files, ~1200 LOC

---

## Overall Assessment

The Chat Mode feature is structurally sound with clean separation of concerns. The known hotfix issues (1-5) appear correctly addressed. However, several **high-severity issues** remain that can cause data loss, UI corruption, and stuck states under real-world usage patterns.

---

## Critical Issues

### C1. `showChat()` recreates SwiftUI view tree on every invocation — state loss

**File:** `WindowManager.swift:337`

Every call to `showChat()` runs `panel.setContent(ChatView(...))` which creates a **new** `NSHostingView` with a fresh `ChatView`. This destroys all `@State` (selected session, messages, input text, streaming state). If user clicks the Chat shortcut while Chat is already open, all in-progress work is wiped.

```swift
// Current: always replaces content
panel.setContent(view)
```

**Fix:** Only call `setContent` when creating a new panel. Reuse existing content:
```swift
func showChat() {
    if chatPanel == nil {
        chatPanel = ChatPanel()
        guard let panel = chatPanel, let container = modelContainer else { return }
        let view = ChatView(onDismiss: { [weak self] in self?.hideChat() })
            .withAppEnvironment(container: container)
        panel.setContent(view)
    }
    guard let panel = chatPanel else { return }
    panel.collectionBehavior.insert(.moveToActiveSpace)
    if !panel.isVisible || !panel.isOnActiveSpace { panel.orderOut(nil) }
    panel.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
}
```

**Impact:** Data loss mid-conversation, streaming task orphaned (continues running with no UI).

### C2. Orphaned streaming Task on view destruction / panel hide

**File:** `ChatView.swift:226-252`

When user closes the chat panel via X button or `hideChat()` during active streaming:
1. `chatService.streamTask` continues running in background
2. It holds references to `ChatService`, `ChatMessageRepository`, `ModelContext`
3. It will attempt to write to `modelContext` after the view hierarchy is gone

The `onDismiss` callback calls `hideChat()` which does `panel.orderOut(nil)` — this doesn't deallocate the view immediately, but the next `showChat()` (per C1) replaces the content, orphaning the old view+task.

**Fix:** Cancel streaming on dismiss:
```swift
let onDismiss: () -> Void
// In ChatView, add:
.onDisappear { chatService.cancelStream() }
```

### C3. Sorting sessions by nullable `lastMessageAt` — new sessions sink to bottom

**File:** `ChatSessionRepository.swift:13-14`

```swift
sortBy: [SortDescriptor(\.lastMessageAt, order: .reverse)]
```

New sessions have `lastMessageAt = nil`. SwiftData sorts `nil` values inconsistently (often last in reverse order). A newly created "New Chat" session may appear at the **bottom** of the sidebar list, invisible without scrolling.

**Fix:** Sort by `updatedAt` as tiebreaker or set `lastMessageAt = Date()` on creation:
```swift
sortBy: [SortDescriptor(\.lastMessageAt, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
```

---

## High Priority

### H1. Race condition: rapid send while streaming causes guard bypass

**File:** `ChatService.swift:24`

The `guard !isStreaming` check is on `@MainActor`, so it's safe from true data races. However, the Task assignment pattern has a gap:

```swift
// ChatView.swift:252
chatService.streamTask = task
```

This is set **after** `Task { ... }` is created. If the task completes before this line executes (e.g., immediate error), `streamTask` is overwritten with an already-completed task. Not a crash, but `cancelStream()` would be a no-op on stale reference.

**Fix:** Assign `streamTask` before the task body begins executing, or use a more robust pattern:
```swift
let task = Task { ... }
chatService.streamTask = task  // This is fine since both are @MainActor
```
Actually this is safe since `@MainActor` ensures serial execution. The Task body won't start until the current synchronous scope yields. **Low risk in practice.**

### H2. `ChatService.cancelStream()` resets `isStreaming` but `sendMessage` defer also resets it

**File:** `ChatService.swift:32, 54-58`

Sequence: user cancels stream -> `cancelStream()` sets `isStreaming = false` -> the `sendMessage` async function's `defer` runs later and sets `isStreaming = false` again. This is benign but the `currentStreamText` is cleared in `cancelStream()` while `sendMessage` returns the potentially-empty string.

In `ChatView.swift:241-246`, cancellation saves partial text:
```swift
} catch is CancellationError {
    let partial = chatService.currentStreamText
```

**Bug:** `cancelStream()` on line 58 sets `currentStreamText = ""` — so by the time the CancellationError catch block reads `chatService.currentStreamText`, it's already empty. Partial responses are **never saved** on cancellation.

**Fix:** Save the partial text before clearing:
```swift
func cancelStream() {
    streamTask?.cancel()
    streamTask = nil
    // Don't clear currentStreamText — let caller read it first
    isStreaming = false
}
```
And clear `currentStreamText` only when starting a new message (which already happens at line 30).

### H3. `sendMessage` history includes the just-sent user message — double-sends user text

**File:** `ChatView.swift:193-213`

Sequence:
1. Line 195: `msgRepo.create(session: session, role: .user, content: text)` — persists to DB
2. Line 207: `loadMessages(for: sessionId)` — reloads messages array, now includes the new user message
3. Line 210-213: builds `history` from `messages` — includes the user message we just saved
4. Line 228: `chatService.sendMessage(userMessage: text, ... history: history, ...)` — sends userMessage + history

In `ChatService.swift:35`:
```swift
messages.append(ChatMessage(role: .user, content: userMessage, attachments: attachments))
```

The user message is sent **twice** — once in `history` (from the DB reload) and once appended by `sendMessage`. The AI sees the user's message duplicated.

**Fix:** Either:
- Don't reload messages before building history (use the pre-persist array), OR
- Don't append `userMessage` in `ChatService.sendMessage`, OR
- Build history before persisting the user message

### H4. Silent error swallowing in repositories

**Files:** `ChatSessionRepository.swift:60-61`, `ChatMessageRepository.swift:39-40`

```swift
private func saveContext() {
    do { try modelContext.save() } catch { }
}
```

Failed saves are silently ignored. If a save fails (disk full, schema mismatch, etc.), the UI shows the message as sent but it's not persisted. User loses data on app restart with no warning.

**Fix:** At minimum, log the error. Better: propagate to caller for UI feedback:
```swift
private func saveContext() {
    do { try modelContext.save() } catch {
        print("[Strata] ModelContext save failed: \(error)")
    }
}
```

### H5. Gemini streamChat prompt construction loses attachment data

**File:** `GeminiProvider.swift:119-125`

The `streamChat` method builds a text-only prompt, concatenating message content as strings. Attachments from `ChatMessage.attachments` are completely ignored:
```swift
for msg in messages {
    guard msg.role != .system else { continue }
    let label = msg.role == .user ? "User" : "Assistant"
    prompt += "\(label): \(msg.content)\n\n"
    // attachments are never processed
}
```

Meanwhile `ChatInputView` allows attaching files, and they're passed through to `chatService.sendMessage()`.

**Fix:** Either disable attachments for Chat mode streaming, or implement multimodal streaming (using `generateContentStream` with `[ModelContent.Part]`).

---

## Medium Priority

### M1. `ChatEmptyStateView` takes unused `onNewChat` closure

**File:** `ChatEmptyStateView.swift:6, ChatView.swift:84`

```swift
ChatEmptyStateView(onNewChat: {})  // always empty closure
```

The `onNewChat` parameter is never used in the view body. Dead code.

### M2. Duplicate session list state — ChatView.sessions vs ChatSessionListView.sessions

**Files:** `ChatView.swift:9`, `ChatSessionListView.swift:9`

Both views maintain their own `[ChatSessionModel]` arrays. They can drift out of sync. For example, after `sendMessage` auto-titles a session, `ChatView` reloads its sessions array (line 203) and forces sidebar reload via `sidebarKey = UUID()`, but this is fragile — it recreates the entire sidebar view.

**Fix:** Consider a shared `@Observable` ChatViewModel that both views read from.

### M3. `sidebarKey = UUID()` forces full sidebar reconstruction

**File:** `ChatView.swift:16, 178, 204, 239`

Using `.id(sidebarKey)` with a new UUID forces SwiftUI to destroy and recreate the entire `ChatSessionListView`. This loses sidebar scroll position, search text, and editing state. Used 3 times after data mutations.

### M4. Markdown renderer recomputes on every StreamingText change

**File:** `ChatMarkdownRenderer.swift`

During streaming, `ChatMessageBubble` renders `ChatMarkdownRenderer(text: streamingText)`. Every new token triggers full re-parsing of the accumulated text (splitting code blocks, re-parsing markdown). For long responses this becomes O(n^2).

**Fix:** Consider throttling updates or caching parsed segments.

### M5. OpenAI provider `validateHTTPResponse` called twice

**File:** `OpenAICompatibleProvider.swift:96-97`

```swift
let (bytes, response) = try await URLSession.shared.bytes(for: request)
try Self.validateHTTPResponse(response)
```

For streaming, if the server returns 401/429 as HTTP status with an SSE body, this correctly catches it before reading lines. Fine. But note: if the server returns 200 with an error in the SSE body (some providers do this), the error JSON lines are silently skipped by the `guard` on line 109-114.

### M6. No timeout handling for streaming

**Files:** `ChatService.swift`, `GeminiProvider.swift`, `OpenAICompatibleProvider.swift`

If the AI provider hangs after sending partial tokens (network issue, server stall), there's no timeout. The stream stays open indefinitely. `isStreaming` remains `true`, the UI shows the typing indicator forever. The only escape is manual cancellation.

**Fix:** Add a timeout wrapper or periodic liveness check.

### M7. ChatPanel `maxSize` constraint is aggressive

**File:** `ChatPanel.swift:19`

```swift
maxSize = NSSize(width: 1400, height: 900)
```

On larger displays, users can't maximize the chat window. Consider removing `maxSize` or using screen-relative sizing.

---

## Low Priority

### L1. `handleDrop` dispatches to main manually — unnecessary in SwiftUI

**File:** `ChatInputView.swift:132`

```swift
DispatchQueue.main.async { addAttachment(from: url) }
```

The `loadItem` completion is on an arbitrary queue, so the dispatch is correct. Not a bug, just noting it works correctly.

### L2. `TypingIndicatorView` timer runs while not visible

**File:** `TypingIndicatorView.swift:7`

`Timer.publish` fires continuously. Since the view is conditionally shown only when `isStreaming && streamingText.isEmpty`, SwiftUI handles lifecycle, but the `autoconnect()` starts immediately on init, before the view may be visible.

### L3. Hardcoded dark code block color in markdown renderer

**File:** `ChatMarkdownRenderer.swift:29`

```swift
code.backgroundColor = Color(red: 0.067, green: 0.094, blue: 0.153)
```

Hardcoded dark color won't adapt to light mode.

Similarly, `AttachmentChip.swift:30`:
```swift
.background(Color(red: 0.122, green: 0.161, blue: 0.216))
```

---

## Verification of Known Hotfixes

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | Migration crash | **FIXED** | `ModelContainer+Config.swift:132-134` — no explicit migration plan, auto lightweight |
| 2 | Streaming hung | **FIXED** | `ChatService.swift:32` — `defer { isStreaming = false }` present |
| 3 | Gemini API error | **FIXED** | `GeminiProvider.swift:119-125` — single prompt string, no roles API |
| 4 | Wrong model | **FIXED** | `ChatView.swift:256-261` — `resolveChatMode()` queries DB for built-in "Chat" mode. No reference to `AIService.shared.currentMode` anywhere in chat code |
| 5 | UI issues | **FIXED** | Sidebar uses `underPageBackgroundColor`, main uses `windowBackgroundColor` |

---

## Edge Cases Found

1. **Session with no "Chat" mode in DB:** If user deletes the built-in Chat mode from settings, `resolveChatMode()` returns `nil`. Fallback in `createNewSession` uses hardcoded defaults. But `sendMessage` line 217-224 builds `AIModeData` with fallback to `session.provider`/`session.modelName` — this works but the system prompt falls back to a hardcoded string (line 270) instead of the session's stored mode.

2. **Concurrent ChatView instances:** `showChat()` creates a new ChatView each time (C1). If called rapidly, two ChatViews could both be streaming on the same session with the same `ModelContext`. SwiftData is not thread-safe for concurrent writes to the same context from different view hierarchies.

3. **Sort nil handling:** New sessions with `lastMessageAt = nil` sorted inconsistently (C3).

4. **ZAIProvider falls back to default `streamChat`:** `ZAIProvider` doesn't implement `streamChat`, so it uses the protocol extension's fallback that wraps `enhance()` in a stream. This means Chat with z.ai provider produces a single-shot response, not streaming. UI will show typing indicator then the full response at once. Not broken, but poor UX.

---

## Positive Observations

- Clean separation: `ChatService` is a focused streaming coordinator, not a god object
- `AIModeData` (Sendable value type) properly bridges `@Model` to async context
- `@MainActor` usage is consistent across repositories and service layer
- Cascade delete rule on `ChatSessionModel.messages` prevents orphaned messages on session delete
- `OpenAICompatibleProvider.isValidBaseURL` properly restricts to HTTPS (http only for localhost)
- File attachment validation (size limits, type restrictions) is solid
- Enter-to-send via NSTextView subclass is the correct approach for macOS

---

## Recommended Actions (Priority Order)

1. **[CRITICAL] Fix C1** — Stop recreating ChatView on every `showChat()` call
2. **[CRITICAL] Fix H3** — User message sent twice to AI (double in history)
3. **[HIGH] Fix H2** — Partial text lost on cancellation (`currentStreamText` cleared before read)
4. **[HIGH] Fix H5** — Attachments silently dropped in Gemini streaming
5. **[HIGH] Fix C3** — Sort tiebreaker for nil `lastMessageAt`
6. **[MEDIUM] Fix C2** — Cancel streaming on panel close/view disappear
7. **[MEDIUM] Fix M4** — Throttle markdown re-parsing during streaming
8. **[MEDIUM] Fix H4** — Log save errors instead of swallowing
9. **[LOW] Fix M1** — Remove dead `onNewChat` param from `ChatEmptyStateView`
10. **[LOW] Fix L3** — Use adaptive colors for code blocks

---

## Metrics

- Type Coverage: Good — `Sendable` compliance on transport types, `@MainActor` on UI/data layer
- Test Coverage: None observed for Chat feature (no test files in diff)
- Linting Issues: Minor (dead parameter M1)

---

## Unresolved Questions

1. Should Chat mode support changing the AI provider/model mid-conversation, or is it locked to the built-in "Chat" mode settings?
2. Is ZAIProvider's single-shot fallback for `streamChat` acceptable UX, or should z.ai be hidden from Chat mode?
3. Should there be a message limit per session to prevent unbounded history growth (token limits, performance)?
4. Is the `StrataMigrationPlan` enum (SchemaVersioning.swift:37-47) dead code now that the container doesn't reference it?
