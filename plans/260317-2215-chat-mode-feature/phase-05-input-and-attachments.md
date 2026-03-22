# Phase 5 — Input & Attachments

## Context
- [plan.md](plan.md)
- [phase-03-chat-window-and-layout.md](phase-03-chat-window-and-layout.md)
- [AIEnhancementResult.swift](../../TaskManager/Sources/TaskManager/AI/Models/AIEnhancementResult.swift) — AIAttachment definition
- EnhanceMeView.swift — reference for drag-drop/paste patterns (~986 lines, read selectively)

## Overview
- **Priority:** P2
- **Status:** pending
- **Effort:** 3h
- **Depends on:** Phase 3 (chat window)

Build the chat input area: multi-line text field with auto-resize, send/stop buttons, file attachment support (drag-drop + paste + button), and keyboard shortcuts.

## Key Insights

- EnhanceMeView uses `NSViewRepresentable` wrapping `NSTextView` for drag-drop and paste interception. Chat input can use a simpler `TextEditor` with `.onDrop` and paste command override — the NSTextView complexity is for the two-column layout which chat doesn't need.
- `AIAttachment` already handles validation: max 10MB, max 4 files, supported types (PNG/JPEG/TIFF/PDF).
- Only Gemini supports attachments (`AIProviderType.supportsAnyAttachments`). Show attachment button conditionally.
- Keyboard: Enter sends, Shift+Enter inserts newline. This requires intercepting the key event since TextEditor treats Enter as newline by default.

## New Files

### `Views/Chat/ChatInputView.swift`

```swift
struct ChatInputView: View {
    @Binding var text: String
    @Binding var attachments: [AIAttachment]
    let isStreaming: Bool
    let supportsAttachments: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    @State private var textEditorHeight: CGFloat = 40
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Attachment preview strip
            if !attachments.isEmpty {
                attachmentPreviewStrip
            }

            // Input row
            HStack(alignment: .bottom, spacing: 8) {
                if supportsAttachments {
                    attachmentButton
                }

                // Text input with Enter-to-send
                ChatTextInput(
                    text: $text,
                    onSend: onSend,
                    isFocused: $isFocused
                )
                .frame(minHeight: 36, maxHeight: 120)

                sendOrStopButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "#111827"))
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    private var attachmentButton: some View {
        Button(action: pickFiles) {
            Image(systemName: "paperclip")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Attach files (images, PDFs)")
    }

    @ViewBuilder
    private var sendOrStopButton: some View {
        if isStreaming {
            Button(action: onStop) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        } else {
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.gray : Color(hex: "#8B5CF6")
                    )
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .keyboardShortcut(.return, modifiers: [])
        }
    }
}
```

### `Views/Chat/ChatTextInput.swift`

Custom text input that sends on Enter, newline on Shift+Enter.

```swift
import SwiftUI
import AppKit

/// NSViewRepresentable wrapping NSTextView for Enter-to-send behavior.
/// TextEditor doesn't support intercepting Enter without Shift modifier.
struct ChatTextInput: NSViewRepresentable {
    @Binding var text: String
    let onSend: () -> Void
    @FocusState.Binding var isFocused: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = ChatNSTextView()

        textView.delegate = context.coordinator
        textView.onSend = onSend
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .white
        textView.backgroundColor = .clear
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: ChatTextInput
        init(_ parent: ChatTextInput) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

/// NSTextView subclass that intercepts Enter key for send behavior.
class ChatNSTextView: NSTextView {
    var onSend: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        // Enter without Shift → send
        if event.keyCode == 36 && !event.modifierFlags.contains(.shift) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            onSend?()
            return
        }
        // Shift+Enter → insert newline (default behavior)
        super.keyDown(with: event)
    }
}
```

**Why NSViewRepresentable:** SwiftUI's `TextEditor` doesn't allow intercepting Return key without modifier. The NSTextView subclass is minimal — only overrides `keyDown`.

### Attachment Handling (within ChatInputView extension)

```swift
// MARK: - Attachments (ChatInputView extension)

extension ChatInputView {
    var attachmentPreviewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    AttachmentChip(
                        fileName: attachment.fileName,
                        kind: attachment.kind,
                        onRemove: { removeAttachment(attachment) }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .pdf]

        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            addAttachment(from: url)
        }
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url") { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    self.addAttachment(from: url)
                }
            }
        }
        return true
    }

    func addAttachment(from url: URL) {
        guard attachments.count < AIAttachment.maxAttachmentCount else { return }
        // Reuse existing AIAttachment validation logic
        // Build AIAttachment from URL, check size/type constraints
        // (exact construction follows AIAttachment's existing pattern)
    }

    func removeAttachment(_ attachment: AIAttachment) {
        attachments.removeAll { $0.id == attachment.id }
    }
}
```

### `Views/Chat/AttachmentChip.swift`

Small preview chip shown in the attachment strip.

```swift
struct AttachmentChip: View {
    let fileName: String
    let kind: AIAttachment.Kind
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: kind == .pdf ? "doc.fill" : "photo.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(fileName)
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(.primary)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: "#1F2937"))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
```

## Keyboard Shortcuts Summary

| Keys | Action |
|------|--------|
| Enter | Send message |
| Shift+Enter | Insert newline |
| Cmd+N | New chat session (handled by ChatView, Phase 6) |
| Escape | Close chat window |

## Implementation Steps

1. Create `ChatNSTextView` + `ChatTextInput.swift` (NSViewRepresentable)
2. Create `AttachmentChip.swift`
3. Create `ChatInputView.swift` with send/stop/attachment buttons
4. Wire attachment handling (pick, drop, remove)
5. Connect ChatInputView into ChatView from Phase 3
6. Build and verify compile
7. Manual test: type, Enter sends, Shift+Enter newlines, attach files

## Todo

- [ ] ChatTextInput (NSViewRepresentable with Enter-to-send)
- [ ] AttachmentChip preview
- [ ] ChatInputView layout (input + buttons + attachment strip)
- [ ] File picker integration
- [ ] Drag-and-drop support
- [ ] Wire into ChatView
- [ ] Build verification

## Success Criteria

- Enter sends message, Shift+Enter inserts newline
- Text field auto-resizes up to max height (120px), then scrolls internally
- Attachment button only visible when provider supports attachments
- Drag-drop files onto input area adds attachments
- Attachment chips show filename with remove button
- Max 4 attachments enforced, max 10MB per file
- Send button disabled when input is empty
- Stop button replaces send button during streaming

## Risk Assessment

- **NSViewRepresentable focus management** — NSTextView may not integrate seamlessly with SwiftUI focus system. Test tab navigation and initial focus on window open.
- **TIFF auto-conversion** — EnhanceMeView converts TIFF pastes to PNG. Same conversion should apply here if reusing `AIAttachment`. Verify during implementation.
