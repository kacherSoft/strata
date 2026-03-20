import SwiftUI

/// Single row in the chat session sidebar list.
/// Switches between display mode and inline rename text field.
struct SessionRow: View {
    let session: ChatSessionModel
    let isEditing: Bool
    @Binding var editingTitle: String
    let onCommitRename: () -> Void
    let onCancelRename: () -> Void

    var body: some View {
        if isEditing {
            TextField("Chat title", text: $editingTitle, onCommit: onCommitRename)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .onExitCommand(perform: onCancelRename)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                if let lastMessage = session.lastMessageAt {
                    Text(lastMessage, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }
}
