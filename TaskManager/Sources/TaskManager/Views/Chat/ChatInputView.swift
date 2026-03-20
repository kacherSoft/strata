import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Modern chat input — rounded card with inline attachment button and send icon.
/// Inspired by ChatGPT / Claude desktop input style.
struct ChatInputView: View {
    @Binding var text: String
    @Binding var attachments: [AIAttachment]
    @Binding var selectedProviderId: UUID?
    @Binding var selectedModelName: String
    let isStreaming: Bool
    let supportsAttachments: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    /// Dynamic height reported by NSTextView content measurement
    @State private var textHeight: CGFloat = ChatTextInput.minContentHeight

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }

    var body: some View {
        VStack(spacing: 0) {
            // Attachment preview strip above input card
            if !attachments.isEmpty {
                attachmentPreviewStrip
            }

            // Input card — tight padding matching Claude/ChatGPT desktop
            HStack(alignment: .bottom, spacing: 0) {
                // Attach button (left side, inside card)
                if supportsAttachments {
                    Button(action: pickFiles) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Attach files (images, PDFs)")
                    .padding(.leading, 8)
                    .padding(.bottom, 4)
                }

                // Text input — explicit height from NSTextView content measurement
                ChatTextInput(text: $text, textHeight: $textHeight, onSend: onSend, onFileDrop: { url in
                    addAttachment(from: url)
                })
                    .frame(height: min(textHeight, 120))
                    .padding(.horizontal, 2)

                // Send / Stop button (right side, inside card)
                actionButton
                    .padding(.trailing, 8)
                    .padding(.bottom, 4)
            }
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, 2)

            // Model selector row — below the input card
            HStack(spacing: 6) {
                ChatModelSelectorView(
                    selectedProviderId: $selectedProviderId,
                    selectedModelName: $selectedModelName
                )
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .padding(.top, 2)
        }
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            var handled = false
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                        if let data = item as? Data,
                           let url = URL(dataRepresentation: data, relativeTo: nil) {
                            DispatchQueue.main.async { addAttachment(from: url) }
                        } else if let url = item as? URL {
                            DispatchQueue.main.async { addAttachment(from: url) }
                        }
                    }
                    handled = true
                }
            }
            return handled
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isStreaming {
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Stop generating")
        } else {
            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(canSend ? Color.accentColor : Color.gray.opacity(0.4))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .help("Send message (Enter)")
        }
    }

    private var attachmentPreviewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    AttachmentChip(
                        fileName: attachment.fileName,
                        kind: attachment.kind,
                        onRemove: { attachments.removeAll { $0.id == attachment.id } }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    // MARK: - File Picking

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .pdf]
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            addAttachment(from: url)
        }
    }

    private func addAttachment(from url: URL) {
        if let attachment = ChatAttachmentHelper.makeAttachment(from: url, currentCount: attachments.count) {
            attachments.append(attachment)
        }
    }
}
