import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Chat input card matching Claude Desktop layout:
/// ┌──────────────────────────────────────┐
/// │ [Attachment chips]                   │
/// │ [Text input area]                    │
/// │──────────────────────────────────────│
/// │ [+]        [model ▾]           [↑]   │
/// └──────────────────────────────────────┘
struct ChatInputView: View {
    @Binding var text: String
    @Binding var attachments: [AIAttachment]
    @Binding var selectedProviderId: UUID?
    @Binding var selectedModelName: String
    let isStreaming: Bool
    let supportsAttachments: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    @State private var textHeight: CGFloat = ChatTextInput.minContentHeight

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }

    var body: some View {
        VStack(spacing: 0) {
            // Input card
            VStack(spacing: 0) {
                // Attachment chips (above text area, inside card)
                if !attachments.isEmpty {
                    attachmentPreviewStrip
                }

                // Text input area
                ChatTextInput(text: $text, textHeight: $textHeight, onSend: onSend, onFileDrop: { url in
                    addAttachment(from: url)
                })
                .frame(height: min(textHeight, 120))
                .padding(.horizontal, 8)
                .padding(.top, 6)

                // Bottom bar: [+] ... [model ▾] ... [send/stop]
                HStack(spacing: 8) {
                    // Attach button
                    if supportsAttachments {
                        Button(action: pickFiles) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 26, height: 26)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Attach files")
                    }

                    Spacer()

                    // Model selector
                    ChatModelSelectorView(
                        selectedProviderId: $selectedProviderId,
                        selectedModelName: $selectedModelName
                    )

                    // Send / Stop button
                    actionButton
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .padding(.top, 4)
        }
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isStreaming {
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11))
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
                    .font(.system(size: 13, weight: .semibold))
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
            .padding(.horizontal, 10)
            .padding(.top, 8)
        }
    }

    // MARK: - Actions

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .pdf]
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { addAttachment(from: url) }
    }

    private func addAttachment(from url: URL) {
        if let attachment = ChatAttachmentHelper.makeAttachment(from: url, currentCount: attachments.count) {
            attachments.append(attachment)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
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
