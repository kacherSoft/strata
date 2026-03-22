# Phase 4 — Message Display & Streaming UI

## Context
- [plan.md](plan.md)
- [phase-02-streaming-provider-protocol.md](phase-02-streaming-provider-protocol.md)
- [phase-03-chat-window-and-layout.md](phase-03-chat-window-and-layout.md)
- [Design guidelines](../../docs/design-guidelines.md)

## Overview
- **Priority:** P2
- **Status:** pending
- **Effort:** 4h
- **Depends on:** Phase 2 (streaming), Phase 3 (window layout)

Build the message display area: scrollable message list, user/assistant bubbles, markdown rendering, auto-scroll during streaming, copy button, stop generation, and typing indicator.

## Key Insights

- SwiftUI `ScrollViewReader` + `scrollTo(id:anchor:)` handles auto-scroll. Scroll to last message ID on each stream chunk.
- User can scroll up to read history — disable auto-scroll when user scrolls away from bottom. Re-enable when new message sent.
- `AttributedString(markdown:)` handles basic markdown (bold, italic, inline code, links, lists). Code blocks need custom parsing.
- Design system: dark bg `#0A0E17`, user bubble uses accent gradient, assistant bubble uses `#1F2937` (bg-tertiary).

## New Files

### `Views/Chat/ChatMessageListView.swift`

Scrollable message list with auto-scroll during streaming.

```swift
struct ChatMessageListView: View {
    let messages: [ChatMessageModel]
    let streamingText: String    // live text from ChatService
    let isStreaming: Bool
    let onCopy: (String) -> Void
    let onStopGeneration: () -> Void

    @State private var isAutoScrollEnabled = true

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        ChatMessageBubble(
                            role: message.role,
                            content: message.content,
                            createdAt: message.createdAt,
                            onCopy: { onCopy(message.content) }
                        )
                        .id(message.id)
                    }

                    // Streaming assistant message (not yet persisted)
                    if isStreaming && !streamingText.isEmpty {
                        ChatMessageBubble(
                            role: .assistant,
                            content: streamingText,
                            createdAt: Date(),
                            isStreaming: true,
                            onCopy: { onCopy(streamingText) }
                        )
                        .id("streaming")
                    }

                    // Typing indicator (before first token arrives)
                    if isStreaming && streamingText.isEmpty {
                        TypingIndicatorView()
                            .id("typing")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: streamingText) { _, _ in
                guard isAutoScrollEnabled else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    let target: any Hashable = streamingText.isEmpty ? "typing" : "streaming"
                    proxy.scrollTo(target as AnyHashable, anchor: .bottom)
                }
            }
            .onChange(of: messages.count) { _, _ in
                guard isAutoScrollEnabled else { return }
                if let lastId = messages.last?.id {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }
}
```

**Auto-scroll logic:**
- `isAutoScrollEnabled` starts true
- On scroll gesture that moves away from bottom → set to false
- On new user message sent → reset to true
- Keep it simple for v1 — can add GeometryReader-based bottom detection later if needed

### `Views/Chat/ChatMessageBubble.swift`

Individual message bubble — different styling for user vs assistant.

```swift
struct ChatMessageBubble: View {
    let role: ChatMessageRole
    let content: String
    let createdAt: Date
    var isStreaming: Bool = false
    let onCopy: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if role == .assistant {
                assistantAvatar
            }

            VStack(alignment: role == .user ? .trailing : .leading, spacing: 4) {
                bubbleContent
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if isHovering && !isStreaming {
                    messageActions
                }
            }
            .frame(maxWidth: 600, alignment: role == .user ? .trailing : .leading)

            if role == .user {
                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: role == .user ? .trailing : .leading)
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        ChatMarkdownRenderer(text: content)
            .foregroundStyle(Color(hex: "#F9FAFB"))
            .textSelection(.enabled)
    }

    @ViewBuilder
    private var bubbleBackground: some ShapeStyle {
        // User: accent gradient. Assistant: tertiary bg
        if role == .user {
            LinearGradient(
                colors: [Color(hex: "#6366F1"), Color(hex: "#8B5CF6")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color(hex: "#1F2937")
        }
    }

    private var assistantAvatar: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 14))
            .foregroundStyle(.purple)
            .frame(width: 28, height: 28)
            .background(Color(hex: "#1F2937"))
            .clipShape(Circle())
    }

    private var messageActions: some View {
        Button(action: onCopy) {
            Label("Copy", systemImage: "doc.on.doc")
                .font(.caption2)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
}
```

**Styling notes:**
- User messages: right-aligned, accent gradient background, no avatar
- Assistant messages: left-aligned, `#1F2937` background, sparkles avatar
- Max width 600px to prevent wall-of-text on wide windows
- Copy button appears on hover, hidden during streaming
- `textSelection(.enabled)` allows native text selection

### `Views/Chat/ChatMarkdownRenderer.swift`

Lightweight markdown rendering using `AttributedString`.

```swift
struct ChatMarkdownRenderer: View {
    let text: String

    var body: some View {
        if let attributed = parseMarkdown(text) {
            Text(attributed)
                .font(.system(size: 14))
        } else {
            Text(text)
                .font(.system(size: 14))
        }
    }

    private func parseMarkdown(_ input: String) -> AttributedString? {
        // Split into code blocks and regular text
        let parts = splitCodeBlocks(input)
        var result = AttributedString()

        for part in parts {
            if part.isCodeBlock {
                var code = AttributedString(part.content)
                code.font = .system(size: 13, design: .monospaced)
                code.backgroundColor = Color(hex: "#111827")
                result += AttributedString("\n")
                result += code
                result += AttributedString("\n")
            } else {
                if let md = try? AttributedString(markdown: part.content,
                    options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                    result += md
                } else {
                    result += AttributedString(part.content)
                }
            }
        }
        return result
    }

    private struct TextPart {
        let content: String
        let isCodeBlock: Bool
    }

    private func splitCodeBlocks(_ text: String) -> [TextPart] {
        // Split on ``` delimiters
        var parts: [TextPart] = []
        let components = text.components(separatedBy: "```")
        for (index, component) in components.enumerated() {
            let isCode = index % 2 == 1  // odd indices are code blocks
            let content = isCode
                ? component.drop(while: { !$0.isNewline }).dropFirst() // skip language tag line
                : component
            guard !content.isEmpty else { continue }
            parts.append(TextPart(content: String(content), isCodeBlock: isCode))
        }
        return parts
    }
}
```

**Scope for v1:**
- Bold, italic, inline code, links, lists — handled by `AttributedString(markdown:)`
- Code blocks (```) — monospaced font with dark background
- No syntax highlighting in v1 (YAGNI — add later if users request)
- Language tag after ``` is stripped but not used for highlighting

### `Views/Chat/TypingIndicatorView.swift`

Animated dots shown while waiting for first token.

```swift
struct TypingIndicatorView: View {
    @State private var dotIndex = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundStyle(.purple)
                .frame(width: 28, height: 28)
                .background(Color(hex: "#1F2937"))
                .clipShape(Circle())

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .opacity(dotIndex == index ? 1.0 : 0.3)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(hex: "#1F2937"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onReceive(timer) { _ in
            dotIndex = (dotIndex + 1) % 3
        }
    }
}
```

### `Views/Chat/StopGenerationButton.swift`

Floating button shown during streaming, positioned above the input area.

```swift
struct StopGenerationButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Stop generating", systemImage: "stop.circle.fill")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
```

## Integration with ChatView (Phase 3)

The `chatContent(sessionId:)` method in `ChatView` composes these views:

```swift
@ViewBuilder
private func chatContent(sessionId: UUID) -> some View {
    VStack(spacing: 0) {
        ChatMessageListView(
            messages: messagesForSession(sessionId),
            streamingText: chatService.currentStreamText,
            isStreaming: chatService.isStreaming,
            onCopy: { copyToClipboard($0) },
            onStopGeneration: { chatService.cancelStream() }
        )

        if chatService.isStreaming {
            StopGenerationButton { chatService.cancelStream() }
                .padding(.bottom, 4)
        }

        Divider()

        // ChatInputView (Phase 5)
        ChatInputView(/* ... */)
    }
}
```

## Implementation Steps

1. Create `ChatMarkdownRenderer.swift`
2. Create `TypingIndicatorView.swift`
3. Create `StopGenerationButton.swift`
4. Create `ChatMessageBubble.swift`
5. Create `ChatMessageListView.swift`
6. Wire into `ChatView.chatContent()` from Phase 3
7. Build and verify compile
8. Manual test: display sample messages, verify styling and scroll

## Todo

- [ ] ChatMarkdownRenderer with code block support
- [ ] TypingIndicatorView with animated dots
- [ ] StopGenerationButton
- [ ] ChatMessageBubble (user + assistant variants)
- [ ] ChatMessageListView with auto-scroll
- [ ] Integration with ChatView
- [ ] Build verification

## Success Criteria

- User messages appear right-aligned with gradient background
- Assistant messages appear left-aligned with sparkles avatar
- Streaming text appears incrementally in real-time
- Typing indicator shows before first token, disappears after
- Auto-scroll follows streaming, stops when user scrolls up
- Code blocks render in monospaced font with dark background
- Copy button appears on hover for completed messages
- Stop button cancels generation mid-stream

## Risk Assessment

- **AttributedString markdown limitations** — `AttributedString(markdown:)` doesn't handle all GFM features (tables, task lists). Acceptable for v1 — covers 90% of chat output.
- **ScrollView performance with long conversations** — `LazyVStack` handles this. If conversations exceed ~500 messages, consider pagination (YAGNI for now).
- **Auto-scroll jank** — `scrollTo` with animation can cause visual judder during fast streaming. Use short animation duration (0.15s) and debounce if needed.
