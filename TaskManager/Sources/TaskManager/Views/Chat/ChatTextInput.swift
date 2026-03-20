import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// NSViewRepresentable wrapping NSTextView for Enter-to-send behavior.
/// Dynamically reports content height so SwiftUI sizes the frame to fit text.
struct ChatTextInput: NSViewRepresentable {
    @Binding var text: String
    @Binding var textHeight: CGFloat
    let onSend: () -> Void
    var onFileDrop: ((URL) -> Void)?

    /// Single line height (14pt font + inset)
    static let minContentHeight: CGFloat = 30

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = ChatNSTextView()

        textView.delegate = context.coordinator
        textView.onSend = onSend
        textView.onFileDrop = onFileDrop
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.textContainer?.widthTracksTextView = true
        textView.drawsBackground = false

        // Register all drag types matching EnhanceMe for broad compatibility
        textView.registerForDraggedTypes(ChatAttachmentHelper.dragTypes)

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear

        // Calculate initial height immediately so SwiftUI doesn't over-allocate
        DispatchQueue.main.async {
            context.coordinator.recalcHeight(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ChatNSTextView else { return }
        if textView.string != text {
            textView.string = text
            context.coordinator.recalcHeight(textView)
        }
        textView.onFileDrop = onFileDrop
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: ChatTextInput
        init(_ parent: ChatTextInput) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            recalcHeight(textView)
        }

        /// Calculate actual text content height and update binding
        @MainActor func recalcHeight(_ textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let inset = textView.textContainerInset
            let newHeight = max(
                ChatTextInput.minContentHeight,
                usedRect.height + inset.height * 2
            )
            parent.textHeight = newHeight
        }
    }
}

/// NSTextView subclass that intercepts Enter key, file drag & drop, and paste.
/// - Enter sends message; Shift+Enter inserts newline.
/// - File drops forwarded to onFileDrop callback instead of inserting path text.
/// - Cmd+V with images/PDFs creates attachment instead of pasting data.
class ChatNSTextView: NSTextView {
    var onSend: (() -> Void)?
    var onFileDrop: ((URL) -> Void)?

    override func keyDown(with event: NSEvent) {
        // Enter → send message (Shift+Enter → newline)
        if event.keyCode == 36 && !event.modifierFlags.contains(.shift) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            onSend?()
            return
        }
        // ESC → resign focus so window can handle close
        if event.keyCode == 53 {
            window?.makeFirstResponder(nil)
            return
        }
        super.keyDown(with: event)
    }

    // MARK: - Paste interception (screenshots, copied images/PDFs)

    override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general
        // If pasteboard has attachable content (file URLs, images, PDFs), handle as attachment
        if ChatAttachmentHelper.hasAttachableContent(pb) {
            // File URLs from Finder copy
            let urls = ChatAttachmentHelper.fileURLs(from: pb)
            if !urls.isEmpty {
                for url in urls { onFileDrop?(url) }
                return
            }
            // Pasted image/PDF data (screenshots, clipboard images)
            if let tempURL = ChatAttachmentHelper.savePastedImageData(from: pb) {
                onFileDrop?(tempURL)
                return
            }
        }
        // Fall through to normal text paste
        super.paste(sender)
    }

    // MARK: - Drag & Drop interception for files

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        if ChatAttachmentHelper.hasAttachableContent(sender.draggingPasteboard) { return .copy }
        return super.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        if ChatAttachmentHelper.hasAttachableContent(sender.draggingPasteboard) { return .copy }
        return super.draggingUpdated(sender)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard

        // Extract file URLs using robust readObjects approach
        let urls = ChatAttachmentHelper.fileURLs(from: pb)
        if !urls.isEmpty {
            for url in urls { onFileDrop?(url) }
            return true
        }

        // Handle raw image/PDF data drops
        if let tempURL = ChatAttachmentHelper.savePastedImageData(from: pb) {
            onFileDrop?(tempURL)
            return true
        }

        return super.performDragOperation(sender)
    }
}
