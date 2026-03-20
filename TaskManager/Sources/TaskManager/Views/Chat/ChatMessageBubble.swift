import SwiftUI

/// Chat message row — user messages right-aligned with accent bubble,
/// assistant messages left-aligned with avatar and flat text (ChatGPT/Claude style).
struct ChatMessageBubble: View {
    let role: ChatMessageRole
    let content: String
    let createdAt: Date
    var attachmentPaths: [String] = []
    var isStreaming: Bool = false
    let onCopy: () -> Void

    @State private var isHovering = false

    var body: some View {
        if role == .user {
            userMessage
        } else {
            assistantMessage
        }
    }

    // MARK: - User Message (right-aligned blue bubble)

    private var userMessage: some View {
        HStack {
            Spacer(minLength: 80)
            VStack(alignment: .trailing, spacing: 6) {
                // Attachment indicators above message text
                if !attachmentPaths.isEmpty {
                    attachmentIndicators
                }
                Text(content)
                    .textSelection(.enabled)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    // MARK: - Assistant Message (left-aligned, flat, with avatar)

    private var assistantMessage: some View {
        HStack(alignment: .top, spacing: 10) {
            // Avatar
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26, height: 26)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                ChatMarkdownRenderer(text: content)
                    .textSelection(.enabled)
                    .foregroundStyle(Color(nsColor: .labelColor))

                // Action buttons on hover
                if isHovering && !isStreaming {
                    HStack(spacing: 12) {
                        Button(action: onCopy) {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.trailing, 40)
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }

    // MARK: - Attachment Indicators

    private var attachmentIndicators: some View {
        HStack(spacing: 6) {
            ForEach(attachmentPaths, id: \.self) { path in
                let fileName = URL(fileURLWithPath: path).lastPathComponent
                let isPDF = path.lowercased().hasSuffix(".pdf")
                HStack(spacing: 4) {
                    Image(systemName: isPDF ? "doc.fill" : "photo.fill")
                        .font(.caption2)
                    Text(fileName)
                        .font(.caption2)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(.white.opacity(0.9))
            }
        }
    }
}
