import SwiftUI

/// Small chip showing an attached file with a remove button.
/// Displayed in the horizontal scroll strip above the chat input.
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
        .background(Color(red: 0.122, green: 0.161, blue: 0.216)) // #1F2937
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
