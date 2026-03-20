import AppKit
import UniformTypeIdentifiers

/// Shared attachment creation logic for Chat UI — eliminates duplication between
/// ChatInputView, ChatView, and ChatNSTextView drag/drop/paste handlers.
enum ChatAttachmentHelper {

    /// Supported drag pasteboard types — matches EnhanceMe for broad compatibility.
    static let dragTypes: [NSPasteboard.PasteboardType] = [
        .fileURL,
        .URL,
        .pdf,
        .png,
        .tiff,
        NSPasteboard.PasteboardType("public.file-url"),
        NSPasteboard.PasteboardType("public.url"),
        NSPasteboard.PasteboardType("NSFilenamesPboardType")
    ]

    /// Supported file extensions for attachment.
    static let supportedExtensions: Set<String> = ["png", "jpg", "jpeg", "tiff", "tif", "heic", "pdf"]

    /// Create an AIAttachment from a file URL, or nil if unsupported/too large.
    static func makeAttachment(from url: URL, currentCount: Int) -> AIAttachment? {
        guard currentCount < AIAttachment.maxAttachmentCount else { return nil }

        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int,
              size <= AIAttachment.maxFileSizeBytes else { return nil }

        let ext = url.pathExtension.lowercased()
        guard supportedExtensions.contains(ext) else { return nil }

        let kind: AIAttachment.Kind
        let mimeType: String
        switch ext {
        case "png":              kind = .image; mimeType = "image/png"
        case "jpg", "jpeg":      kind = .image; mimeType = "image/jpeg"
        case "tiff", "tif":      kind = .image; mimeType = "image/tiff"
        case "heic":             kind = .image; mimeType = "image/heic"
        case "pdf":              kind = .pdf;   mimeType = "application/pdf"
        default: return nil
        }

        return AIAttachment(
            id: UUID(), kind: kind, fileURL: url,
            mimeType: mimeType, fileName: url.lastPathComponent, byteCount: size
        )
    }

    /// Extract file URLs from a pasteboard (drag or clipboard — handles multiple formats).
    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        var results: [URL] = []

        // Method 1: readObjects (works for drag & drop)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
            results = urls.filter { $0.isFileURL }
        }

        // Method 2: propertyList (works for Finder copy/paste)
        if results.isEmpty, let urlString = pasteboard.propertyList(forType: .fileURL) as? String,
           let url = URL(string: urlString), url.isFileURL {
            results = [url]
        }

        // Method 3: NSFilenamesPboardType (legacy Finder)
        if results.isEmpty, let paths = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            results = paths.compactMap { URL(fileURLWithPath: $0) }
        }

        return results.filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
    }

    /// Save pasted image data (PNG/TIFF from clipboard) to a temp file and return URL.
    /// Converts TIFF (macOS screenshot format) to PNG automatically.
    static func savePastedImageData(from pasteboard: NSPasteboard) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StrataChatAttachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Try PNG data first
        if let pngData = pasteboard.data(forType: .png) {
            let url = tempDir.appendingPathComponent("\(UUID().uuidString).png")
            try? pngData.write(to: url)
            return url
        }

        // Try TIFF data (macOS screenshots) — convert to PNG
        if let tiffData = pasteboard.data(forType: .tiff),
           let imageRep = NSBitmapImageRep(data: tiffData),
           let pngData = imageRep.representation(using: .png, properties: [:]) {
            let url = tempDir.appendingPathComponent("\(UUID().uuidString).png")
            try? pngData.write(to: url)
            return url
        }

        // Try PDF data
        if let pdfData = pasteboard.data(forType: .pdf) {
            let url = tempDir.appendingPathComponent("\(UUID().uuidString).pdf")
            try? pdfData.write(to: url)
            return url
        }

        return nil
    }

    /// Check if pasteboard contains file URLs with supported extensions.
    static func hasAttachableContent(_ pasteboard: NSPasteboard) -> Bool {
        guard let types = pasteboard.types else { return false }
        return types.contains(.fileURL) || types.contains(.png)
            || types.contains(.tiff) || types.contains(.pdf)
    }
}
