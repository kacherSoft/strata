import SwiftUI
import SwiftData
import AppKit
import TaskManagerUIComponents

struct EnhanceMeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Query(sort: \AIModeModel.sortOrder) private var modes: [AIModeModel]

    @State private var aiService = AIService.shared
    @State private var originalText: String
    @State private var enhancedText = ""
    @State private var displayedText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCopiedIndicator = false
    @State private var shouldFocusTextField = false
    @State private var attachments: [AIAttachment] = []
    @State private var toastMessage: String?
    @State private var toastStyle: ToastStyle = .info
    @State private var typewriterTimer: Timer?
    
    let initialText: String
    var onDismiss: () -> Void
    
    init(initialText: String = "", onDismiss: @escaping () -> Void) {
        self.initialText = initialText
        self._originalText = State(initialValue: initialText)
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentView
            Divider()
            footerView
        }
        .frame(minWidth: 500, idealWidth: 700, minHeight: 400, idealHeight: 500)
        .background(.ultraThickMaterial)
        .onAppear {
            aiService.loadDefaultMode(from: modelContext)
            shouldFocusTextField = true
        }
        .onDisappear {
            cleanupAttachments()
            typewriterTimer?.invalidate()
            typewriterTimer = nil
        }
        .onChange(of: subscriptionService.hasFullAccess) { _, hasAccess in
            if !hasAccess {
                cleanupAttachments()
            }
        }
        .onChange(of: aiService.currentMode?.id) { _, _ in
            if !currentModeSupportsAttachments {
                cleanupAttachments()
            }
        }
        .overlay(alignment: .bottom) {
            if let toastMessage {
                ToastView(message: toastMessage, style: toastStyle)
                    .padding(.bottom, 12)
                    .padding(.horizontal, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toastMessage)
        .background(EnhanceMeShortcutHandler(onCycleMode: {
            aiService.cycleMode(in: modelContext)
        }))
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 16) {
            Text("Enhance Me")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            modeSelector
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var modeSelector: some View {
        HStack(spacing: 12) {
            if let mode = aiService.currentMode {
                HStack(spacing: 6) {
                    Text(mode.name)
                        .fontWeight(.medium)
                    if mode.supportsAttachments && mode.provider.supportsAnyAttachments && subscriptionService.hasFullAccess {
                        Image(systemName: "paperclip")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(mode.provider.displayName) \(mode.modelName)")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("No Mode")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            
            Button(action: {
                aiService.cycleMode(in: modelContext)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Tab")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .help("Cycle Mode (Tab)")
        }
    }
    
    // MARK: - Content
    
    private var contentView: some View {
        HStack(spacing: 0) {
            originalColumn
            
            Divider()
            
            enhancedColumn
        }
    }
    
    private var originalColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Original")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            EnhanceTextEditor(
                text: $originalText,
                shouldFocus: shouldFocusTextField,
                attachmentsEnabled: currentModeSupportsAttachments,
                onSubmit: { enhance() },
                onPasteAttachment: { attachment in
                    if attachment.kind == .image && !currentModeSupportsImages {
                        try? FileManager.default.removeItem(at: attachment.fileURL)
                        errorMessage = "Current mode does not support image attachments."
                        return
                    }
                    if attachment.kind == .pdf && !currentModeSupportsPDFs {
                        try? FileManager.default.removeItem(at: attachment.fileURL)
                        errorMessage = "Current mode does not support PDF attachments."
                        return
                    }
                    guard attachments.count < AIAttachment.maxAttachmentCount else {
                        try? FileManager.default.removeItem(at: attachment.fileURL)
                        errorMessage = "You can attach up to \(AIAttachment.maxAttachmentCount) files."
                        return
                    }
                    attachments.append(attachment)
                    errorMessage = nil
                },
                onUnsupportedAttachment: { message in
                    showToast(message, style: .error)
                }
            )
            .padding(8)
            .background(.background.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if currentModeSupportsAttachments {
                attachmentBar
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var attachmentBar: some View {
        if attachments.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "paperclip")
                    .font(.caption2)
                Text(currentModeSupportsAttachments ? "Drop or paste image/PDF" : attachmentSupportMessage)
                    .font(.caption2)
            }
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 4)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(attachments) { attachment in
                        AttachmentPill(attachment: attachment) {
                            withAnimation {
                                attachments.removeAll { $0.id == attachment.id }
                                try? FileManager.default.removeItem(at: attachment.fileURL)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var enhancedColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Enhanced")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if showCopiedIndicator {
                    Label("Copied!", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            
            ZStack {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Enhancing...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Try Again") {
                            errorMessage = nil
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if enhancedText.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                        Text("Press Enter or ⌘↩ to enhance")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TextEditor(text: displayedText.isEmpty ? $enhancedText : $displayedText)
                        .scrollContentBackground(.hidden)
                        .font(.body)
                        .padding(8)
                        .background(.background.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .disabled(!displayedText.isEmpty)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: showCopiedIndicator)
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            if let mode = aiService.currentMode, !aiService.isConfigured(for: mode.provider) {
                Label("Configure \(mode.provider.displayName) API key in Settings", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            
            Spacer()
            
            Button("Enhance") {
                enhance()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled((originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty) || isLoading || aiService.currentMode == nil || !isCurrentModeConfigured)
        }
        .padding()
    }
    
    private var isCurrentModeConfigured: Bool {
        guard let mode = aiService.currentMode else { return false }
        return aiService.isConfigured(for: mode.provider)
    }

    private var currentModeSupportsAttachments: Bool {
        guard let mode = aiService.currentMode else { return false }
        return mode.supportsAttachments && mode.provider.supportsAnyAttachments && subscriptionService.hasFullAccess
    }

    private var attachmentSupportMessage: String {
        guard let mode = aiService.currentMode else { return "Select a mode to enable attachments" }
        if !subscriptionService.hasFullAccess {
            return "Upgrade to Premium to use attachments"
        }
        if !mode.supportsAttachments {
            return "This mode has attachments disabled"
        }
        if !mode.provider.supportsAnyAttachments {
            return "\(mode.provider.displayName) does not support attachments"
        }
        return "Attachments not available"
    }

    private var currentModeSupportsImages: Bool {
        guard let mode = aiService.currentMode else { return false }
        return mode.supportsAttachments && mode.provider.supportsImageAttachments && subscriptionService.hasFullAccess
    }

    private var currentModeSupportsPDFs: Bool {
        guard let mode = aiService.currentMode else { return false }
        return mode.supportsAttachments && mode.provider.supportsPDFAttachments && subscriptionService.hasFullAccess
    }
    
    // MARK: - Actions
    
    private func enhance() {
        guard let mode = aiService.currentMode else { return }

        let sendAttachments: [AIAttachment]
        if currentModeSupportsAttachments {
            sendAttachments = attachments.filter { attachment in
                switch attachment.kind {
                case .image: return currentModeSupportsImages
                case .pdf: return true
                }
            }
        } else {
            sendAttachments = []
        }

        let hasText = !originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasText || !sendAttachments.isEmpty else { return }
        guard isCurrentModeConfigured else { return }

        isLoading = true
        errorMessage = nil
        showCopiedIndicator = false
        displayedText = ""

        Task {
            do {
                let result = try await aiService.enhance(text: originalText, attachments: sendAttachments, mode: mode)
                enhancedText = result.enhancedText
                startTypewriterAnimation(for: result.enhancedText)
                copyToClipboard(result.enhancedText)
            } catch let error as AIError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    private func startTypewriterAnimation(for text: String) {
        typewriterTimer?.invalidate()
        typewriterTimer = nil
        displayedText = ""
        
        Task { @MainActor in
            let characters = Array(text)
            var index = 0
            let batchSize = 5 // Characters per update for smoother rendering

            while index < characters.count {
                let endIndex = min(index + batchSize, characters.count)
                let chunk = characters[index..<endIndex]
                displayedText += String(chunk)
                index = endIndex

                // Allow UI to update before continuing
                try? await Task.sleep(nanoseconds: 8_000_000) // 8ms
            }
            
            // Animation complete - sync back to enhancedText for editing
            enhancedText = displayedText
            displayedText = ""
        }
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        withAnimation {
            showCopiedIndicator = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedIndicator = false
            }
        }
    }

    private func cleanupAttachments() {
        for attachment in attachments {
            try? FileManager.default.removeItem(at: attachment.fileURL)
        }
        attachments.removeAll()
    }

    private func showToast(_ message: String, style: ToastStyle = .info) {
        withAnimation {
            toastStyle = style
            toastMessage = message
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if toastMessage == message {
                withAnimation {
                    toastMessage = nil
                }
            }
        }
    }
}


private struct AttachmentPill: View {
    let attachment: AIAttachment
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Group {
                if attachment.kind == .image, let image = NSImage(contentsOf: attachment.fileURL) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 24, height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: attachment.kind == .pdf ? "doc.fill" : "photo.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(attachment.fileName)
                    .font(.caption2)
                    .lineLimit(1)
                Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.byteCount), countStyle: .file))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Custom TextEditor with Enter handling

struct EnhanceMeShortcutHandler: NSViewRepresentable {
    var onCycleMode: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = EnhanceMeShortcutNSView()
        view.onCycleMode = onCycleMode
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? EnhanceMeShortcutNSView)?.onCycleMode = onCycleMode
    }
}

final class EnhanceMeShortcutNSView: KeyEventMonitorNSView {
    var onCycleMode: (() -> Void)?

    override func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard window?.isKeyWindow == true else { return event }
        if event.keyCode == 48 && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [] {
            onCycleMode?()
            return nil
        }
        return event
    }
}

final class EnhanceDragClipView: NSClipView {
    weak var enhanceTextView: EnhanceNSTextView?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        enhanceTextView?.draggingEntered(sender) ?? []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        enhanceTextView?.draggingUpdated(sender) ?? []
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        enhanceTextView != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        enhanceTextView?.performDragOperation(sender) ?? false
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        if let sender {
            enhanceTextView?.concludeDragOperation(sender)
        }
        super.concludeDragOperation(sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        if let sender {
            enhanceTextView?.draggingExited(sender)
        }
        super.draggingExited(sender)
    }
}

final class EnhanceNSTextView: NSTextView {
    var onPasteAttachment: ((AIAttachment) -> Void)?
    var onUnsupportedAttachment: ((String) -> Void)?
    var attachmentsEnabled = false

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        configureDragTypes()
    }

    convenience init() {
        let textContainer = NSTextContainer(size: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)
        self.init(frame: .zero, textContainer: textContainer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureDragTypes()
    }

    private func configureDragTypes() {
        registerForDraggedTypes([
            .fileURL,
            .URL,
            .pdf,
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("public.url"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ])
    }

    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
        let superTypes = super.readablePasteboardTypes
        let imageTypes: [NSPasteboard.PasteboardType] = [
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.jpeg-2000"),
            NSPasteboard.PasteboardType("public.heic"),
            .pdf,
            .fileURL,
            .URL
        ]
        return superTypes + imageTypes
    }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(paste(_:)) {
            if attachmentsEnabled {
                let pasteboard = NSPasteboard.general
                
                // Check for raw image data types
                if let types = pasteboard.types {
                    let imageTypes: Set<NSPasteboard.PasteboardType> = [
                        .png, .tiff, .pdf,
                        NSPasteboard.PasteboardType("public.jpeg"),
                        NSPasteboard.PasteboardType("public.jpeg-2000"),
                        NSPasteboard.PasteboardType("public.heic")
                    ]
                    if types.contains(where: { imageTypes.contains($0) }) {
                        return true
                    }
                }
                
                // Check for file URLs (including images)
                if !supportedAttachmentFileURLs(from: pasteboard).isEmpty {
                    return true
                }
            }
        }
        return super.validateUserInterfaceItem(item)
    }

    override func paste(_ sender: Any?) {
        guard attachmentsEnabled else {
            super.paste(sender)
            return
        }

        if handlePasteboardAttachment(NSPasteboard.general) {
            return
        }

        super.paste(sender)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard attachmentsEnabled else { return super.draggingEntered(sender) }
        guard canReadAttachments(from: sender.draggingPasteboard) else { return [] }
        let mask = sender.draggingSourceOperationMask.intersection([.copy, .generic])
        return mask.isEmpty ? [] : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard attachmentsEnabled else { return super.draggingUpdated(sender) }
        guard canReadAttachments(from: sender.draggingPasteboard) else { return [] }
        let mask = sender.draggingSourceOperationMask.intersection([.copy, .generic])
        return mask.isEmpty ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard attachmentsEnabled else { return super.performDragOperation(sender) }
        return handlePasteboardAttachment(sender.draggingPasteboard)
    }

    private func canReadAttachments(from pasteboard: NSPasteboard) -> Bool {
        if !supportedAttachmentFileURLs(from: pasteboard).isEmpty {
            return true
        }

        let supportedTypes: [NSPasteboard.PasteboardType] = [
            .fileURL,
            .URL,
            .pdf,
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("public.url"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ]
        return pasteboard.availableType(from: supportedTypes) != nil
    }

    private func handlePasteboardAttachment(_ pasteboard: NSPasteboard) -> Bool {
        let supportedURLs = supportedAttachmentFileURLs(from: pasteboard)
        if !supportedURLs.isEmpty {
            return supportedURLs.contains { handleFileURL($0) }
        }

        let urls = fileURLs(from: pasteboard)
        if !urls.isEmpty {
            onUnsupportedAttachment?("Unsupported file extension. Only PNG, JPG, JPEG, TIFF, HEIC, and PDF are supported.")
            NSSound.beep()
            return true
        }

        if let pdfData = pasteboard.data(forType: .pdf) {
            handlePDFPaste(pdfData)
            return true
        }

        if let (imageData, mimeType) = pasteboardImageData(from: pasteboard) {
            handleImagePaste(imageData, mimeType: mimeType)
            return true
        }

        return false
    }

    private func supportedAttachmentFileURLs(from pasteboard: NSPasteboard) -> [URL] {
        fileURLs(from: pasteboard).filter { isSupportedAttachmentURL($0) }
    }

    private func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
            NSPasteboard.ReadingOptionKey(rawValue: "NSPasteboardURLReadingSecurityScopedFileURLsKey"): true
        ]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL], !urls.isEmpty {
            return urls
        }
        if let fileURLString = pasteboard.string(forType: .fileURL), let fileURL = URL(string: fileURLString) {
            return [fileURL]
        }
        if let urlString = pasteboard.string(forType: .URL), let fileURL = URL(string: urlString), fileURL.isFileURL {
            return [fileURL]
        }
        return []
    }

    private func isSupportedAttachmentURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "tiff", "heic", "pdf"].contains(ext)
    }

    private func pasteboardImageData(from pasteboard: NSPasteboard) -> (Data, String)? {
        // Try PNG directly
        if let data = pasteboard.data(forType: .png) {
            return (data, "image/png")
        }
        // Try JPEG
        if let data = pasteboard.data(forType: NSPasteboard.PasteboardType("public.jpeg")) {
            return (data, "image/jpeg")
        }
        // Try TIFF (common for screenshots) - convert to PNG
        if let data = pasteboard.data(forType: .tiff) {
            if let image = NSImage(data: data),
               let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                return (pngData, "image/png")
            }
        }
        // Fallback: read as NSImage from pasteboard (handles various formats)
        if let image = NSImage(pasteboard: pasteboard) {
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                return (pngData, "image/png")
            }
        }
        return nil
    }

    private func handlePDFPaste(_ data: Data) {
        guard data.count <= AIAttachment.maxFileSizeBytes else {
            NSSound.beep()
            return
        }

        let fileName = "pasted-document-\(UUID().uuidString.prefix(8)).pdf"
        guard let attachment = saveToTemp(data: data, fileName: fileName, kind: .pdf, mimeType: "application/pdf") else {
            NSSound.beep()
            return
        }
        onPasteAttachment?(attachment)
    }

    private func handleImagePaste(_ data: Data, mimeType: String) {
        guard data.count <= AIAttachment.maxFileSizeBytes else {
            NSSound.beep()
            return
        }

        let ext = mimeType == "image/png" ? "png" : "jpg"
        let fileName = "pasted-image-\(UUID().uuidString.prefix(8)).\(ext)"
        guard let attachment = saveToTemp(data: data, fileName: fileName, kind: .image, mimeType: mimeType) else {
            NSSound.beep()
            return
        }
        onPasteAttachment?(attachment)
    }

    private func handleFileURL(_ url: URL) -> Bool {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let ext = url.pathExtension.lowercased()
        if ["png", "jpg", "jpeg", "tiff", "heic"].contains(ext) {
            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe), data.count <= AIAttachment.maxFileSizeBytes else { return false }
            let mimeType: String
            switch ext {
            case "png":
                mimeType = "image/png"
            case "jpg", "jpeg":
                mimeType = "image/jpeg"
            case "tiff":
                mimeType = "image/tiff"
            case "heic":
                mimeType = "image/heic"
            default:
                mimeType = "image/jpeg"
            }
            if let attachment = saveToTemp(data: data, fileName: url.lastPathComponent, kind: .image, mimeType: mimeType) {
                onPasteAttachment?(attachment)
                return true
            }
        } else if ext == "pdf" {
            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe), data.count <= AIAttachment.maxFileSizeBytes else { return false }
            if let attachment = saveToTemp(data: data, fileName: url.lastPathComponent, kind: .pdf, mimeType: "application/pdf") {
                onPasteAttachment?(attachment)
                return true
            }
        }
        return false
    }

    private func saveToTemp(data: Data, fileName: String, kind: AIAttachment.Kind, mimeType: String) -> AIAttachment? {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("EnhanceMeAttachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let safeFileName = "\(UUID().uuidString.prefix(8))-\(fileName)"
        let fileURL = tempDir.appendingPathComponent(safeFileName)

        do {
            try data.write(to: fileURL)
            return AIAttachment(
                id: UUID(),
                kind: kind,
                fileURL: fileURL,
                mimeType: mimeType,
                fileName: fileName,
                byteCount: data.count
            )
        } catch {
            return nil
        }
    }
}

struct EnhanceTextEditor: NSViewRepresentable {
    @Binding var text: String
    var shouldFocus: Bool
    var attachmentsEnabled: Bool
    var onSubmit: () -> Void
    var onPasteAttachment: ((AIAttachment) -> Void)?
    var onUnsupportedAttachment: ((String) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = EnhanceNSTextView()
        let clipView = EnhanceDragClipView()

        textView.delegate = context.coordinator
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.backgroundColor = NSColor.clear
        textView.drawsBackground = false
        textView.textColor = NSColor.labelColor
        textView.insertionPointColor = NSColor.labelColor
        textView.textContainerInset = NSSize(width: 4, height: 4)
        applyBaseTextAttributes(to: textView)
        textView.attachmentsEnabled = attachmentsEnabled
        textView.onPasteAttachment = onPasteAttachment
        textView.onUnsupportedAttachment = onUnsupportedAttachment

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        clipView.enhanceTextView = textView
        scrollView.contentView = clipView
        scrollView.documentView = textView

        let dragTypes: [NSPasteboard.PasteboardType] = [
            .fileURL,
            .URL,
            .pdf,
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("public.url"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ]
        clipView.registerForDraggedTypes(dragTypes)

        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? EnhanceNSTextView else { return }

        if textView.string != text {
            textView.string = text
            applyBaseTextAttributes(to: textView)
        }

        applyBaseTextAttributes(to: textView)
        textView.attachmentsEnabled = attachmentsEnabled
        textView.onPasteAttachment = onPasteAttachment
        textView.onUnsupportedAttachment = onUnsupportedAttachment

        if shouldFocus && !context.coordinator.hasFocused {
            context.coordinator.hasFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                scrollView.window?.makeFirstResponder(textView)
            }
        }
    }

    private func applyBaseTextAttributes(to textView: EnhanceNSTextView) {
        let baseFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let baseColor = NSColor.labelColor // Adapts to light/dark mode
        textView.typingAttributes[.font] = baseFont
        textView.typingAttributes[.foregroundColor] = baseColor
        textView.textColor = baseColor
        textView.insertionPointColor = NSColor.labelColor
        let fullRange = NSRange(location: 0, length: textView.string.utf16.count)
        if fullRange.length > 0 {
            textView.textStorage?.setAttributes([
                .font: baseFont,
                .foregroundColor: baseColor
            ], range: fullRange)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var onSubmit: () -> Void
        weak var textView: NSTextView?
        var hasFocused = false

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            _text = text
            self.onSubmit = onSubmit
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let event = NSApp.currentEvent
                if event?.modifierFlags.contains(.shift) == true {
                    return false
                }
                onSubmit()
                return true
            }
            return false
        }
    }
}
