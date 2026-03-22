import SwiftUI

/// Scrollable message list with auto-scroll during streaming.
/// Uses LazyVStack for performance on long conversations.
struct ChatMessageListView: View {
    let messages: [ChatMessageModel]
    let streamingText: String
    let isStreaming: Bool
    let onCopy: (String) -> Void
    let onStopGeneration: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        ChatMessageBubble(
                            role: message.role,
                            content: message.content,
                            createdAt: message.createdAt,
                            attachmentPaths: message.attachmentPaths,
                            onCopy: { onCopy(message.content) }
                        )
                        .id(message.id)
                    }

                    // Live streaming assistant message (not yet persisted)
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

                    // Typing indicator shown before first token arrives
                    if isStreaming && streamingText.isEmpty {
                        TypingIndicatorView()
                            .id("typing")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: streamingText) { _, _ in
                let target: String = streamingText.isEmpty ? "typing" : "streaming"
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(target, anchor: .bottom)
                }
            }
            .onChange(of: messages.count) { _, _ in
                if let lastId = messages.last?.id {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }
}
